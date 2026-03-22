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
  conditions do
    all?(conditions)
  end
  actions do
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
conditions do
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
conditions do
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
conditions do
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
conditions do
  all?(
    any?(user(:admin?), user(:moderator?)),
    record(:published?)
  )
end
```

#### `not?(condition)`

Negates a condition inside a `match` block.

```ruby
conditions do
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
actions do
  set :discount, 0.15
  set :approved, true
  set :message, 'Order processed'
end
```



### Method Calls

#### `call_method(object, method_name, *args)`

Calls a method on an object.

```ruby
actions do
  order = context[:order]
  call_method(order, :apply_discount, 0.15)
  call_method(order, :add_note, 'Discount applied')
end
```

### Context Access

Within action blocks, you have access to:

```ruby
actions do
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
    conditions do
      all?(
        user(:present),
        not?(user(:banned?))
      )
    end
    actions do
      set :user_valid, true
    end
  end

  # Permission rule
  rule 'allow_edit', salience: 50, tags: [:permissions] do
    conditions do
      any?(
        user(:admin?),
        all?(
          user(:owner?, record),
          record(:editable?),
          not?(record(:locked?))
        )
      )
    end
    actions do
      set :edit, true
      set :reason, 'User has edit permissions'
    end
  end

  # Workflow rule with no_loop
  rule 'process_order', salience: 10, no_loop: true do
    conditions do
      all?(
        flag(:user_valid),
        flag(:update),
        recordord(:ready_to_process?)
      )
    end
    actions do
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
    conditions do
      all?(order(:total).gt?(literal(threshold)))
    end
    actions { set :tier, name }
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
  conditions do
    all?(
      user(:subscription, :tier).eq?('premium'),
      user(:subscription, :active?),
      user(:subscription, :expires_at).gt?(literal(Date.today))
    )
  end
  actions do
    set :premium_features, true
  end
end
```

### Complex Conditionals in Actions

```ruby
rule 'calculate_shipping' do
  conditions do
    all?(flag(:order_valid))
  end
  actions do
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
