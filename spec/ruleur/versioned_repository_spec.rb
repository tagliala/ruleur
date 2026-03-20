# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::Persistence::VersionedActiveRecordRepository do
  let(:mock_model) { double('RuleModel') }
  let(:mock_version_model) { double('RuleVersionModel') }
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
    context 'creating a new rule' do
      let(:mock_record) do
        record = double('record', new_record?: true)
        allow(record).to receive(:version=)
        allow(record).to receive(:payload=)
        allow(record).to receive(:updated_at=)
        allow(record).to receive(:updated_by=)
        allow(record).to receive(:created_at=)
        allow(record).to receive(:created_by=)
        allow(record).to receive(:save!)
        allow(record).to receive(:version).and_return(1)
        allow(record).to receive(:updated_at).and_return(Time.now.utc)
        allow(record).to receive(:created_at).and_return(Time.now.utc)
        allow(record).to receive(:created_by).and_return('alice')
        allow(record).to receive(:updated_by).and_return('alice')
        record
      end

      it 'sets version to 1 and creates version history' do
        expect(mock_model).to receive(:transaction).and_yield
        expect(mock_model).to receive(:lock).and_return(mock_model)
        expect(mock_model).to receive(:find_or_initialize_by).with(name: 'test_rule').and_return(mock_record)
        expect(mock_record).to receive(:version=).with(1)
        expect(mock_version_model).to receive(:create!)

        result = repo.save(rule, user: 'alice', change_description: 'Initial version')

        expect(result).to be_a(Ruleur::Persistence::VersionedRule)
        expect(result.name).to eq('test_rule')
      end
    end

    context 'updating an existing rule' do
      let(:mock_record) do
        record = double('record', new_record?: false)
        new_version = 3
        allow(record).to receive(:version).and_return(2, new_version) # Returns 2 first, then 3
        allow(record).to receive(:version=) do |v|
          new_version = v
        end
        allow(record).to receive(:payload=)
        allow(record).to receive(:updated_at=)
        allow(record).to receive(:updated_by=)
        allow(record).to receive(:save!)
        allow(record).to receive(:updated_at).and_return(Time.now.utc)
        allow(record).to receive(:created_at).and_return(Time.now.utc - 3600)
        allow(record).to receive(:created_by).and_return('alice')
        allow(record).to receive(:updated_by).and_return('bob')
        record
      end

      it 'increments version and creates version history' do
        expect(mock_model).to receive(:transaction).and_yield
        expect(mock_model).to receive(:lock).and_return(mock_model)
        expect(mock_model).to receive(:find_or_initialize_by).with(name: 'test_rule').and_return(mock_record)
        expect(mock_record).to receive(:version=).with(3)
        expect(mock_version_model).to receive(:create!).with(hash_including(
                                                               version: 3,
                                                               rule_name: 'test_rule'
                                                             ))

        result = repo.save(rule, user: 'bob', change_description: 'Updated logic')

        expect(result).to be_a(Ruleur::Persistence::VersionedRule)
        expect(result.version).to eq(3)
      end
    end
  end

  describe '#all' do
    it 'returns all rules with version metadata' do
      created = Time.now.utc - 3600
      updated = Time.now.utc
      mock_record = double(
        'record',
        payload: payload,
        version: 2,
        created_at: created,
        updated_at: updated,
        created_by: 'alice',
        updated_by: 'bob'
      )

      expect(mock_model).to receive(:order).with(:name).and_return([mock_record])

      rules = repo.all

      expect(rules.size).to eq(1)
      expect(rules.first).to be_a(Ruleur::Persistence::VersionedRule)
      expect(rules.first.name).to eq('test_rule')
      expect(rules.first.version).to eq(2)
      expect(rules.first.created_by).to eq('alice')
      expect(rules.first.updated_by).to eq('bob')
    end
  end

  describe '#find' do
    it 'finds a rule by name with version metadata' do
      mock_record = double(
        'record',
        payload: payload,
        version: 1,
        created_at: Time.now.utc,
        updated_at: Time.now.utc,
        created_by: 'alice',
        updated_by: 'alice'
      )

      expect(mock_model).to receive(:find_by).with(name: 'test_rule').and_return(mock_record)

      rule = repo.find('test_rule')

      expect(rule).to be_a(Ruleur::Persistence::VersionedRule)
      expect(rule.name).to eq('test_rule')
    end

    it 'returns nil when rule not found' do
      expect(mock_model).to receive(:find_by).with(name: 'missing').and_return(nil)

      expect(repo.find('missing')).to be_nil
    end
  end

  describe '#find_version' do
    it 'finds a specific version of a rule' do
      mock_version_record = double(
        'version_record',
        rule_name: 'test_rule',
        version: 1,
        payload: payload,
        created_at: Time.now.utc,
        created_by: 'alice',
        change_description: 'Initial'
      )

      expect(mock_version_model).to receive(:find_by)
        .with(rule_name: 'test_rule', version: 1)
        .and_return(mock_version_record)

      rule = repo.find_version('test_rule', 1)

      expect(rule).to be_a(Ruleur::Persistence::VersionedRule)
      expect(rule.version).to eq(1)
    end

    it 'returns nil when version not found' do
      expect(mock_version_model).to receive(:find_by)
        .with(rule_name: 'test_rule', version: 99)
        .and_return(nil)

      expect(repo.find_version('test_rule', 99)).to be_nil
    end
  end

  describe '#version_history' do
    it 'returns version history for a rule' do
      mock_versions = [
        double(
          'v3',
          rule_name: 'test_rule',
          version: 3,
          payload: payload,
          created_at: Time.now.utc,
          created_by: 'bob',
          change_description: 'Latest'
        ),
        double(
          'v2',
          rule_name: 'test_rule',
          version: 2,
          payload: payload,
          created_at: Time.now.utc - 3600,
          created_by: 'bob',
          change_description: 'Update'
        ),
        double(
          'v1',
          rule_name: 'test_rule',
          version: 1,
          payload: payload,
          created_at: Time.now.utc - 7200,
          created_by: 'alice',
          change_description: 'Initial'
        )
      ]

      mock_relation = double('relation')
      expect(mock_version_model).to receive(:where).with(rule_name: 'test_rule').and_return(mock_relation)
      expect(mock_relation).to receive(:order).with(version: :desc).and_return(mock_versions)

      history = repo.version_history('test_rule')

      expect(history.size).to eq(3)
      expect(history).to all(be_a(Ruleur::Persistence::RuleVersion))
      expect(history.map(&:version)).to eq([3, 2, 1])
    end
  end

  describe '#delete' do
    it 'deletes rule and version history in transaction' do
      mock_model_relation = double('model_relation')
      mock_version_relation = double('version_relation')

      expect(mock_model).to receive(:transaction).and_yield
      expect(mock_model).to receive(:where).with(name: 'test_rule').and_return(mock_model_relation)
      expect(mock_model_relation).to receive(:delete_all)
      expect(mock_version_model).to receive(:where).with(rule_name: 'test_rule').and_return(mock_version_relation)
      expect(mock_version_relation).to receive(:delete_all)

      repo.delete('test_rule')
    end
  end

  describe '#rollback' do
    it 'rolls back to a previous version' do
      # Mock the version record to rollback to
      mock_version_record = double(
        'version_record',
        rule_name: 'test_rule',
        version: 2,
        payload: payload,
        created_at: Time.now.utc - 3600,
        created_by: 'alice',
        change_description: 'Previous version'
      )

      expect(mock_version_model).to receive(:find_by)
        .with(rule_name: 'test_rule', version: 2)
        .and_return(mock_version_record)

      # Mock the save operation
      expect(mock_model).to receive(:transaction).and_yield
      expect(mock_model).to receive(:lock).and_return(mock_model)

      mock_record = double('record', new_record?: false)
      new_version = 4
      allow(mock_record).to receive(:version).and_return(3, new_version) # Returns 3 first, then 4
      allow(mock_record).to receive(:version=) do |v|
        new_version = v
      end
      allow(mock_record).to receive(:payload=)
      allow(mock_record).to receive(:updated_at=)
      allow(mock_record).to receive(:updated_by=)
      allow(mock_record).to receive(:save!)
      allow(mock_record).to receive(:updated_at).and_return(Time.now.utc)
      allow(mock_record).to receive(:created_at).and_return(Time.now.utc - 7200)
      allow(mock_record).to receive(:created_by).and_return('alice')
      allow(mock_record).to receive(:updated_by).and_return('bob')

      expect(mock_model).to receive(:find_or_initialize_by).with(name: 'test_rule').and_return(mock_record)
      expect(mock_version_model).to receive(:create!).with(hash_including(
                                                             version: 4,
                                                             change_description: 'Rolled back to version 2'
                                                           ))

      result = repo.rollback('test_rule', 2, user: 'bob')

      expect(result).to be_a(Ruleur::Persistence::VersionedRule)
    end

    it 'raises error when version not found' do
      expect(mock_version_model).to receive(:find_by)
        .with(rule_name: 'test_rule', version: 99)
        .and_return(nil)

      expect do
        repo.rollback('test_rule', 99, user: 'bob')
      end.to raise_error(ArgumentError, /Version 99 not found/)
    end
  end
end
