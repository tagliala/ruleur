# DSL Basics

The Ruleur DSL provides a fluent, readable Ruby interface for defining business rules. It strikes a balance between expressiveness and safety, avoiding metaprogramming hazards while keeping the syntax clean.

## Quick Example

```ruby
require "ruleur"

engine = Ruleur.define do
  rule "admin_create", no_loop: true do
    when_any(
      user(:admin?),
      all(record(:updatable?), record(:draft?))
    )
    set :create, true
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
  when_all(
    # conditions go here
  )
  set :create, true
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
record(:admin?)       # => truthy(record.admin?)
record(:published?)   # => truthy(record.published?)
```

::: tip
`record(method)` is shorthand for `truthy(ref(:record).call(method))`. The `truthy` operator checks if the value is not `nil` or `false`.
:::

### `user(method_name)` - User Method Check

Checks if a method on the `user` returns truthy:

```ruby
user(:admin?)       # => truthy(user.admin?)
user(:verified?)    # => truthy(user.verified?)
:::

### `record_value(method_name)` - Record Value Reference

Gets the actual value (not truthy check) from a record method:

```ruby
equals(record_value(:age), 18)
includes(lit(['draft', 'pending']), record_value(:status))
```

### `user_value(method_name)` - User Value Reference

Gets the actual value from a user method:

```ruby
equals(user_value(:role), 'admin')
gte(user_value(:subscription_level), 3)
```

### `flag(name)` - Context Flag Check

Checks if a flag was set by another rule:

```ruby
flag(:create)  # => truthy(:create)
flag(:update)  # => truthy(:update)
```

This is useful for chaining rules - one rule sets `:create`, another checks it:

```ruby
rule "admin_create" do
  when_any(user(:admin?))
  set :create, true
end

rule "draft_update" do
  when_all(
    flag(:create),
    record(:draft?)
  )
  set :update, true
end
```

## Conditions

Conditions determine when a rule fires. Use `when_all`, `when_any`, or `when_predicate`.

### `when_all` - All Conditions Must Be True

```ruby
rule "admin_update" do
  when_all(
    user(:admin?),
    record(:published?),
    not(record(:locked?))
  )
  set :update, true
end
```

All conditions must be truthy for the rule to fire.

### `when_any` - At Least One Condition True

```ruby
rule "editor_show" do
  when_any(
    user(:admin?),
    record(:public?),
    equals(record_value(:owner_id), user_value(:id))
  )
  set :show, true
end
```

If any condition is truthy, the rule fires.

### Nesting Conditions

You can nest `all` and `any` within `when_all` or `when_any`:

```ruby
rule "editor_update" do
  when_all(
    any(
      user(:admin?),
      user(:editor?)
    ),
    all(
      record(:published?),
      not(record(:archived?))
    )
  )
  set :update, true
end
```

### Using Operators

For more complex comparisons, use operators directly:

```ruby
rule "premium_purchase" do
  when_all(
    gte(record_value(:age), 18),
    equals(record_value(:country), 'US'),
    includes(lit(['active', 'trial']), record_value(:status))
  )
  set :purchase, true
end
```

See [Operators](./operators.md) for a complete list.

## Actions

Actions define what happens when a rule fires. Use the `set` method or `action` block.

### `set(key, value)` - Set a Context Value

```ruby
rule "set_discount" do
  when_all(user(:premium?))
  set :discount, 0.20
end
```

### `assert(hash)` - Set Multiple Values

```ruby
rule "set_defaults" do
  when_all(record(:new?))
  assert(
    status: 'draft',
    priority: 'low',
    assignee: nil
  )
end
```

### Custom Action Block

For more complex logic, use an `action` block:

```ruby
rule "calculate_total" do
  when_all(record(:items))
  action do |ctx|
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
  when_all(user(:premium?))
  action do |ctx|
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
  when_all(
    equals(ref(:custom_value), 123)
  )
  set :custom_check, true
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
    when_all(user(:admin?))
    set :create, true
    set :show, true
    set :update, true
    set :destroy, true
  end

  rule "editor_create_update", salience: 50 do
    when_all(
      user(:editor?),
      record(:draft?)
    )
    set :create, true
    set :update, true
  end

  rule "owner_update" do
    when_all(
      record(:draft?),
      not(record(:locked?)),
      equals(record_value(:owner_id), user_value(:id))
    )
    set :update, true
  end

  rule "editor_published_update" do
    when_all(
      record(:published?),
      any(user(:admin?), user(:editor?))
    )
    set :update, true
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
  when_all(user(:admin?))
  set :create, true
end

rule "verified_user_create" do
  when_all(user(:verified?))
  set :create, true
end
```

### 3. Use Salience for Priority

Higher salience rules fire first:

```ruby
rule "set_default_discount", salience: 0 do
  set :discount, 0.0
end

rule "apply_premium_discount", salience: 10 do
  when_all(user(:premium?))
  set :discount, 0.15
end

rule "apply_vip_discount", salience: 20 do
  when_all(user(:vip?))
  set :discount, 0.30
end
```

### 4. Use `no_loop` to Prevent Infinite Firing

If a rule's action could make its own condition true again, use `no_loop`:

```ruby
rule "increment_counter", no_loop: true do
  when_all(lt(ref(:counter), 100))
  action do |ctx|
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
