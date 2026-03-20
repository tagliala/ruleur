# frozen_string_literal: true

require_relative 'validation/validation_result'
require_relative 'validation/condition_validator'
require_relative 'validation/action_validator'
require_relative 'validation/rule_validator'

module Ruleur
  # Validation provides comprehensive rule validation before persistence/execution
  module Validation
    module_function

    # Validate a Rule object
    # @param rule [Rule] Rule to validate
    # @param test_context [Hash, Context, nil] Optional context for test execution
    # @return [ValidationResult] Validation outcome
    def validate_rule(rule, test_context: nil)
      validator = RuleValidator.new(test_context: test_context)
      validator.validate_rule(rule)
    end

    # Validate a rule hash (before deserialization)
    # @param rule_hash [Hash] Serialized rule
    # @return [ValidationResult] Validation outcome
    def validate_hash(rule_hash)
      validator = RuleValidator.new
      validator.validate_hash(rule_hash)
    end

    # Validate a condition node
    # @param condition [Condition::Node] Condition to validate
    # @return [ValidationResult] Validation outcome
    def validate_condition(condition)
      validator = ConditionValidator.new
      validator.validate(condition)
    end

    # Validate an action spec
    # @param action_spec [Hash] Action specification
    # @return [ValidationResult] Validation outcome
    def validate_action(action_spec)
      validator = ActionValidator.new
      validator.validate(action_spec)
    end
  end
end
