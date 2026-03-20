# frozen_string_literal: true

require File.expand_path('boot', __dir__)

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'active_record/railtie'

Bundler.require :default

module RailsApp
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.api_only = false

    config.eager_load = false
    config.cache_classes = false
    config.action_controller.allow_forgery_protection = false

    if ActiveRecord::Migrator.migrations_paths.empty?
      config.paths.add 'db/migrate'
      ActiveRecord::Migrator.migrations_paths = config.paths['db/migrate'].expanded
    end
  end
end
