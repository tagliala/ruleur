# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Rule do
  describe 'action_spec execution' do
    it 'executes serialized action specs' do
      rule = described_class.new(
        name: 'test',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { result: 'from_spec' } }
      )

      ctx = Ruleur::Context.new
      rule.fire(ctx)

      expect(ctx[:result]).to eq('from_spec')
    end

    it 'resolves Ref values in action specs' do
      ref = Ruleur::Condition::Ref.new(:source, :value)
      rule = described_class.new(
        name: 'test',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { target: ref } }
      )

      source = Struct.new(:value).new('resolved')
      ctx = Ruleur::Context.new(source: source)
      rule.fire(ctx)

      expect(ctx[:target]).to eq('resolved')
    end

    it 'resolves Call values in action specs' do
      helper_ref = Ruleur::Condition::Ref.new(:helper)
      call = Ruleur::Condition::Call.new(helper_ref, :compute)
      rule = described_class.new(
        name: 'test',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { result: call } }
      )

      helper = Struct.new(:compute).new(42)
      ctx = Ruleur::Context.new(helper: helper)
      rule.fire(ctx)

      expect(ctx[:result]).to eq(42)
    end

    it 'resolves LambdaValue in action specs' do
      lambda_val = Ruleur::Condition::LambdaValue.new(->(ctx) { ctx[:a] + ctx[:b] })
      rule = described_class.new(
        name: 'test',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { sum: lambda_val } }
      )

      ctx = Ruleur::Context.new(a: 10, b: 20)
      rule.fire(ctx)

      expect(ctx[:sum]).to eq(30)
    end

    it 'handles action_spec with multiple values' do
      ref = Ruleur::Condition::Ref.new(:config, :timeout)
      rule = described_class.new(
        name: 'test',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { literal: 'value', referenced: ref, flag: true } }
      )

      config = Struct.new(:timeout).new(30)
      ctx = Ruleur::Context.new(config: config)
      rule.fire(ctx)

      expect(ctx[:literal]).to eq('value')
      expect(ctx[:referenced]).to eq(30)
    end

    it 'handles boolean flags in action_spec' do
      rule = described_class.new(
        name: 'test',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { flag: true } }
      )

      ctx = Ruleur::Context.new
      rule.fire(ctx)

      expect(ctx[:flag]).to be(true)
    end
  end

  describe 'ActionRunner.stringify_keys' do
    it 'converts symbol keys to strings recursively' do
      input = {
        set: {
          nested: { key: 'value' },
          array: [{ item: 1 }]
        }
      }

      result = Ruleur::Rule::ActionRunner.stringify_keys(input)

      expect(result).to eq(
        'set' => {
          'nested' => { 'key' => 'value' },
          'array' => [{ 'item' => 1 }]
        }
      )
    end
  end
end
