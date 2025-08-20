# frozen_string_literal: true

require "json"

module Ruleur
  module Persistence
    class MemoryRepository
      # stores an array of serialized rule hashes
      def initialize(serialized_rules = [])
        @serialized_rules = serialized_rules
      end

      def save(rule)
        h = Serializer.rule_to_h(rule)
        idx = @serialized_rules.index { |r| (r[:name] || r["name"]) == h[:name] }
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
        @serialized_rules.reject! { |h| (h[:name] || h["name"]) == name.to_s }
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
        unless defined?(::ActiveRecord)
          raise "ActiveRecord not loaded. Provide model_class: or load ActiveRecord"
        end
        klass = Class.new(::ActiveRecord::Base) do
          self.table_name = "ruleur_rules"
          serialize :payload, JSON unless respond_to?(:attribute_types) && attribute_types["payload"].respond_to?(:deserialize)
        end
        klass
      end
    end
  end
end