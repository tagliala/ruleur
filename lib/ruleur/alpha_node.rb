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

    def filter_fact(fact)
      children.each do |child|
        if match?(fact)
          child.filter_fact(fact)
          break
        end
      end
    end

    def add_child(node)
      children << node
    end

    def remove_child(node)
      children.delete(node)
    end

    def reset
      children.clear
    end

    private

    def match?(fact)
      conditions.all? { |condition| condition.call(fact) }
    end
  end
end
