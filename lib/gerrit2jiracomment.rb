# coding: utf-8
# frozen_string_literal: true

require 'gerrit2jiracomment/version'
require 'logger'
require 'syslog/logger'
require 'json'
require 'open3'
require 'ostruct'
require 'jira-ruby'
require 'yaml'
require 'rx'

# Gerrit 2 jira sync module
module Gerrit2jiracomment
  # wrapper for a logger that always adds tags
  class LoggerWithTag
    def initialize(log, tag)
      @log = log
      @tag = tag
    end

    def debug(message)
      @log.debug("#{@tag}†#{message}")
    end

    def info(message)
      @log.info("#{@tag}†#{message}")
    end

    def error(message, error)
      error_message = "#{error} #{error.backtrace.join('\\n\\t')}"
      @log.error("#{@tag}†#{message}: #{error_message}")
    end

    def fail(exception, message)
      raise(exception, "#{@tag}†#{message}")
    end
  end

  def self.regexp
    Regexp.new('\\b*[A-Z0-9]+-\\d+\\b*')
  end

  # Exception if something goes wrong with processing events
  class ProcessException < RuntimeError
    def initialize(msg)
      super(msg)
    end
  end

  # React on events by sending data to jira
  class ToJira
    def initialize(logger, jira)
      @logger = logger
      @jira = jira
    end

    def gitiles_url(base_url, event)
      gitiles = "#{base_url}/plugins/gitiles/"
      "[#{event.patchSet.revision}|" \
      "#{gitiles}#{event.change.project}/+/#{event.patchSet.revision}]"
    end

    def author_line(event)
      "Author: #{event.patchSet.author.email}"
    end

    def submitter_line(event)
      "Submitter: #{event.submitter.email}"
    end

    def commit_line(base_url, event)
      "Commit: #{gitiles_url(base_url, event)}"
    end

    def changeset_line(event)
      url = event.change.url
      "Changeset: [#{url}|#{url}]"
    end

    def branch_line(event)
      "Branch: #{event.change.branch}"
    end

    def project_line(server, event)
      "Project: #{server}/#{event.change.project}"
    end

    def title_line(event)
      "Title: #{event.change.subject}"
    end

    def assemble_change_merged_comment(event, server, uri)
      base_url = "#{uri.scheme}://#{uri.host}"
      [title_line(event), author_line(event), submitter_line(event),
       changeset_line(event), branch_line(event),
       project_line(server, event), commit_line(base_url, event)]
        .join("\n")
    end

    def handle_change_merged_issue_comment(issue, log, event, server)
      log.debug("Found jira issue comment: '#{issue}'")
      uri = URI.parse(event.change.url)
      comment_text = assemble_change_merged_comment(event, server, uri)
      log.debug("Adding #{comment_text} to jira #{issue}")
      @jira.Issue.find(issue).comments.build.save!(body: comment_text)
      true
    rescue JIRA::HTTPError => e
      log.error("Cannot find #{issue} in our jira", e)
      false
    end

    def change_merged(log, event, server)
      log = LoggerWithTag.new(log, 'changeset')

      log.debug("Send change merged to jira #{event}")

      message = event.change.commitMessage
      log.debug("Found commit: #{event.change.subject}\n#{message}")

      found = false
      message.scan(Gerrit2jiracomment.regexp).map(&:strip).each do |match|
        found = handle_change_merged_issue_comment(match, log, event, server) || found
      end

      found || log.fail(ProcessException, "No jira-issue found in #{event}")
    end
  end

  def self.parse_json(line)
    JSON.parse(line, object_class: OpenStruct)
  end

  def self.stdout_in_utf8(command)
    _stdin, stdout, _stderr = Open3.popen3(command)
    stdout.set_encoding 'UTF-8:UTF-8'
    stdout
  end

  def self.receive_events(logger, from, sink)
    Thread.new do
      logger.debug("lifecycle†Connecting to event stream of #{from}")
      stdout_in_utf8("ssh #{from} gerrit stream-events").each_line do |line|
        sink.on_next([JSON.parse(line, object_class: OpenStruct), from])
      end
      logger.debug("lifecycle†Processing stream from #{from} finished")
    rescue StandardError => e
      logger.error(e.to_s)
    end
  end

  def self.dispatch(log, event, sink)
    logger = LoggerWithTag.new(log, 'events')
    event, server = event
    logger.debug("#{event} from #{server}")
    sink.send(event.type.tr('-', '_').to_sym, log, event, server)
  rescue NoMethodError => e
    logger.debug("Cannot handle event of type #{event.type} - #{e}")
    false
  rescue StandardError => e
    logger.error('Cannot process event', e)
    false
  end

  def self.syslog_or_stdout_logger
    Syslog::Logger.new 'g2jc'
  rescue StandardError
    Logger.new(STDOUT)
  end

  def self.tag_and_message(msg)
    tag, m = msg.split('†')
    unless m
      m = tag
      tag = 'gerrit2jiracomment'
    end
    [tag, m]
  end

  def self.init_logger
    logger = syslog_or_stdout_logger
    logger.formatter = proc do |severity, datetime, _progname, msg|
      tag, message = tag_and_message(msg)
      format('%<year>04d-%<month>02d-%<day>02d %<hour>02d:%<min>02d:' \
             "%<sec>02d.000 7331 %<severity>s %<tag>s: %<message>s\n",
             year: datetime.year, month: datetime.month, day: datetime.day,
             hour: datetime.hour, min: datetime.min, sec: datetime.sec,
             severity: severity[0], tag: tag, message: message)
    end
    logger
  end

  def self.load_settings(logger)
    logger.debug('lifecycle†loading settings from settings.yaml.gpg')
    YAML.safe_load(`gpg --decrypt settings.yaml.gpg 2> /dev/null`)
  end

  def self.to_jira(logger, settings)
    ToJira.new(logger,
               JIRA::Client.new(
                 username: settings['jira_user'],
                 password: settings['jira_password'],
                 site: 'https://esrlabs.atlassian.net/',
                 context_path: '', auth_type: :basic,
                 use_ssl: true,
                 ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
               ))
  end

  def self.connect(logger, subject, event_sink)
    subject.as_observable.subscribe(
      ->(e) { dispatch(logger, e, event_sink) },
      ->(_err) { logger.error(error) },
      -> { logger.info('lifecycle†finished') }
    )
  end

  def self.hosts
    ['gerrit.int.esrlabs.com', 'git.esrlabs.com',
     'hcp5-sources.int.esrlabs.com']
  end

  def self.run
    logger = init_logger

    settings = load_settings(logger)

    subject = Rx::Subject.new
    event_sink = to_jira(logger, settings)

    connect(logger, subject, event_sink)
    hosts
      .map { |server| receive_events(logger, server, subject) }
      .each(&:join)
    logger.info('lifecycle†exiting')
  end
end
