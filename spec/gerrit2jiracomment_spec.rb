# frozen_string_literal: true

RSpec.describe Gerrit2jiracomment do
  it 'has a version number' do
    expect(Gerrit2jiracomment::VERSION).not_to be nil
  end

  it 'parses a comment for jira issues' do
    text = 'AUDIGW-3897 - Implement loopback backend communication' \
           "\n\nChange-Id: I4624d944dd2b06c442eb0df9eddc84d58f17187a\n"
    text.scan(Gerrit2jiracomment.regexp) do |match|
      expect(match).to eq('AUDIGW-3897')
    end
  end

  it 'dispatches change_merged' do
    logger = spy('logger')
    sink = spy('sink')
    content = File.open('spec/input/change_merged.txt', 'r:UTF-8', &:read)
    event = Gerrit2jiracomment.parse_json(content)

    Gerrit2jiracomment.dispatch(logger, [event, 'gerrit'], sink)
    expect(sink).to have_received(:change_merged).with(logger, event, 'gerrit')
  end

  it 'executes change_merged' do
    logger = spy('logger') # Logger.new(STDOUT)
    jira = instance_double('jira')
    allow(jira)
      .to(receive_message_chain('Issue.find.comments.build.save!')
            .with(body: File.read('spec/output/change_merged_result.txt')))

    sink = Gerrit2jiracomment::ToJira.new(logger, jira)
    content = File.open('spec/input/change_merged.txt', 'r:UTF-8', &:read)
    event = Gerrit2jiracomment.parse_json(content)
    expect(Gerrit2jiracomment.dispatch(logger, [event, 'gerrit'], sink))
      .to eq(true)
  end

  it 'complains if there is no ticket number found' do
    logger = spy('logger')
    jira = instance_double('jira')
    allow(jira)
      .to(receive_message_chain('Issue.find').and_raise(
            JIRA::HTTPError.new('test')
      ))
    sink = Gerrit2jiracomment::ToJira.new(logger, jira)
    content = File.open('spec/input/change_merged_no_ticket.txt', 'r:UTF-8', &:read)
    event = Gerrit2jiracomment.parse_json(content)
    expect(Gerrit2jiracomment.dispatch(logger, [event, 'gerrit'], sink))
      .to eq(false)
  end
end
