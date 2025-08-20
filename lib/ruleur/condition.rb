# frozen_string_literal: true

module Ruleur
  module Condition
    # Value refs

    Ref = Struct.new(:root, :path) do
      def initialize(root, *path)
        super(root.to_sym, path.flatten)
      end
    end

    Call = Struct.new(:receiver, :method, :args) do
      def initialize(receiver, method, *args)
        super(receiver, method.to_sym, args.flatten)
      end
    end

    LambdaValue = Struct.new(:block)

    # AST nodes

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

    class Predicate < Node
      attr_reader :left, :op, :right

      def initialize(left, op, right = nil)
        @left = left
        @op = op
        @right = right
      end

      def evaluate(ctx)
        l = ctx.resolve_value(left)
        r = ctx.resolve_value(right)
        Operators.call(op, l, r)
      end
    end

    class All < Node
      attr_reader :children
      def initialize(*children)
        @children = children.flatten
      end

      def evaluate(ctx)
        children.all? { |c| c.evaluate(ctx) }
      end
    end

    class Any < Node
      attr_reader :children
      def initialize(*children)
        @children = children.flatten
      end

      def evaluate(ctx)
        children.any? { |c| c.evaluate(ctx) }
      end
    end

    class Not < Node
      attr_reader :child
      def initialize(child)
        @child = child
      end

      def evaluate(ctx)
        !child.evaluate(ctx)
      end
    end

    class BlockPredicate < Node
      def initialize(&block)
        @block = block
      end

      def evaluate(ctx)
        @block.call(ctx)
      end
    end

    # Builders

    module Builders
      module_function

      def ref(root, *path)
        Ref.new(root, *path)
      end

      # Call a method on resolved receiver with (possibly ref) args
      def call(receiver, method, *args)
        Call.new(receiver, method, *args)
      end

      def lambda_value(&block)
        LambdaValue.new(block)
      end

      def eq(l, r) = Predicate.new(l, :eq, r)
      def ne(l, r) = Predicate.new(l, :ne, r)
      def gt(l, r) = Predicate.new(l, :gt, r)
      def gte(l, r) = Predicate.new(l, :gte, r)
      def lt(l, r) = Predicate.new(l, :lt, r)
      def lte(l, r) = Predicate.new(l, :lte, r)
      def includes(l, r) = Predicate.new(l, :includes, r)
      def in_(l, r) = Predicate.new(l, :in, r)
      def matches(l, r) = Predicate.new(l, :matches, r)
      def truthy(l) = Predicate.new(l, :truthy, nil)
      def falsy(l) = Predicate.new(l, :falsy, nil)
      def present(l) = Predicate.new(l, :present, nil)
      def blank(l) = Predicate.new(l, :blank, nil)

      def all(*children) = All.new(*children)
      def any(*children) = Any.new(*children)
      def not_(child) = Not.new(child)

      def predicate(&block) = BlockPredicate.new(&block)
    end
  end
end