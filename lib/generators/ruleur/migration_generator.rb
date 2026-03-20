# frozen_string_literal: true

require 'rails/generators/active_record'

module Ruleur
  module Generators
    # Generates migrations for the ruleur_rules and ruleur_rule_versions tables.
    #
    # Usage:
    #   rails generate ruleur:migration
    #   rails generate ruleur:migration --simple
    #
    # The default migration includes versioning support. Use --simple for a basic
    # rules table without versioning.
    class MigrationGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      class_option :simple,
                   type: :boolean,
                   default: false,
                   desc: 'Generate a simple migration without versioning support'

      source_root File.expand_path('templates', __dir__)

      def create_migrations
        if options.simple?
          migration_template 'migration_simple.rb.erb',
                             'db/migrate/create_ruleur_rules.rb'
        else
          migration_template 'migration.rb.erb',
                             'db/migrate/create_ruleur_rules.rb'
          migration_template 'migration_versions.rb.erb',
                             'db/migrate/create_ruleur_rule_versions.rb'
        end
      end

      private

      def migration_version
        major = Rails::VERSION::MAJOR
        minor = Rails::VERSION::MINOR
        "[#{major}.#{minor}]"
      end

      def primary_key_type
        return '' unless options[:primary_key_type]

        ", id: :#{options[:primary_key_type]}"
      end
    end
  end
end
