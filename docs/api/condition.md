# Condition

Conditions define when a rule should fire. Ruleur provides composable condition types that can be combined to create complex logic.

## Overview

- **Composite Conditions**: `all`, `any`, `not?`
- **Predicate Conditions**: Leaf nodes that perform actual evaluations

## Condition Types

### Composite Conditions

#### `all` (AND)

All child conditions must be true.

```ruby
match do
  all(
    user(:admin?),
    record(:published?),
    record(:approved?)
  )
end
```

#### `any` (OR)

At least one child condition must be true.

```ruby
match do
  any(
    user(:admin?),
    user(:owner?, record)
  )
end
```

#### `not?` (NEGATION)

Inverts the child condition.

```ruby
match do
  all(
    not?(record(:archived?)),
    record(:active?)
  )
end
```

### Predicate Conditions

Predicates perform actual comparisons and checks.

```ruby
# Method call check
user(:admin?)

# Comparison
order(:total).gt?(100)

# Nested property access
user(:profile, :verified?).eq?(true)
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
match do
    any(
      all(
        user(:admin?),
        not?(record(:locked?))
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
end
```

## DSL Shortcuts

The DSL provides convenient methods for creating conditions:

### Context Reference Shortcuts

```ruby
# Reference a fact by key
user(:method_name)    # context[:user].method_name
record(:method_name)  # context[:record].method_name
obj(:key, :method)    # context[:key].method

# Flag check
flag(:key)            # context[:key]

# Literal value
literal(42)               # The value 42
```

### Comparison Shortcuts

```ruby
# Equality
user(:role).eq?("admin")

# Comparisons
order(:total).gt?(100)
order(:total).lt?(1000)
order(:items).includes("premium_item")

# Boolean checks
user(:admin?)        # Implicitly checks truthiness
not?(record(:draft?))
```

## Examples

### Simple Boolean Check

```ruby
rule "admin_only" do
  match do
    all(user(:admin?))
  end

  execute do
    allow! :access
  end
end
```

### Comparison with Operators

```ruby
rule "bulk_discount" do
  match do
    all(
      order(:total).gt?(500),
      order(:items_count).gt?(10)
    )
  end

  execute do
    set :discount, 0.15
  end
end
```

### Complex Nested Logic

```ruby
rule "can_edit" do
  match do
    any(
      # Admin can always edit
      user(:admin?),
      # Owner can edit if not locked and either draft or has force flag
      all(
        user(:owner?, record),
      not?(record(:locked?)),
       any(
         record(:draft?),
         flag(:force_edit)
       )
      )
    )
  end

  execute do
    allow! :edit
  end
end
```

### Chaining Conditions

```ruby
rule "premium_feature" do
  match do
    all(
      user(:subscription, :active?),
      user(:subscription, :tier).eq?("premium"),
      feature(:enabled?),
      not?(feature(:deprecated?))
    )
  end

  execute do
    allow! :premium_feature
  end
end
```

## See Also

- [Operators](./operators) - Available comparison operators
- [DSL](./dsl) - DSL syntax for conditions
- [Conditions Guide](/guide/conditions) - Detailed condition patterns
