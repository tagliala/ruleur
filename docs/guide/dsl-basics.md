# DSL Basics

The Ruleur DSL provides a fluent, readable Ruby interface for defining business rules. It strikes a balance between expressiveness and safety, avoiding metaprogramming hazards while keeping the syntax clean.

## Quick Example

```ruby
require "ruleur"

engine = Ruleur.define do
  rule "admin_create", no_loop: true do
    match do
      any?(
        user(:admin?),
        all?(record(:updatable?), record(:draft?))
      )
    end

    execute do
      set :create, true
    end
  end
end

ctx = engine.run(record: record, user: user)
ctx[:create] # => true (if rule fired) or nil
```

With Ruleur, context values are only set when rules fire. If no rule matches, the value remains nil.

## Defining Engines

Use `Ruleur.define` to create an engine with rules:

```ruby
engine = Ruleur.define do
  rule "rule_name" do
    # conditions
    # actions
  end

  rule "another_rule", salience: 10 do
    # ...
  end
end
```

## Defining Rules

Each rule has:
- **Name**: A unique identifier (string or symbol)
- **Conditions**: When the rule should fire
- **Actions**: What the rule does when it fires
- **Options**: salience, tags, no_loop (optional)

### Basic Structure

```ruby
rule "rule_name", salience: 10, tags: ['permissions'], no_loop: true do
  match do
    all?(
      # conditions go here
    )
  end

  execute do
    set :create, true
  end
end
```

### Rule Options

- **`salience`**: Priority (higher = fires first). Default: 0
- **`tags`**: Array of strings for categorization. Default: []
- **`no_loop`**: Prevent rule from firing twice in same execution. Default: false

```ruby
rule "high_priority", salience: 100 do
  # This rule fires before others
end

rule "admin_crud", tags: ['permissions', 'admin'] do
  # Tagged for organization
end

rule "once_only", no_loop: true do
  # Won't fire again even if conditions remain true
end
```

## DSL Shortcuts

Ruleur provides convenient helper methods to keep your rules readable.

### `record(method_name)` - Record Method Check

Checks if a method on the `record` returns truthy:

```ruby
record(:admin?)       # => truthy?(record.admin?)
record(:published?)   # => truthy?(record.published?)
```

::: tip
`record(method)` is shorthand for `truthy?(ref(:record).call(method))`. The `truthy` operator checks if the value is not `nil` or `false`.
:::

### `user(method_name)` - User Method Check

Checks if a method on the `user` returns truthy:

```ruby
user(:admin?)       # => truthy?(user.admin?)
user(:verified?)    # => truthy?(user.verified?)
:::

### `record_value(method_name)` - Record Value Reference

Gets the actual value (not truthy check) from a record method:

```ruby
eq?(record_value(:age), 18)
includes(literal(['draft', 'pending']), record_value(:status))
```

### `user_value(method_name)` - User Value Reference

Gets the actual value from a user method:

```ruby
eq?(user_value(:role), 'admin')
gte(user_value(:subscription_level), 3)
```

### `flag(name)` - Context Flag Check

Checks if a flag was set by another rule:

```ruby
flag(:create)  # => truthy?(:create)
flag(:update)  # => truthy?(:update)
```

This is useful for chaining rules - one rule sets `:create`, another checks it:

```ruby
rule "admin_create" do
  match do
    any?(user(:admin?))
  end

  execute do
    set :create, true
  end
end

rule "draft_update" do
  match do
    all?(
      flag(:create),
      record(:draft?)
    )
  end

  execute do
    set :update, true
  end
end
```

## Conditions

Conditions determine when a rule fires. Use `match` with `all`/`any` builders or the legacy `when_all`/`when_any` helpers.

### `when_all` - All Conditions Must Be True

```ruby
rule "admin_update" do
  match do
    all?(
      user(:admin?),
      record(:published?),
      not?(record(:locked?))
    )
  end

  execute do
    set :update, true
  end
end
```

All conditions must be truthy for the rule to fire.

### `when_any` - At Least One Condition True

```ruby
rule "editor_show" do
  match do
    any?(
      user(:admin?),
      record(:public?),
      eq?(record_value(:owner_id), user_value(:id))
    )
  end

  execute do
    set :show, true
  end
end
```

If any condition is truthy, the rule fires.

### Nesting Conditions

You can nest `all` and `any` within `when_all` or `when_any`:

```ruby
rule "editor_update" do
  match do
    all?(
      any?(
        user(:admin?),
        user(:editor?)
      ),
      all?(
        record(:published?),
        not?(record(:archived?))
      )
    )
  end

  execute do
    set :update, true
  end
end
```

### Using Operators

For more complex comparisons, use operators directly:

```ruby
rule "premium_purchase" do
  match do
    all?(
      gte(record_value(:age), 18),
      eq?(record_value(:country), 'US'),
      includes(literal(['active', 'trial']), record_value(:status))
    )
  end
  execute do
    set :purchase, true
  end
end
```

See [Operators](./operators.md) for a complete list.

## Actions

Actions define what happens when a rule fires. Use the `set` method or `action` block.

### `set(key, value)` - Set a Context Value

```ruby
rule "set_discount" do
  match do
    all?(user(:premium?))
  end
  execute do
    set :discount, 0.20
  end
end
```

### `assert(hash)` - Set Multiple Values

```ruby
rule "set_defaults" do
  match do
    all?(record(:new?))
  end
  execute do
    assert(
      status: 'draft',
      priority: 'low',
      assignee: nil
    )
  end
end
```

### Custom Action Block

For more complex logic, use an `action` block:

```ruby
rule "calculate_total" do
  match do
    all?(record(:items))
  end
  execute do |ctx|
    items = ctx[:record].items
    total = items.sum(&:price)
    tax = total * 0.1
    ctx[:total] = total
    ctx[:tax] = tax
  end
end
```

::: tip
The `action` method provides a block for executing code:

```ruby
rule "apply_discount" do
  match do
    all?(user(:premium?))
  end
  execute do |ctx|
    ctx[:discount] = 0.20
  end
end
```
:::

## Context Variables

The execution context holds all facts and values during rule evaluation:

```ruby
ctx = engine.run(
  record: my_record,
  user: current_user,
  custom_value: 123
)

ctx[:record]       # => my_record
ctx[:user]         # => current_user
ctx[:custom_value] # => 123

ctx[:update] # => true (if rule fired) or nil (denied)
ctx[:discount]     # => 0.20 (if rule set it)
```

Rules can reference any context key using `ref`:

```ruby
rule "check_custom" do
  match do
    all?(
      eq?(ref(:custom_value), 123)
    )
  end
  execute do
    set :custom_check, true
  end
end
```

## Complete Example

Here's a real-world permission system:

```ruby
require "ruleur"

Document = Struct.new(:status, :owner_id, :locked) do
  def draft? = status == 'draft'
  def published? = status == 'published'
  def locked? = !!locked
end

User = Struct.new(:id, :role) do
  def admin? = role == 'admin'
  def editor? = role == 'editor'
end

engine = Ruleur.define do
  rule "admin_crud", salience: 100 do
    match do
      all?(user(:admin?))
    end
    execute do
      set :create, true
      set :show, true
      set :update, true
      set :destroy, true
    end
  end

  rule "editor_create_update", salience: 50 do
    match do
      all?(
        user(:editor?),
        record(:draft?)
      )
    end
    execute do
      set :create, true
      set :update, true
    end
  end

  rule "owner_update" do
    match do
      all?(
        record(:draft?),
        not?(record(:locked?)),
        eq?(record_value(:owner_id), user_value(:id))
      )
    end
    execute do
      set :update, true
    end
  end

  rule "editor_published_update" do
    match do
      all?(
        record(:published?),
        any?(user(:admin?), user(:editor?))
      )
    end
    execute do
      set :update, true
    end
  end
end

doc = Document.new('draft', 123, false)
user = User.new(123, 'user')

ctx = engine.run(record: doc, user: user)

puts ctx[:create]  # => true (editor can create drafts)
puts ctx[:update]  # => true (owner can update own draft)
puts ctx[:destroy] # => nil (no permission)
```

## Best Practices

### 1. Use Descriptive Names

```ruby
rule "admin_destroy" do
  # ...
end

rule "user_destroy" do
  # ...
end
```

### 2. Keep Rules Focused

Each rule should have a single responsibility:

```ruby
rule "admin_create" do
  match do
    all?(user(:admin?))
  end
  execute do
    set :create, true
  end
end

rule "verified_user_create" do
  match do
    all?(user(:verified?))
  end
  execute do
    set :create, true
  end
end
```

### 3. Use Salience for Priority

Higher salience rules fire first:

```ruby
rule "set_default_discount", salience: 0 do
  execute do
    set :discount, 0.0
  end
end

rule "apply_premium_discount", salience: 10 do
  match do
    all?(user(:premium?))
  end
  execute do
    set :discount, 0.15
  end
end

rule "apply_vip_discount", salience: 20 do
  match do
    all?(user(:vip?))
  end
  execute do
    set :discount, 0.30
  end
end
```

### 4. Use `no_loop` to Prevent Infinite Firing

If a rule's action could make its own condition true again, use `no_loop`:

```ruby
rule "increment_counter", no_loop: true do
  match do
    all?(lt(ref(:counter), 100))
  end
  execute do |ctx|
    ctx[:counter] = (ctx[:counter] || 0) + 1
  end
end
```

### 6. Tag Rules for Organization

```ruby
rule "admin_create", tags: ['permissions', 'admin'] do
  set :create, true
end

rule "editor_update", tags: ['permissions', 'editor'] do
  set :update, true
end

engine.rules_with_tag('admin')
```

## Next Steps

- **[Conditions](./conditions.md)**: Deep dive into composable conditions
- **[Operators](./operators.md)**: Complete list of comparison operators
- **[YAML Rules](./yaml-rules.md)**: Define rules in YAML for database storage
- **[Validation](./validation.md)**: Validate rules before execution

## Related API

- [Ruleur::DSL Module](../api/dsl.md)
- [Ruleur::Rule Class](../api/rule.md)
- [Ruleur::Context Class](../api/context.md)
