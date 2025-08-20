# frozen_string_literal: true

module Ruleur
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

    def self.register_defaults!
      register(:eq) { |l, r| l == r }
      register(:ne) { |l, r| l != r }
      register(:gt) { |l, r| l && r && l > r }
      register(:gte) { |l, r| l && r && l >= r }
      register(:lt) { |l, r| l && r && l < r }
      register(:lte) { |l, r| l && r && l <= r }
      register(:in) { |l, r| r.respond_to?(:include?) && r.include?(l) }
      register(:includes) { |l, r| l.respond_to?(:include?) && l.include?(r) }
      register(:matches) { |l, r| r.is_a?(Regexp) && l.is_a?(String) && l.match?(r) }
      register(:truthy) { |l, _| !!l }
      register(:falsy) { |l, _| !l }
      register(:present) { |l, _| !(l.nil? || (l.respond_to?(:empty?) && l.empty?)) }
      register(:blank) { |l, _| l.nil? || (l.respond_to?(:empty?) && l.empty?) }
    end
  end

  # Auto-register on load
  Operators.register_defaults!
end