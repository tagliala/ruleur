# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Persistence::MemoryRepository do
  describe '#save' do
    it 'updates existing rule with same name' do
      repo = described_class.new

      rule1 = Ruleur::Rule.new(
        name: 'test',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { v: 1 } }
      )

      repo.save(rule1)
      expect(repo.all.size).to eq(1)
      expect(repo.all.first.action_spec[:set][:v]).to eq(1)

      rule2 = Ruleur::Rule.new(
        name: 'test',
        condition: Ruleur::Condition::Predicate.new(false, :eq, false),
        action_spec: { set: { v: 2 } }
      )

      repo.save(rule2)
      expect(repo.all.size).to eq(1) # Still 1, updated
      expect(repo.all.first.action_spec[:set][:v]).to eq(2)
    end

    it 'adds new rules with different names' do
      repo = described_class.new

      rule1 = Ruleur::Rule.new(
        name: 'rule_one',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { v: 1 } }
      )

      rule2 = Ruleur::Rule.new(
        name: 'rule_two',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { v: 2 } }
      )

      repo.save(rule1)
      repo.save(rule2)
      expect(repo.all.size).to eq(2)
    end

    it 'handles symbol vs string name matching' do
      repo = described_class.new

      rule1 = Ruleur::Rule.new(
        name: :symbol_name,
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { v: 1 } }
      )

      repo.save(rule1)

      rule2 = Ruleur::Rule.new(
        name: 'symbol_name',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { v: 2 } }
      )

      repo.save(rule2)
      expect(repo.all.size).to eq(1) # Updated, not added
    end
  end

  describe '#delete' do
    it 'removes rules by name' do
      repo = described_class.new

      rule = Ruleur::Rule.new(
        name: 'to_delete',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { v: 1 } }
      )

      repo.save(rule)
      expect(repo.all.size).to eq(1)

      repo.delete('to_delete')
      expect(repo.all.size).to eq(0)
    end

    it 'handles symbol names in delete' do
      repo = described_class.new

      rule = Ruleur::Rule.new(
        name: :symbol_rule,
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { v: 1 } }
      )

      repo.save(rule)
      repo.delete(:symbol_rule)
      expect(repo.all.size).to eq(0)
    end

    it 'deletes only matching rules' do
      repo = described_class.new

      rule1 = Ruleur::Rule.new(
        name: 'keep',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { v: 1 } }
      )

      rule2 = Ruleur::Rule.new(
        name: 'delete',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { v: 2 } }
      )

      repo.save(rule1)
      repo.save(rule2)
      expect(repo.all.size).to eq(2)

      repo.delete('delete')
      expect(repo.all.size).to eq(1)
      expect(repo.all.first.name).to eq('keep')
    end

    it 'handles deleting non-existent rules gracefully' do
      repo = described_class.new

      rule = Ruleur::Rule.new(
        name: 'exists',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { v: 1 } }
      )

      repo.save(rule)
      expect(repo.all.size).to eq(1)

      repo.delete('does_not_exist')
      expect(repo.all.size).to eq(1) # No change
    end
  end

  describe '#all' do
    it 'returns empty array when no rules' do
      repo = described_class.new
      expect(repo.all).to eq([])
    end

    it 'returns all saved rules' do
      repo = described_class.new

      3.times do |i|
        rule = Ruleur::Rule.new(
          name: "rule_#{i}",
          condition: Ruleur::Condition::Predicate.new(true, :eq, true),
          action_spec: { set: { v: i } }
        )
        repo.save(rule)
      end

      expect(repo.all.size).to eq(3)
      expect(repo.all.map(&:name)).to contain_exactly('rule_0', 'rule_1', 'rule_2')
    end
  end
end
