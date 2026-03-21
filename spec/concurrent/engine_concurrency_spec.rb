# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'

RSpec.describe 'Engine concurrency' do
  it 'collects metrics correctly when engine runs concurrently' do
    engine = Ruleur.define do
      rule 'r1', no_loop: true do
        when_all(record(:updatable?))
        set :a, true
      end

      rule 'r2', no_loop: true do
        when_all(user(:admin?))
        set :b, true
      end
    end

    threads = []
    10.times do |i|
      threads << Thread.new do
        engine.run(record: OpenStruct.new(updatable?: i.even?), user: OpenStruct.new(admin?: i.odd?))
      end
    end

    threads.each(&:join)

    stats = engine.stats
    expect(stats[:rules].keys).to include('r1', 'r2')
    expect(stats[:rules]['r1'][:count]).to be >= 1
    expect(stats[:rules]['r2'][:count]).to be >= 1
  end
end
