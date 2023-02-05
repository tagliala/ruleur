# frozen_string_literal: true

require 'ruleur/fact'

RSpec.describe Ruleur::Fact do
  let(:fact) { described_class.new(name: 'John Doe', age: 30) }

  describe '#attributes' do
    it 'returns the attributes' do
      expect(fact.attributes).to eq(name: 'John Doe', age: 30)
    end
  end
end
