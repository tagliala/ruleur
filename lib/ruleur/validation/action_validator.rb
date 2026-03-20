# frozen_string_literal: true

require_relative 'validation_result'

module Ruleur
  module Validation
    # ActionValidator validates action specifications
    class ActionValidator
      def initialize
        @result = ValidationResult.new
      end

      # rubocop:disable Metrics/MethodLength
      def validate(action_spec)
        @result = ValidationResult.new

        if action_spec.nil? || action_spec.empty?
          @result.add_error('Action spec cannot be nil or empty')
          return @result
        end

        unless action_spec.is_a?(Hash)
          @result.add_error("Action spec must be a Hash, got #{action_spec.class}")
          return @result
        end

        validate_set_action(action_spec[:set]) if action_spec[:set]
        validate_unknown_actions(action_spec)

        @result
      end
      # rubocop:enable Metrics/MethodLength

      private

      # rubocop:disable Metrics/MethodLength
      def validate_set_action(set_hash)
        unless set_hash.is_a?(Hash)
          @result.add_error("Action 'set' must be a Hash, got #{set_hash.class}")
          return
        end

        @result.add_warning("Action 'set' is empty") if set_hash.empty?

        set_hash.each do |key, value|
          unless key.is_a?(Symbol) || key.is_a?(String)
            @result.add_error("Action 'set' key must be Symbol or String, got #{key.class}")
          end

          validate_action_value(value, key)
        end
      end
      # rubocop:enable Metrics/MethodLength

      def validate_action_value(value, key)
        case value
        when Condition::Ref, Condition::Call
          # These will be resolved at runtime
        when Condition::LambdaValue
          @result.add_warning("LambdaValue at key '#{key}' cannot be serialized")
        when nil, String, Numeric, TrueClass, FalseClass, Symbol, Array, Hash
          # Valid literal values
        else
          @result.add_error("Invalid action value type at key '#{key}': #{value.class}")
        end
      end

      def validate_unknown_actions(action_spec)
        # Currently only 'set' is supported
        known_actions = [:set]
        unknown = action_spec.keys.map(&:to_sym) - known_actions

        unknown.each do |action|
          @result.add_warning("Unknown action type: '#{action}' (may not be serializable)")
        end
      end
    end
  end
end
