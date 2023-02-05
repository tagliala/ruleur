# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::BetaNode do
  describe '#initialize' do
    it 'accepts left and right nodes' do
      node = BetaNode.new(left: :left, right: :right)
      expect(node.left).to eq :left
      expect(node.right).to eq :right
    end
  end
end
