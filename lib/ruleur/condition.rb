# frozen_string_literal: true

module Ruleur
  # Condition provides composable AST nodes for building rule conditions
  module Condition
    # Value refs

    # Ref represents a reference to a fact attribute via dot-notation path
    Ref = Struct.new(:root, :path) do
      def initialize(root, *path)
        super(root.to_sym, path.flatten)
      end
    end

    # Call represents a method invocation on a resolved receiver
    Call = Struct.new(:receiver, :method_name, :args) do
      def initialize(receiver, method_name, *args)
        super(receiver, method_name.to_sym, args.flatten)
      end
    end

    # LambdaValue wraps a block for deferred evaluation
    LambdaValue = Struct.new(:block)

    # AST nodes

    # Node is the base class for all condition AST nodes
    class Node
      def evaluate(_ctx)
        raise NotImplementedError
      end

      # Enable a & b and a | b in DSL
      def &(other) = All.new(self, other)
      def |(other) = Any.new(self, other)

      def !
        Not.new(self)
      end
    end

    # Predicate evaluates a binary operator on left and right values
    class Predicate < Node
      attr_reader :left, :operator, :right

      def initialize(left, operator, right = nil)
        super()
        @left = left
        @operator = operator
        @right = right
      end

      def evaluate(ctx)
        left_val = ctx.resolve_value(left)
        right_val = ctx.resolve_value(right)
        Operators.call(operator, left_val, right_val)
      end
    end

    # All evaluates to true if all children evaluate to true
    class All < Node
      attr_reader :children

      def initialize(*children)
        super()
        @children = children.flatten
      end

      def evaluate(ctx)
        children.all? { |c| c.evaluate(ctx) }
      end
    end

    # Any evaluates to true if any child evaluates to true
    class Any < Node
      attr_reader :children

      def initialize(*children)
        super()
        @children = children.flatten
      end

      def evaluate(ctx)
        children.any? { |c| c.evaluate(ctx) }
      end
    end

    # Not negates the evaluation result of its child
    class Not < Node
      attr_reader :child

      def initialize(child)
        super()
        @child = child
      end

      # rubocop:disable Naming/PredicateMethod
      # evaluate is part of the AST pattern - not renamed to predicate
      def evaluate(ctx)
        !child.evaluate(ctx)
      end
      # rubocop:enable Naming/PredicateMethod
    end

    # BlockPredicate allows arbitrary Ruby code as a condition
    class BlockPredicate < Node
      def initialize(&block)
        super()
        @block = block
      end

      def evaluate(ctx)
        @block.call(ctx)
      end
    end

    # Builders

    # Builders provides factory methods for creating condition nodes
    module Builders
      module_function

      def ref(root, *path)
        Ref.new(root, *path)
      end

      # Call a method on resolved receiver with (possibly ref) args
      def call(receiver, method, *)
        Call.new(receiver, method, *)
      end

      def lambda_value(&block)
        LambdaValue.new(block)
      end

      def eq?(left, right) = Predicate.new(left, :eq, right)

      def not_eq?(left, right) = Predicate.new(left, :ne, right)

      def gt?(left, right) = Predicate.new(left, :gt, right)

      def gte?(left, right) = Predicate.new(left, :gte, right)

      def lt?(left, right) = Predicate.new(left, :lt, right)

      def lte?(left, right) = Predicate.new(left, :lte, right)

      def contains?(left, right) = Predicate.new(left, :includes, right)

      def in?(left, right) = Predicate.new(left, :in, right)

      def matches?(left, right) = Predicate.new(left, :matches, right)
      def truthy?(left) = Predicate.new(left, :truthy, nil)
      def falsy?(left) = Predicate.new(left, :falsy, nil)
      def present?(left) = Predicate.new(left, :present, nil)
      def blank?(left) = Predicate.new(left, :blank, nil)

      def literal(value = nil, &block)
        LambdaValue.new(block || -> { value })
      end

      def all(*children) = All.new(*children)
      def any(*children) = Any.new(*children)
      def not?(child) = Not.new(child)

      def predicate(&) = BlockPredicate.new(&)
    end
  end
end
