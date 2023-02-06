# frozen_string_literal: true

module Ruleur
  # The RuleSet class represents a collection of business rules in the BRMS.
  # The RuleSet can be evaluated against a set of facts, known as the working memory,
  # to trigger the actions associated with the rules whose conditions are satisfied.
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
