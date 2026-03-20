# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Persistence::Serializer do
  describe 'Not condition serialization' do
    it 'serializes and deserializes Not nodes' do
      # Create a Not node directly, not via DSL which wraps it in All
      not_node = Ruleur::Condition::Not.new(
        Ruleur::Condition::Predicate.new(
          Ruleur::Condition::Ref.new(:user, :admin?),
          :truthy,
          nil
        )
      )

      rule = Ruleur::Rule.new(
        name: 'not_admin',
        condition: not_node,
        action_spec: { set: { restricted: true } }
      )

      serialized = described_class.rule_to_h(rule)
      expect(serialized[:condition][:type]).to eq('not')
      expect(serialized[:condition][:child]).to be_a(Hash)

      deserialized = described_class.rule_from_h(serialized)
      expect(deserialized.condition).to be_a(Ruleur::Condition::Not)

      # Verify it still works
      ctx = Ruleur::Context.new(user: MockUser.new(false))
      if deserialized.eligible?(ctx)
        deserialized.fire(ctx)
        expect(ctx[:restricted]).to be(true)
      end
    end

    it 'serializes nested Not conditions' do
      cond = Ruleur::Condition::Builders.truthy(:flag)
      double_negated = !(!cond)

      serialized = described_class.node_to_h(double_negated)
      expect(serialized[:type]).to eq('not')
      expect(serialized[:child][:type]).to eq('not')

      deserialized = described_class.node_from_h(serialized)
      expect(deserialized).to be_a(Ruleur::Condition::Not)
      expect(deserialized.child).to be_a(Ruleur::Condition::Not)
    end
  end

  describe 'Call node serialization' do
    it 'serializes and deserializes Call nodes without arguments' do
      ref = Ruleur::Condition::Ref.new(:user)
      call = Ruleur::Condition::Call.new(ref, :email)

      serialized = described_class.value_to_h(call)
      expect(serialized[:type]).to eq('call')
      expect(serialized[:method]).to eq(:email)
      expect(serialized[:recv]).to eq({ type: 'ref', root: :user, path: [] })
      expect(serialized[:args]).to eq([])

      deserialized = described_class.value_from_h(serialized)
      expect(deserialized).to be_a(Ruleur::Condition::Call)
      expect(deserialized.method_name).to eq(:email)
    end

    it 'serializes and deserializes Call nodes with arguments' do
      ref = Ruleur::Condition::Ref.new(:calculator)
      call = Ruleur::Condition::Call.new(ref, :add, 5, 10)

      serialized = described_class.value_to_h(call)
      expect(serialized[:type]).to eq('call')
      expect(serialized[:method]).to eq(:add)
      expect(serialized[:args]).to eq([5, 10])

      deserialized = described_class.value_from_h(serialized)
      expect(deserialized).to be_a(Ruleur::Condition::Call)
      expect(deserialized.method_name).to eq(:add)
      expect(deserialized.args).to eq([5, 10])
    end

    it 'serializes Call nodes with complex arguments' do
      ref_arg = Ruleur::Condition::Ref.new(:config, :timeout)
      service_ref = Ruleur::Condition::Ref.new(:service)
      call = Ruleur::Condition::Call.new(service_ref, :execute, ref_arg, 'literal')

      serialized = described_class.value_to_h(call)
      expect(serialized[:args][0]).to be_a(Hash)
      expect(serialized[:args][0][:type]).to eq('ref')
      expect(serialized[:args][1]).to eq('literal')

      deserialized = described_class.value_from_h(serialized)
      expect(deserialized.args[0]).to be_a(Ruleur::Condition::Ref)
      expect(deserialized.args[1]).to eq('literal')
    end

    it 'works in complete rule serialization' do
      engine = Ruleur.define do
        rule 'call_test' do
          when_all(
            eq(call(ref(:user), :role), 'admin')
          )
          set :is_admin, true
        end
      end

      serialized = described_class.rule_to_h(engine.rules.first)
      deserialized = described_class.rule_from_h(serialized)

      user = Struct.new(:role).new('admin')
      ctx = Ruleur::Context.new(user: user)
      deserialized.fire(ctx) if deserialized.eligible?(ctx)

      expect(ctx[:is_admin]).to be(true)
    end
  end

  describe 'LambdaValue serialization error' do
    it 'raises error when attempting to serialize lambda values' do
      lambda_val = Ruleur::Condition::LambdaValue.new(-> { 42 })

      expect do
        described_class.value_to_h(lambda_val)
      end.to raise_error(ArgumentError, 'Lambda values cannot be serialized')
    end

    it 'prevents serialization of rules with lambda values' do
      engine = Ruleur.define do
        rule 'with_lambda' do
          when_all(
            eq(lambda_value { |_ctx| 42 }, 42)
          )
          set :result, true
        end
      end

      expect do
        described_class.rule_to_h(engine.rules.first)
      end.to raise_error(ArgumentError, /cannot be serialized/)
    end
  end

  describe 'unknown type errors' do
    it 'raises error for unknown node types during deserialization' do
      bad_hash = { type: 'unknown_node_type', data: 'test' }

      expect do
        described_class.node_from_h(bad_hash)
      end.to raise_error(ArgumentError, /Unknown node type/)
    end

    it 'raises error for unknown value types during deserialization' do
      bad_hash = { type: 'unknown_value_type', data: 'test' }

      expect do
        described_class.value_from_h(bad_hash)
      end.to raise_error(ArgumentError, /Unknown value type/)
    end

    it 'handles string keys in unknown node detection' do
      bad_hash = { 'type' => 'bad_type' }

      expect do
        described_class.node_from_h(bad_hash)
      end.to raise_error(ArgumentError, /Unknown node type/)
    end

    it 'handles string keys in unknown value detection' do
      bad_hash = { 'type' => 'bad_value' }

      expect do
        described_class.value_from_h(bad_hash)
      end.to raise_error(ArgumentError, /Unknown value type/)
    end
  end
end
