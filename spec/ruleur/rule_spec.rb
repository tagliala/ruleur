# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Rule do
  describe '#evaluate' do
    let(:fact) { double }
    let(:condition) { double(call: true) }
    let(:action) { double(call: nil) }
    let(:rule) { described_class.new([condition], [action]) }

    it 'executes action when condition is satisfied' do
      expect(action).to receive(:call).with(fact)
      rule.evaluate(fact)
    end

    it 'does not execute action when condition is not satisfied' do
      allow(condition).to receive(:call).and_return(false)

      rule.evaluate(fact)

      expect(action).not_to have_received(:call)
    end
  end
end
