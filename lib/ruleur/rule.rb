# frozen_string_literal: true

module Ruleur
  # The Rule class represents a business rule in the BRMS.
  class Rule
    attr_reader :condition, :action

    def initialize(condition, action)
      @condition = condition
      @action = action
    end

    def evaluate(facts)
      facts.select { |fact| condition.call(fact) }.each { |fact| action.call(fact) }
    end
  end
end
