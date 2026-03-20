# frozen_string_literal: true

module Ruleur
  # Validation provides rule validation before persistence/execution
  module Validation
    # ValidationResult encapsulates validation outcome
    class ValidationResult
      attr_reader :errors, :warnings

      def initialize
        @errors = []
        @warnings = []
      end

      def valid?
        @errors.empty?
      end

      def add_error(message)
        @errors << message
      end

      def add_warning(message)
        @warnings << message
      end

      def merge(other_result)
        @errors.concat(other_result.errors)
        @warnings.concat(other_result.warnings)
      end

      def to_h
        { valid: valid?, errors: @errors, warnings: @warnings }
      end
    end
  end
end
