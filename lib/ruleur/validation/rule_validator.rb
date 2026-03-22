# frozen_string_literal: true

require_relative 'validation_result'
require_relative 'condition_validator'
require_relative 'action_validator'

module Ruleur
  module Validation
    # RuleValidator validates complete rules (structure, semantics, and optional execution)
    # rubocop:disable Metrics/ClassLength
    class RuleValidator
      def initialize(test_context: nil)
        @test_context = test_context
        @condition_validator = ConditionValidator.new
        @action_validator = ActionValidator.new
      end

      # Validate a Rule object
      # @param rule [Rule] Rule to validate
      # @return [ValidationResult] Validation outcome
      # rubocop:disable Metrics/MethodLength
      def validate_rule(rule)
        result = ValidationResult.new

        # Validate basic structure
        validate_structure(rule, result)

        # Validate condition tree
        if rule.condition
          condition_result = @condition_validator.validate(rule.condition)
          result.merge(condition_result)
        end

        # Validate action spec
        if rule.action_spec
          action_result = @action_validator.validate(rule.action_spec)
          result.merge(action_result)
        end

        # Optional: test execution
        if @test_context && result.valid?
          execution_result = test_execution(rule)
          result.merge(execution_result)
        end

        result
      end
      # rubocop:enable Metrics/MethodLength

      # Validate a rule hash (before deserialization)
      # @param rule_hash [Hash] Serialized rule
      # @return [ValidationResult] Validation outcome
      def validate_hash(rule_hash)
        result = ValidationResult.new

        # Check required fields
        validate_required_fields(rule_hash, result)

        # Validate condition structure
        validate_condition_hash(rule_hash[:conditions], result) if rule_hash[:conditions]

        # Validate action structure
        validate_action_hash(rule_hash[:actions], result) if rule_hash[:actions]

        result
      end

      private

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
      def validate_structure(rule, result)
        result.add_error('Rule name cannot be nil or empty') if rule.name.nil? || rule.name.to_s.strip.empty?

        result.add_error('Rule condition cannot be nil') if rule.condition.nil?
        result.add_error('Rule action_spec cannot be nil') if rule.action_spec.nil?

        # Validate metadata
        result.add_error("Salience must be an Integer, got #{rule.salience.class}") unless rule.salience.is_a?(Integer)

        result.add_error("Tags must be an Array, got #{rule.tags.class}") unless rule.tags.is_a?(Array)

        return if [true, false].include?(rule.no_loop)

        result.add_error("no_loop must be boolean, got #{rule.no_loop.class}")
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

      def validate_required_fields(hash, result)
        result.add_error('Missing required field: name') unless hash[:name]
        result.add_error('Missing required field: conditions') unless hash[:conditions]
        result.add_error('Missing required field: actions') unless hash[:actions]
      end

      # rubocop:disable Metrics/MethodLength
      def validate_condition_hash(cond_hash, result)
        unless cond_hash.is_a?(Hash)
          result.add_error("Condition must be a Hash, got #{cond_hash.class}")
          return
        end

        type = cond_hash[:type]
        unless %w[pred all any not].include?(type)
          result.add_error("Invalid condition type: #{type.inspect}")
          return
        end

        case type
        when 'pred'
          validate_predicate_hash(cond_hash, result)
        when 'all', 'any'
          validate_composite_hash(cond_hash, result, type)
        when 'not'
          validate_not_hash(cond_hash, result)
        end
      end
      # rubocop:enable Metrics/MethodLength

      def validate_predicate_hash(hash, result)
        result.add_error('Predicate missing operator') unless hash[:op]

        # Check if operator exists (only if we can access Operators)
        return unless defined?(Ruleur::Operators) && hash[:op]

        op_sym = hash[:op].to_sym
        return if Ruleur::Operators.registry.key?(op_sym)

        result.add_error("Unknown operator: #{hash[:op].inspect}")
      end

      def validate_composite_hash(hash, result, type)
        children = hash[:children]

        unless children.is_a?(Array)
          result.add_error("#{type} condition must have children array")
          return
        end

        result.add_warning("#{type} condition has no children") if children.empty?

        children.each do |child|
          validate_condition_hash(child, result)
        end
      end

      def validate_not_hash(hash, result)
        child = hash[:child]

        if child.nil?
          result.add_error('Not condition must have child')
        else
          validate_condition_hash(child, result)
        end
      end

      def validate_action_hash(action_hash, result)
        unless action_hash.is_a?(Hash)
          result.add_error("Action must be a Hash, got #{action_hash.class}")
          return
        end

        result.add_error('Action cannot be empty') if action_hash.empty?

        # Currently only 'set' is supported
        return unless action_hash[:set]
        return if action_hash[:set].is_a?(Hash)

        result.add_error("Action 'set' must be a Hash")
      end

      def test_execution(rule)
        result = ValidationResult.new

        begin
          ctx = @test_context.is_a?(Context) ? @test_context : Context.new(@test_context)

          # Try to evaluate condition
          rule.eligible?(ctx)

          # Try to fire action
          rule.fire(ctx)

          result.add_warning('Test execution passed')
        rescue StandardError => e
          result.add_error("Test execution failed: #{e.message}")
        end

        result
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
