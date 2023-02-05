# frozen_string_literal: true

module Ruleur
  # The WorkingMemory class represents the working memory of the BRMS.
  class WorkingMemory
    attr_reader :facts

    def initialize
      @facts = []
    end

    def insert(fact)
      @facts << fact
    end

    def delete(fact)
      @facts.delete(fact)
    end

    def update(fact, new_fact)
      index = @facts.index(fact)
      @facts[index] = new_fact if index
    end
  end
end
