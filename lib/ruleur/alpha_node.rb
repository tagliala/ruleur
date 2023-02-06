# frozen_string_literal: true

module Ruleur
  # The AlphaNode class represents an alpha node in the Rete algorithm.
  # An alpha node is responsible for filtering the set of facts that
  # match a given condition.
  class AlphaNode
    attr_reader :conditions, :parent, :children

    def initialize(conditions, parent = nil)
      @conditions = conditions
      @parent = parent
      @children = []
    end

    def activate(fact)
      return unless match(fact)

      @parent&.activate(fact)
    end

    def match(fact)
      @conditions.all? { |condition| condition.call(fact) }
    end

    def add_child(node)
      @children << node
    end
  end
end
