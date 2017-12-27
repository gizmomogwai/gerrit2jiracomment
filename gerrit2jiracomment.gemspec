
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "gerrit2jiracomment/version"

Gem::Specification.new do |spec|
  spec.name          = "gerrit2jiracomment"
  spec.version       = Gerrit2jiracomment::VERSION
  spec.authors       = ["Christian Koestlin"]
  spec.email         = ["info@esrlabs.com"]

  spec.summary       = %q{Simple gem that listens on gerrit stream-events and puts comments to jira.}
  spec.description   = %q{Nothing more to add}
  spec.homepage      = "https://not.done.yet"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'byebug'
  spec.add_dependency 'rx'
  spec.add_dependency 'jira-ruby'
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-mocks"
end
