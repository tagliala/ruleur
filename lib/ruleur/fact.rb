# frozen_string_literal: true

module Ruleur
  # The Fact class represents a piece of information that is processed by the Rete algorithm.
  # It is a PORO (Plain Old Ruby Object) that holds the data for the rules to operate on.
  class Fact
    attr_reader :attributes

    def initialize(attributes = {})
      @attributes = attributes
    end
  end
end
