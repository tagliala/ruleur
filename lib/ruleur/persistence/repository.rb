# frozen_string_literal: true

require 'json'

module Ruleur
  module Persistence
    # MemoryRepository stores rules in memory as serialized hashes
    class MemoryRepository
      # stores an array of serialized rule hashes
      def initialize(serialized_rules = [])
        @serialized_rules = serialized_rules
      end

      def save(rule)
        h = Serializer.rule_to_h(rule)
        idx = @serialized_rules.index { |r| (r[:name] || r['name']) == h[:name] }
        if idx
          @serialized_rules[idx] = h
        else
          @serialized_rules << h
        end
      end

      def all
        @serialized_rules.map { |h| Serializer.rule_from_h(h) }
      end

      def delete(name)
        @serialized_rules.reject! { |h| (h[:name] || h['name']) == name.to_s }
      end
    end

    # Optional ActiveRecord-backed repository
    class ActiveRecordRepository
      def initialize(model_class: nil)
        @model = model_class || default_model
      end

      def save(rule)
        payload = Serializer.rule_to_h(rule)
        rec = @model.find_or_initialize_by(name: rule.name)
        rec.payload = payload
        rec.save!
      end

      def all
        @model.order(:name).map { |rec| Serializer.rule_from_h(rec.payload) }
      end

      def delete(name)
        @model.where(name: name.to_s).delete_all
      end

      private

      def default_model
        raise 'ActiveRecord not loaded. Provide model_class: or load ActiveRecord' unless defined?(::ActiveRecord)

        Class.new(::ActiveRecord::Base) do
          self.table_name = 'ruleur_rules'
          unless respond_to?(:attribute_types) && attribute_types['payload'].respond_to?(:deserialize)
            serialize :payload,
                      JSON
          end
        end
      end
    end

    # VersionedActiveRecordRepository adds full version tracking and audit trail
    # rubocop:disable Metrics/ClassLength
    class VersionedActiveRecordRepository
      attr_reader :model, :version_model

      def initialize(model_class: nil, version_model_class: nil)
        @model = model_class || default_model
        @version_model = version_model_class || default_version_model
      end

      # Save a rule with version tracking
      # @param rule [Rule] Rule to save
      # @param user [String, nil] User identifier for audit trail
      # @param change_description [String, nil] Description of changes
      # @return [VersionedRule] Saved rule with version metadata
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      # Complexity needed for transaction, version tracking, and history recording
      def save(rule, user: nil, change_description: nil)
        payload = Serializer.rule_to_h(rule)

        @model.transaction do
          rec = @model.lock.find_or_initialize_by(name: rule.name)
          is_new = rec.new_record?

          # Increment version for existing records
          rec.version = is_new ? 1 : (rec.version + 1)
          rec.payload = payload
          rec.updated_at = Time.now.utc
          rec.updated_by = user

          # Set created_at/created_by for new records
          if is_new
            rec.created_at = rec.updated_at
            rec.created_by = user
          end

          rec.save!

          # Create version history record
          @version_model.create!(
            rule_name: rule.name,
            version: rec.version,
            payload: payload,
            created_at: rec.updated_at,
            created_by: user,
            change_description: change_description
          )

          # Return VersionedRule with metadata
          build_versioned_rule(rule, rec)
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Load all current rules with version metadata
      # @return [Array<VersionedRule>]
      def all
        @model.order(:name).map do |rec|
          rule = Serializer.rule_from_h(rec.payload)
          build_versioned_rule(rule, rec)
        end
      end

      # Load a specific rule by name
      # @param name [String] Rule name
      # @return [VersionedRule, nil]
      def find(name)
        rec = @model.find_by(name: name.to_s)
        return nil unless rec

        rule = Serializer.rule_from_h(rec.payload)
        build_versioned_rule(rule, rec)
      end

      # Load a specific version of a rule
      # @param name [String] Rule name
      # @param version [Integer] Version number
      # @return [VersionedRule, nil]
      def find_version(name, version)
        version_rec = @version_model.find_by(rule_name: name.to_s, version: version)
        return nil unless version_rec

        RuleVersion.from_record(version_rec).to_rule
      end

      # Get version history for a rule
      # @param name [String] Rule name
      # @return [Array<RuleVersion>]
      def version_history(name)
        @version_model
          .where(rule_name: name.to_s)
          .order(version: :desc)
          .map { |rec| RuleVersion.from_record(rec) }
      end

      # Delete a rule and its version history
      # @param name [String] Rule name
      def delete(name)
        @model.transaction do
          @model.where(name: name.to_s).delete_all
          @version_model.where(rule_name: name.to_s).delete_all
        end
      end

      # Rollback a rule to a previous version
      # @param name [String] Rule name
      # @param target_version [Integer] Version to rollback to
      # @param user [String, nil] User performing the rollback
      # @return [VersionedRule] Rolled back rule
      def rollback(name, target_version, user: nil)
        version_rec = @version_model.find_by(rule_name: name.to_s, version: target_version)
        raise ArgumentError, "Version #{target_version} not found for rule '#{name}'" unless version_rec

        # Load the rule from the target version
        rule = Serializer.rule_from_h(version_rec.payload)

        # Save as a new version with rollback description
        save(
          rule,
          user: user,
          change_description: "Rolled back to version #{target_version}"
        )
      end

      private

      # rubocop:disable Metrics/MethodLength
      # Method needs to construct VersionedRule with all metadata fields
      def build_versioned_rule(rule, record)
        VersionedRule.new(
          name: rule.name,
          condition: rule.condition,
          action: rule.action,
          action_spec: rule.action_spec,
          salience: rule.salience,
          tags: rule.tags,
          no_loop: rule.no_loop,
          version: record.version,
          created_at: record.created_at,
          updated_at: record.updated_at,
          created_by: record.created_by,
          updated_by: record.updated_by,
          change_description: nil # Current rule doesn't have change_description
        )
      end
      # rubocop:enable Metrics/MethodLength

      def default_model
        raise 'ActiveRecord not loaded. Provide model_class: or load ActiveRecord' unless defined?(::ActiveRecord)

        Class.new(::ActiveRecord::Base) do
          self.table_name = 'ruleur_rules'
          unless respond_to?(:attribute_types) && attribute_types['payload'].respond_to?(:deserialize)
            serialize :payload, JSON
          end
        end
      end

      def default_version_model
        unless defined?(::ActiveRecord)
          raise 'ActiveRecord not loaded. Provide version_model_class: or load ActiveRecord'
        end

        Class.new(::ActiveRecord::Base) do
          self.table_name = 'ruleur_rule_versions'
          unless respond_to?(:attribute_types) && attribute_types['payload'].respond_to?(:deserialize)
            serialize :payload, JSON
          end
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
