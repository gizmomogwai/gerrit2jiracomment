require "gerrit2jiracomment/version"
require 'json'
require 'open3'
require 'ostruct'
require 'byebug'
require 'jira-ruby'
require 'colorize'

module Gerrit2jiracomment

  def send_to_jira(jira, event)
    puts event
    puts "Send to jira: #{event.change.url}".grey
    r = Regexp.new("([A-Z]+-\\d+)")
    found = false
    event.change.commitMessage.scan(r).each do |match|
      issue_comment = match.first.strip
      puts "found jira issue comment: #{issue_comment}".grey
      begin
        issue = jira.Issue.find(issue_comment)
        comment = issue.comments.build
        comment.save!(body: event.change.url)
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

  def run()
    jira = JIRA::Client.new({
                              username: "jenkins-jira@esrlabs.com",
                              password: "Uyearg1P5K6O",
                              site: 'https://esrlabs.atlassian.net/',
                              context_path: '',
                              auth_type: :basic,
                              use_ssl: true,
                              ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
                            })

    stdin, stdout, stderr = Open3.popen3('ssh gerrit gerrit stream-events')
    stdout.each_line do |line|
      event = JSON.parse(line, object_class: OpenStruct)
      msg = case event.type
                when 'comment-added'
                  send_to_jira(jira, event)
                when 'patchset-created'
                  send_to_jira(jira, event)
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
