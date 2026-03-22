# frozen_string_literal: true

module Ruleur
  module Persistence
    # Serializer converts rules to/from JSON-serializable hashes
    # rubocop:disable Metrics/ModuleLength
    module Serializer
      module_function

      def rule_to_h(rule)
        {
          name: rule.name,
          salience: rule.salience,
          tags: rule.tags,
          no_loop: rule.no_loop,
          conditions: node_to_h(rule.condition),
          actions: rule.action_spec # serialized action spec only
        }
      end

      # rubocop:disable Metrics/MethodLength
      def node_to_h(node)
        case node
        when Condition::Predicate
          serialize_predicate(node)
        when Condition::All
          { type: 'all', children: node.children.map { |c| node_to_h(c) } }
        when Condition::Any
          { type: 'any', children: node.children.map { |c| node_to_h(c) } }
        when Condition::Not
          { type: 'not', child: node_to_h(node.child) }
        else
          raise ArgumentError, "Cannot serialize node: #{node.inspect}"
        end
      end
      # rubocop:enable Metrics/MethodLength

      def serialize_predicate(node)
        {
          type: 'pred',
          op: node.instance_variable_get(:@operator),
          left: value_to_h(node.instance_variable_get(:@left)),
          right: value_to_h(node.instance_variable_get(:@right))
        }
      end

      def value_to_h(val)
        case val
        when Condition::Ref
          { type: 'ref', root: val.root, path: val.path }
        when Condition::Call
          serialize_call(val)
        when Condition::LambdaValue
          raise ArgumentError, 'Lambda values cannot be serialized'
        else
          val
        end
      end

      def serialize_call(val)
        {
          type: 'call',
          recv: value_to_h(val.receiver),
          method: val.method_name,
          args: val.args.map { |a| value_to_h(a) }
        }
      end

      def rule_from_h(hash)
        Rule.new(
          name: hash[:name] || hash['name'],
          salience: hash[:salience] || hash['salience'],
          tags: hash[:tags] || hash['tags'],
          no_loop: hash[:no_loop] || hash['no_loop'],
          condition: node_from_h(hash[:conditions] || hash['conditions']),
          action_spec: hash[:actions] || hash['actions']
        )
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      # rubocop:disable Metrics/PerceivedComplexity
      def node_from_h(hash)
        type = hash['type'] || hash[:type]
        case type
        when 'pred'
          deserialize_predicate(hash)
        when 'all'
          Condition::All.new(*(hash['children'] || hash[:children]).map { |c| node_from_h(c) })
        when 'any'
          Condition::Any.new(*(hash['children'] || hash[:children]).map { |c| node_from_h(c) })
        when 'not'
          Condition::Not.new(node_from_h(hash['child'] || hash[:child]))
        else
          raise ArgumentError, "Unknown node type: #{hash.inspect}"
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      def deserialize_predicate(hash)
        operator = (hash['op'] || hash[:op]).to_sym
        left = value_from_h(hash['left'] || hash[:left])
        right = value_from_h(hash['right'] || hash[:right])
        Condition::Predicate.new(left, operator, right)
      end

      def value_from_h(hash)
        return hash unless hash.is_a?(Hash)

        type = hash['type'] || hash[:type]
        return hash unless type

        deserialize_value_by_type(hash, type)
      end

      def deserialize_value_by_type(hash, type)
        case type
        when 'ref'
          Condition::Ref.new(hash['root'] || hash[:root], *(hash['path'] || hash[:path]))
        when 'call'
          deserialize_call(hash)
        else
          raise ArgumentError, "Unknown value type: #{hash.inspect}"
        end
      end

      def deserialize_call(hash)
        recv = value_from_h(hash['recv'] || hash[:recv])
        args = (hash['args'] || hash[:args] || []).map { |a| value_from_h(a) }
        Condition::Call.new(recv, (hash['method'] || hash[:method]).to_sym, *args)
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
