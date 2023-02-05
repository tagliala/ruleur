# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Rule do
  describe '#initialize' do
    it 'accepts conditions and actions as arguments' do
      conditions = [double, double]
      actions = [double, double]
      rule = described_class.new(conditions, actions)

      expect(rule.conditions).to eq(conditions)
      expect(rule.actions).to eq(actions)
    end
  end
end
