# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ruleur/version'

Gem::Specification.new do |gem|
  gem.authors       = ['Geremia Taglialatela']
  gem.email         = ['tagliala.dev@gmail.com']
  gem.summary       = 'A Ruby gem that implements a Business Rule Management System (BRMS) using the Rete algorithm'
  gem.description   = <<~DESC
    Ruleur is a Ruby gem that provides a scalable and efficient way to manage
    your business rules. It uses the Rete algorithm, a well-known algorithm
    for efficient rule-based systems, to implement a Business Rule Management
    System (BRMS). With Ruleur, you can manage your rules in a straightforward
    and effective manner, without having to worry about performance or
    scalability issues.
  DESC
  gem.homepage      = 'https://github.com/tagliala/ruleur'
  gem.license       = 'MIT'

  gem.files         = `git ls-files -z -- {CHANGELOG.md,LICENSE,README.md,lib}`.split("\x0")
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.name          = 'ruleur'
  gem.require_paths = ['lib']
  gem.version       = Ruleur::VERSION

  gem.metadata['rubygems_mfa_required'] = 'true'

  gem.metadata['bug_tracker_uri'] = 'https://github.com/tagliala/ruleur/issues'
  gem.metadata['changelog_uri'] = 'https://github.com/tagliala/ruleur/blob/main/CHANGELOG.md'
  gem.metadata['source_code_uri'] = 'https://github.com/tagliala/ruleur'

  gem.required_ruby_version = '>= 3.0'

  gem.add_development_dependency 'bundler', '~> 2.0'
  gem.add_development_dependency 'rake', '~> 13.0'
  gem.add_development_dependency 'rspec', '~> 3.12'
  gem.add_development_dependency 'simplecov', '~> 0.22.0'
  gem.add_development_dependency 'simplecov-lcov', '~> 0.8.0'
end
