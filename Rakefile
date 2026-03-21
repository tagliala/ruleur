# frozen_string_literal: true

require 'bundler/gem_tasks'

require 'rubygems'
require 'rake'
require 'rspec/core/rake_task'

require 'rubocop/rake_task'

RuboCop::RakeTask.new
RSpec::Core::RakeTask.new

desc 'Extract Ruby code examples from documentation'
task :extract_docs_examples do
  load './bin/extract-docs-examples'
  DocsExamplesExtractor.new('docs', 'tmp/docs-examples').extract
end

desc 'Lint documentation code examples'
task docs_lint: :extract_docs_examples do
  system('bundle exec rubocop -c .rubocop_docs.yml "tmp/docs-examples/**/*.rb"')
end

task default: %i[rubocop spec docs_lint]
