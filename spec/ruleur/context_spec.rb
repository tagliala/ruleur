# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Context do
  describe '#fetch' do
    it 'fetches existing values' do
      ctx = described_class.new(existing: 'value')
      expect(ctx.fetch(:existing)).to eq('value')
    end

    it 'returns default for missing keys' do
      ctx = described_class.new(existing: 'value')
      expect(ctx.fetch(:missing, 'default')).to eq('default')
    end

    it 'raises KeyError when key not found without default' do
      ctx = described_class.new(existing: 'value')
      expect { ctx.fetch(:missing) }.to raise_error(KeyError)
    end

    it 'works with block defaults' do
      ctx = described_class.new(existing: 'value')
      result = ctx.fetch(:missing) { |key| "default_for_#{key}" }
      expect(result).to eq('default_for_missing')
    end
  end

  describe 'method calls with arguments' do
    it 'resolves method calls with arguments via path arrays' do
      calculator = Struct.new(:base) do
        def multiply(left, right)
          left * right
        end
      end.new(0)

      ctx = described_class.new(calc: calculator)
      result = ctx.resolve_ref(:calc, [:multiply, 5, 10])

      expect(result).to eq(50)
    end

    it 'resolves nested paths with method calls' do
      user = Struct.new(:profile) do
        # profile has format method
      end.new(
        Struct.new(:name) do
          def format(prefix)
            "#{prefix}: #{name}"
          end
        end.new('John')
      )

      ctx = described_class.new(user: user)
      result = ctx.resolve_ref(:user, :profile, [:format, 'Name'])

      expect(result).to eq('Name: John')
    end
  end

  describe 'Call value resolution' do
    it 'resolves Call values' do
      user = Struct.new(:email).new('test@example.com')
      ctx = described_class.new(user: user)

      ref = Ruleur::Condition::Ref.new(:user)
      call = Ruleur::Condition::Call.new(ref, :email)
      result = ctx.resolve_value(call)

      expect(result).to eq('test@example.com')
    end

    it 'resolves Call values with arguments' do
      greeter = Struct.new(:name) do
        def greet(prefix)
          "#{prefix} #{name}"
        end
      end.new('World')

      ctx = described_class.new(greeter: greeter)
      ref = Ruleur::Condition::Ref.new(:greeter)
      call = Ruleur::Condition::Call.new(ref, :greet, 'Hello')
      result = ctx.resolve_value(call)

      expect(result).to eq('Hello World')
    end

    it 'resolves nested Call values' do
      inner = Struct.new(:value).new(42)
      outer = Struct.new(:inner).new(inner)

      ctx = described_class.new(outer: outer)
      outer_ref = Ruleur::Condition::Ref.new(:outer)
      inner_call = Ruleur::Condition::Call.new(outer_ref, :inner)
      value_call = Ruleur::Condition::Call.new(inner_call, :value)

      result = ctx.resolve_value(value_call)
      expect(result).to eq(42)
    end
  end
end
