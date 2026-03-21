# DSL

The Ruleur Domain-Specific Language (DSL) provides a Ruby-friendly way to define rules with readable, composable syntax.

## Overview

The DSL consists of:
- **Engine Definition**: `Ruleur.define` block
- **Rule Definition**: `rule "name"` block
- **Conditions**: `when_all()`, `when_any()`, `not()`
- **Actions**: `action` block with helper methods

## Engine Definition

### `Ruleur.define`

Creates an engine with rules defined in the block.

```ruby
engine = Ruleur.define do
  rule "first_rule" do
    # ...
  end
  
  rule "second_rule" do
    # ...
  end
end
```

**Returns:**
- `Ruleur::Engine` - Configured engine instance

## Rule Definition

### `rule(name, options = {}, &block)`

Defines a rule within the engine.

```ruby
rule "example", salience: 10, tags: [:important], no_loop: true do
  when_all(conditions)
  action do
    # action code here
  end
end
```

**Parameters:**
- `name` (String) - Unique rule identifier
- `options` (Hash) - Optional configuration
  - `salience` (Integer) - Priority (default: 0)
  - `tags` (Array\<Symbol\>) - Tags for categorization
  - `no_loop` (Boolean) - Prevent recursive firing

## Condition Methods

### Composite Conditions

#### `when_all(*conditions)`

All conditions must be true (AND).

```ruby
when_all(
  user(:admin?),
  record(:published?),
  not(record(:archived?))
)
```

#### `when_any(*conditions)`

At least one condition must be true (OR).

```ruby
when_any(
  user(:admin?),
  user(:owner?, record),
  flag(:force_access)
)
```

#### `all(*conditions)`

Same as `when_all` but can be nested.

```ruby
when_any(
  user(:admin?),
  all(
    user(:moderator?),
    record(:flagged?)
  )
)
```

#### `any(*conditions)`

Same as `when_any` but can be nested.

```ruby
when_all(
  any(user(:admin?), user(:moderator?)),
  record(:published?)
)
```

#### `not(condition)`

Negates a condition.

```ruby
when_all(
  user(:active?),
  not(user(:banned?))
)
```

### Reference Methods

#### `obj(key, *methods)`

References a fact from context and optionally calls methods.

```ruby
obj(:user, :admin?)
obj(:order, :total)
obj(:settings, :feature, :enabled?)
```

#### Shortcut Methods

Convenience methods for common references:

```ruby
# usr() - shorthand for obj(:user)
usr(:admin?)

# rec() - shorthand for obj(:record)
rec(:published?)

# doc() - shorthand for obj(:document)
doc(:approved?)
```

#### `flag(key)`

References a boolean flag from context.

```ruby
flag(:approval_required)
flag(:email_sent)
```

#### `lit(value)`

Creates a literal value reference.

```ruby
usr(:role).equals(lit("admin"))
order(:total).greater_than(lit(100))
```

## Action Methods

### Setting Values

#### `set(key, value)`

Sets a value in the context.

```ruby
action do
  set :discount, 0.15
  set :approved, true
  set :message, "Order processed"
end
```

#### Shorthand Methods

```ruby
action do
  # allow! sets a permission flag to true
  allow! :create
  allow! :update
  
  # deny! sets a permission flag to false
  deny! :delete
  deny! :export
end
```

### Method Calls

#### `call_method(object, method_name, *args)`

Calls a method on an object.

```ruby
action do
  order = context[:order]
  call_method(order, :apply_discount, 0.15)
  call_method(order, :add_note, "Discount applied")
end
```

### Context Access

Within action blocks, you have access to:

```ruby
action do
  # Direct context access
  user = context[:user]
  order = context[:order]
  
  # Set values
  set :total, order.total * (1 - discount)
  
  # Conditional logic
  if user.admin?
    set :expedited, true
  end
end
```

## Complete Example

```ruby
engine = Ruleur.define do
  # High priority rule
  rule "validate_user", salience: 100 do
    when_all(
      usr(:present),
      not(usr(:banned?))
    )
    action do
      set :user_valid, true
    end
  end
  
  # Permission rule
  rule "allow_edit", salience: 50, tags: [:permissions] do
    when_any(
      usr(:admin?),
      all(
        usr(:owner?, rec()),
        rec(:editable?),
        not(rec(:locked?))
      )
    )
    action do
      allow! :edit
      set :reason, "User has edit permissions"
    end
  end
  
  # Workflow rule with no_loop
  rule "process_order", salience: 10, no_loop: true do
    when_all(
      flag(:user_valid),
      flag(:update),
      record(:ready_to_process?)
    )
    action do
      order = context[:record]
      call_method(order, :process!)
      set :processed, true
      set :processed_at, Time.now
    end
  end
end

# Run the engine
result = engine.run(user: current_user, record: order)
puts result[:processed] # => true
```

## Advanced Patterns

### Dynamic Rule Creation

```ruby
def create_threshold_rule(name, threshold)
  rule name do
    when_all(order(:total).greater_than(lit(threshold)))
    action { set :tier, name }
  end
end

engine = Ruleur.define do
  create_threshold_rule("bronze", 100)
  create_threshold_rule("silver", 500)
  create_threshold_rule("gold", 1000)
end
```

### Nested Method Calls

```ruby
rule "premium_check" do
  when_all(
    usr(:subscription, :tier).equals("premium"),
    usr(:subscription, :active?),
    usr(:subscription, :expires_at).greater_than(lit(Date.today))
  )
  action do
    allow! :premium_features
  end
end
```

### Complex Conditionals in Actions

```ruby
rule "calculate_shipping" do
  when_all(flag(:order_valid))
  action do
    order = context[:order]
    total = order.total
    
    shipping = case
      when total > 100 then 0
      when total > 50 then 5
      else 10
    end
    
    set :shipping_cost, shipping
    set :free_shipping, shipping == 0
  end
end
```

## See Also

- [DSL Basics Guide](/guide/dsl-basics) - DSL patterns and usage
- [Condition](./condition) - Condition types
- [Operators](./operators) - Available operators
- [Rule](./rule) - Rule structure
