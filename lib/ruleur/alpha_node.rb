# frozen_string_literal: true

module Ruleur
  # The AlphaNode class represents an alpha node in the Rete algorithm.
  # An alpha node is responsible for filtering the set of facts that
  # match a given condition.
  class AlphaNode
    attr_reader :fact, :parent, :children

    def initialize(fact, parent = nil)
      @fact = fact
      @parent = parent
      @children = []
    end

    def add_child(node)
      @children << node
    end
  end
end
