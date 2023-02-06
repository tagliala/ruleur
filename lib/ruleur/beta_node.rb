# frozen_string_literal: true

module Ruleur
  # The BetaNode class represents a beta node in the Rete algorithm.
  # A beta node is responsible for checking if two or more conditions
  # match and passing the facts that match to the next node.
  class BetaNode
    attr_reader :left, :right, :parent, :children

    def initialize(left, right, parent = nil)
      @left = left
      @right = right
      @parent = parent
      @children = []
    end

    def add_child(node)
      @children << node
    end

    def activate(fact)
      if left.fact == fact && right.fact == fact
        children.each do |child|
          child.activate(fact)
        end
      end
    end
  end
end
