# frozen_string_literal: true

module Ruleur
  # The WorkingMemory class represents the working memory of the BRMS. It acts as
  # an intermediate layer between the rules and the facts. The facts are inserted
  # into the working memory where they can be manipulated and updated by the rules.
  # The working memory then takes the updated facts and transfers the changes back
  # to the original objects.
  class WorkingMemory
    attr_reader :facts

    def initialize
      @facts = []
    end

    def insert(fact)
      facts << fact
    end

    def delete(fact)
      facts.delete(fact)
    end

    def update(fact, new_fact)
      index = facts.index(fact)
      facts[index] = new_fact if index
    end
  end
end
