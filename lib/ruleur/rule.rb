# frozen_string_literal: true

module Ruleur
  # Rule represents a single business rule with condition, action, and metadata
  class Rule
    attr_reader :name, :condition, :action, :salience, :tags, :no_loop, :action_spec

    # rubocop:disable Metrics/ParameterLists
    def initialize(name:, condition:, action: nil, action_spec: nil, salience: 0, tags: [], no_loop: false)
      @name = name.to_s
      @condition = condition
      @action = action # ->(ctx) { ... }
      @action_spec = action_spec # serializable action (e.g., { set: { allow_update: true } })
      @salience = salience.to_i
      @tags = Array(tags).map!(&:to_sym)
      @no_loop = !no_loop.nil?
      @fired_once = false
    end
    # rubocop:enable Metrics/ParameterLists

    def eligible?(ctx)
      return false if no_loop && @fired_once

      !!condition.evaluate(ctx)
    end

    def fire(ctx)
      if action
        action.call(ctx)
      elsif action_spec
        ActionRunner.apply_action(ctx, action_spec)
      end
      @fired_once = true if no_loop
    end

    # ActionRunner handles execution of serialized action specifications
    module ActionRunner
      module_function

      # rubocop:disable Naming/PredicateMethod
      # apply_action performs an action and returns success status - intentional naming
      def apply_action(ctx, spec)
        spec = stringify_keys(spec)
        return true unless spec['set'].is_a?(Hash)

        spec['set'].each do |key, value|
          ctx[key.to_sym] = resolve_value(ctx, value)
        end
        true
      end
      # rubocop:enable Naming/PredicateMethod

      def stringify_keys(obj)
        case obj
        when Hash then obj.transform_keys(&:to_s).transform_values { |v| stringify_keys(v) }
        when Array then obj.map { |e| stringify_keys(e) }
        else obj
        end
      end

      def resolve_value(ctx, val)
        case val
        when Condition::Ref, Condition::Call, Condition::LambdaValue
          ctx.resolve_value(val)
        else
          val
        end
      end
    end
  end
end
