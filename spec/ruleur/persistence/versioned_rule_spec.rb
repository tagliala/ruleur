# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Persistence::VersionedRule do
  let(:condition) { Ruleur::Condition::Predicate.new(true, :eq, true) }
  let(:action_spec) { { set: { result: true } } }

  describe 'initialization' do
    it 'creates a versioned rule with metadata' do
      rule = described_class.new(
        name: 'test_rule',
        condition: condition,
        action_spec: action_spec,
        version: 5,
        created_at: Time.now,
        updated_at: Time.now,
        created_by: 'alice',
        updated_by: 'bob',
        change_description: 'Updated logic'
      )

      expect(rule.name).to eq('test_rule')
      expect(rule.version).to eq(5)
      expect(rule.created_by).to eq('alice')
    end

    it 'has correct update metadata' do
      rule = described_class.new(
        name: 'test_rule',
        condition: condition,
        action_spec: action_spec,
        version: 5,
        created_at: Time.now,
        updated_at: Time.now,
        created_by: 'alice',
        updated_by: 'bob',
        change_description: 'Updated logic'
      )

      expect(rule.updated_by).to eq('bob')
      expect(rule.change_description).to eq('Updated logic')
    end

    it 'converts version to integer' do
      rule = described_class.new(
        name: 'test',
        condition: condition,
        action_spec: action_spec,
        version: '42'
      )

      expect(rule.version).to eq(42)
    end

    it 'defaults to version 1' do
      rule = described_class.new(
        name: 'test',
        condition: condition,
        action_spec: action_spec
      )

      expect(rule.version).to eq(1)
    end
  end

  describe '#versioned?' do
    it 'returns true when version is positive' do
      rule = described_class.new(
        name: 'test',
        condition: condition,
        action_spec: action_spec,
        version: 1
      )

      expect(rule.versioned?).to be true
    end

    it 'returns false when version is zero' do
      rule = described_class.new(
        name: 'test',
        condition: condition,
        action_spec: action_spec,
        version: 0
      )

      expect(rule.versioned?).to be false
    end
  end

  describe '#version_info' do
    let(:info_params) do
      {
        name: 'test',
        condition: condition,
        action_spec: action_spec,
        version: 3,
        created_at: Time.now - 3600,
        updated_at: Time.now,
        created_by: 'alice',
        updated_by: 'bob',
        change_description: 'Fix bug'
      }
    end

    it 'returns version metadata as hash' do
      rule = described_class.new(**info_params)

      info = rule.version_info

      expect(info[:version]).to eq(3)
      expect(info[:created_at]).to eq(info_params[:created_at])
      expect(info[:updated_at]).to eq(info_params[:updated_at])
    end

    it 'includes author info' do
      rule = described_class.new(**info_params)

      info = rule.version_info

      expect(info[:created_by]).to eq('alice')
      expect(info[:updated_by]).to eq('bob')
      expect(info[:change_description]).to eq('Fix bug')
    end
  end

  describe 'inheritance from Rule' do
    it 'behaves like a normal Rule' do
      rule = described_class.new(
        name: 'test',
        condition: condition,
        action_spec: action_spec,
        salience: 10,
        tags: [:test],
        no_loop: true
      )

      ctx = Ruleur::Context.new(test: true)
      expect(rule.eligible?(ctx)).to be true
      expect(rule.salience).to eq(10)
      expect(rule.tags).to eq([:test])
      expect(rule.no_loop).to be true
    end
  end

  def versioned_rule_info
    {
      name: 'test',
      condition: condition,
      action_spec: action_spec,
      version: 3,
      created_at: Time.now - 3600,
      updated_at: Time.now,
      created_by: 'alice',
      updated_by: 'bob',
      change_description: 'Fix bug'
    }
  end
end
