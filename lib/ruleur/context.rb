# frozen_string_literal: true

module Ruleur
  # Simple fact/context container. Supports resolving references via method chain.
  class Context
    attr_reader :facts

    def initialize(facts = {})
      @facts = facts.transform_keys(&:to_sym)
    end

    def [](key)
      @facts[key.to_sym]
    end

    def []=(key, value)
      @facts[key.to_sym] = value
    end

    def fetch(key, ...)
      @facts.fetch(key.to_sym, ...)
    end

    # Resolve a reference path starting from a root fact key.
    # path can contain symbols (method calls) or arrays like [:method, arg1, arg2]
    def resolve_ref(root_key, *path)
      obj = @facts[root_key.to_sym]
      path.each do |segment|
        return nil if obj.nil?

        obj = resolve_segment(obj, segment)
      end
      obj
    end

    # Resolve a Value-like object (Ref/Call/Literal) or raw literal.
    def resolve_value(val)
      case val
      when Condition::Ref
        resolve_ref(val.root, *val.path)
      when Condition::Call
        resolve_call_value(val)
      when Condition::LambdaValue
        val.block.call(self)
      else
        val
      end
    end

    private

    def resolve_segment(obj, segment)
      if segment.is_a?(Array)
        method_name, *args = segment
        obj.public_send(method_name, *resolve_args(args))
      else
        obj.public_send(segment)
      end
    end

    def resolve_args(args)
      args.map { |a| resolve_value(a) }
    end

    def resolve_call_value(val)
      recv = resolve_value(val.receiver)
      args = resolve_args(val.args)
      recv&.public_send(val.method_name, *args)
    end
  end
end
