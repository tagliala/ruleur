# frozen_string_literal: true

module Ruleur
  # Simple fact/context container. Supports resolving references via method chain.
  class Context
    attr_reader :facts, :debug

    def initialize(facts = {})
      @facts = facts.transform_keys(&:to_sym)
      # collect debug info separately from facts; allow callers to pass a preseeded :debug
      @debug = @facts.delete(:debug) || []
      # pointer to track which debug entries have been consumed by the engine
      @debug_consumed = 0
      # protect debug array and counters when accessed from multiple threads
      @debug_lock = Mutex.new
    end

    # Temporarily set the current rule for predicate-level debugging
    # current_rule is stored per-thread so concurrent requests using the same
    # Context instance don't clobber each other's active rule marker.
    def with_current_rule(rule_name)
      key = :"ruleur_current_rule_#{object_id}"
      old = Thread.current[key]
      Thread.current[key] = rule_name
      yield
    ensure
      Thread.current[key] = old
    end

    def current_rule
      key = :"ruleur_current_rule_#{object_id}"
      Thread.current[key]
    end

    # Add a debug entry in a thread-safe manner
    def add_debug(entry)
      @debug_lock.synchronize { @debug << entry }
    end

    # Return debug entries that have not yet been consumed and mark them consumed.
    def drain_debug_since_last
      return [] unless @debug.is_a?(Array)

      @debug_lock.synchronize do
        new_entries = @debug[@debug_consumed..-1] || []
        @debug_consumed = @debug.length
        new_entries
      end
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
