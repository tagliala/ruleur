# frozen_string_literal: true

require 'bundler/gem_tasks'

require 'rubygems'
require 'rake'
require 'rspec/core/rake_task'

require 'rubocop/rake_task'
require 'json'
require 'fileutils'

RuboCop::RakeTask.new
RSpec::Core::RakeTask.new

desc 'Extract Ruby code examples from documentation'
task :extract_docs_examples do
  load './bin/extract-docs-examples'
  DocsExamplesExtractor.new('docs', 'tmp/docs-examples').extract
end

desc 'Lint documentation code examples'
task 'docs:rubocop': :extract_docs_examples do
  system('bundle exec rubocop -c .rubocop_docs.yml "tmp/docs-examples/**/*.rb"')
end

desc 'Autocorrect documentation examples (safe)'
task 'docs:rubocop:autocorrect': :extract_docs_examples do
  cmd = 'bundle exec rubocop -c .rubocop_docs.yml --autocorrect "tmp/docs-examples/**/*.rb"'
  puts "Running: #{cmd}"
  success = system(cmd)
  warn 'RuboCop returned non-zero exit status' unless success

  puts 'Applying corrections back into documentation'
  apply_examples('tmp/docs-examples/manifest.json', 'tmp/docs-examples')
end

desc 'Autocorrect all documentation examples (aggressive)'
task 'docs:rubocop:autocorrect_all': :extract_docs_examples do
  cmd = 'bundle exec rubocop -c .rubocop_docs.yml --autocorrect-all "tmp/docs-examples/**/*.rb"'
  puts "Running: #{cmd}"
  success = system(cmd)
  warn 'RuboCop returned non-zero exit status' unless success

  puts 'Applying corrections back into documentation'
  apply_examples('tmp/docs-examples/manifest.json', 'tmp/docs-examples')
end

def apply_examples(manifest_path, examples_dir)
  unless File.file?(manifest_path)
    warn "Manifest not found: #{manifest_path}"
    return
  end

  manifest = JSON.parse(File.read(manifest_path))

  by_source = Hash.new { |h, k| h[k] = [] }
  manifest.each do |filename, meta|
    src = meta['source']
    by_source[src] << { 'extracted_filename' => filename }.merge(meta)
  end

  apply_count = 0
  by_source.each do |src_file, entries|
    unless File.file?(src_file)
      warn "Source file not found: #{src_file} -- skipping"
      next
    end

    content = File.read(src_file)
    lines = content.lines.map(&:chomp)

    entries.sort_by! { |e| -e['start_line'].to_i }

    modified = false

    entries.each do |entry|
      extracted_name = entry['extracted_filename']
      extracted_path = File.join(examples_dir, extracted_name)
      unless File.file?(extracted_path)
        warn "Extracted example not found: #{extracted_path} -- skipping"
        next
      end

      start_line = entry['start_line'].to_i
      end_line = entry['end_line'].to_i

      if start_line < 1 || end_line < start_line || end_line > lines.size
        warn "Invalid line range for #{extracted_name} -> #{src_file}: #{start_line}-#{end_line} (file has #{lines.size} lines) -- skipping"
        next
      end

      new_content = File.read(extracted_path).lines.map(&:chomp)

      next if lines[(start_line - 1)..(end_line - 1)] == new_content

      modified = true
      apply_count += 1

      # perform replacement
      lines[(start_line - 1)..(end_line - 1)] = new_content
    end

    next unless modified

    final_newline = File.read(src_file).end_with?("\n")
    new_text = lines.join("\n")
    new_text += "\n" if final_newline

    File.write(src_file, new_text)
    puts "Updated #{src_file}"
  end

  puts "Applied #{apply_count} example replacements."
end

task default: ['rubocop', 'spec', 'docs:rubocop']
