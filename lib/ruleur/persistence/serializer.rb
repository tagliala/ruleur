# frozen_string_literal: true

module Ruleur
  module Persistence
    module Serializer
      module_function

      def rule_to_h(rule)
        {
          name: rule.name,
          salience: rule.salience,
          tags: rule.tags,
          no_loop: rule.no_loop,
          condition: node_to_h(rule.condition),
          action: rule.action_spec # serialized action spec only
        }
      end

      def node_to_h(node)
        case node
        when Condition::Predicate
          {
            type: 'pred',
            op: node.instance_variable_get(:@op),
            left: value_to_h(node.instance_variable_get(:@left)),
            right: value_to_h(node.instance_variable_get(:@right))
          }
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

      def value_to_h(v)
        case v
        when Condition::Ref
          { type: 'ref', root: v.root, path: v.path }
        when Condition::Call
          { type: 'call', recv: value_to_h(v.receiver), method: v.method, args: v.args.map { |a| value_to_h(a) } }
        when Condition::LambdaValue
          raise ArgumentError, 'Lambda values cannot be serialized'
        else
          v
        end
      end

      def rule_from_h(h)
        Rule.new(
          name: h[:name] || h['name'],
          salience: h[:salience] || h['salience'],
          tags: h[:tags] || h['tags'],
          no_loop: h[:no_loop] || h['no_loop'],
          condition: node_from_h(h[:condition] || h['condition']),
          action_spec: h[:action] || h['action']
        )
      end

      def node_from_h(h)
        case h['type'] || h[:type]
        when 'pred'
          op = (h['op'] || h[:op]).to_sym
          left = value_from_h(h['left'] || h[:left])
          right = value_from_h(h['right'] || h[:right])
          Condition::Predicate.new(left, op, right)
        when 'all'
          Condition::All.new(*(h['children'] || h[:children]).map { |c| node_from_h(c) })
        when 'any'
          Condition::Any.new(*(h['children'] || h[:children]).map { |c| node_from_h(c) })
        when 'not'
          Condition::Not.new(node_from_h(h['child'] || h[:child]))
        else
          raise ArgumentError, "Unknown node type: #{h.inspect}"
        end
      end

      def value_from_h(h)
        if h.is_a?(Hash) && (t = h['type'] || h[:type])
          case t
          when 'ref'
            Condition::Ref.new(h['root'] || h[:root], *(h['path'] || h[:path]))
          when 'call'
            recv = value_from_h(h['recv'] || h[:recv])
            args = (h['args'] || h[:args] || []).map { |a| value_from_h(a) }
            Condition::Call.new(recv, (h['method'] || h[:method]).to_sym, *args)
          else
            raise ArgumentError, "Unknown value type: #{h.inspect}"
          end
        else
          h
        end
      end
    end
  end
end
