# frozen_string_literal: true

module Ruleur
  module Persistence
    # VersionedRule extends Rule with version tracking metadata
    # This is used when loading rules from a versioned repository
    class VersionedRule < Rule
      attr_reader :version, :created_at, :updated_at, :created_by, :updated_by, :change_description

      # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      # Large number of parameters needed for version metadata tracking
      def initialize(
        name:, condition:, action: nil, action_spec: nil,
        salience: 0, tags: [], no_loop: false,
        version: 1, created_at: nil, updated_at: nil,
        created_by: nil, updated_by: nil, change_description: nil
      )
        super(
          name: name,
          condition: condition,
          action: action,
          action_spec: action_spec,
          salience: salience,
          tags: tags,
          no_loop: no_loop
        )

        @version = version.to_i
        @created_at = created_at
        @updated_at = updated_at
        @created_by = created_by
        @updated_by = updated_by
        @change_description = change_description
      end
      # rubocop:enable Metrics/MethodLength, Metrics/ParameterLists

      # Check if this rule has version metadata
      def versioned?
        !version.nil? && version.positive?
      end

      # Get version info as a hash
      def version_info
        {
          version: version,
          created_at: created_at,
          updated_at: updated_at,
          created_by: created_by,
          updated_by: updated_by,
          change_description: change_description
        }
      end
    end
  end
end
