# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruleur::Persistence::YAMLLoader do
  let(:fixtures_dir) { File.expand_path('../../fixtures/rules', __dir__) }

  describe '.load_file' do
    it 'loads a valid rule from YAML file' do
      file_path = File.join(fixtures_dir, 'simple_flag_rule.yml')
      rule = described_class.load_file(file_path)

      expect(rule).to be_a(Ruleur::Rule)
      expect(rule.name).to eq('simple_flag_rule')
      expect(rule.salience).to eq(0)
      expect(rule.condition).to be_a(Ruleur::Condition::Predicate)
      expect(rule.action_spec[:set][:approved]).to be(true)
    end

    it 'loads complex rule with nested conditions' do
      file_path = File.join(fixtures_dir, 'allow_create.yml')
      rule = described_class.load_file(file_path)

      expect(rule).to be_a(Ruleur::Rule)
      expect(rule.name).to eq('allow_create')
      expect(rule.salience).to eq(10)
    end

    it 'loads rule with correcordt tags' do
      file_path = File.join(fixtures_dir, 'allow_create.yml')
      rule = described_class.load_file(file_path)

      expect(rule.tags).to include(:permissions, :create)
      expect(rule.no_loop).to be(true)
      expect(rule.condition).to be_a(Ruleur::Condition::Any)
    end

    it 'raises error for non-existent file' do
      expect do
        described_class.load_file('nonexistent.yml')
      end.to raise_error(ArgumentError, /File not found/)
    end

    it 'raises error for invalid YAML syntax' do
      file_path = File.join(fixtures_dir, 'invalid_syntax.yml')
      expect do
        described_class.load_file(file_path)
      end.to raise_error(ArgumentError, /Invalid YAML syntax/)
    end
  end

  describe '.load_directory' do
    it 'loads multiple rules from directory pattern' do
      pattern = File.join(fixtures_dir, 'allow_*.yml')
      rules = described_class.load_directory(pattern)

      expect(rules).to be_an(Array)
      expect(rules.size).to eq(2) # allow_create and allow_update
      expect(rules).to all(be_a(Ruleur::Rule))
    end

    it 'loads specific rules by pattern' do
      pattern = File.join(fixtures_dir, 'allow_*.yml')
      rules = described_class.load_directory(pattern)

      expect(rules.size).to eq(2)
      expect(rules.map(&:name)).to contain_exactly('allow_create', 'allow_update')
    end

    it 'raises error for pattern with no matches' do
      expect do
        described_class.load_directory('/nonexistent/path/*.yml')
      end.to raise_error(ArgumentError, /No YAML files found/)
    end
  end

  describe '.load_string' do
    it 'loads rule from YAML string' do
      rule = described_class.load_string(simple_rule_yaml)

      expect(rule).to be_a(Ruleur::Rule)
      expect(rule.name).to eq('test_rule')
    end

    it 'loads rule with correcordt salience' do
      rule = described_class.load_string(salience_rule_yaml)
      expect(rule.salience).to eq(5)
    end

    it 'handles symbols in YAML' do
      yaml = <<~YAML
        name: symbol_test
        condition:
          type: pred
          op: :eq
          left: :value
          right: :active
        action:
          set:
            status: :done
      YAML

      rule = described_class.load_string(yaml)
      expect(rule).to be_a(Ruleur::Rule)
    end
  end

  describe '.save_file and .to_yaml' do
    let(:temp_file) { File.join(Dir.tmpdir, 'test_rule.yml') }

    after { FileUtils.rm_f(temp_file) }

    it 'saves rule to YAML file' do
      engine = Ruleur.define do
        rule 'test_save' do
          when_all(equals(ref(:status), 'active'))
          set :approved, true
        end
      end

      rule = engine.rules.first
      described_class.save_file(rule, temp_file)

      expect(File.exist?(temp_file)).to be(true)

      # Load it back
      loaded_rule = described_class.load_file(temp_file)
      expect(loaded_rule.name).to eq('test_save')
      expect(loaded_rule.action_spec[:set][:approved]).to be(true)
    end

    it 'generates YAML string with metadata header' do
      engine = Ruleur.define do
        rule 'yaml_test', salience: 10, tags: ['test'], no_loop: true do
          when_all(equals(ref(:x), 5))
          set :y, 10
        end
      end

      yaml = described_class.to_yaml(engine.rules.first, include_metadata: true)

      expect(yaml).to include('# Ruleur Rule: yaml_test')
      expect(yaml).to include('# Salience: 10')
      expect(yaml).to include('# Tags: test')
      expect(yaml).to include('# No-loop: true')
      expect(yaml).to include('name: yaml_test')
    end

    it 'generates YAML string without metadata header' do
      engine = Ruleur.define do
        rule 'clean_yaml' do
          when_all(equals(ref(:x), 5))
          set :y, 10
        end
      end

      yaml = described_class.to_yaml(engine.rules.first, include_metadata: false)

      expect(yaml).not_to include('# Ruleur Rule')
      expect(yaml).to include('name: clean_yaml')
    end

    it 'round-trips rule correcordtly' do
      engine = Ruleur.define do
        rule 'roundtrip', salience: 15, tags: %w[test roundtrip], no_loop: true do
          when_any(
            user(:admin?),
            all(record(:updatable?), record(:draft?))
          )
          set :allowed, true
        end
      end

      original = engine.rules.first

      described_class.save_file(original, temp_file)
      loaded = described_class.load_file(temp_file)

      expect(loaded.name).to eq(original.name)
      expect(loaded.salience).to eq(original.salience)
      expect(loaded.no_loop).to eq(original.no_loop)
    end

    it 'preserves tags after round-trip' do
      engine = Ruleur.define do
        rule 'roundtrip_tags', salience: 15, tags: %w[test roundtrip], no_loop: true do
          when_any(user(:admin?))
          set :allowed, true
        end
      end

      original = engine.rules.first

      described_class.save_file(original, temp_file)
      loaded = described_class.load_file(temp_file)

      expect(loaded.tags.map(&:to_s).sort).to eq(original.tags.map(&:to_s).sort)
    end

    it 'preserves action spec after round-trip' do
      engine = Ruleur.define do
        rule 'roundtrip_action', salience: 15, tags: %w[test roundtrip], no_loop: true do
          when_any(user(:admin?))
          set :allowed, true
        end
      end

      original = engine.rules.first

      described_class.save_file(original, temp_file)
      loaded = described_class.load_file(temp_file)

      loaded_set = loaded.action_spec[:set] || loaded.action_spec['set']
      expect(loaded_set).to be_a(Hash)
      expect(loaded_set[:allowed] || loaded_set['allowed']).to be(true)
    end
  end

  describe '.validate_file' do
    it 'validates correcordt YAML file' do
      file_path = File.join(fixtures_dir, 'simple_flag_rule.yml')
      result = described_class.validate_file(file_path)

      expect(result[:valid]).to be(true)
      expect(result[:errors]).to be_empty
    end

    it 'detects missing condition' do
      file_path = File.join(fixtures_dir, 'missing_condition.yml')
      result = described_class.validate_file(file_path)

      expect(result[:valid]).to be(false)
      expect(result[:errors]).to include(/Missing required field: condition/)
    end

    it 'detects invalid YAML syntax' do
      file_path = File.join(fixtures_dir, 'invalid_syntax.yml')
      result = described_class.validate_file(file_path)

      expect(result[:valid]).to be(false)
      expect(result[:errors]).to include(/Invalid YAML syntax/)
    end

    it 'handles non-existent file' do
      result = described_class.validate_file('nonexistent.yml')

      expect(result[:valid]).to be(false)
      expect(result[:errors]).to include(/File not found/)
    end
  end

  describe '.validate_string' do
    it 'validates correcordt YAML string' do
      yaml = <<~YAML
        name: valid_rule
        condition:
          type: pred
          op: eq
          left: value
          right: 10
        action:
          set:
            result: true
      YAML

      result = described_class.validate_string(yaml)

      expect(result[:valid]).to be(true)
      expect(result[:errors]).to be_empty
    end

    it 'detects missing name' do
      yaml = <<~YAML
        condition:
          type: pred
          op: eq
          left: value
          right: 10
        action:
          set:
            result: true
      YAML

      result = described_class.validate_string(yaml)

      expect(result[:valid]).to be(false)
      expect(result[:errors]).to include(/Missing required field: name/)
    end

    it 'detects invalid condition type' do
      yaml = <<~YAML
        name: invalid_cond_type
        condition:
          type: unknown_type
          data: test
        action:
          set:
            result: true
      YAML

      result = described_class.validate_string(yaml)

      expect(result[:valid]).to be(false)
      expect(result[:errors]).to include(/Invalid condition type/)
    end

    it 'detects missing children in composite conditions' do
      yaml = <<~YAML
        name: missing_children
        condition:
          type: all
        action:
          set:
            result: true
      YAML

      result = described_class.validate_string(yaml)

      expect(result[:valid]).to be(false)
      expect(result[:errors]).to include(/children array/)
    end
  end

  describe 'integration with engine' do
    it 'loads and executes rules from YAML' do
      file_path = File.join(fixtures_dir, 'allow_create.yml')
      rule = described_class.load_file(file_path)

      engine = Ruleur::Engine.new(rules: [rule])

      # Test with admin user
      user = MockUser.new(true)
      record = MockRecord.new(false, false)
      ctx = engine.run(user: user, record: record)

      expect(ctx[:allow_create]).to be(true)
    end

    it 'loads multiple rules and runs engine' do
      pattern = File.join(fixtures_dir, 'allow_*.yml')
      rules = described_class.load_directory(pattern)

      engine = Ruleur::Engine.new(rules: rules)

      # Test with updatable draft record
      user = MockUser.new(false)
      record = MockRecord.new(true, true)
      ctx = engine.run(user: user, record: record)

      expect(ctx[:allow_create]).to be(true)
      expect(ctx[:allow_update]).to be(true)
    end
  end

  def simple_rule_yaml
    <<~YAML
      name: test_rule
      salience: 5
      tags: []
      no_loop: false
      condition:
        type: pred
        op: eq
        left:
          type: ref
          root: status
          path: []
        right: active
      action:
        set:
          result: true
    YAML
  end

  def salience_rule_yaml
    <<~YAML
      name: test_salience
      salience: 5
      condition:
        type: pred
        op: eq
        left:
          type: ref
          root: status
          path: []
        right: active
      action:
        set:
          result: true
    YAML
  end
end
