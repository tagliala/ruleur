# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Validation do
  describe 'ValidationResult' do
    it 'starts as valid with no errors' do
      result = Ruleur::Validation::ValidationResult.new
      expect(result.valid?).to be(true)
      expect(result.errors).to be_empty
      expect(result.warnings).to be_empty
    end

    it 'becomes invalid when error added' do
      result = Ruleur::Validation::ValidationResult.new
      result.add_error('Test error')
      expect(result.valid?).to be(false)
      expect(result.errors).to eq(['Test error'])
    end

    it 'allows warnings without affecting validity' do
      result = Ruleur::Validation::ValidationResult.new
      result.add_warning('Test warning')
      expect(result.valid?).to be(true)
      expect(result.warnings).to eq(['Test warning'])
    end

    it 'merges results correctly' do
      result1 = Ruleur::Validation::ValidationResult.new
      result1.add_error('Error 1')
      result1.add_warning('Warning 1')

      result2 = Ruleur::Validation::ValidationResult.new
      result2.add_error('Error 2')

      result1.merge(result2)

      expect(result1.errors).to eq(['Error 1', 'Error 2'])
      expect(result1.warnings).to eq(['Warning 1'])
    end

    it 'converts to hash' do
      result = Ruleur::Validation::ValidationResult.new
      result.add_error('Test error')
      result.add_warning('Test warning')

      hash = result.to_h
      expect(hash[:valid]).to be(false)
      expect(hash[:errors]).to eq(['Test error'])
      expect(hash[:warnings]).to eq(['Test warning'])
    end
  end

  describe 'ConditionValidator' do
    let(:validator) { Ruleur::Validation::ConditionValidator.new }

    it 'validates simple predicate' do
      cond = Ruleur::Condition::Predicate.new(
        Ruleur::Condition::Ref.new(:status),
        :eq,
        'active'
      )

      result = validator.validate(cond)
      expect(result.valid?).to be(true)
    end

    it 'detects unknown operator' do
      cond = Ruleur::Condition::Predicate.new(
        Ruleur::Condition::Ref.new(:value),
        :unknown_op,
        10
      )

      result = validator.validate(cond)
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/Unknown operator: :unknown_op/)
    end

    it 'validates All composite condition' do
      cond = Ruleur::Condition::All.new(
        Ruleur::Condition::Predicate.new(:x, :eq, 1),
        Ruleur::Condition::Predicate.new(:y, :eq, 2)
      )

      result = validator.validate(cond)
      expect(result.valid?).to be(true)
    end

    it 'warns about empty composite conditions' do
      cond = Ruleur::Condition::All.new

      result = validator.validate(cond)
      expect(result.valid?).to be(true)
      expect(result.warnings).to include(/All node has no children/)
    end

    it 'validates Not condition' do
      cond = Ruleur::Condition::Not.new(
        Ruleur::Condition::Predicate.new(:flag, :truthy, nil)
      )

      result = validator.validate(cond)
      expect(result.valid?).to be(true)
    end

    it 'validates Ref values' do
      cond = Ruleur::Condition::Predicate.new(
        Ruleur::Condition::Ref.new(:user, :name),
        :eq,
        'admin'
      )

      result = validator.validate(cond)
      expect(result.valid?).to be(true)
    end

    it 'validates Call values' do
      call = Ruleur::Condition::Call.new(
        Ruleur::Condition::Ref.new(:user),
        :admin?
      )

      cond = Ruleur::Condition::Predicate.new(call, :truthy, nil)

      result = validator.validate(cond)
      expect(result.valid?).to be(true)
    end

    it 'detects invalid Call receiver' do
      # Create a Call with an invalid receiver (string instead of Ref)
      call = Ruleur::Condition::Call.allocate
      call.instance_variable_set(:@receiver, 'invalid')
      call.instance_variable_set(:@method_name, :test)
      call.instance_variable_set(:@args, [])

      cond = Ruleur::Condition::Predicate.new(call, :truthy, nil)

      result = validator.validate(cond)
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/invalid receiver type/)
    end

    it 'warns about LambdaValue (non-serializable)' do
      lambda_val = Ruleur::Condition::LambdaValue.new(-> { 42 })
      cond = Ruleur::Condition::Predicate.new(lambda_val, :eq, 42)

      result = validator.validate(cond)
      expect(result.valid?).to be(true)
      expect(result.warnings).to include(/cannot be serialized/)
    end

    it 'warns about BlockPredicate (arbitrary code)' do
      block_pred = Ruleur::Condition::BlockPredicate.new { |_ctx| true }

      result = validator.validate(block_pred)
      expect(result.valid?).to be(true)
      expect(result.warnings).to include(/arbitrary code/)
    end
  end

  describe 'ActionValidator' do
    let(:validator) { Ruleur::Validation::ActionValidator.new }

    it 'validates simple set action' do
      action_spec = { set: { result: true, value: 42 } }

      result = validator.validate(action_spec)
      expect(result.valid?).to be(true)
    end

    it 'detects nil action spec' do
      result = validator.validate(nil)
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/cannot be nil or empty/)
    end

    it 'detects empty action spec' do
      result = validator.validate({})
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/cannot be nil or empty/)
    end

    it 'detects invalid action spec type' do
      result = validator.validate('not a hash')
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/must be a Hash/)
    end

    it 'detects invalid set action type' do
      action_spec = { set: 'not a hash' }

      result = validator.validate(action_spec)
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/must be a Hash/)
    end

    it 'warns about empty set action' do
      action_spec = { set: {} }

      result = validator.validate(action_spec)
      expect(result.valid?).to be(true)
      expect(result.warnings).to include(/is empty/)
    end

    it 'validates Ref values in actions' do
      action_spec = { set: { result: Ruleur::Condition::Ref.new(:computed_value) } }

      result = validator.validate(action_spec)
      expect(result.valid?).to be(true)
    end

    it 'validates Call values in actions' do
      call = Ruleur::Condition::Call.new(Ruleur::Condition::Ref.new(:obj), :compute)
      action_spec = { set: { result: call } }

      result = validator.validate(action_spec)
      expect(result.valid?).to be(true)
    end

    it 'warns about LambdaValue in actions' do
      lambda_val = Ruleur::Condition::LambdaValue.new(-> { 42 })
      action_spec = { set: { result: lambda_val } }

      result = validator.validate(action_spec)
      expect(result.valid?).to be(true)
      expect(result.warnings).to include(/cannot be serialized/)
    end

    it 'warns about unknown action types' do
      action_spec = { set: { x: 1 }, unknown_action: { y: 2 } }

      result = validator.validate(action_spec)
      expect(result.valid?).to be(true)
      expect(result.warnings).to include(/Unknown action type: 'unknown_action'/)
    end
  end

  describe 'RuleValidator' do
    let(:validator) { Ruleur::Validation::RuleValidator.new }

    it 'validates complete valid rule' do
      rule = Ruleur::Rule.new(
        name: 'test_rule',
        condition: Ruleur::Condition::Predicate.new(:x, :eq, 5),
        action_spec: { set: { y: 10 } }
      )

      result = validator.validate_rule(rule)
      expect(result.valid?).to be(true)
    end

    it 'detects missing rule name' do
      rule = Ruleur::Rule.new(
        name: nil,
        condition: Ruleur::Condition::Predicate.new(:x, :eq, 5),
        action_spec: { set: { y: 10 } }
      )

      result = validator.validate_rule(rule)
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/name cannot be nil/)
    end

    it 'detects empty rule name' do
      rule = Ruleur::Rule.new(
        name: '  ',
        condition: Ruleur::Condition::Predicate.new(:x, :eq, 5),
        action_spec: { set: { y: 10 } }
      )

      result = validator.validate_rule(rule)
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/name cannot be nil or empty/)
    end

    it 'detects nil condition' do
      rule = Ruleur::Rule.allocate
      rule.instance_variable_set(:@name, 'test')
      rule.instance_variable_set(:@condition, nil)
      rule.instance_variable_set(:@action_spec, { set: { y: 10 } })
      rule.instance_variable_set(:@salience, 0)
      rule.instance_variable_set(:@tags, [])
      rule.instance_variable_set(:@no_loop, false)

      result = validator.validate_rule(rule)
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/condition cannot be nil/)
    end

    it 'detects invalid salience type' do
      rule = Ruleur::Rule.allocate
      rule.instance_variable_set(:@name, 'test')
      rule.instance_variable_set(:@condition, Ruleur::Condition::Predicate.new(:x, :eq, 5))
      rule.instance_variable_set(:@action_spec, { set: { y: 10 } })
      rule.instance_variable_set(:@salience, 'not an integer')
      rule.instance_variable_set(:@tags, [])
      rule.instance_variable_set(:@no_loop, false)

      result = validator.validate_rule(rule)
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/Salience must be an Integer/)
    end

    it 'validates rule hash before deserialization' do
      rule_hash = {
        name: 'test',
        condition: { type: 'pred', op: 'eq', left: 'x', right: 5 },
        action: { set: { y: 10 } }
      }

      result = validator.validate_hash(rule_hash)
      expect(result.valid?).to be(true)
    end

    it 'detects missing required fields in hash' do
      rule_hash = { name: 'test' }

      result = validator.validate_hash(rule_hash)
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/Missing required field: condition/)
      expect(result.errors).to include(/Missing required field: action/)
    end

    it 'detects invalid condition type in hash' do
      rule_hash = {
        name: 'test',
        condition: { type: 'invalid_type' },
        action: { set: { y: 10 } }
      }

      result = validator.validate_hash(rule_hash)
      expect(result.valid?).to be(false)
      expect(result.errors).to include(/Invalid condition type/)
    end

    it 'performs test execution when context provided' do
      rule = Ruleur::Rule.new(
        name: 'test_rule',
        condition: Ruleur::Condition::Predicate.new(
          Ruleur::Condition::Ref.new(:status),
          :eq,
          'active'
        ),
        action_spec: { set: { approved: true } }
      )

      validator_with_test = Ruleur::Validation::RuleValidator.new(
        test_context: { status: 'active' }
      )

      result = validator_with_test.validate_rule(rule)
      expect(result.valid?).to be(true)
      expect(result.warnings).to include(/Test execution passed/)
    end

    it 'detects runtime errors during test execution' do
      # Create a rule that will fail at runtime
      rule = Ruleur::Rule.new(
        name: 'failing_rule',
        condition: Ruleur::Condition::Predicate.new(
          Ruleur::Condition::Call.new(Ruleur::Condition::Ref.new(:obj), :nonexistent_method),
          :eq,
          true
        ),
        action_spec: { set: { result: true } }
      )

      validator_with_test = Ruleur::Validation::RuleValidator.new(
        test_context: { obj: Object.new }
      )

      result = validator_with_test.validate_rule(rule)
      expect(result.valid?).to be(false)
      expect(result.errors.join).to include(/Test execution failed/)
    end
  end

  describe 'module-level convenience methods' do
    it 'provides validate_rule shortcut' do
      rule = Ruleur::Rule.new(
        name: 'test',
        condition: Ruleur::Condition::Predicate.new(:x, :eq, 5),
        action_spec: { set: { y: 10 } }
      )

      result = described_class.validate_rule(rule)
      expect(result).to be_a(Ruleur::Validation::ValidationResult)
      expect(result.valid?).to be(true)
    end

    it 'provides validate_hash shortcut' do
      hash = {
        name: 'test',
        condition: { type: 'pred', op: 'eq', left: 'x', right: 5 },
        action: { set: { y: 10 } }
      }

      result = described_class.validate_hash(hash)
      expect(result).to be_a(Ruleur::Validation::ValidationResult)
      expect(result.valid?).to be(true)
    end

    it 'provides validate_condition shortcut' do
      cond = Ruleur::Condition::Predicate.new(:x, :eq, 5)

      result = described_class.validate_condition(cond)
      expect(result).to be_a(Ruleur::Validation::ValidationResult)
      expect(result.valid?).to be(true)
    end

    it 'provides validate_action shortcut' do
      action_spec = { set: { y: 10 } }

      result = described_class.validate_action(action_spec)
      expect(result).to be_a(Ruleur::Validation::ValidationResult)
      expect(result.valid?).to be(true)
    end
  end
end
