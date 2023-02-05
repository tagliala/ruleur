# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Network do
  let(:alpha_node) { instance_double(Ruleur::AlphaNode) }
  let(:beta_node) { instance_double(Ruleur::BetaNode) }
  let(:network) { described_class.new }

  describe '#add_alpha_node' do
    it 'adds a new alpha node to the network' do
      network.add_alpha_node(alpha_node)
      expect(network.alpha_nodes).to include(alpha_node)
    end
  end

  describe '#add_beta_node' do
    it 'adds a new beta node to the network' do
      network.add_beta_node(beta_node)
      expect(network.beta_nodes).to include(beta_node)
    end
  end
end
