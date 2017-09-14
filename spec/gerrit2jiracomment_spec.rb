RSpec.describe Gerrit2jiracomment do
  it "has a version number" do
    expect(Gerrit2jiracomment::VERSION).not_to be nil
    Gerrit2jiracomment::run
  end
end
