# frozen_string_literal: true

module Ruleur
  # Engine implements a forward-chaining rule engine with salience-based conflict resolution
  class Engine
    attr_reader :rules, :trace

    def initialize(rules: [], trace: false)
      @rules = []
      @trace = !trace.nil?
      rules.each { |r| add_rule(r) }
    end

    def add_rule(rule)
      @rules << rule
      self
    end

    # Run forward-chaining until fixpoint or max_cycles
    def run(initial_facts = {}, max_cycles: 100, **kwargs)
      ctx = prepare_context(initial_facts, kwargs)
      execute_cycles(ctx, max_cycles)
      ctx
    end

    private

    def prepare_context(initial_facts, kwargs)
      # If kwargs are provided, merge them with initial_facts
      # but exclude engine control parameters
      kwargs.delete(:trace)
      initial_facts = initial_facts.merge(kwargs) unless kwargs.empty?
      initial_facts.is_a?(Context) ? initial_facts : Context.new(initial_facts)
    end

    def execute_cycles(ctx, max_cycles)
      cycles = 0

      loop do
        cycles += 1
        break if cycles > max_cycles

        conflict_set = build_conflict_set(ctx)
        break if conflict_set.empty?

        fire_rules(conflict_set, ctx)
      end
    end

    def build_conflict_set(ctx)
      @rules.select { |r| r.eligible?(ctx) }
            .sort_by { |r| [-r.salience, r.name] }
    end

    def fire_rules(conflict_set, ctx)
      conflict_set.each do |rule|
        log "Firing: #{rule.name} (salience=#{rule.salience})"
        before = ctx.facts.dup
        rule.fire(ctx)
        after = ctx.facts
        log_fact_changes(before, after)
      end
    end

    def log_fact_changes(before, after)
      return if before == after

      changed = (after.to_a - before.to_a).map(&:first).join(', ')
      log "Facts changed: #{changed}"
    end

    def log(msg)
      warn "[Ruleur] #{msg}" if trace
    end
  end
end
