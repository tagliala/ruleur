# frozen_string_literal: true

module Ruleur
  # The RuleSet class represents a set of rules that can be managed and evaluated.
  class RuleSet
    attr_reader :rules

    def initialize
      @rules = []
    end

    def add_rule(rule)
      @rules << rule
    end

    def evaluate(working_memory)
      @rules.each do |rule|
        rule.evaluate(working_memory)
      end
    end
  end
end
