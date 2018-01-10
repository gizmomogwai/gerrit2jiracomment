# frozen_string_literal: true

RSpec.describe Gerrit2jiracomment do
  it 'has a version number' do
    expect(Gerrit2jiracomment::VERSION).not_to be nil
  end

  it 'parses a comment for jira issues' do
    text = "AUDIGW-3897 - Implement loopback backend communication\n\nChange-Id: I4624d944dd2b06c442eb0df9eddc84d58f17187a\n"
    text.scan(Gerrit2jiracomment.regexp) do |match|
      expect(match).to eq('AUDIGW-3897')
    end
  end

  it 'dispatches ' do
    logger = spy('logger')
    sink = spy('sink')
    event = Gerrit2jiracomment.parse_json('{"type": "change-merged","submitter": {"name": "Christian Koestlin","email": "christian.koestlin@esrlabs.com","username": "christian.koestlin"},"newRev": "ceafa8d99a435ef33d78fe9e878522689f26bfc8","patchSet": {"number": "1","revision": "ceafa8d99a435ef33d78fe9e878522689f26bfc8","parents": ["258bd6d82148cf0a40d60c02bebe983633f416a6"],"ref": "refs/changes/77/26077/1","uploader": {"name": "Christian Koestlin","email": "christian.koestlin@esrlabs.com","username": "christian.koestlin"},"createdOn": 1509084844,"author": {"name": "Christian Koestlin","email": "info@esrlabs.com","username": ""},"isDraft": false,"kind": "REWORK","sizeInsertions": 1,"sizeDeletions": 0},"change": {"project": "test/gerrit-playground","branch": "master","id": "Ibd51993552d6619922e9b0b6807f8a84b6ca0d2b","number": "26077","subject": "TESTSYNC-620 - .....","owner": {"name": "Christian Koestlin","email": "christian.koestlin@esrlabs.com","username": "christian.koestlin"},"url": "http://gerrit/26077","commitMessage": "TESTSYNC-620 - .....\n\nChange-Id: Ibd51993552d6619922e9b0b6807f8a84b6ca0d2b\n","status": "MERGED"},"eventCreatedOn": 1509085016}')

    Gerrit2jiracomment.dispatch(logger, [event, 'gerrit'], sink)
    expect(sink).to have_received(:change_merged).with(logger, event, 'gerrit')
  end
end
