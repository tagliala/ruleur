# frozen_string_literal: true

module Ruleur
  # Engine implements a forward-chaining rule engine with salience-based conflict resolution
  class Engine
    attr_reader :rules, :trace, :stats

    def initialize(rules: [], trace: false)
      @rules = []
      @trace = !trace.nil?
      # stats holds aggregated timings collected across runs in this Engine instance
      @stats = { rules: {}, predicates: {} }
      # lock to protect stats when engine is shared across threads
      @stats_lock = Mutex.new
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
      # Sort by salience (desc) and estimated predicate cost (asc) so cheaper rules
      # within the same salience fire earlier. Use recorded averages when available.
      @rules.select do |r|
        if ctx.respond_to?(:with_current_rule)
          ctx.with_current_rule(r.name) { r.eligible?(ctx) }
        else
          r.eligible?(ctx)
        end
      end.sort_by { |r| [-r.salience, estimate_rule_cost(r.name), r.name] }
    end

    def estimate_rule_cost(rule_name)
      @stats_lock.synchronize do
        data = @stats[:rules][rule_name]
        data ? (data[:total_ms] / data[:count]) : 0.0
      end
    end

    def fire_rules(conflict_set, ctx)
      conflict_set.each do |rule|
        log "Firing: #{rule.name} (salience=#{rule.salience})"
        before = ctx.facts.dup
        debug_len = ctx.debug.length

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        # set current_rule for predicate-level timings
        ctx.with_current_rule(rule.name) do
          rule.fire(ctx)
        end
        duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000.0
        after = ctx.facts

        changed = (after.to_a - before.to_a).map(&:first)

        # append rule-level debug info to context if available
        begin
          ctx.debug << { rule: rule.name, salience: rule.salience, duration_ms: duration_ms, changed: changed }
        rescue StandardError
          # ignore if context doesn't support debug
        end

        # aggregate stats from any new debug entries (predicate timings etc.)
        new_entries = if ctx.respond_to?(:drain_debug_since_last)
                        ctx.drain_debug_since_last
                      else
                        ctx.debug[debug_len..-1] || []
                      end
        update_stats_from_debug(new_entries)

        log "Fired: #{rule.name} (salience=#{rule.salience}) in #{'%.3f' % duration_ms}ms"
        log_fact_changes(before, after)
      end
    end

    def update_stats_from_debug(entries)
      @stats_lock.synchronize do
        entries.each do |e|
          if e.is_a?(Hash) && e[:rule] && e[:duration_ms]
            # rule-level entry
            r = e[:rule].to_s
            @stats[:rules][r] ||= { total_ms: 0.0, count: 0 }
            @stats[:rules][r][:total_ms] += e[:duration_ms].to_f
            @stats[:rules][r][:count] += 1
          end

          next unless e.is_a?(Hash) && e[:predicate] && e[:duration_ms]

          p = e[:predicate].to_sym
          @stats[:predicates][p] ||= { total_ms: 0.0, count: 0 }
          @stats[:predicates][p][:total_ms] += e[:duration_ms].to_f
          @stats[:predicates][p][:count] += 1
        end
      end
    end

    # Convenience accessors for averages
    def rule_avg_ms(name)
      @stats_lock.synchronize do
        d = @stats[:rules][name.to_s]
        d && d[:count] > 0 ? (d[:total_ms] / d[:count]) : nil
      end
    end

    def predicate_avg_ms(predicate)
      @stats_lock.synchronize do
        d = @stats[:predicates][predicate.to_sym]
        d && d[:count] > 0 ? (d[:total_ms] / d[:count]) : nil
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
