# frozen_string_literal: true

require 'ruleur/rule_set'

RSpec.describe Ruleur::RuleSet do
  let(:rule_set) { described_class.new }
  let(:rule) { instance_double(Ruleur::Rule) }

  describe '#add_rule' do
    it 'adds a rule to the rule set' do
      rule_set.add_rule(rule)
      expect(rule_set.rules).to include(rule)
    end
  end

  describe '#evaluate' do
    let(:working_memory) { instance_double(Ruleur::WorkingMemory) }

    it 'evaluates each rule in the rule set' do
      allow(rule).to receive(:evaluate)

      rule_set.add_rule(rule)
      rule_set.evaluate(working_memory)

      expect(rule).to have_received(:evaluate).with(working_memory)
    end
  end
end
