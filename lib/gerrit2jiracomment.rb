require "gerrit2jiracomment/version"
require 'json'
require 'open3'
require 'ostruct'
require 'byebug'
require 'jira-ruby'
require 'colorize'
require 'gerry'
require 'yaml'

module Gerrit2jiracomment
  def self.regexp
    return Regexp.new("\\b[A-Z0-9]+-\\d+\\b")
  end
  def self.send_to_jira(jira, event)
    puts "Send to jira: #{event.change.url}".blue
    found = false
    event.change.commitMessage.scan(regexp).each do |match|
      issue_comment = match.first.strip
      puts "found jira issue comment: #{issue_comment}".blue
      begin
        issue = jira.Issue.find(issue_comment)
        comment = issue.comments.build
        uri = URI.parse(event.change.url)
        base_url = "#{uri.scheme}://#{uri.host}"
        link_to_changeset = "[changeset|#{event.change.url}]"
        link_to_commit = "[#{event.patchSet.revision}|#{base_url}/plugins/gitiles/#{event.change.project}/+/#{event.patchSet.revision}]"
        comment.save!(body: "#{link_to_changeset} for #{event.change.branch}@#{event.change.project} commit: #{link_to_commit}")
        found = true
      rescue JIRA::HTTPError => e
        puts "Cannot find #{issue_comment} in our jira".red
      end
    end
    if found
      return nil
    else
      return "No jira-issue found in #{event}"
    end
  end
  def self.send_ref_update_to_jira(gerrit, jira, ref_update_event)
    ref_update = ref_update_event.refUpdate
    project = ref_update.project
    rev = ref_update.newRev
    puts "now get the commit message for #{rev}@#{project}"
    c = gerrit.find_project_commit(project.gsub('/', '%2F'), rev)
    c['message'].scan(regexp).each do |issue_comment|
      puts "found jira issue comment: #{issue_comment}".blue
      begin
        issue = jira.Issue.find(issue_comment)
        comment = issue.comments.build
        base_url = 'http://gerrit'
        link_to_commit = "[#{rev}|#{base_url}/plugins/gitiles/#{project}/+/#{rev}]"
        comment.save!(body: "Commit for #{project}: #{link_to_commit}")
      rescue JIRA::HTTPError => e
        puts "Cannot find #{issue_comment} in our jira".red
      end
    end
  end

  def self.run()
    settings = YAML.load_file('settings.yaml')
    gerrit = Gerry.new('http://gerrit', settings['gerrit_user'], settings['gerrit_password'])
    gerrit.set_auth_type(:digest_auth)
    # this is only included in gerrits > 2.12.2
    # h = gerrit.find_project_commit_included_in("test%2Fgerrit-playground", '51ccabf8a446c18b0b025a8893495f0763ca158a')
    jira = JIRA::Client.new({
                              username: settings['jira_user'],
                              password: settings['jira_password'],
                              site: 'https://esrlabs.atlassian.net/',
                              context_path: '',
                              auth_type: :basic,
                              use_ssl: true,
                              ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
                            })

    stdin, stdout, stderr = Open3.popen3('ssh gerrit gerrit stream-events')
    stdout.each_line do |line|
      event = JSON.parse(line, object_class: OpenStruct)
      puts "Got event #{event.type}".blue
      msg = case event.type
                when 'change-merged'
                  send_to_jira(jira, event)
                when 'ref-updated'
                  send_ref_update_to_jira(gerrit, jira, event)
                else
                  "Unhandled event-type: #{event.type}"
                end
      if msg
        puts "#{msg}".red
        puts event
      else
        puts "Added comment to changeset/commit for event".green
      end
    end
  end
end
