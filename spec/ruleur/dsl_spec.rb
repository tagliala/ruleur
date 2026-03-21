# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::DSL do
  describe 'shortcuts' do
    it 'uses record_value and user_value in predicates' do
      engine = Ruleur.define do
        rule 'compare_values' do
          when_all(
            eq?(record_value(:score), user_value(:threshold))
          )
          set :match, true
        end
      end

      record = Struct.new(:score).new(100)
      user = Struct.new(:threshold).new(100)
      ctx = engine.run(record: record, user: user)

      expect(ctx[:match]).to be(true)

      record2 = Struct.new(:score).new(50)
      ctx2 = engine.run(record: record2, user: user)
      expect(ctx2[:match]).to be_nil
    end

    it 'uses record_value with nested paths' do
      engine = Ruleur.define do
        rule 'nested_check' do
          when_all(
            eq?(record_value(:profile, :level), 5)
          )
          set :senior, true
        end
      end

      profile = Struct.new(:level).new(5)
      record = Struct.new(:profile).new(profile)
      ctx = engine.run(record: record)

      expect(ctx[:senior]).to be(true)
    end

    it 'uses user_value with nested paths' do
      engine = Ruleur.define do
        rule 'permission_check' do
          when_all(
            truthy?(user_value(:permissions, :admin))
          )
          set :is_admin, true
        end
      end

      permissions = Struct.new(:admin).new(true)
      user = Struct.new(:permissions).new(permissions)
      ctx = engine.run(user: user)

      expect(ctx[:is_admin]).to be(true)
    end
  end

  describe 'assert method' do
    it 'sets multiple facts at once' do
      engine = Ruleur.define do
        rule 'multi_set' do
          when_all(truthy?(:trigger))
          assert(
            flag1: true,
            flag2: false,
            value: 42
          )
        end
      end

      ctx = engine.run(trigger: true)
      expect(ctx[:flag1]).to be(true)
      expect(ctx[:flag2]).to be(false)
      expect(ctx[:value]).to eq(42)
    end

    it 'can use references in assert' do
      engine = Ruleur.define do
        rule 'copy_values' do
          when_all(truthy?(:enabled))
          assert(
            output1: record_value(:input1),
            output2: user_value(:input2)
          )
        end
      end

      record = Struct.new(:input1).new('from_record')
      user = Struct.new(:input2).new('from_user')
      ctx = engine.run(enabled: true, record: record, user: user)

      expect(ctx[:output1]).to eq('from_record')
      expect(ctx[:output2]).to eq('from_user')
    end

    it 'creates serializable action specs' do
      engine = Ruleur.define do
        rule 'serializable' do
          when_all(truthy?(:go))
          assert(
            result: 'success',
            code: 200
          )
        end
      end

      rule = engine.rules.first
      expect(rule.action_spec).to eq({ set: { result: 'success', code: 200 } })
    end
  end

  describe 'empty conditions' do
    it 'creates always-true rule when no conditions provided' do
      engine = Ruleur.define do
        rule 'always_fires' do
          set :always, true
        end
      end

      ctx = engine.run({})
      expect(ctx[:always]).to be(true)
    end

    it 'fires even with empty context' do
      engine = Ruleur.define do
        rule 'unconditional' do
          set :result, 'fired'
        end
      end

      ctx = Ruleur::Context.new
      ctx = engine.run(ctx)
      expect(ctx[:result]).to eq('fired')
    end
  end
end
