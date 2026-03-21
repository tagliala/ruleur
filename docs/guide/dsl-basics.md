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
    allow! :create
  end
end

ctx = engine.run(record: record, user: user)
ctx[:create] # => true or nil
```

## Security Principle: Deny by Default

> *"The default rule should always be: deny access unless explicitly permitted."*
> — [OWASP Access Control](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/)

With Ruleur, you only define **when access is granted**. If no rule sets a permission flag, access is implicitly denied.

```ruby
engine = Ruleur.define do
  rule "admin_update" do
    when_all(user(:admin?))
    allow! :update
  end
  # No rule for guest? => access denied by default
end

ctx = engine.run(user: guest, record: doc)
ctx[:update]  # => nil (denied)
```

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
  allow! :create
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

### `record_val(method_name)` - Record Value Reference

Gets the actual value (not truthy check) from a record method:

```ruby
eq(record_val(:age), 18)
includes(lit(['draft', 'pending']), record_val(:status))
```

### `user_val(method_name)` - User Value Reference

Gets the actual value from a user method:

```ruby
eq(user_val(:role), 'admin')
gte(user_val(:subscription_level), 3)
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
  allow! :create
end

rule "draft_update" do
  when_all(
    flag(:create),
    record(:draft?)
  )
  allow! :update
end
```

### `allow!(name)` - Grant Permission

Convenience method to grant a permission:

```ruby
allow! :create
allow! :update
allow! :destroy
```

This is equivalent to `set(:create, true)` but more readable.

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
  allow! :update
end
```

All conditions must be truthy for the rule to fire.

### `when_any` - At Least One Condition True

```ruby
rule "editor_show" do
  when_any(
    user(:admin?),
    record(:public?),
    eq(record_val(:owner_id), user_val(:id))
  )
  allow! :show
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
  allow! :update
end
```

### Using Operators

For more complex comparisons, use operators directly:

```ruby
rule "premium_purchase" do
  when_all(
    gte(record_val(:age), 18),
    eq(record_val(:country), 'US'),
    includes(lit(['active', 'trial']), record_val(:status))
  )
  allow! :purchase
end
```

See [Operators](./operators.md) for a complete list.

## Actions

Actions define what happens when a rule fires. Use the `allow!` helper or `action` block.

### `allow!(name)` - Grant Permission

```ruby
rule "admin_crud" do
  when_all(user(:admin?))
  allow! :create
  allow! :show
  allow! :update
  allow! :destroy
end
```

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
The `action` method can also be written as `then` for readability:

```ruby
rule "apply_discount" do
  when_all(user(:premium?))
  then do |ctx|
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
    eq(ref(:custom_value), 123)
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
    allow! :create
    allow! :show
    allow! :update
    allow! :destroy
  end

  rule "editor_create_update", salience: 50 do
    when_all(
      user(:editor?),
      record(:draft?)
    )
    allow! :create
    allow! :update
  end

  rule "owner_update" do
    when_all(
      record(:draft?),
      not(record(:locked?)),
      eq(record_val(:owner_id), user_val(:id))
    )
    allow! :update
  end

  rule "editor_published_update" do
    when_all(
      record(:published?),
      any(user(:admin?), user(:editor?))
    )
    allow! :update
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

### 1. Deny by Default

Never explicitly deny in rules. Only grant when conditions are met:

```ruby
# Bad: Explicit deny
rule "deny_guests" do
  when_all(not(user(:authenticated?)))
  set :update, false
end

# Good: Only grant when appropriate
rule "auth_update" do
  when_all(user(:authenticated?))
  allow! :update
end
```

### 2. Use Descriptive Names

```ruby
rule "admin_destroy" do
  # ...
end

rule "user_destroy" do
  # ...
end
```

### 3. Keep Rules Focused

Each rule should have a single responsibility:

```ruby
rule "admin_create" do
  when_all(user(:admin?))
  allow! :create
end

rule "verified_user_create" do
  when_all(user(:verified?))
  allow! :create
end
```

### 4. Use Salience for Priority

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

### 5. Use `no_loop` to Prevent Infinite Firing

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
  allow! :create
end

rule "editor_update", tags: ['permissions', 'editor'] do
  allow! :update
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
