# Operators

Operators are used in predicate conditions to compare values and evaluate expressions.

## Overview

Ruleur provides a comprehensive set of operators for:
- Equality and identity checks
- Numeric comparisons
- Collection operations
- Pattern matching
- Type checking

## Comparison Operators

### `equals`

Checks equality using `==`.

```ruby
user(:role).eq?("admin")
order(:status).eq?("pending")
```

### `not_equals`

Checks inequality using `!=`.

```ruby
user(:role).not_eq?("guest")
order(:status).not_eq?("cancelled")
```

### `identical`

Checks identity using `eql?`.

```ruby
value(:type).identical(expected_type)
```

## Numeric Operators

### `greater_than`

Greater than comparison using `>`.

```ruby
order(:total).gt?(100)
user(:age).gt?(18)
```

### `greater_than_or_equal`

Greater than or equal comparison using `>=`.

```ruby
order(:total).gte?(50)
user(:age).gte?(21)
```

### `less_than`

Less than comparison using `<`.

```ruby
order(:total).lt?(1000)
user(:age).lt?(65)
```

### `less_than_or_equal`

Less than or equal comparison using `<=`.

```ruby
order(:items_count).lte?(10)
user(:attempts).lte?(3)
```

## Collection Operators

### `contains`

Checks if collection includes a value using `include?`.

```ruby
user(:roles).contains?("admin")
order(:tags).contains?("express")
```

### `include?`

Checks if value is in a collection.

```ruby
user(:status).include?(["active", "pending", "trial"])
order(:type).include?(allowed_types)
```

## Pattern Matching

### `matches`

Pattern matching using `match?` or `===`.

```ruby
email(:address).matches(/^[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+$/i)
user(:role).matches(/admin|super/)
```

## Boolean Operators

### `truthy`

Checks if value is truthy (not `nil` or `false`).

```ruby
user(:admin?)          # Implicit truthy check
flag(:enabled).truthy
```

### `falsy`

Checks if value is falsy (`nil` or `false`).

```ruby
user(:banned?).falsy
flag(:disabled).falsey
```

## Type Checking

### `is_a` / `instance_of`

Type checking using `is_a?`.

```ruby
record(:object).is_a(User)
value(:data).instance_of(Hash)
```

### `nil` / `null`

Checks if value is `nil`.

```ruby
user(:deleted_at).nil
record(:parent).null
```

### `present`

Checks if value is present (not `nil` and not empty).

```ruby
user(:email).present
order(:items).present
```

### `blank`

Checks if value is blank (`nil`, `false`, empty, or whitespace).

```ruby
user(:notes).blank
order(:special_instructions).blank
```

## Method Call Operator

### `call`

Calls a method with arguments.

```ruby
# Check if user owns the record
user(:owns?, record)

# Call with multiple arguments
calculator(:compute, value1, value2, operator: :add)
```

## Operator Usage

### In DSL

```ruby
rule "example" do
  match do
    all(
    order(:total).gt?(100),
    user(:email).matches(/@company\.com$/),
    user(:roles).includes("premium")
  )
  end
  execute do set :qualified, true end
end
```

### In YAML

```yaml
condition:
  type: all
  children:
    - type: pred
      op: greater_than
      left:
        type: call
        recv: { type: ref, root: order }
        method: total
      right:
        type: literal
        value: 100
```

## Custom Operators

::: warning TODO
Document how to create custom operators and extend the operator system.
:::

## Operator Precedence

When combining operators, use explicit grouping with `all()` and `any()`:

```ruby
# Clear precedence with grouping
match do
  all(
  any(
    user(:admin?),
    user(:moderator?)
  ),
  record(:published?)
)
end
```

## Examples

### Numeric Range Check

```ruby
rule "medium_order" do
  match do
    all(
    order(:total).gte?(50),
    order(:total).lt?(200)
  )
  end
  execute do set :tier, "medium" end
end
```

### Email Validation

```ruby
rule "valid_email" do
  match do
    all(
    user(:email).present,
    user(:email).matches(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  )
  end
  execute do set :email_valid, true end
end
```

### Role-Based Access

```ruby
rule "can_approve" do
  match do
    all(
    user(:roles).includes("approver"),
    document(:status).in(["pending", "submitted"]),
    not?(document(:approved_at).present)
  )
  end
  execute do allow! :approve end
end
```

### Type and Presence Checks

```ruby
rule "process_data" do
  match do
    all(
    input(:data).present,
    input(:data).is_a(Hash),
    input(:data, :items).is_a(Array),
    not?(input(:data, :items).blank)
  )
  end
  execute do set :ready_to_process, true end
end
```

## See Also

- [Condition](./condition) - Condition types
- [Operators Guide](/guide/operators) - Operator usage patterns
- [DSL](./dsl) - DSL syntax reference
