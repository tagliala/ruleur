# frozen_string_literal: true

require 'spec_helper'

MockRecord = Struct.new(:updatable, :draft) do
  def updatable? = !!updatable
  def draft? = !!draft
end

MockUser = Struct.new(:admin) do
  def admin? = !!admin
end

RSpec.describe 'Policy PoC rules' do
  let(:engine) do
    Ruleur.define do
      rule 'allow_create', no_loop: true do
        when_any(
          usr(:admin?),
          all(
            rec(:updatable?),
            rec(:draft?)
          )
        )
        action { allow! :create }
      end

      rule 'allow_update', no_loop: true do
        when_all(
          rec(:updatable?),
          any(
            usr(:admin?),
            all(
              rec(:draft?),
              flag(:create)
            )
          )
        )
        action { allow! :update }
      end
    end
  end

  it 'grants both when admin and updatable' do
    ctx = engine.run(record: MockRecord.new(true, false), user: MockUser.new(true))
    expect(ctx[:allow_create]).to be(true)
    expect(ctx[:allow_update]).to be(true)
  end

  it 'grants both when draft and updatable (no admin)' do
    ctx = engine.run(record: MockRecord.new(true, true), user: MockUser.new(false))
    expect(ctx[:allow_create]).to be(true)
    expect(ctx[:allow_update]).to be(true)
  end

  it 'denies both when not draft, not admin' do
    ctx = engine.run(record: MockRecord.new(true, false), user: MockUser.new(false))
    expect(ctx[:allow_create]).not_to be(true)
    expect(ctx[:allow_update]).not_to be(true)
  end
end

RSpec.describe 'Persistence' do
  it 'serializes/deserializes rules and runs them' do
    engine = Ruleur.define do
      rule 'allow_create', no_loop: true do
        when_any(
          usr(:admin?),
          all(rec(:updatable?), rec(:draft?))
        )
        action { allow! :create }
      end
    end

    repo = Ruleur::Persistence::MemoryRepository.new
    engine.rules.each { |r| repo.save(r) }

    loaded_engine = Ruleur::Engine.new(rules: repo.all)
    ctx = loaded_engine.run(record: MockRecord.new(true, true), user: MockUser.new(false))
    expect(ctx[:allow_create]).to be(true)
  end
end
