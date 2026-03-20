# frozen_string_literal: true

require_relative 'validation_result'

module Ruleur
  module Validation
    # ConditionValidator validates condition tree structure and semantics
    class ConditionValidator
      def initialize
        @result = ValidationResult.new
      end

      def validate(condition_node)
        @result = ValidationResult.new
        validate_node(condition_node)
        @result
      end

      private

      # rubocop:disable Metrics/MethodLength
      def validate_node(node)
        case node
        when Condition::Predicate
          validate_predicate(node)
        when Condition::All, Condition::Any
          validate_composite(node)
        when Condition::Not
          validate_not(node)
        when Condition::BlockPredicate
          validate_block_predicate(node)
        else
          @result.add_error("Unknown condition node type: #{node.class}")
        end
      end
      # rubocop:enable Metrics/MethodLength

      def validate_predicate(node)
        # Check if operator exists
        operator = node.instance_variable_get(:@operator)
        @result.add_error("Unknown operator: #{operator.inspect}") unless Operators.registry.key?(operator)

        # Validate left and right values
        left = node.instance_variable_get(:@left)
        right = node.instance_variable_get(:@right)

        validate_value(left, 'left')
        validate_value(right, 'right')
      end

      def validate_composite(node)
        children = node.children

        @result.add_warning("#{node.class.name.split('::').last} node has no children") if children.empty?

        children.each { |child| validate_node(child) }
      end

      def validate_not(node)
        validate_node(node.child)
      end

      def validate_block_predicate(_node)
        # BlockPredicate contains arbitrary Ruby code; can't validate deeply
        @result.add_warning('BlockPredicate contains arbitrary code; runtime validation only')
      end

      # rubocop:disable Metrics/MethodLength
      def validate_value(value, position)
        case value
        when Condition::Ref
          validate_ref(value, position)
        when Condition::Call
          validate_call(value, position)
        when Condition::LambdaValue
          @result.add_warning("LambdaValue at #{position} cannot be serialized")
        when nil, String, Numeric, TrueClass, FalseClass, Symbol, Array, Hash
          # Valid literal values
        else
          @result.add_error("Invalid value type at #{position}: #{value.class}")
        end
      end
      # rubocop:enable Metrics/MethodLength

      def validate_ref(ref, position)
        # Check that root is a symbol or string
        unless ref.root.is_a?(Symbol) || ref.root.is_a?(String)
          @result.add_error("Ref at #{position} has invalid root type: #{ref.root.class}")
        end

        # Check that path is an array
        return if ref.path.is_a?(Array)

        @result.add_error("Ref at #{position} has invalid path type: #{ref.path.class}")
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      def validate_call(call, position)
        # Validate receiver
        receiver = call.receiver
        unless receiver.is_a?(Condition::Ref) || receiver.is_a?(Condition::Call)
          @result.add_error("Call at #{position} has invalid receiver type: #{receiver.class}")
        end

        validate_value(receiver, "#{position}.receiver") if receiver.is_a?(Condition::Ref)

        # Validate method name
        unless call.method_name.is_a?(Symbol) || call.method_name.is_a?(String)
          @result.add_error("Call at #{position} has invalid method name type: #{call.method_name.class}")
        end

        # Validate arguments (handle nil case)
        args = call.args || []
        args.each_with_index do |arg, idx|
          validate_value(arg, "#{position}.arg[#{idx}]")
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    end
  end
end
