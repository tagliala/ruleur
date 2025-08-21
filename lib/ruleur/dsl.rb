# frozen_string_literal: true

module Ruleur
  module DSL
    include Condition::Builders

    # Small helpers for a "fine" DSL without metaprogramming hazards
    module Shortcuts
      def rec(*path)
        Condition::Builders.truthy(Condition::Builders.ref(:record, *path))
      end

      def usr(*path)
        Condition::Builders.truthy(Condition::Builders.ref(:user, *path))
      end

      # use inside predicates: value of a record/user property
      def rec_val(*path)
        Condition::Builders.ref(:record, *path)
      end

      def usr_val(*path)
        Condition::Builders.ref(:user, *path)
      end

      # refer to a permission flag like :allow_create
      def flag(name)
        Condition::Builders.truthy(Condition::Builders.ref(:"allow_#{name}"))
      end
    end

    class RuleBuilder
      include Condition::Builders
      include Shortcuts

      def initialize(name, **opts)
        @name = name.to_s
        @opts = opts
        @conds = []
        @action = nil
        @action_spec = nil
      end

      def all(*children, &block)
        children += [instance_eval(&block)] if block
        Condition::All.new(*children)
      end

      def any(*children, &block)
        children += [instance_eval(&block)] if block
        Condition::Any.new(*children)
      end

      # Inline builder helpers: returns a Condition::Node
      def when_all(*children, &)
        @conds << all(*children, &)
      end

      def when_any(*children, &)
        @conds << any(*children, &)
      end

      # Low-level: add a predicate explicitly
      def when_predicate(&)
        @conds << predicate(&)
      end

      # Action helpers

      # Set a fact key to a literal or resolved value
      def set(key, value)
        action { |ctx| ctx[key] = resolve_value_for_action(ctx, value) }
        @action_spec ||= { set: {} }
        @action_spec[:set][key.to_sym] = value
      end

      # Assert multiple facts at once from a hash
      def assert(hash)
        action do |ctx|
          hash.each do |k, v|
            ctx[k] = resolve_value_for_action(ctx, v)
          end
        end
        @action_spec ||= { set: {} }
        hash.each { |k, v| @action_spec[:set][k.to_sym] = v }
      end

      # Convenience to set allow_#{sym} => true
      def allow!(sym)
        set(:"allow_#{sym}", true)
      end

      # Provide arbitrary action
      def action(&block)
        @action = block
        # If the block calls DSL methods, we need to capture them
        instance_eval(&block) if block.arity.zero?
      end

      alias then action

      def build
        cond = if @conds.empty?
                 Condition::Predicate.new(true, :eq, true)
               elsif @conds.size == 1
                 @conds.first
               else
                 Condition::All.new(*@conds)
               end

        Rule.new(
          name: @name,
          condition: cond,
          action: @action || ->(_ctx) {},
          action_spec: @action_spec,
          **@opts
        )
      end

      private

      def resolve_value_for_action(ctx, val)
        case val
        when Condition::Ref, Condition::Call, Condition::LambdaValue
          ctx.resolve_value(val)
        else
          val
        end
      end
    end

    class EngineBuilder
      include Shortcuts

      def initialize
        @engine = Engine.new
      end

      def rule(name, salience: 0, tags: [], no_loop: false, &block)
        rb = RuleBuilder.new(name, salience: salience, tags: tags, no_loop: no_loop)
        rb.instance_eval(&block)
        @engine.add_rule(rb.build)
      end

      def build
        @engine
      end
    end

    module_function

    def build(&)
      eb = EngineBuilder.new
      eb.instance_eval(&)
      eb.build
    end
  end
end
