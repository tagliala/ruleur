# frozen_string_literal: true

module Ruleur
  # The Rule class represents a business rule in the BRMS.
  class Rule
    attr_reader :conditions, :actions

    def initialize(conditions, actions)
      @conditions = conditions
      @actions = actions
    end
  end
end
