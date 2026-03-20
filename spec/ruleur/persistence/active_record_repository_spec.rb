# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Persistence::ActiveRecordRepository do
  describe 'without ActiveRecord' do
    it 'raises error when ActiveRecord is not loaded' do
      skip 'ActiveRecord is loaded, cannot test error path' if defined?(ActiveRecord)

      expect do
        described_class.new
      end.to raise_error(/ActiveRecord not loaded/)
    end
  end

  describe 'with mocked ActiveRecord' do
    let(:mock_model) { double }
    let(:repo) { described_class.new(model_class: mock_model) }
    let(:rule) do
      Ruleur::Rule.new(
        name: 'test_rule',
        condition: Ruleur::Condition::Predicate.new(true, :eq, true),
        action_spec: { set: { result: true } }
      )
    end

    describe '#save' do
      it 'serializes and saves rule to model' do
        mock_record = double
        allow(mock_model).to receive(:find_or_initialize_by).with(name: 'test_rule').and_return(mock_record)
        allow(mock_record).to receive(:payload=)
        allow(mock_record).to receive(:save!)

        repo.save(rule)

        expect(mock_model).to have_received(:find_or_initialize_by).with(name: 'test_rule')
        expect(mock_record).to have_received(:payload=)
        expect(mock_record).to have_received(:save!)
      end
    end

    describe '#all' do
      it 'loads and deserializes all rules' do
        payload = Ruleur::Persistence::Serializer.rule_to_h(rule)
        mock_record = double
        allow(mock_record).to receive(:payload).and_return(payload)
        mock_relation = [mock_record]

        allow(mock_model).to receive(:order).with(:name).and_return(mock_relation)

        rules = repo.all

        expect(rules.size).to eq(1)
        expect(rules.first).to be_a(Ruleur::Rule)
        expect(rules.first.name).to eq('test_rule')
      end
    end

    describe '#delete' do
      it 'deletes rules by name' do
        mock_relation = double
        allow(mock_model).to receive(:where).with(name: 'test_rule').and_return(mock_relation)
        allow(mock_relation).to receive(:delete_all)

        repo.delete('test_rule')

        expect(mock_model).to have_received(:where).with(name: 'test_rule')
        expect(mock_relation).to have_received(:delete_all)
      end
    end

    describe 'default_model' do
      it 'creates default AR model with serialize for old ActiveRecord' do
        ar_base = build_ar_base_class
        stub_const('ActiveRecord', Module.new)
        stub_const('ActiveRecord::Base', ar_base)

        repo = described_class.new
        model = repo.instance_variable_get(:@model)

        expect(model).to be_a(Class)
        expect(model.table_name).to eq('ruleur_rules')
        expect(model.serialized_attrs).to eq([:payload, JSON])
      end
    end
  end

  def build_ar_base_class
    Class.new do
      class << self
        attr_accessor :table_name, :serialized_attrs

        def serialize(*args)
          @serialized_attrs = args
        end

        def respond_to?(method, include_private: false)
          return false if method == :attribute_types

          super
        end
      end
    end
  end
end
