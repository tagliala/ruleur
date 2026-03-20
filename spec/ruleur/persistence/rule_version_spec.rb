# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Persistence::RuleVersion do
  let(:rule) do
    Ruleur::Rule.new(
      name: 'test_rule',
      condition: Ruleur::Condition::Predicate.new(true, :eq, true),
      action_spec: { set: { result: true } }
    )
  end

  let(:payload) { Ruleur::Persistence::Serializer.rule_to_h(rule) }

  let(:created_at) { Time.now.utc }

  describe 'initialization' do
    it 'creates a rule version' do
      version = described_class.new(
        rule_name: 'test_rule',
        version: 3,
        payload: payload,
        created_at: created_at,
        created_by: 'alice',
        change_description: 'Updated condition'
      )

      expect(version.rule_name).to eq('test_rule')
      expect(version.version).to eq(3)
      expect(version.payload).to eq(payload)
    end

    it 'has correct metadata' do
      version = described_class.new(
        rule_name: 'test_rule',
        version: 3,
        payload: payload,
        created_at: created_at,
        created_by: 'alice',
        change_description: 'Updated condition'
      )

      expect(version.created_at).to eq(created_at)
      expect(version.created_by).to eq('alice')
      expect(version.change_description).to eq('Updated condition')
    end

    it 'converts rule_name to string' do
      version = described_class.new(
        rule_name: :test_rule,
        version: 1,
        payload: payload,
        created_at: created_at,
        created_by: 'alice'
      )

      expect(version.rule_name).to eq('test_rule')
    end

    it 'converts version to integer' do
      version = described_class.new(
        rule_name: 'test_rule',
        version: '5',
        payload: payload,
        created_at: created_at,
        created_by: 'alice'
      )

      expect(version.version).to eq(5)
    end
  end

  describe '#to_rule' do
    it 'deserializes to a VersionedRule' do
      version = described_class.new(
        rule_name: 'test_rule',
        version: 2,
        payload: payload,
        created_at: created_at,
        created_by: 'bob',
        change_description: 'Bug fix'
      )

      rule = version.to_rule

      expect(rule).to be_a(Ruleur::Persistence::VersionedRule)
      expect(rule.name).to eq('test_rule')
      expect(rule.version).to eq(2)
    end

    it 'preserves version metadata' do
      version = described_class.new(
        rule_name: 'test_rule',
        version: 2,
        payload: payload,
        created_at: created_at,
        created_by: 'bob',
        change_description: 'Bug fix'
      )

      rule = version.to_rule

      expect(rule.created_by).to eq('bob')
      expect(rule.updated_by).to eq('bob')
      expect(rule.change_description).to eq('Bug fix')
    end

    it 'deserializes rule attributes correctly' do
      version = described_class.new(
        rule_name: 'complex_rule',
        version: 1,
        payload: payload.merge(salience: 10, tags: ['test'], no_loop: true),
        created_at: created_at,
        created_by: 'alice'
      )

      rule = version.to_rule

      expect(rule.salience).to eq(10)
      expect(rule.tags).to eq([:test])
      expect(rule.no_loop).to be true
    end
  end

  describe '.from_record' do
    it 'creates RuleVersion from ActiveRecord-like object' do
      record = double
      allow(record).to receive_messages(
        rule_name: 'test_rule',
        version: 4,
        payload: payload,
        created_at: created_at,
        created_by: 'charlie',
        change_description: 'Refactored'
      )

      version = described_class.from_record(record)

      expect(version).to be_a(described_class)
      expect(version.rule_name).to eq('test_rule')
      expect(version.version).to eq(4)
    end

    it 'preserves metadata from record' do
      record = double
      allow(record).to receive_messages(
        rule_name: 'test_rule',
        version: 4,
        payload: payload,
        created_at: created_at,
        created_by: 'charlie',
        change_description: 'Refactored'
      )

      version = described_class.from_record(record)

      expect(version.created_by).to eq('charlie')
      expect(version.change_description).to eq('Refactored')
    end
  end
end
