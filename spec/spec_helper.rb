# frozen_string_literal: true

require "rspec"
require_relative "../lib/ruleur"

RSpec.configure do |config|
  config.order = :random
  Kernel.srand config.seed
end