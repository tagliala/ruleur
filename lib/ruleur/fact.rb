# frozen_string_literal: true

module Ruleur
  # The Fact class represents a piece of information processed by the Rete algorithm in the BRMS.
  # This class acts as a data container, holding the relevant information for the rules to operate on.
  # Instead of using the original data source directly, the information is extracted and stored as instances of the Fact class.
  # This allows for better management and processing of the data within the BRMS.
  class Fact
    attr_reader :attributes

    def initialize(attributes = {})
      @attributes = attributes
    end
  end
end
