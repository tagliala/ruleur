# frozen_string_literal: true

# Ruleur is a composable Business Rules Management System (BRMS) for Ruby
module Ruleur
  # Operators provides pluggable comparison and predicate operators for conditions
  module Operators
    @ops = {}

    def self.register(name, &block)
      @ops[name.to_sym] = block
    end

    def self.call(name, left, right)
      fn = @ops[name.to_sym]
      raise ArgumentError, "Unknown operator: #{name}" unless fn

      fn.call(left, right)
    end

    def self.registry
      @ops
    end

    def self.register_defaults!
      register_comparison_operators
      register_collection_operators
      register_predicate_operators
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    # Complexity acceptable for operator registration - clear and maintainable
    def self.register_comparison_operators
      register(:eq) { |left, right| left == right }
      register(:ne) { |left, right| left != right }
      register(:gt) { |left, right| left && right && left > right }
      register(:gte) { |left, right| left && right && left >= right }
      register(:lt) { |left, right| left && right && left < right }
      register(:lte) { |left, right| left && right && left <= right }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def self.register_collection_operators
      register(:in) { |left, right| right.respond_to?(:include?) && right.include?(left) }
      register(:includes) { |left, right| left.respond_to?(:include?) && left.include?(right) }
      register(:matches) { |left, right| right.is_a?(Regexp) && left.is_a?(String) && left.match?(right) }
    end

    def self.register_predicate_operators
      register(:truthy) { |left, _| !left.nil? && left != false }
      register(:falsy) { |left, _| !left }
      register(:present) { |left, _| !(left.nil? || (left.respond_to?(:empty?) && left.empty?)) }
      register(:blank) { |left, _| left.nil? || (left.respond_to?(:empty?) && left.empty?) }
    end
  end

  # Auto-register on load
  Operators.register_defaults!
end
