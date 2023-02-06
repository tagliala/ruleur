# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::AlphaNode do
  describe '#initialize' do
    it 'creates a new Alpha Node with the given conditions' do
      conditions = [->(fact) { fact[:age] > 18 }]
      alpha_node = described_class.new(conditions)
      expect(alpha_node.conditions).to eq conditions
    end

    it 'creates a new Alpha Node with the given parent node' do
      parent = instance_double(described_class)
      alpha_node = described_class.new([], parent)
      expect(alpha_node.parent).to eq parent
    end
  end

  describe '#activate' do
    let(:alpha_node) { described_class.new([->(fact) { fact[:age] > 18 }]) }
    let(:parent) { instance_double(Ruleur::BetaNode, activate: nil) }
    let(:fact) { { age: 21 } }

    before do
      allow(alpha_node).to receive(:parent).and_return(parent)
    end

    it 'activates the parent node if conditions match the fact' do
      alpha_node.activate(fact)
      expect(parent).to have_received(:activate).with(fact)
    end

    it "does not activate the parent node if conditions don't match the fact" do
      fact = { age: 17 }
      alpha_node.activate(fact)
      expect(parent).not_to have_received(:activate)
    end
  end

  describe '#match' do
    let(:alpha_node) { described_class.new([->(fact) { fact[:age] > 18 }]) }

    it 'returns true if all conditions match the fact' do
      fact = { age: 21 }
      expect(alpha_node.match(fact)).to be true
    end

    it "returns false if any conditions don't match the fact" do
      fact = { age: 17 }
      expect(alpha_node.match(fact)).to be false
    end
  end

  describe '#add_child' do
    let(:alpha_node) { described_class.new([]) }
    let(:child) { instance_double(Ruleur::BetaNode) }

    it 'adds a child node to the Alpha Node' do
      alpha_node.add_child(child)
      expect(alpha_node.children).to include child
    end
  end
end
