# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::WorkingMemory do
  describe '#initialize' do
    it 'initializes an empty array for facts' do
      wm = described_class.new

      expect(wm.facts).to eq([])
    end
  end

  describe '#insert' do
    it 'inserts a fact into the working memory' do
      wm = described_class.new
      fact = double

      wm.insert(fact)

      expect(wm.facts).to include(fact)
    end
  end

  describe '#delete' do
    it 'deletes a fact from the working memory' do
      wm = described_class.new
      fact = double
      wm.insert(fact)

      wm.delete(fact)

      expect(wm.facts).not_to include(fact)
    end
  end

  describe '#update' do
    it 'updates a fact in the working memory' do
      wm = described_class.new
      fact = double
      wm.insert(fact)
      new_fact = double

      wm.update(fact, new_fact)

      expect(wm.facts).not_to include(fact)
      expect(wm.facts).to include(new_fact)
    end
  end
end
