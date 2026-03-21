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
      end

      it 'grants both when draft and updatable (no admin)' do
        ctx = engine.run(record: MockRecord.new(true, true), user: MockUser.new(false))
        expect(ctx[:create]).to be(true)
        expect(ctx[:update]).to be(true)
      end

      it 'denies both when not draft, not admin' do
        ctx = engine.run(record: MockRecord.new(true, false), user: MockUser.new(false))
        expect(ctx[:create]).not_to be(true)
        expect(ctx[:update]).not_to be(true)
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
