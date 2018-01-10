# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RuboCop::RakeTask.new
# as soon as the project is clean enough, enable this
# Rake::Task['build'].enhance(['rubocop:auto_correct'])

RSpec::Core::RakeTask.new(:spec)

task default: :spec
