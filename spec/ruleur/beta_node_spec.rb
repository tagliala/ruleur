# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::BetaNode do
  subject(:beta_node) { described_class.new(left, right, parent) }

  let(:left) { double('left') }
  let(:right) { double('right') }
  let(:parent) { double('parent') }

  describe '#initialize' do
    it 'sets left and right' do
      expect(beta_node.left).to eq(left)
      expect(beta_node.right).to eq(right)
    end

    it 'sets parent' do
      expect(beta_node.parent).to eq(parent)
    end

    it 'initializes children as an empty array' do
      expect(beta_node.children).to eq([])
    end
  end

  describe '#add_child' do
    let(:child) { double('child') }

    it 'adds child to children array' do
      beta_node.add_child(child)
      expect(beta_node.children).to include(child)
    end
  end
end
