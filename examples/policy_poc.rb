# frozen_string_literal: true

# Minimal example showing allow_create and allow_update without workflow checks.
# Run with: ruby examples/policy_poc.rb

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'ruleur'

MockRecord = Struct.new(:updatable, :draft) do
  def updatable? = !!updatable
  def draft? = !!draft
end

MockUser = Struct.new(:admin) do
  def admin? = !!admin
end

def create_engine
  Ruleur.define do
    # allow_create if admin OR (record is draft and updatable)
    rule 'allow_create', no_loop: true, salience: 10 do
      when_any(
        usr(:admin?),
        all(
          rec(:updatable?),
          rec(:draft?)
        )
      )
      action { allow! :create }
    end

    # allow_update if updatable and (admin OR (draft AND allow_create))
    rule 'allow_update', no_loop: true, salience: 5 do
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

def run_case(record:, user:)
  engine = create_engine
  ctx = engine.run(record: record, user: user)
  {
    allow_create: ctx[:allow_create],
    allow_update: ctx[:allow_update]
  }
end

puts run_case(record: MockRecord.new(true, true),  user: MockUser.new(false)).inspect  # => both true
puts run_case(record: MockRecord.new(true, false), user: MockUser.new(true)).inspect   # => both true
puts run_case(record: MockRecord.new(true, false), user: MockUser.new(false)).inspect  # => both false
