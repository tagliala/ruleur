# frozen_string_literal: true

module Ruleur
  class Rule
    attr_reader :name, :condition, :action, :salience, :tags, :no_loop, :action_spec

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

    def eligible?(ctx)
      return false if no_loop && @fired_once

      !!condition.evaluate(ctx)
    end

    def fire(ctx)
      if action
        action.call(ctx)
      elsif action_spec
        ActionRunner.apply(ctx, action_spec)
      end
      @fired_once = true if no_loop
    end

    module ActionRunner
      module_function

      def apply(ctx, spec)
        spec = stringify_keys(spec)
        if spec['set'].is_a?(Hash)
          spec['set'].each do |k, v|
            ctx[k.to_sym] = resolve_value(ctx, v)
          end
        end
        true
      end

      def stringify_keys(obj)
        case obj
        when Hash then obj.transform_keys(&:to_s).transform_values { |v| stringify_keys(v) }
        when Array then obj.map { |e| stringify_keys(e) }
        else obj
        end
      end

      def resolve_value(ctx, v)
        case v
        when Condition::Ref, Condition::Call, Condition::LambdaValue
          ctx.resolve_value(v)
        else
          v
        end
      end
    end
  end
end
