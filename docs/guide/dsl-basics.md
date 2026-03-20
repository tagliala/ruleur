# DSL Basics

The Ruleur DSL provides a fluent, readable Ruby interface for defining business rules. It strikes a balance between expressiveness and safety, avoiding metaprogramming hazards while keeping the syntax clean.

## Quick Example

```ruby
require "ruleur"

engine = Ruleur.define do
  rule "allow_create", no_loop: true do
    when_any(
      usr(:admin?),
      all(rec(:updatable?), rec(:draft?))
    )
    action { allow! :create }
  end
end

ctx = engine.run(record: record, user: user)
ctx[:allow_create] # => true or false
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

The block is evaluated in the context of an `EngineBuilder`, which provides the `rule` method.

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
  action do
    # actions go here
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

rule "categorized", tags: ['permissions', 'admin'] do
  # Tagged for organization
end

rule "once_only", no_loop: true do
  # Won't fire again even if conditions remain true
end
```

## DSL Shortcuts

Ruleur provides convenient helper methods to keep your rules readable:

### `rec(method_name)` - Record Method Check

Checks if a method on the `record` returns truthy:

```ruby
rec(:admin?)       # => truthy(record.admin?)
rec(:published?)   # => truthy(record.published?)
```

::: tip
`rec(method)` is shorthand for `truthy(ref(:record).call(method))`. The `truthy` operator checks if the value is not `nil` or `false`.
:::

### `usr(method_name)` - User Method Check

Checks if a method on the `user` returns truthy:

```ruby
usr(:admin?)       # => truthy(user.admin?)
usr(:verified?)    # => truthy(user.verified?)
```

### `rec_val(method_name)` - Record Value Reference

Gets the actual value (not truthy check) from a record method:

```ruby
# Compare record's age directly
eq(rec_val(:age), 18)

# Check if record's status is in a list
includes(lit(['draft', 'pending']), rec_val(:status))
```

### `usr_val(method_name)` - User Value Reference

Gets the actual value from a user method:

```ruby
# Compare user's role
eq(usr_val(:role), 'admin')

# Check user's subscription level
gte(usr_val(:subscription_level), 3)
```

### `flag(name)` - Permission Flag Check

Checks if a permission flag was set by another rule:

```ruby
flag(:create)  # => truthy(:allow_create)
flag(:update)  # => truthy(:allow_update)
```

This is useful for chaining rules - one rule sets `:allow_create`, another checks it:

```ruby
rule "allow_create" do
  when_any(usr(:admin?))
  allow! :create  # Sets :allow_create => true
end

rule "allow_update" do
  when_all(
    flag(:create),  # Checks :allow_create flag
    rec(:draft?)
  )
  allow! :update
end
```

### `allow!(name)` - Set Permission Flag

Convenience method to set a permission flag:

```ruby
allow! :create   # Sets :allow_create => true
allow! :update   # Sets :allow_update => true
allow! :delete   # Sets :allow_delete => true
```

This is equivalent to `set(:allow_create, true)` but more readable for permission rules.

## Conditions

Conditions determine when a rule fires. Use `when_all`, `when_any`, or `when_predicate`.

### `when_all` - All Conditions Must Be True

```ruby
rule "restricted_update" do
  when_all(
    usr(:admin?),
    rec(:published?),
    rec(:locked?)
  )
  allow! :update
end
```

All conditions must be truthy for the rule to fire.

### `when_any` - At Least One Condition True

```ruby
rule "can_view" do
  when_any(
    usr(:admin?),
    rec(:public?),
    rec(:owner_id) == ctx[:user].id
  )
  allow! :view
end
```

If any condition is truthy, the rule fires.

### Nesting Conditions

You can nest `all` and `any` within `when_all` or `when_any`:

```ruby
rule "complex_permission" do
  when_all(
    any(
      usr(:admin?),
      usr(:moderator?)
    ),
    all(
      rec(:published?),
      not_(rec(:archived?))
    )
  )
  allow! :edit
end
```

This reads as: "Allow edit if (user is admin OR moderator) AND (record is published AND NOT archived)"

### Using Operators

For more complex comparisons, use operators directly:

```ruby
rule "age_check" do
  when_all(
    gte(rec_val(:age), 18),           # age >= 18
    eq(rec_val(:country), 'US'),      # country == 'US'
    includes(lit(['active', 'trial']), rec_val(:status))
  )
  allow! :purchase
end
```

See [Operators](./operators.md) for a complete list.

## Actions

Actions define what happens when a rule fires. Use the `action` block or helper methods.

### `set(key, value)` - Set a Context Value

```ruby
rule "set_discount" do
  when_all(usr(:premium?))
  set :discount, 0.20  # Set discount to 20%
end
```

### `assert(hash)` - Set Multiple Values

```ruby
rule "set_defaults" do
  when_all(rec(:new?))
  assert(
    status: 'draft',
    priority: 'low',
    assignee: nil
  )
end
```

### `allow!(name)` - Set Permission Flag

```ruby
rule "admin_permissions" do
  when_all(usr(:admin?))
  action do
    allow! :create
    allow! :update
    allow! :delete
  end
end
```

### Custom Action Block

For more complex logic, use an `action` block:

```ruby
rule "calculate_total" do
  when_all(rec(:items))
  action do |ctx|
    items = ctx[:record].items
    total = items.sum(&:price)
    tax = total * 0.1
    ctx[:total] = total
    ctx[:tax] = tax
    ctx[:grand_total] = total + tax
  end
end
```

The block receives the context as an argument and can read/write any values.

::: tip
The `action` method can also be written as `then` for readability:

```ruby
rule "apply_discount" do
  when_all(usr(:premium?))
  then do |ctx|
    ctx[:discount] = 0.20
  end
end
```
:::

## Context Variables

The execution context holds all facts and values during rule evaluation:

```ruby
# Initial context
ctx = engine.run(
  record: my_record,
  user: current_user,
  custom_value: 123
)

# Access values
ctx[:record]       # => my_record
ctx[:user]         # => current_user
ctx[:custom_value] # => 123

# Values set by rules
ctx[:allow_create] # => true (if rule fired)
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
  # Admins can do everything
  rule "admin_full_access", salience: 100 do
    when_all(usr(:admin?))
    action do
      allow! :create
      allow! :update
      allow! :delete
      allow! :publish
    end
  end
  
  # Editors can create and update drafts
  rule "editor_draft_access", salience: 50 do
    when_all(
      usr(:editor?),
      rec(:draft?)
    )
    action do
      allow! :create
      allow! :update
    end
  end
  
  # Owners can update their own drafts (not locked)
  rule "owner_update_draft" do
    when_all(
      rec(:draft?),
      not_(rec(:locked?)),
      eq(rec_val(:owner_id), usr_val(:id))
    )
    allow! :update
  end
  
  # Published documents can only be updated by admins or editors
  rule "published_restricted" do
    when_all(
      rec(:published?),
      any(usr(:admin?), usr(:editor?))
    )
    allow! :update
  end
end

# Test the rules
doc = Document.new('draft', 123, false)
user = User.new(123, 'user')

ctx = engine.run(record: doc, user: user)

puts ctx[:allow_create] # => nil (no permission)
puts ctx[:allow_update] # => true (owner can update own draft)
puts ctx[:allow_delete] # => nil (no permission)
```

## Best Practices

### 1. Use Descriptive Names

```ruby
# Good
rule "admin_can_delete_any_post" do
  # ...
end

# Less clear
rule "delete_rule_1" do
  # ...
end
```

### 2. Keep Rules Focused

Each rule should have a single responsibility:

```ruby
# Good - separate concerns
rule "allow_create_if_admin" do
  when_all(usr(:admin?))
  allow! :create
end

rule "allow_create_if_verified_user" do
  when_all(usr(:verified?))
  allow! :create
end

# Less clear - mixed concerns
rule "allow_create" do
  when_any(usr(:admin?), usr(:verified?), usr(:premium?))
  action do
    allow! :create
    allow! :update  # Different action mixed in
    set :created_by, usr_val(:id)  # Side effect
  end
end
```

### 3. Use Salience for Priority

Higher salience rules fire first:

```ruby
rule "set_defaults", salience: 0 do
  set :discount, 0.0
end

rule "apply_premium_discount", salience: 10 do
  when_all(usr(:premium?))
  set :discount, 0.15
end

rule "apply_vip_discount", salience: 20 do
  when_all(usr(:vip?))
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

### 5. Tag Rules for Organization

```ruby
rule "admin_create", tags: ['permissions', 'admin'] do
  # ...
end

rule "editor_update", tags: ['permissions', 'editor'] do
  # ...
end

# Filter by tag (future feature)
# engine.rules_with_tag('admin')
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
