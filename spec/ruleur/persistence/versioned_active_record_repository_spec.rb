# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Persistence::VersionedActiveRecordRepository do
  let(:mock_model) { double }
  let(:mock_version_model) { double }
  let(:repo) { described_class.new(model_class: mock_model, version_model_class: mock_version_model) }

  let(:rule) do
    Ruleur::Rule.new(
      name: 'test_rule',
      condition: Ruleur::Condition::Predicate.new(true, :eq, true),
      action_spec: { set: { result: true } },
      salience: 10,
      tags: [:test]
    )
  end

  let(:payload) { Ruleur::Persistence::Serializer.rule_to_h(rule) }

  describe '#save' do
    context 'with new rule' do
      it 'sets version to 1 and creates version history' do
        mock_record = new_record_mock
        allow(mock_model).to receive(:transaction).and_yield
        allow(mock_model).to receive(:lock).and_return(mock_model)
        allow(mock_model).to receive(:find_or_initialize_by).with(name: 'test_rule').and_return(mock_record)
        allow(mock_version_model).to receive(:create!)

        result = repo.save(rule, user: 'alice', change_description: 'Initial version')

        expect(result).to be_a(Ruleur::Persistence::VersionedRule)
        expect(result.name).to eq('test_rule')
        expect(mock_version_model).to have_received(:create!)
      end
    end

    context 'with existing rule' do
      it 'increments version and creates version history' do
        mock_record = build_existing_record_mock
        allow(mock_model).to receive(:transaction).and_yield
        allow(mock_model).to receive(:lock).and_return(mock_model)
        allow(mock_model).to receive(:find_or_initialize_by).with(name: 'test_rule').and_return(mock_record)
        allow(mock_version_model).to receive(:create!)

        result = repo.save(rule, user: 'bob', change_description: 'Updated logic')

        expect(result).to be_a(Ruleur::Persistence::VersionedRule)
        expect(mock_version_model).to have_received(:create!).with(hash_including(
                                                                     version: 3,
                                                                     rule_name: 'test_rule'
                                                                   ))
      end
    end
  end

  describe '#all' do
    it 'returns all rules with version metadata' do
      mock_record = mock_record_with_payload
      allow(mock_model).to receive(:order).with(:name).and_return([mock_record])

      rules = repo.all

      expect(rules.size).to eq(1)
      expect(rules.first).to be_a(Ruleur::Persistence::VersionedRule)
      expect(rules.first.name).to eq('test_rule')
    end

    it 'includes version metadata in results' do
      mock_record = mock_record_with_payload
      allow(mock_model).to receive(:order).with(:name).and_return([mock_record])

      rules = repo.all

      expect(rules.first.version).to eq(2)
      expect(rules.first.created_by).to eq('alice')
      expect(rules.first.updated_by).to eq('bob')
    end
  end

  describe '#find' do
    it 'finds a rule by name with version metadata' do
      mock_record = double
      allow(mock_record).to receive_messages(
        payload: payload,
        version: 1,
        created_at: Time.now.utc,
        updated_at: Time.now.utc,
        created_by: 'alice',
        updated_by: 'alice'
      )
      allow(mock_model).to receive(:find_by).with(name: 'test_rule').and_return(mock_record)

      rule = repo.find('test_rule')

      expect(rule).to be_a(Ruleur::Persistence::VersionedRule)
      expect(rule.name).to eq('test_rule')
    end

    it 'returns nil when rule not found' do
      allow(mock_model).to receive(:find_by).with(name: 'missing').and_return(nil)

      expect(repo.find('missing')).to be_nil
    end
  end

  describe '#find_version' do
    it 'finds a specific version of a rule' do
      mock_version_record = double
      allow(mock_version_record).to receive_messages(
        rule_name: 'test_rule',
        version: 1,
        payload: payload,
        created_at: Time.now.utc,
        created_by: 'alice',
        change_description: 'Initial'
      )
      allow(mock_version_model).to receive(:find_by)
        .with(rule_name: 'test_rule', version: 1)
        .and_return(mock_version_record)

      rule = repo.find_version('test_rule', 1)

      expect(rule).to be_a(Ruleur::Persistence::VersionedRule)
      expect(rule.version).to eq(1)
    end

    it 'returns nil when version not found' do
      allow(mock_version_model).to receive(:find_by)
        .with(rule_name: 'test_rule', version: 99)
        .and_return(nil)

      expect(repo.find_version('test_rule', 99)).to be_nil
    end
  end

  describe '#version_history' do
    it 'returns version history for a rule' do
      version_history_mocks

      history = repo.version_history('test_rule')

      expect(history.size).to eq(3)
      expect(history).to all(be_a(Ruleur::Persistence::RuleVersion))
      expect(history.map(&:version)).to eq([3, 2, 1])
    end
  end

  describe '#delete' do
    it 'deletes rule and version history in transaction' do
      mock_model_relation = double
      mock_version_relation = double
      allow(mock_model).to receive(:transaction).and_yield
      allow(mock_model).to receive(:where).with(name: 'test_rule').and_return(mock_model_relation)
      allow(mock_model_relation).to receive(:delete_all)
      allow(mock_version_model).to receive(:where).with(rule_name: 'test_rule').and_return(mock_version_relation)
      allow(mock_version_relation).to receive(:delete_all)

      repo.delete('test_rule')

      expect(mock_model).to have_received(:transaction)
      expect(mock_model_relation).to have_received(:delete_all)
      expect(mock_version_relation).to have_received(:delete_all)
    end
  end

  describe '#rollback' do
    it 'rolls back to a previous version' do
      mock_version_record = version_record_mock
      allow(mock_version_model).to receive(:find_by)
        .with(rule_name: 'test_rule', version: 2)
        .and_return(mock_version_record)

      mock_record = existing_record_mock
      allow(mock_model).to receive(:transaction).and_yield
      allow(mock_model).to receive(:lock).and_return(mock_model)
      allow(mock_model).to receive(:find_or_initialize_by).with(name: 'test_rule').and_return(mock_record)
      allow(mock_version_model).to receive(:create!)

      result = repo.rollback('test_rule', 2, user: 'bob')

      expect(result).to be_a(Ruleur::Persistence::VersionedRule)
      expect(mock_version_model).to have_received(:find_by)
      expect(mock_version_model).to have_received(:create!).with(hash_including(
                                                                   change_description: 'Rolled back to version 2'
                                                                 ))
    end

    it 'raises error when version not found' do
      allow(mock_version_model).to receive(:find_by)
        .with(rule_name: 'test_rule', version: 99)
        .and_return(nil)

      expect do
        repo.rollback('test_rule', 99, user: 'bob')
      end.to raise_error(ArgumentError, /Version 99 not found/)
    end
  end

  def new_record_mock
    mock = double
    allow(mock).to receive_messages(
      new_record?: true,
      version: 1,
      'version=': nil,
      payload: nil,
      'payload=': nil,
      created_at: Time.now.utc,
      updated_at: Time.now.utc,
      'created_at=': nil,
      'updated_at=': nil,
      created_by: 'alice',
      updated_by: 'alice',
      'created_by=': nil,
      'updated_by=': nil,
      save!: true
    )
    mock
  end

  def existing_record_mock
    mock = double
    allow(mock).to receive_messages(
      new_record?: false,
      version: 2,
      'version=': nil,
      payload: nil,
      'payload=': nil,
      created_at: Time.now.utc - 3600,
      updated_at: Time.now.utc,
      'created_at=': nil,
      'updated_at=': nil,
      created_by: 'alice',
      updated_by: 'bob',
      'created_by=': nil,
      'updated_by=': nil,
      save!: true
    )
    mock
  end

  def mock_record_with_payload
    mock = double
    allow(mock).to receive_messages(
      payload: payload, version: 2,
      created_at: Time.now.utc, updated_at: Time.now.utc,
      created_by: 'alice', updated_by: 'bob'
    )
    mock
  end

  def version_record_mock
    mock = double
    allow(mock).to receive_messages(
      rule_name: 'test_rule', version: 2, payload: payload,
      created_at: Time.now.utc - 3600, created_by: 'alice',
      change_description: 'Previous version'
    )
    mock
  end

  def version_history_mocks
    mock_v3 = double
    mock_v2 = double
    mock_v1 = double
    mock_relation = double

    allow(mock_v3).to receive_messages(
      rule_name: 'test_rule', version: 3, payload: payload,
      created_at: Time.now.utc, created_by: 'bob', change_description: 'Latest'
    )
    allow(mock_v2).to receive_messages(
      rule_name: 'test_rule', version: 2, payload: payload,
      created_at: Time.now.utc - 3600, created_by: 'bob', change_description: 'Update'
    )
    allow(mock_v1).to receive_messages(
      rule_name: 'test_rule', version: 1, payload: payload,
      created_at: Time.now.utc - 7200, created_by: 'alice', change_description: 'Initial'
    )
    allow(mock_version_model).to receive(:where).with(rule_name: 'test_rule').and_return(mock_relation)
    allow(mock_relation).to receive(:order).with(version: :desc).and_return([mock_v3, mock_v2, mock_v1])
    [mock_v3, mock_v2, mock_v1]
  end

  def build_existing_record_mock
    current_version = 2
    new_version = nil
    mock = double
    allow(mock).to receive(:new_record?).and_return(false)
    allow(mock).to receive(:version) { new_version || current_version }
    allow(mock).to receive(:version=) { |v| new_version = v }
    allow(mock).to receive_messages(
      payload: nil,
      'payload=': nil,
      created_at: Time.now.utc - 3600,
      updated_at: Time.now.utc,
      'created_at=': nil,
      'updated_at=': nil,
      created_by: 'alice',
      updated_by: 'bob',
      'created_by=': nil,
      'updated_by=': nil,
      save!: true
    )
    mock
  end
end
