# frozen_string_literal: true

# lib/ruleur/beta_node.rb
module Ruleur
  # The BetaNode class represents a beta node in the Rete algorithm.
  # A beta node is responsible for comparing two sets of facts and
  # returning the set of tuples that match a given condition.
  class BetaNode
    attr_reader :left, :right

    def initialize(left:, right:)
      @left = left
      @right = right
    end

    # ...
  end
end
