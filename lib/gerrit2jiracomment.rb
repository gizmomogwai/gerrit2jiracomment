# coding: utf-8
require "gerrit2jiracomment/version"
require 'logger'
require 'json'
require 'open3'
require 'ostruct'
require 'byebug'
require 'jira-ruby'
require 'yaml'
require 'rx'

module Gerrit2jiracomment
  def self.regexp
    return Regexp.new("\\b*[A-Z0-9]+-\\d+\\b*")
  end
  class ProcessException < Exception
    def initialize(msg)
      super(msg)
    end
  end
  class ToJira
    def initialize(jira)
      @jira = jira
    end
    def change_merged(logger, event, server)
      #if event.change.owner.email != "christian.koestlin@esrlabs.com"
      #  logger.debug("not doing anything its not christian")
      #  raise ProcessException('skipping merge, as it does not belong to christian')
      #end

      logger.debug("changeset†Send change merged to jira #{event}")
      commit_message = event.change.commitMessage
      logger.debug("changeset†found commit message: #{commit_message}")

      found = false
      commit_message.scan(Gerrit2jiracomment::regexp).each do |match|
        issue_comment = match.strip
        logger.debug("changeset†Found jira issue comment: '#{issue_comment}'")
        begin
          issue = @jira.Issue.find(issue_comment)
          comment = issue.comments.build
          uri = URI.parse(event.change.url)
          base_url = "#{uri.scheme}://#{uri.host}"
          link_to_changeset = "[changeset|#{event.change.url}]"
          link_to_commit = "[#{event.patchSet.revision}|#{base_url}/plugins/gitiles/#{event.change.project}/+/#{event.patchSet.revision}]"
          comment_text = "#{link_to_changeset} for #{event.change.branch}@#{server}/#{event.change.project} commit: #{link_to_commit}"
          logger.debug("changeset†Adding #{comment_text} to jira #{issue_comment}")
          comment.save!(body: comment_text)
          found = true
        rescue JIRA::HTTPError => e
          logger.error("changeset†Cannot find #{issue_comment} in our jira")
        end
      end

      if found
        return nil
      else
        raise ProcessException("changeset†No jira-issue found in #{event}")
      end
    end
  end

  def self.send_ref_update_to_jira(logger, gerrit, jira, ref_update_event, server)
    logger.debug("refupdate†Send ref update to jira #{ref_update_event}")
    ref_update = ref_update_event.refUpdate
    project = ref_update.project
    rev = ref_update.newRev
    branch = ref_update.refName
    logger.debug("regupdate†Getting the commit message for #{rev}@#{project}")
    c = gerrit.find_project_commit(project.gsub('/', '%2F'), rev)
    commit_message = c['message']
    logger.debug("refupdate†Found commit_message: #{commit_message}")

    logs = commit_message.scan(regexp).map do |issue_comment|
      logger.debug("refupdate†Found jira issue comment: #{issue_comment}")
      issue = jira.Issue.find(issue_comment)
      comments = issue.comments
      already_included = (0...comments.size).any? do |idx|
        comment = comments[idx]
        comment.body.include?(rev)
      end
      if already_included
        "refupdate†Not adding comment, because #{rev} is already included in comments for #{issue_comment}"
      else
        comment = comments.build

        base_url = 'http://gerrit'
        link_to_commit = "[#{rev}|#{base_url}/plugins/gitiles/#{project}/+/#{rev}]"
        comment_text = "Commit for #{branch}@#{server}/#{project}: #{link_to_commit}"
        comment.save!(body: comment_text)
        logger.debug("refupdate†Adding # comment #{comment_text} to jira #{issue_comment}")
        nil
      end
    end.compact

    logs.each do |log|
      logger.info(log)
    end

    return nil
  end
  def self.parse_json(line)
    JSON.parse(line, object_class: OpenStruct)
  end
  def self.simulate_gerrit(logger, sink)
    t = Thread.new do
      [
        #        '{"type":"patchset-created","uploader": {"name": "Christian Koestlin","email": "christian.koestlin@esrlabs.com","username": "christian.koestlin"},"patchSet": {"number": "1","revision": "ceafa8d99a435ef33d78fe9e878522689f26bfc8","parents": ["258bd6d82148cf0a40d60c02bebe983633f416a6"],"ref": "refs/changes/77/26077/1","uploader": {"name": "Christian Koestlin","email": "christian.koestlin@esrlabs.com","username": "christian.koestlin"},"createdOn": 1509084844,"author": {"name": "Christian Koestlin","email": "info@esrlabs.com","username": ""},"isDraft": false,"kind": "REWORK","sizeInsertions": 1,"sizeDeletions": 0},"change": {"project": "test/gerrit-playground","branch": "master","id": "Ibd51993552d6619922e9b0b6807f8a84b6ca0d2b","number": "26077","subject": "TESTSYNC-620 - .....","owner": {"name": "Christian Koestlin","email": "christian.koestlin@esrlabs.com","username": "christian.koestlin"},"url": "http://gerrit/26077","commitMessage": "TESTSYNC-620 - .....\n\nChange-Id: Ibd51993552d6619922e9b0b6807f8a84b6ca0d2b\n","status": "NEW"},"eventCreatedOn": 1509084844}'

        '{"type":"patchset-created","uploader": {"name": "Christian Koestlin","email": "christian.koestlin@esrlabs.com","username": "christian.koestlin"},"patchSet": {"number": "1","revision": "ceafa8d99a435ef33d78fe9e878522689f26bfc8","parents": ["258bd6d82148cf0a40d60c02bebe983633f416a6"],"ref": "refs/changes/77/26077/1","uploader": {"name": "Christian Koestlin","email": "christian.koestlin@esrlabs.com","username": "christian.koestlin"},"createdOn": 1509084844,"author": {"name": "Christian Koestlin","email": "info@esrlabs.com","username": ""},"isDraft": false,"kind": "REWORK","sizeInsertions": 1,"sizeDeletions": 0},"change": {"project": "test/gerrit-playground","branch": "master","id": "Ibd51993552d6619922e9b0b6807f8a84b6ca0d2b","number": "26077","subject": "TESTSYNC-620 - .....","owner": {"name": "Christian Koestlin","email": "christian.koestlin@esrlabs.com","username": "christian.koestlin"},"url": "http://gerrit/26077","commitMessage": "TESTSYNC-620 - .....\n\nChange-Id: Ibd51993552d6619922e9b0b6807f8a84b6ca0d2b\n","status": "NEW"},"eventCreatedOn": 1509084844}'
      ].each do |line|
        event = parse_json(line)
        sink.on_next([event, "gerrit"])
      end
    end
    return t
  end
  def self.receive_events(logger, from, sink)
    t = Thread.new do
      begin
        logger.debug("lifecycle†Connecting to event stream of #{from}")
        stdin, stdout, stderr = Open3.popen3("ssh #{from} gerrit stream-events")
        stdout.set_encoding 'UTF-8:UTF-8'
        stdout.each_line do |line|
          logger.debug("got string event: #{line}")
          event = JSON.parse(line, object_class: OpenStruct)
          # todo filter by author
          logger.debug("events†Received #{event}")
          sink.on_next([event, from])
        end
        logger.debug("lifecycle†Processing stream from #{from} finished")
      rescue => e
        logger.error("#{e}")
      end
    end
    return t
  end

  def self.dispatch(logger, e, sink)
    event = e.first
    server = e[1]
    begin
      sink.send(event.type.gsub("-", "_").to_sym, logger, event, server)
      logger.info("events†Finished processing")
    rescue NoMethodError => e
      logger.debug("events†Cannot handle event of type #{event.type}")
    rescue => error
      bt = error.backtrace.join("\n")
      logger.error("events†Cannot process event #{error} / #{bt}")
    end
  end

  def self.run()
    logger = Logger.new(STDOUT)
    logger.formatter = proc do |severity, datetime, progname, msg|
      tag, m = msg.split("†")
      if !m
        m = tag
        tag = "gerrit2jiracomment"
      end
      sprintf("%04d-%02d-%02d %02d:%02d:%02d.000 %s %s %s: %s\n",
              datetime.year, datetime.month, datetime.day, datetime.hour, datetime.min, datetime.sec,
              "7331", severity[0], tag, m)
    end

    settings = YAML.load(`gpg --decrypt settings.yaml.gpg 2> /dev/null`)
    logger.debug("lifecycle†Connecting to jira")

    subject = Rx::Subject.new
    source = subject.as_observable
    event_sink = ToJira.new(JIRA::Client.new({
                              username: settings['jira_user'],
                              password: settings['jira_password'],
                              site: 'https://esrlabs.atlassian.net/',
                              context_path: '',
                              auth_type: :basic,
                              use_ssl: true,
                              ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
                            }))
    source.subscribe(
      lambda {|e| dispatch(logger, e, event_sink)},
      lambda {|err| logger.error(error)},
      lambda { logger.info("lifecycle†finished")}
    )

    threads = []
    threads.push(receive_events(logger, "gerrit.int.esrlabs.com", subject))
    threads.push(receive_events(logger, "git.esrlabs.com", subject))
    threads.each { |t| t.join }
    logger.info("lifecycle†exiting")
  end
end
