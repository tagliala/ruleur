# frozen_string_literal: true

module Ruleur
  module Generators
    # Generator for creating database migrations for versioned rules
    module MigrationGenerator
      module_function

      # Generate a migration for the main ruleur_rules table
      def rules_table_migration
        <<~RUBY
          # frozen_string_literal: true

          class CreateRuleurRules < ActiveRecord::Migration[7.0]
            def change
              create_table :ruleur_rules do |t|
                t.string :name, null: false, index: { unique: true }
                t.json :payload, null: false
                t.integer :version, null: false, default: 1
                t.string :created_by
                t.string :updated_by
                t.timestamps
              end
            end
          end
        RUBY
      end

      # Generate a migration for the ruleur_rule_versions table
      def versions_table_migration
        <<~RUBY
          # frozen_string_literal: true

          class CreateRuleurRuleVersions < ActiveRecord::Migration[7.0]
            def change
              create_table :ruleur_rule_versions do |t|
                t.string :rule_name, null: false
                t.integer :version, null: false
                t.json :payload, null: false
                t.string :created_by
                t.text :change_description
                t.datetime :created_at, null: false

                t.index [:rule_name, :version], unique: true
                t.index :rule_name
              end
            end
          end
        RUBY
      end

      # Generate both migrations with proper timestamps
      def generate_all(_output_dir = 'db/migrate')
        timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
        timestamp2 = (Time.now.utc + 1).strftime('%Y%m%d%H%M%S')

        [
          { filename: "#{timestamp}_create_ruleur_rules.rb", content: rules_table_migration },
          { filename: "#{timestamp2}_create_ruleur_rule_versions.rb", content: versions_table_migration }
        ]
      end

      # Write migrations to files
      def write_migrations(output_dir = 'db/migrate')
        require 'fileutils'
        FileUtils.mkdir_p(output_dir)

        generate_all.each do |migration|
          path = File.join(output_dir, migration[:filename])
          File.write(path, migration[:content])
          puts "Created #{path}"
        end
      end
    end
  end
end
