# Engine

The `Ruleur::Engine` is the core component responsible for executing rules against a context.

## Overview

The Engine manages rule execution, conflict resolution, and fact propagation in a forward-chaining manner.

## Class: `Ruleur::Engine`

### Constructor

```ruby
engine = Ruleur::Engine.new(rules: [rule1, rule2])
```

#### Parameters

- `rules` (Array) - Array of `Ruleur::Rule` objects

### Instance Methods

#### `#run(context_hash)`

Executes all rules against the provided context.

```ruby
context = engine.run(user: current_user, record: @record)
```

**Parameters:**
- `context_hash` (Hash) - Initial facts and objects for the execution context

**Returns:**
- `Ruleur::Context` - The execution context with results

#### `#add_rule(rule)`

Adds a rule to the engine.

```ruby
engine.add_rule(my_rule)
```

**Parameters:**
- `rule` (Ruleur::Rule) - The rule to add

**Returns:**
- `self` - For method chaining

## DSL Helper: `Ruleur.define`

The recommended way to create an engine is using the DSL:

```ruby
engine = Ruleur.define do
  rule "rule_name" do
    when_all(condition)
    action do
      # action code
    end
  end
end
```

## Examples

### Basic Engine Usage

```ruby
engine = Ruleur::Engine.new(rules: [
  discount_rule,
  shipping_rule
])

result = engine.run(
  order: order,
  customer: customer
)

puts result[:discount_applied] # => true
```

### Salience-Based Execution

Rules execute in priority order based on salience:

```ruby
engine = Ruleur.define do
  rule "high_priority", salience: 100 do
    # Executes first
  end
  
  rule "low_priority", salience: 1 do
    # Executes last
  end
end
```

## Configuration Options

::: warning TODO
Document engine configuration options, execution strategies, and advanced features.
:::

## See Also

- [Rule](./rule) - Individual rule definition
- [Context](./context) - Execution context
- [DSL Basics](/guide/dsl-basics) - DSL syntax guide
