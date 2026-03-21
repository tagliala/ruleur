# frozen_string_literal: true

# Minimal example showing create and update without workflow checks.
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

# rubocop:disable Metrics/MethodLength
def create_engine
  Ruleur.define do
    rule 'create_if_admin_or_draft', no_loop: true, salience: 10 do
      when_any(
        user(:admin?),
        all(
          record(:updatable?),
          record(:draft?)
        )
      )
      set :create, true
    end

    rule 'update_if_updatable', no_loop: true, salience: 5 do
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
# rubocop:enable Metrics/MethodLength

def run_case(record:, user:)
  engine = create_engine
  ctx = engine.run(record: record, user: user)
  {
    create: ctx[:create],
    update: ctx[:update]
  }
end

puts run_case(record: MockRecord.new(true, true),  user: MockUser.new(false)).inspect
puts run_case(record: MockRecord.new(true, false), user: MockUser.new(true)).inspect
puts run_case(record: MockRecord.new(true, false), user: MockUser.new(false)).inspect
