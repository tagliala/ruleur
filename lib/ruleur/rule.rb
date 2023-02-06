# frozen_string_literal: true

module Ruleur
  # The Rule class represents a business rule in the BRMS. A rule is defined as a set
  # of conditions and actions. The rule is evaluated by checking if all of the
  # conditions are satisfied. If the conditions are satisfied, the associated actions
  # are triggered.
  class Rule
    attr_reader :conditions, :actions

    def initialize(conditions, actions)
      @conditions = conditions
      @actions = actions
    end

    def evaluate(facts)
      conditions.each do |condition|
        actions.each { |action| action.call(facts) } if condition.call(facts)
      end
    end
  end
end
