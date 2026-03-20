# frozen_string_literal: true

require 'rails'
require 'rails/generators'

$LOAD_PATH.unshift File.expand_path('../../../lib', __dir__)
require 'generators/ruleur/migration_generator'

RSpec.describe Ruleur::Generators::MigrationGenerator, type: :generator do
  let(:destination_root) { File.expand_path('tmp', __dir__) }

  before do
    allow(described_class).to receive(:next_migration_number) do |*_args|
      Time.now.strftime('%Y%m%d%H%M%S')
    end
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)
  end

  after do
    FileUtils.rm_rf(destination_root)
  end

  def run_generator(args = [], config = {})
    generator = described_class.new(args, config)
    generator.behavior = :invoke
    generator.destination_root = destination_root
    generator.invoke_all
    generator
  end

  def assert_migration(relative, pattern = /#{Regexp.escape(relative)}/)
    expect(
      Dir[File.join(destination_root, 'db/migrate/*')].grep(pattern)
    ).not_to be_empty, "Expected migration matching #{pattern.inspect} to exist"
  end

  def assert_no_migration(relative, pattern = /#{Regexp.escape(relative)}/)
    expect(
      Dir[File.join(destination_root, 'db/migrate/*')].grep(pattern)
    ).to be_empty, "Expected no migration matching #{pattern.inspect}"
  end

  describe 'default behavior (with versioning)' do
    it 'creates migration for rules table' do
      run_generator

      migrations = Dir[File.join(destination_root, 'db/migrate/*')]
      rules_migration = migrations.find { |f| f.include?('create_ruleur_rules') }
      expect(rules_migration).to be_a(String)
      expect(File.read(rules_migration)).to include('create_table :ruleur_rules')
    end

    it 'creates migration for rule versions table' do
      run_generator

      migrations = Dir[File.join(destination_root, 'db/migrate/*')]
      versions_migration = migrations.find { |f| f.include?('create_ruleur_rule_versions') }
      expect(versions_migration).to be_a(String)
      expect(File.read(versions_migration)).to include('create_table :ruleur_rule_versions')
    end

    it 'uses jsonb column type' do
      run_generator

      migrations = Dir[File.join(destination_root, 'db/migrate/*')]
      rules_migration = migrations.find { |f| f.include?('create_ruleur_rules') }
      expect(File.read(rules_migration)).to include('t.jsonb :payload')
    end

    it 'creates version column in rules table' do
      run_generator

      migrations = Dir[File.join(destination_root, 'db/migrate/*')]
      rules_migration = migrations.find { |f| f.include?('create_ruleur_rules') }
      expect(File.read(rules_migration)).to include('t.integer :version')
    end

    it 'creates audit columns in rules table' do
      run_generator

      migrations = Dir[File.join(destination_root, 'db/migrate/*')]
      rules_migration = migrations.find { |f| f.include?('create_ruleur_rules') }
      content = File.read(rules_migration)
      expect(content).to include('t.string :created_by')
      expect(content).to include('t.string :updated_by')
    end

    it 'adds unique index on name' do
      run_generator

      migrations = Dir[File.join(destination_root, 'db/migrate/*')]
      rules_migration = migrations.find { |f| f.include?('create_ruleur_rules') }
      expect(File.read(rules_migration)).to include('add_index :ruleur_rules, :name, unique: true')
    end
  end

  describe 'with --simple option' do
    it 'creates only rules table migration' do
      run_generator([], { simple: true })

      migrations = Dir[File.join(destination_root, 'db/migrate/*')]
      rules_migration = migrations.find { |f| f.include?('create_ruleur_rules') }
      versions_migration = migrations.find { |f| f.include?('create_ruleur_rule_versions') }

      expect(rules_migration).to be_a(String)
      expect(versions_migration).to be_nil
    end

    it 'does not include version column in simple migration' do
      run_generator([], { simple: true })

      migrations = Dir[File.join(destination_root, 'db/migrate/*')]
      rules_migration = migrations.find { |f| f.include?('create_ruleur_rules') }
      content = File.read(rules_migration)
      expect(content).to include('t.jsonb :payload')
      expect(content).not_to match(/t\.integer :version/)
    end

    it 'does not include audit columns in simple migration' do
      run_generator([], { simple: true })

      migrations = Dir[File.join(destination_root, 'db/migrate/*')]
      rules_migration = migrations.find { |f| f.include?('create_ruleur_rules') }
      content = File.read(rules_migration)
      expect(content).not_to include('t.string :created_by')
      expect(content).not_to include('t.string :updated_by')
    end
  end
end
