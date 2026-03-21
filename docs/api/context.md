# Context

The `Ruleur::Context` class holds the facts, intermediate values, and results during rule execution.

## Overview

The Context serves as:
- A container for input facts (objects, values)
- A working memory for intermediate calculations
- A result store for rule actions
- A history tracker for rule execution

## Class: `Ruleur::Context`

### Constructor

```ruby
context = Ruleur::Context.new(
  user: current_user,
  order: order,
  date: Date.today
)
```

#### Parameters

All parameters become facts in the context accessible by their keys.

### Instance Methods

#### `#[]=(key, value)`

Sets a value in the context.

```ruby
context[:discount] = 0.15
context[:approved] = true
```

**Parameters:**
- `key` (Symbol) - The key
- `value` (Any) - The value to store

#### `#[](key)`

Gets a value from the context.

```ruby
user = context[:user]
is_approved = context[:approved]
```

**Parameters:**
- `key` (Symbol) - The key

**Returns:**
- The stored value or `nil`

#### `#fetch(key, default = nil)`

Gets a value with a default fallback.

```ruby
discount = context.fetch(:discount, 0)
```

**Parameters:**
- `key` (Symbol) - The key
- `default` (Any) - Default value if key doesn't exist

**Returns:**
- The stored value or default

#### `#key?(key)`

Checks if a key exists.

```ruby
if context.key?(:user)
  # User fact is present
end
```

**Parameters:**
- `key` (Symbol) - The key

**Returns:**
- `Boolean`

#### `#to_h`

Converts context to a Hash.

```ruby
hash = context.to_h
```

**Returns:**
- `Hash` - All context values

#### `#rule_fired?(rule_name)`

Checks if a rule has already fired.

```ruby
if context.rule_fired?("discount_rule")
  # Rule already executed
end
```

**Parameters:**
- `rule_name` (String) - The rule name

**Returns:**
- `Boolean`

## Usage in Actions

Within rule actions, the context is available and can be modified:

```ruby
rule "calculate_discount" do
  when_all(customer(:vip?))
  action do
    # Access facts
    order = context[:order]
    
    # Set new values
    set :discount, 0.2
    set :discount_amount, order.total * 0.2
    
    # Call methods on facts
    call_method order, :apply_discount, context[:discount]
  end
end
```

## Context Lifecycle

1. **Initialization**: Created with initial facts
2. **Rule Evaluation**: Facts are read during condition evaluation
3. **Rule Firing**: Actions modify the context
4. **Fact Propagation**: Modified facts may trigger additional rules
5. **Completion**: Final context contains all results

## Best Practices

### Permission Results

For permissions, use `set :key, true` to grant access. Access is denied by default when no flag is set:

```ruby
rule "admin_create" do
  when_all(user(:admin?))
  set :create, true
end
```

Then check permissions:
```ruby
ctx[:create] == true  # granted
ctx[:create].nil?     # denied by default
```

### General Context Values

For non-permission values, use `set` with clear names:

```ruby
action do
  set :discount, 0.20
  set :discount_reason, "VIP customer"
  set :error_message, "Something went wrong"
end
```

### Preserving Input Facts

Avoid overwriting input facts directly:

```ruby
# Bad
action do
  context[:user] = modified_user
end

# Good
action do
  set :modified_user, modified_user
  set :user_updated, true
end
```

### Type Safety

Check fact presence before use:

```ruby
action do
  if context.key?(:order)
    order = context[:order]
    set :total, order.total
  else
    set :error, "Order not provided"
  end
end
```

## Examples

### Accessing Facts in Conditions

```ruby
rule "premium_check" do
  when_all(
    customer(:premium?),
    order(:total).greater_than(100)
  )
  action do
    customer = context[:customer]
    order = context[:order]
    
    discount = customer.discount_rate * order.total
    set :discount_amount, discount
  end
end
```

### Chaining Rule Results

```ruby
# First rule sets a flag
rule "validate_order" do
  when_all(order(:valid?))
  action do
    set :order_valid, true
  end
end

# Second rule depends on the flag
rule "process_payment" do
  when_all(flag(:order_valid))
  action do
    set :payment_processed, true
  end
end
```

## See Also

- [Engine](./engine) - Engine execution
- [Rule](./rule) - Rule actions
- [DSL](./dsl) - Action DSL methods
