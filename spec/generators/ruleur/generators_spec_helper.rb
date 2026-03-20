# frozen_string_literal: true

require 'rails'
require 'rails/generators/test_case'

RSpec.configure do |config|
  config.include Rails::Generators::TestCase::Behavior, type: :generator
end
