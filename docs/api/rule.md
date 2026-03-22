# Rule

The `Ruleur::Rule` class represents an individual business rule with conditions and actions.

## Overview

A Rule consists of:
- A unique name/identifier
- Conditions (when to fire)
- Actions (what to execute)
- Metadata (salience, tags, no_loop flag)

## Class: `Ruleur::Rule`

### Constructor

```ruby
rule = Ruleur::Rule.new(
  name: 'example_rule',
  condition: condition_tree,
  execute: action_proc,
  salience: 10,
  tags: [:example],
  no_loop: true
)
```

#### Parameters

- `name` (String) - Unique identifier for the rule
- `condition` (Condition) - The condition tree to evaluate
- `action` (Proc) - The action to execute when conditions are met
- `salience` (Integer) - Priority level (higher fires first), default: 0
- `tags` (Array\<Symbol\>) - Tags for categorization
- `no_loop` (Boolean) - Prevent recursive firing, default: false

### Instance Methods

#### `#evaluate(context)`

Evaluates the rule's condition against a context.

```ruby
if rule.evaluate(context)
  # Condition is true
end
```

**Parameters:**
- `context` (Ruleur::Context) - The execution context

**Returns:**
- `Boolean` - Whether the condition evaluates to true

#### `#fire(context)`

Executes the rule's action.

```ruby
rule.fire(context)
```

**Parameters:**
- `context` (Ruleur::Context) - The execution context

**Returns:**
- Result of the action execution

#### `#to_h`

Serializes the rule to a Hash.

```ruby
hash = rule.to_h
```

**Returns:**
- `Hash` - Hash representation of the rule

#### `#to_yaml`

Serializes the rule to YAML format.

```ruby
yaml_string = rule.to_yaml
```

**Returns:**
- `String` - YAML representation

### Attributes

- `name` (String, readonly) - Rule name
- `salience` (Integer, readonly) - Priority level
- `tags` (Array\<Symbol\>, readonly) - Rule tags
- `no_loop` (Boolean, readonly) - No-loop flag

## Creating Rules with DSL

The recommended way to create rules is using the DSL within `Ruleur.define`:

```ruby
engine = Ruleur.define do
  rule 'discount_rule', salience: 10, tags: [:pricing] do
    conditions do
      all?(
        customer(:vip?),
        order(:total).gt?(100)
      )
    end
    actions do
      set :discount, 0.2
      set :discount_applied, true
    end
  end
end
```

## Rule Metadata

### Salience

Controls execution order. Higher salience rules fire first.

```ruby
rule 'urgent', salience: 100 do
  # Fires first
end

rule 'normal' do
  # Default salience: 0
end
```

### Tags

Organize and filter rules:

```ruby
rule 'example', tags: %i[permissions admin] do
  # ...
end
```

### No-Loop

Prevents a rule from firing again after it modifies facts:

```ruby
rule 'counter', no_loop: true do
  actions do
    increment :count
  end
end
```

## Examples

### Rule with Complex Condition

```ruby
rule 'shipping_discount' do
  conditions do
    all?(
      order(:total).gt?(50),
      any?(
        customer(:premium?),
        order(:items_count).gt?(3)
      )
    )
  end
  actions do
    set :free_shipping, true
  end
end
```

### Rule with Multiple Actions

```ruby
rule 'approval_workflow' do
  conditions do
    all?(
      document(:ready_for_review?),
      not?(document(:approved?))
    )
  end
  actions do
    call_method document, :mark_pending_review
    set :notification_sent, send_notification(document)
    set :approval_required, true
  end
end
```

## Serialization

### To YAML

```ruby
yaml = rule.to_yaml
File.write('rules/my_rule.yml', yaml)
```

### From YAML

```ruby
rule = Ruleur::Persistence::YAMLLoader.load_file('rules/my_rule.yml')
```

## See Also

- [Condition](./condition) - Condition types and operators
- [DSL](./dsl) - DSL syntax reference
- [YAML Rules](/guide/yaml-rules) - YAML authoring guide
