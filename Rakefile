# frozen_string_literal: true

require 'bundler/gem_tasks'

require 'rubygems'
require 'rake'
require 'rspec/core/rake_task'

require 'rubocop/rake_task'

RuboCop::RakeTask.new
RSpec::Core::RakeTask.new

task default: %i[rubocop spec]
