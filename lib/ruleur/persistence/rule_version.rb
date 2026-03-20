# frozen_string_literal: true

module Ruleur
  module Persistence
    # RuleVersion represents a snapshot of a rule at a specific version
    # This is a wrapper around ActiveRecord models for version history
    class RuleVersion
      attr_reader :rule_name, :version, :payload, :created_at, :created_by, :change_description

      # rubocop:disable Metrics/ParameterLists
      # Multiple parameters needed to capture version history metadata
      def initialize(rule_name:, version:, payload:, created_at:, created_by:, change_description: nil)
        @rule_name = rule_name.to_s
        @version = version.to_i
        @payload = payload
        @created_at = created_at
        @created_by = created_by
        @change_description = change_description
      end
      # rubocop:enable Metrics/ParameterLists

      # Deserialize the rule from this version's payload
      # @return [VersionedRule] The rule with version metadata
      # rubocop:disable Metrics/MethodLength
      # Method constructs VersionedRule with all necessary metadata
      def to_rule
        rule = Serializer.rule_from_h(payload)

        # Convert to VersionedRule with version metadata
        VersionedRule.new(
          name: rule.name,
          condition: rule.condition,
          action: rule.action,
          action_spec: rule.action_spec,
          salience: rule.salience,
          tags: rule.tags,
          no_loop: rule.no_loop,
          version: version,
          created_at: created_at,
          updated_at: created_at, # For historical versions, updated_at = created_at
          created_by: created_by,
          updated_by: created_by,
          change_description: change_description
        )
      end
      # rubocop:enable Metrics/MethodLength

      # Factory method to create from an ActiveRecord model
      def self.from_record(record)
        new(
          rule_name: record.rule_name,
          version: record.version,
          payload: record.payload,
          created_at: record.created_at,
          created_by: record.created_by,
          change_description: record.change_description
        )
      end
    end
  end
end
