# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Rule do
  describe '#initialize' do
    it 'takes a condition and an action as arguments' do
      condition = proc {}
      action = proc {}

      rule = described_class.new(condition, action)

      expect(rule.condition).to eq(condition)
      expect(rule.action).to eq(action)
    end
  end

  describe '#evaluate' do
    let(:condition) { proc { |fact| fact > 5 } }
    let(:action) { proc { |fact| results << fact } }
    let(:rule) { described_class.new(condition, action) }
    let(:results) { [] }
    let(:facts) { [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] }

    it 'evaluates the rule against a set of facts' do
      rule.evaluate(facts)

      expect(results).to eq([6, 7, 8, 9, 10])
    end
  end
end
