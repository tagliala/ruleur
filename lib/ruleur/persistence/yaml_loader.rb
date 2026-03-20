# frozen_string_literal: true

require 'yaml'

module Ruleur
  module Persistence
    # YAMLLoader handles loading and saving rules from/to YAML files
    # rubocop:disable Metrics/ModuleLength
    module YAMLLoader
      module_function

      # Load a single rule from a YAML file
      # @param file_path [String] Path to the YAML file
      # @return [Rule] Deserialized rule object
      # @raise [ArgumentError] if file doesn't exist or YAML is invalid
      def load_file(file_path)
        raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)

        yaml_content = File.read(file_path)
        load_string(yaml_content)
      rescue Psych::SyntaxError => e
        raise ArgumentError, "Invalid YAML syntax in #{file_path}: #{e.message}"
      end

      # Load multiple rules from a directory or glob pattern
      # @param pattern [String] Glob pattern (e.g., "config/rules/*.yml")
      # @return [Array<Rule>] Array of deserialized rules
      def load_directory(pattern)
        files = Dir.glob(pattern)
        raise ArgumentError, "No YAML files found matching: #{pattern}" if files.empty?

        files.map { |file| load_file(file) }
      end

      # Load a rule from a YAML string
      # @param yaml_string [String] YAML content as string
      # @return [Rule] Deserialized rule object
      def load_string(yaml_string)
        hash = YAML.safe_load(yaml_string, permitted_classes: [Symbol], symbolize_names: true)
        normalize_hash_keys!(hash)
        Serializer.rule_from_h(hash)
      end

      # Save a rule to a YAML file
      # @param rule [Rule] Rule to serialize
      # @param file_path [String] Path where to save the YAML file
      # @param include_metadata [Boolean] Whether to include comments/metadata
      def save_file(rule, file_path, include_metadata: true)
        yaml_string = to_yaml(rule, include_metadata: include_metadata)
        File.write(file_path, yaml_string)
      end

      # Convert a rule to YAML string
      # @param rule [Rule] Rule to serialize
      # @param include_metadata [Boolean] Whether to include comments
      # @return [String] YAML representation
      def to_yaml(rule, include_metadata: true)
        hash = Serializer.rule_to_h(rule)
        normalize_for_yaml!(hash)

        yaml = YAML.dump(hash.transform_keys(&:to_s))

        if include_metadata
          add_metadata_header(yaml, rule)
        else
          yaml
        end
      end

      # Validate YAML structure before loading
      # @param file_path [String] Path to YAML file
      # @return [Hash] Validation result with :valid and :errors keys
      def validate_file(file_path)
        return { valid: false, errors: ["File not found: #{file_path}"] } unless File.exist?(file_path)

        yaml_content = File.read(file_path)
        validate_string(yaml_content)
      rescue Psych::SyntaxError => e
        { valid: false, errors: ["Invalid YAML syntax: #{e.message}"] }
      end

      # Validate YAML string
      # @param yaml_string [String] YAML content
      # @return [Hash] Validation result with :valid and :errors keys
      def validate_string(yaml_string)
        hash = YAML.safe_load(yaml_string, permitted_classes: [Symbol], symbolize_names: true)
        errors = validate_hash_structure(hash)

        { valid: errors.empty?, errors: errors }
      rescue Psych::SyntaxError => e
        { valid: false, errors: ["Invalid YAML syntax: #{e.message}"] }
      end

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
      private_class_method def self.normalize_hash_keys!(hash)
        # Recursively convert string keys to symbols for consistency
        return hash unless hash.is_a?(Hash)

        hash.transform_keys!(&:to_sym)

        # Recursively normalize nested hashes
        hash.each_value do |value|
          case value
          when Hash
            normalize_hash_keys!(value)
          when Array
            value.each { |item| normalize_hash_keys!(item) if item.is_a?(Hash) }
          end
        end

        hash
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
      private_class_method def self.normalize_for_yaml!(hash)
        # Convert symbols to strings for cleaner YAML output
        return hash unless hash.is_a?(Hash)

        hash.transform_keys!(&:to_s)

        hash.each do |key, value|
          case value
          when Hash
            normalize_for_yaml!(value)
          when Array
            value.each { |item| normalize_for_yaml!(item) if item.is_a?(Hash) }
          when Symbol
            hash[key] = value.to_s
          end
        end

        hash
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

      private_class_method def self.add_metadata_header(yaml, rule)
        header = "# Ruleur Rule: #{rule.name}\n"
        header += "# Salience: #{rule.salience}\n" if rule.salience != 0
        header += "# Tags: #{rule.tags.join(', ')}\n" unless rule.tags.empty?
        header += "# No-loop: #{rule.no_loop}\n" if rule.no_loop
        header += "# Generated: #{Time.now.utc.iso8601}\n"
        header += "\n"
        header + yaml
      end

      private_class_method def self.validate_hash_structure(hash)
        errors = []

        # Check required fields
        errors << 'Missing required field: name' unless hash[:name]
        errors << 'Missing required field: condition' unless hash[:condition]
        errors << 'Missing required field: action' unless hash[:action]

        # Validate condition structure
        errors.concat(validate_condition_structure(hash[:condition])) if hash[:condition]

        # Validate action structure
        errors.concat(validate_action_structure(hash[:action])) if hash[:action]

        errors
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
      private_class_method def self.validate_condition_structure(cond)
        errors = []

        return errors unless cond.is_a?(Hash)

        type = cond[:type]
        unless %w[pred all any not].include?(type)
          errors << "Invalid condition type: #{type.inspect}"
          return errors
        end

        case type
        when 'pred'
          errors << 'Predicate missing operator' unless cond[:op]
        when 'all', 'any'
          if cond[:children].nil? || !cond[:children].is_a?(Array)
            errors << "#{type} condition must have children array"
          else
            cond[:children].each do |child|
              errors.concat(validate_condition_structure(child))
            end
          end
        when 'not'
          if cond[:child].nil?
            errors << 'Not condition must have child'
          else
            errors.concat(validate_condition_structure(cond[:child]))
          end
        end

        errors
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity

      private_class_method def self.validate_action_structure(action)
        errors = []

        return errors unless action.is_a?(Hash)

        # For now, we only support 'set' actions
        if action[:set]
          errors << 'Action set must be a hash' unless action[:set].is_a?(Hash)
        elsif action.empty?
          errors << 'Action cannot be empty'
        end

        errors
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
