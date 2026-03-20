# Condition

Conditions define when a rule should fire. Ruleur provides composable condition types that can be combined to create complex logic.

## Overview

Conditions are organized in a tree structure:
- **Composite Conditions**: `all`, `any`, `not`
- **Predicate Conditions**: Leaf nodes that perform actual evaluations

## Condition Types

### Composite Conditions

#### `all` (AND)

All child conditions must be true.

```ruby
when_all(
  user(:admin?),
  record(:published?),
  record(:approved?)
)
```

#### `any` (OR)

At least one child condition must be true.

```ruby
when_any(
  user(:admin?),
  user(:owner?, record)
)
```

#### `not` (NEGATION)

Inverts the child condition.

```ruby
when_all(
  not(record(:archived?)),
  record(:active?)
)
```

### Predicate Conditions

Predicates perform actual comparisons and checks.

```ruby
# Method call check
user(:admin?)

# Comparison
order(:total).greater_than(100)

# Nested property access
user(:profile, :verified?).equals(true)
```

## Class: `Ruleur::Condition::Base`

Base class for all conditions.

### Instance Methods

#### `#evaluate(context)`

Evaluates the condition against a context.

```ruby
result = condition.evaluate(context)
```

**Parameters:**
- `context` (Ruleur::Context) - The execution context

**Returns:**
- `Boolean` - Evaluation result

#### `#to_h`

Serializes condition to Hash.

```ruby
hash = condition.to_h
```

**Returns:**
- `Hash` - Serialized representation

## Composite Condition Classes

### `Ruleur::Condition::All`

Logical AND of child conditions.

```ruby
all_condition = Ruleur::Condition::All.new([
  condition1,
  condition2,
  condition3
])
```

### `Ruleur::Condition::Any`

Logical OR of child conditions.

```ruby
any_condition = Ruleur::Condition::Any.new([
  condition1,
  condition2
])
```

### `Ruleur::Condition::Not`

Logical negation of a condition.

```ruby
not_condition = Ruleur::Condition::Not.new(condition)
```

## Predicate Condition Classes

### `Ruleur::Condition::Predicate`

Evaluates a method call or comparison.

```ruby
predicate = Ruleur::Condition::Predicate.new(
  receiver: { type: :ref, root: :user },
  method: :admin?,
  operator: :truthy
)
```

## Operators

See [Operators](./operators) for a complete list of available comparison operators.

## Nesting Conditions

Conditions can be nested to arbitrary depth:

```ruby
when_any(
  all(
    user(:admin?),
    not(record(:locked?))
  ),
  all(
    user(:owner?, record),
    record(:editable?),
    any(
      flag(:force_edit),
      not(record(:published?))
    )
  )
)
```

## DSL Shortcuts

The DSL provides convenient methods for creating conditions:

### Context Reference Shortcuts

```ruby
# Reference a fact by key
usr(:method_name)    # context[:user].method_name
rec(:method_name)    # context[:record].method_name
obj(:key, :method)   # context[:key].method

# Flag check
flag(:key)           # context[:key]

# Literal value
lit(42)              # The value 42
```

### Comparison Shortcuts

```ruby
# Equality
usr(:role).equals("admin")

# Comparisons
order(:total).greater_than(100)
order(:total).less_than(1000)
order(:items).includes("premium_item")

# Boolean checks
user(:admin?)        # Implicitly checks truthiness
not(record(:draft?))
```

## Examples

### Simple Boolean Check

```ruby
rule "admin_only" do
  when_all(user(:admin?))
  action { allow! :access }
end
```

### Comparison with Operators

```ruby
rule "bulk_discount" do
  when_all(
    order(:total).greater_than(500),
    order(:items_count).greater_than(10)
  )
  action { set :discount, 0.15 }
end
```

### Complex Nested Logic

```ruby
rule "can_edit" do
  when_any(
    # Admin can always edit
    user(:admin?),
    # Owner can edit if not locked and either draft or has force flag
    all(
      user(:owner?, record),
      not(record(:locked?)),
      any(
        record(:draft?),
        flag(:force_edit)
      )
    )
  )
  action { allow! :edit }
end
```

### Chaining Conditions

```ruby
rule "premium_feature" do
  when_all(
    user(:subscription, :active?),
    user(:subscription, :tier).equals("premium"),
    feature(:enabled?),
    not(feature(:deprecated?))
  )
  action { allow! :premium_feature }
end
```

## See Also

- [Operators](./operators) - Available comparison operators
- [DSL](./dsl) - DSL syntax for conditions
- [Conditions Guide](/guide/conditions) - Detailed condition patterns
