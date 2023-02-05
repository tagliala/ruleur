# frozen_string_literal: true

module Ruleur
  # The Network class represents the rule network in the Rete algorithm.
  # It is responsible for managing the set of alpha and beta nodes that
  # make up the network.
  class Network
    attr_reader :alpha_nodes, :beta_nodes

    def initialize
      @alpha_nodes = []
      @beta_nodes = []
    end

    def add_alpha_node(node)
      @alpha_nodes << node
    end

    def add_beta_node(node)
      @beta_nodes << node
    end
  end
end
