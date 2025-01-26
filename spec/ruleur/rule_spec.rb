# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Rule do
  describe '#evaluate' do
    let(:fact) { double }
    let(:condition) { Struct.new(call:).new(true) }
    let(:action) { Struct.new(call:).new(nil) }
    let(:rule) { described_class.new([condition], [action]) }

    it 'executes action when condition is satisfied' do
      rule.evaluate(fact)
      expect(action).to have_received(:call).with(fact)
    end

    it 'does not execute action when condition is not satisfied' do
      allow(condition).to receive(:call).and_return(false)

      rule.evaluate(fact)

      expect(action).not_to have_received(:call)
    end
  end
end
