# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Condition do
  describe 'Call node' do
    it 'creates method calls on resolved values' do
      user = MockUser.new(true)
      ctx = Ruleur::Context.new(user: user)

      ref = Ruleur::Condition::Ref.new(:user)
      call = Ruleur::Condition::Call.new(ref, :admin?)
      expect(ctx.resolve_value(call)).to be(true)
    end

    it 'uses call() builder method' do
      user = MockUser.new(true)
      ctx = Ruleur::Context.new(user: user)

      ref = Ruleur::Condition::Ref.new(:user)
      call_node = Ruleur::Condition::Builders.call(ref, :admin?)
      expect(ctx.resolve_value(call_node)).to be(true)
    end

    it 'handles method calls with arguments' do
      calculator = Struct.new(:base) do
        def add(left, right)
          base + left + right
        end
      end.new(10)

      ctx = Ruleur::Context.new(calc: calculator)
      ref = Ruleur::Condition::Ref.new(:calc)
      call = Ruleur::Condition::Call.new(ref, :add, 5, 3)
      expect(ctx.resolve_value(call)).to eq(18)
    end

    it 'handles nil receivers gracefully' do
      ctx = Ruleur::Context.new(user: nil)
      ref = Ruleur::Condition::Ref.new(:user)
      call = Ruleur::Condition::Call.new(ref, :admin?)
      expect(ctx.resolve_value(call)).to be_nil
    end
  end

  describe 'Node base class' do
    it 'raises NotImplementedError when evaluate is called directly' do
      node = Ruleur::Condition::Node.new
      ctx = Ruleur::Context.new

      expect { node.evaluate(ctx) }.to raise_error(NotImplementedError)
    end
  end

  describe 'Not operator' do
    it 'negates conditions using !' do
      ref = Ruleur::Condition::Ref.new(:admin)
      cond = Ruleur::Condition::Builders.truthy?(ref)
      negated = !cond

      ctx_truthy = Ruleur::Context.new(admin: 'yes')
      expect(negated.evaluate(ctx_truthy)).to be(false)

      ctx_falsy = Ruleur::Context.new(admin: nil)
      expect(negated.evaluate(ctx_falsy)).to be(true)
    end

    it 'works in rule conditions' do
      engine = Ruleur.define do
        rule 'not_admin' do
          when_all(!user(:admin?))
          set :restricted, true
        end
      end

      ctx = engine.run(user: MockUser.new(false))
      expect(ctx[:restricted]).to be(true)

      ctx2 = engine.run(user: MockUser.new(true))
      expect(ctx2[:restricted]).to be_nil
    end
  end

  describe 'BlockPredicate' do
    it 'evaluates custom block predicates' do
      engine = Ruleur.define do
        rule 'custom_predicate' do
          when_predicate { |ctx| ctx[:value] > 10 }
          set :result, true
        end
      end

      ctx = engine.run(value: 15)
      expect(ctx[:result]).to be(true)

      ctx2 = engine.run(value: 5)
      expect(ctx2[:result]).to be_nil
    end

    it 'has access to full context' do
      engine = Ruleur.define do
        rule 'complex_predicate' do
          when_predicate { |ctx| ctx[:a] + ctx[:b] == ctx[:sum] }
          set :match, true
        end
      end

      ctx = engine.run(a: 7, b: 3, sum: 10)
      expect(ctx[:match]).to be(true)
    end
  end

  describe 'LambdaValue' do
    it 'defers evaluation with lambda_value' do
      engine = Ruleur.define do
        rule 'lambda_test' do
          when_all(
            eq?(literal { |ctx| ctx[:a] + ctx[:b] }, 10)
          )
          set :sum_is_ten, true
        end
      end

      ctx = engine.run(a: 7, b: 3)
      expect(ctx[:sum_is_ten]).to be(true)

      ctx2 = engine.run(a: 5, b: 3)
      expect(ctx2[:sum_is_ten]).to be_nil
    end

    it 'can be used for complex calculations' do
      engine = Ruleur.define do
        rule 'lambda_calculation' do
          when_all(
            gt?(literal { |ctx| ctx[:x] * ctx[:y] }, 100)
          )
          set :large_product, true
        end
      end

      ctx = engine.run(x: 10, y: 15)
      expect(ctx[:large_product]).to be(true)
    end
  end
end
