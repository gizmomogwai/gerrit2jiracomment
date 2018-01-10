# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RuboCop::RakeTask.new
Rake::Task['build'].enhance(['rubocop:auto_correct'])

RSpec::Core::RakeTask.new(:spec)

task default: :spec
