# DSL

The Ruleur Domain-Specific Language (DSL) provides a Ruby-friendly way to define rules with readable, composable syntax.

## Overview

The DSL consists of:
- **Engine Definition**: `Ruleur.define` block
- **Rule Definition**: `rule "name"` block
  - **Conditions**: use `match` with `all?()`, `any?()`, `not?()` builders
- **Actions**: `action` block with helper methods

## Engine Definition

### `Ruleur.define`

Creates an engine with rules defined in the block.

```ruby
engine = Ruleur.define do
  rule 'first_rule' do
    # ...
  end

  rule 'second_rule' do
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
rule 'example', salience: 10, tags: [:important], no_loop: true do
  match do
    all?(conditions)
  end
  execute do
    # action code here
  end
end
```

**Parameters:**
- `name` (String) - Unique rule identifier
- `options` (Hash) - Optional configuration
  - `salience` (Integer) - Priority (default: 0)
  - `tags` (Array\<Symbol\>) - Tags for categorization
  - `no_loop` (Boolean) - Prevent recordursive firing

## Condition Methods

### Composite Conditions

#### `all?(*conditions)`

All conditions must be true (AND). Wrap them in a `match` block in rules:

```ruby
match do
  all?(
    user(:admin?),
    record(:published?),
    not?(record(:archived?))
  )
end
```

#### `any?(*conditions)`

At least one condition must be true (OR). Wrap them in a `match` block in rules:

```ruby
match do
  any?(
    user(:admin?),
    user(:owner?, record),
    flag(:force_access)
  )
end
```

#### `all?(*conditions)`

Same as above but can be nested within `any`.

```ruby
match do
  any?(
    user(:admin?),
    all?(
      user(:moderator?),
      record(:flagged?)
    )
  )
end
```

#### `any?(*conditions)`

Same as above but can be nested within `all`.

```ruby
match do
  all?(
    any?(user(:admin?), user(:moderator?)),
    record(:published?)
  )
end
```

#### `not?(condition)`

Negates a condition inside a `match` block.

```ruby
match do
  all?(
    user(:active?),
    not?(user(:banned?))
  )
end
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
# user() - shorthand for obj(:user)
user(:admin?)

# record() - shorthand for obj(:record)
record(:published?)

# doc() - shorthand for obj(:document)
doc(:approved?)
```

#### `flag(key)`

References a boolean flag from context.

```ruby
flag(:approval_required)
flag(:email_sent)
```

#### `literal(value)`

Creates a literal value reference (use `literal(...)` instead of `lit`):

```ruby
user(:role).eq?(literal('admin'))
order(:total).gt?(literal(100))
```

## Action Methods

### Setting Values

#### `set(key, value)`

Sets a value in the context.

```ruby
execute do
  set :discount, 0.15
  set :approved, true
  set :message, 'Order processed'
end
```



### Method Calls

#### `call_method(object, method_name, *args)`

Calls a method on an object.

```ruby
execute do
  order = context[:order]
  call_method(order, :apply_discount, 0.15)
  call_method(order, :add_note, 'Discount applied')
end
```

### Context Access

Within action blocks, you have access to:

```ruby
execute do
  # Direcordt context access
  user = context[:user]
  order = context[:order]

  # Set values
  set :total, order.total * (1 - discount)

  # Conditional logic
  set :expedited, true if user.admin?
end
```

## Complete Example

```ruby
engine = Ruleur.define do
  # High priority rule
  rule 'validate_user', salience: 100 do
    match do
      all?(
        user(:present),
        not?(user(:banned?))
      )
    end
    execute do
      set :user_valid, true
    end
  end

  # Permission rule
  rule 'allow_edit', salience: 50, tags: [:permissions] do
    match do
      any?(
        user(:admin?),
        all?(
          user(:owner?, record),
          record(:editable?),
          not?(record(:locked?))
        )
      )
    end
    execute do
      set :edit, true
      set :reason, 'User has edit permissions'
    end
  end

  # Workflow rule with no_loop
  rule 'process_order', salience: 10, no_loop: true do
    match do
      all?(
        flag(:user_valid),
        flag(:update),
        recordord(:ready_to_process?)
      )
    end
    execute do
      order = context[:recordord]
      call_method(order, :process!)
      set :processed, true
      set :processed_at, Time.now
    end
  end
end

# Run the engine
result = engine.run(user: current_user, recordord: order)
puts result[:processed] # => true
```

## Advanced Patterns

### Dynamic Rule Creation

```ruby
def create_threshold_rule(name, threshold)
  rule name do
    match do
      all?(order(:total).gt?(literal(threshold)))
    end
    execute { set :tier, name }
  end
end

engine = Ruleur.define do
  create_threshold_rule('bronze', 100)
  create_threshold_rule('silver', 500)
  create_threshold_rule('gold', 1000)
end
```

### Nested Method Calls

```ruby
rule 'premium_check' do
  match do
    all?(
      user(:subscription, :tier).eq?('premium'),
      user(:subscription, :active?),
      user(:subscription, :expires_at).gt?(literal(Date.today))
    )
  end
  execute do
    set :premium_features, true
  end
end
```

### Complex Conditionals in Actions

```ruby
rule 'calculate_shipping' do
  match do
    all?(flag(:order_valid))
  end
  execute do
    order = context[:order]
    total = order.total

    shipping = if total > 100
                 0
               elsif total > 50
                 5
               else
                 10
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
