# frozen_string_literal: true

require 'spec_helper'

MockRecord = Struct.new(:updatable, :draft) do
  def updatable? = !!updatable
  def draft? = !!draft
end

MockUser = Struct.new(:admin) do
  def admin? = !!admin
end

RSpec.describe Ruleur do
  describe Ruleur::Engine do
    describe 'policy rules' do
      let(:engine) do
        Ruleur.define do
          rule 'allow_create', no_loop: true do
            when_any(
              user(:admin?),
              all(
                record(:updatable?),
                record(:draft?)
              )
            )
            set :create, true
          end

          rule 'allow_update', no_loop: true do
            when_all(
              record(:updatable?),
              any(
                user(:admin?),
                all(
                  record(:draft?),
                  flag(:create)
                )
              )
            )
            set :update, true
          end
        end
      end

      it 'grants both when admin and updatable' do
        ctx = engine.run(record: MockRecord.new(true, false), user: MockUser.new(true))
        expect(ctx[:create]).to be(true)
        expect(ctx[:update]).to be(true)
        # debug metrics should contain rule and predicate timings
        expect(ctx.debug).to be_an(Array)
        # must include at least one rule timing entry for allow_create and allow_update
        rule_names = ctx.debug.filter_map { |e| e[:rule] }
        expect(rule_names).to include('allow_create', 'allow_update')
        # predicate timings must be present and reference a rule
        pred = ctx.debug.find { |e| e[:predicate] }
        expect(pred).to be_a(Hash)
        expect(pred[:rule]).not_to be_nil
        expect(pred[:duration_ms]).to be_a(Float)
      end

      it 'grants both when draft and updatable (no admin)' do
        ctx = engine.run(record: MockRecord.new(true, true), user: MockUser.new(false))
        expect(ctx[:create]).to be(true)
        expect(ctx[:update]).to be(true)
        expect(ctx.debug).to be_an(Array)
        expect(ctx.debug.any? { |e| e[:rule] == 'allow_create' }).to be(true)
        expect(ctx.debug.any? { |e| e[:rule] == 'allow_update' }).to be(true)
      end

      it 'denies both when not draft, not admin' do
        ctx = engine.run(record: MockRecord.new(true, false), user: MockUser.new(false))
        expect(ctx[:create]).not_to be(true)
        expect(ctx[:update]).not_to be(true)
        # Even when rules don't fire, predicates may have been evaluated; ensure debug exists
        expect(ctx.debug).to be_an(Array)
      end

      it 'exposes aggregated metrics in engine.stats' do
        # Run once to ensure stats are collected
        engine.run(record: MockRecord.new(true, true), user: MockUser.new(false))
        stats = engine.stats
        expect(stats).to be_a(Hash)
        expect(stats[:rules]).to include('allow_create', 'allow_update')

        r = stats[:rules]['allow_create']
        expect(r[:count]).to be > 0
        expect(r[:total_ms]).to be > 0.0

        # predicates should include truthy (used by record/user helpers)
        expect(stats[:predicates].keys).to include(:truthy)
        p = stats[:predicates][:truthy]
        expect(p[:count]).to be > 0
        expect(p[:total_ms]).to be > 0.0
      end
    end
  end

  describe Ruleur::Persistence do
    describe 'serialization' do
      it 'serializes/deserializes rules and runs them' do
        engine = Ruleur.define do
          rule 'allow_create', no_loop: true do
            when_any(
              user(:admin?),
              all(record(:updatable?), record(:draft?))
            )
            set :create, true
          end
        end

        repo = Ruleur::Persistence::MemoryRepository.new
        engine.rules.each { |r| repo.save(r) }

        loaded_engine = Ruleur::Engine.new(rules: repo.all)
        ctx = loaded_engine.run(record: MockRecord.new(true, true), user: MockUser.new(false))
        expect(ctx[:create]).to be(true)
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
