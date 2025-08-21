# frozen_string_literal: true

module Ruleur
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
      # If kwargs are provided, merge them with initial_facts
      # but exclude engine control parameters
      kwargs.delete(:trace)
      initial_facts = initial_facts.merge(kwargs) unless kwargs.empty?
      ctx = initial_facts.is_a?(Context) ? initial_facts : Context.new(initial_facts)
      cycles = 0

      loop do
        cycles += 1
        break if cycles > max_cycles

        conflict_set = @rules.select { |r| r.eligible?(ctx) }
                             .sort_by { |r| [-r.salience, r.name] }

        break if conflict_set.empty?

        conflict_set.each do |rule|
          log "Firing: #{rule.name} (salience=#{rule.salience})"
          before = ctx.facts.dup
          rule.fire(ctx)
          after = ctx.facts
          log "Facts changed: #{(after.to_a - before.to_a).map(&:first).join(', ')}" if before != after
        end
      end

      ctx
    end

    private

    def log(msg)
      warn "[Ruleur] #{msg}" if trace
    end
  end
end
