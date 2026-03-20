# frozen_string_literal: true

require 'rails/generators/test_case'
require 'generators/ruleur/migration_generator'

RSpec.configure do |config|
  config.include Rails::Generators::TestCase::Assertions, type: :generator
  config.include Rails::Generators::TestCase::Behavior, type: :generator

  config.define_derived_metadata(file_path: %r{/spec/generators/}) do |metadata|
    metadata[:type] = :generator
  end
end

RSpec.configure do |config|
  config.before :type, :generator do
    require Rails.root.join('test/rails_app/config/environment')
  end
end
