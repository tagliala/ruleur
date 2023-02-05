# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::AlphaNode do
  let(:fact) { double('fact') }
  let(:parent) { double('parent') }
  let(:node) { described_class.new(fact, parent) }

  describe '#initialize' do
    it 'accepts a fact and a parent node' do
      expect(node.fact).to eq(fact)
      expect(node.parent).to eq(parent)
    end

    it 'has an empty array of children' do
      expect(node.children).to eq([])
    end
  end

  describe '#add_child' do
    let(:child) { double('child') }

    it 'adds a child node' do
      node.add_child(child)
      expect(node.children).to eq([child])
    end
  end
end
