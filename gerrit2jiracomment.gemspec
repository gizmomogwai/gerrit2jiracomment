# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "gerrit2jiracomment/version"

Gem::Specification.new do |spec|
  spec.name          = "gerrit2jiracomment"
  spec.version       = Gerrit2jiracomment::VERSION
  spec.authors       = ["Christian Koestlin"]
  spec.email         = ["info@esrlabs.com"]

  spec.summary       = "Simple gem that listens on gerrit stream-events" \
                       " and puts comments to jira."
  spec.description   = "Nothing more to add"
  spec.homepage      = "https://github.com/gizmomogwai/gerrit2jiracomment"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "jira-ruby"
  spec.add_dependency "rx"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-mocks"
  spec.add_development_dependency "rubocop"
end
