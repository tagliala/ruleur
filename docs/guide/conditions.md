# Composable Conditions

Conditions are the heart of Ruleur's rule system. They determine when rules fire by evaluating boolean expressions against your application's data. Ruleur's condition system is built on composable nodes that can be nested arbitrarily deep.

## Condition Types

Ruleur provides five core condition types:

1. **Predicate** - Compares two values using an operator
2. **All** - Logical AND - all children must be true
3. **Any** - Logical OR - at least one child must be true
4. **Not** - Logical NOT - negates the child
5. **BlockPredicate** - Custom Ruby code (advanced)

## Predicates

A **predicate** is the basic building block - it compares two values using an operator.

### Basic Predicate

```ruby
rule "adult_check" do
  when_all(
    gte(rec_val(:age), 18)  # Predicate: record.age >= 18
  )
  allow! :access
end
```

The predicate has three parts:
- **Left value**: `rec_val(:age)` - the value to test
- **Operator**: `gte` - greater than or equal
- **Right value**: `18` - the comparison value

### Predicate Anatomy

```ruby
# eq(left, right)
#  ^  ^     ^
#  |  |     +-- Right value (comparison value)
#  |  +-------- Left value (value to test)
#  +----------- Operator

eq(rec_val(:status), "published")
```

### Common Predicates

```ruby
# Equality
eq(rec_val(:status), "active")
ne(rec_val(:status), "archived")

# Numeric comparison
gt(rec_val(:age), 21)
gte(rec_val(:age), 18)
lt(rec_val(:price), 100)
lte(rec_val(:stock), 5)

# Collection membership
in(rec_val(:status), lit(['draft', 'pending']))
includes(rec_val(:roles), 'admin')

# Pattern matching
matches(rec_val(:email), lit(/@example\.com$/))

# Truthiness
truthy(rec(:published?))
falsy(rec(:locked?))
present(rec_val(:name))
blank(rec_val(:description))
```

See [Operators](./operators.md) for a complete list.

## Composite Conditions

Composite conditions combine multiple conditions using logical operators.

### All - Logical AND

The `all` condition evaluates to true only if **all** children are true.

```ruby
rule "restricted_access" do
  when_all(
    all(
      usr(:verified?),
      usr(:premium?),
      gte(rec_val(:age), 21)
    )
  )
  allow! :vip_access
end
```

This rule fires only when:
- User is verified **AND**
- User is premium **AND**
- Record age >= 21

::: tip
`when_all` is a shorthand for wrapping conditions in `all`. These are equivalent:

```ruby
# Using when_all (preferred)
when_all(
  usr(:verified?),
  usr(:premium?)
)

# Using all explicitly
when_all(
  all(
    usr(:verified?),
    usr(:premium?)
  )
)
```
:::

### Any - Logical OR

The `any` condition evaluates to true if **at least one** child is true.

```ruby
rule "can_edit" do
  when_any(
    usr(:admin?),
    usr(:editor?),
    eq(rec_val(:owner_id), usr_val(:id))
  )
  allow! :edit
end
```

This rule fires when:
- User is admin **OR**
- User is editor **OR**
- User is the owner

### Not - Logical Negation

The `not_` condition inverts the result of its child.

```ruby
rule "not_archived" do
  when_all(
    not_(rec(:archived?))
  )
  allow! :view
end
```

::: warning
Note the underscore: Use `not_` (with underscore) in Ruby DSL because `not` is a reserved keyword.
:::

## Nesting Conditions

The real power comes from nesting conditions to express complex logic.

### Example 1: OR within AND

"Allow update if user is admin OR (user is owner AND document is draft)"

```ruby
rule "complex_update" do
  when_all(
    any(
      usr(:admin?),
      all(
        eq(rec_val(:owner_id), usr_val(:id)),
        rec(:draft?)
      )
    )
  )
  allow! :update
end
```

### Example 2: AND within OR

"Allow view if (document is public) OR (user is logged in AND document is not archived)"

```ruby
rule "complex_view" do
  when_any(
    rec(:public?),
    all(
      usr(:logged_in?),
      not_(rec(:archived?))
    )
  )
  allow! :view
end
```

### Example 3: Deep Nesting

"Allow publish if user is admin OR (user is editor AND document is complete AND either urgent or user is senior)"

```ruby
rule "publish_permission" do
  when_any(
    usr(:admin?),
    all(
      usr(:editor?),
      rec(:complete?),
      any(
        rec(:urgent?),
        usr(:senior?)
      )
    )
  )
  allow! :publish
end
```

## Using Operators in DSL

### Method 1: DSL Shortcuts (Recommended)

For simple truthy checks, use the DSL helpers:

```ruby
rule "simple" do
  when_all(
    usr(:admin?),      # Checks user.admin? is truthy
    rec(:published?)   # Checks record.published? is truthy
  )
end
```

### Method 2: Explicit Operators

For comparisons and complex checks:

```ruby
rule "explicit" do
  when_all(
    gte(rec_val(:age), 18),
    in(rec_val(:status), lit(['active', 'trial']))
  )
end
```

### Method 3: Mixed

Combine both approaches:

```ruby
rule "mixed" do
  when_all(
    usr(:verified?),                    # Shortcut
    gte(rec_val(:subscription_level), 3), # Explicit
    not_(rec(:banned?))                 # Shortcut with negation
  )
end
```

## Boolean Operators

Condition nodes support Ruby's boolean operators for composing conditions:

### `&` - AND Operator

```ruby
condition = usr(:admin?) & rec(:published?)

# Equivalent to:
condition = all(usr(:admin?), rec(:published?))
```

### `|` - OR Operator

```ruby
condition = usr(:admin?) | usr(:editor?)

# Equivalent to:
condition = any(usr(:admin?), usr(:editor?))
```

### `!` - NOT Operator

```ruby
condition = !rec(:archived?)

# Equivalent to:
condition = not_(rec(:archived?))
```

### Combining Operators

```ruby
# Complex expression
condition = (usr(:admin?) | usr(:editor?)) & !rec(:archived?)

# Equivalent to:
condition = all(
  any(usr(:admin?), usr(:editor?)),
  not_(rec(:archived?))
)
```

::: tip
Use parentheses to control precedence when combining operators:

```ruby
# With parentheses (correct)
(a | b) & c  # => (a OR b) AND c

# Without parentheses (may not be what you want)
a | b & c    # => a OR (b AND c)  [& has higher precedence]
```
:::

## Value References

Conditions operate on **values** from the execution context.

### Literal Values

Use `lit()` to reference constant values:

```ruby
eq(rec_val(:status), "published")  # "published" is auto-wrapped in lit()
in(rec_val(:role), lit(['admin', 'editor']))  # Explicit lit() for array
```

### Context References

Use `ref()` to reference context keys:

```ruby
ref(:user)           # => ctx[:user]
ref(:record, :id)    # => ctx[:record].id
ref(:custom_value)   # => ctx[:custom_value]
```

### Method Calls

Use `call()` to invoke methods:

```ruby
call(ref(:user), :admin?)        # => ctx[:user].admin?
call(ref(:record), :price)       # => ctx[:record].price
```

### Helper Shortcuts

The DSL provides shortcuts for common patterns:

```ruby
rec(:published?)     # => call(ref(:record), :published?)
usr(:admin?)         # => call(ref(:user), :admin?)
rec_val(:age)        # => call(ref(:record), :age)
usr_val(:id)         # => call(ref(:user), :id)
```

## Custom Conditions with Blocks

For complex logic that doesn't fit the operator model, use `predicate` blocks:

```ruby
rule "custom_logic" do
  when_all(
    predicate do |ctx|
      user = ctx[:user]
      record = ctx[:record]

      # Custom logic
      user.credits > record.cost &&
      user.last_purchase_at < 7.days.ago
    end
  )
  allow! :purchase
end
```

::: warning Serialization Limitation
Block predicates **cannot** be serialized to YAML. Only use them for rules that will stay in code, not stored in databases.
:::

## Condition Evaluation

Conditions are evaluated lazily when the engine runs:

```ruby
ctx = engine.run(record: my_record, user: current_user)
```

### Evaluation Order

1. **All**: Evaluates children left-to-right, short-circuits on first `false`
2. **Any**: Evaluates children left-to-right, short-circuits on first `true`
3. **Not**: Evaluates child, inverts result
4. **Predicate**: Resolves left/right values, applies operator

### Short-Circuiting

Composite conditions short-circuit for efficiency:

```ruby
when_all(
  expensive_check(),   # Evaluated first
  cheap_check()        # Not evaluated if expensive_check() returns false
)

when_any(
  cheap_check(),       # Evaluated first
  expensive_check()    # Not evaluated if cheap_check() returns true
)
```

## Common Patterns

### Pattern 1: Permission Cascade

Check permissions in priority order:

```ruby
rule "permission_cascade" do
  when_any(
    usr(:admin?),                           # Highest priority
    all(usr(:editor?), rec(:draft?)),       # Medium priority
    all(eq(rec_val(:owner_id), usr_val(:id)), not_(rec(:locked?)))  # Lowest
  )
  allow! :edit
end
```

### Pattern 2: Feature Flags

Combine feature flags with business logic:

```ruby
rule "new_feature" do
  when_all(
    flag(:new_feature_enabled),  # Feature flag
    usr(:premium?),                # Business rule
    gte(rec_val(:created_at), Time.new(2026, 1, 1))  # Time constraint
  )
  set :use_new_feature, true
end
```

### Pattern 3: Multi-Tier Access

Different access levels based on user tier:

```ruby
rule "vip_access" do
  when_all(
    usr(:vip?),
    any(
      rec(:public?),
      rec(:premium?),
      rec(:exclusive?)
    )
  )
  allow! :access
end

rule "premium_access" do
  when_all(
    usr(:premium?),
    any(
      rec(:public?),
      rec(:premium?)
    )
  )
  allow! :access
end

rule "basic_access" do
  when_all(
    usr(:registered?),
    rec(:public?)
  )
  allow! :access
end
```

### Pattern 4: Dependent Rules

Use flags set by earlier rules:

```ruby
rule "check_eligibility", salience: 10 do
  when_all(
    gte(rec_val(:age), 18),
    usr(:verified?)
  )
  allow! :eligible
end

rule "grant_access", salience: 0 do
  when_all(
    flag(:eligible),  # Depends on previous rule
    rec(:active?)
  )
  allow! :access
end
```

## YAML Representation

Conditions serialize to YAML for storage:

```yaml
condition:
  type: any
  children:
    - type: pred
      op: truthy
      left:
        type: call
        recv:
          type: ref
          root: user
          path: []
        method: admin?
      right: null
    - type: all
      children:
        - type: pred
          op: eq
          left:
            type: call
            recv:
              type: ref
              root: record
              path: []
            method: status
          right:
            type: lit
            value: draft
```

See [YAML Rules](./yaml-rules.md) for details.

## Best Practices

### 1. Keep Conditions Readable

Break complex conditions into smaller rules:

```ruby
# Good - clear intent
rule "eligible_for_discount" do
  when_all(
    usr(:premium?),
    gte(rec_val(:total), 100)
  )
  allow! :discount
end

# Hard to read
rule "complex" do
  when_all(
    any(
      all(usr(:premium?), gte(rec_val(:total), 100)),
      all(usr(:vip?), gte(rec_val(:total), 50)),
      all(usr(:staff?), present(rec_val(:staff_id)))
    )
  )
end
```

### 2. Order Conditions by Likelihood

Put cheap, likely-to-fail checks first:

```ruby
# Good - cheap check first
when_all(
  usr(:logged_in?),      # Fast, often false
  expensive_database_check()
)

# Less efficient
when_all(
  expensive_database_check(),
  usr(:logged_in?)
)
```

### 3. Use Descriptive Names

```ruby
# Good
is_adult = gte(rec_val(:age), 18)
is_verified = usr(:verified?)
when_all(is_adult, is_verified)

# Less clear
when_all(gte(rec_val(:age), 18), usr(:verified?))
```

### 4. Avoid Deep Nesting

More than 3 levels deep gets hard to follow. Break into multiple rules:

```ruby
# Too deep (4 levels)
when_any(
  a,
  all(
    b,
    any(
      c,
      all(d, e, any(f, g))  # 4 levels!
    )
  )
)

# Better - split into rules
rule "check_complex_1" do
  when_all(d, e, any(f, g))
  set :complex_1, true
end

rule "check_complex_2" do
  when_any(c, flag(:complex_1))
  set :complex_2, true
end

rule "final_check" do
  when_any(a, all(b, flag(:complex_2)))
  allow! :access
end
```

## Troubleshooting

### Condition Always False

**Problem:** Rule never fires even when you expect it to.

**Solution:** Check each predicate individually:

```ruby
# Add tracing
engine = Ruleur::Engine.new(trace: true)

# Or test conditions directly
ctx = Ruleur::Context.new(user: user, record: record)
puts condition.evaluate(ctx)  # => true or false
```

### Nil Value Errors

**Problem:** `NoMethodError` when accessing nested attributes.

**Solution:** Use `present` checks or safe navigation:

```ruby
# Add presence checks
when_all(
  present(rec_val(:user)),
  eq(rec_val(:user).call(:role), 'admin')
)

# Or use safe navigation in models
class Record
  def user_role
    user&.role
  end
end
```

### Short-Circuit Not Working

**Problem:** All conditions evaluated even when early ones fail.

**Solution:** Use `when_all` correctly (it short-circuits automatically):

```ruby
# This short-circuits
when_all(
  cheap_check(),    # If false, stops here
  expensive_check()
)
```

## Next Steps

- **[Operators](./operators.md)**: Learn all available comparison operators
- **[DSL Basics](./dsl-basics.md)**: Master the DSL shortcuts
- **[YAML Rules](./yaml-rules.md)**: Serialize conditions to YAML

## Related API

- [Condition Module](../api/condition.md)
- [Condition::Predicate](../api/condition.md#predicate)
- [Condition::All/Any/Not](../api/condition.md#composite)
- [Operators Registry](../api/operators.md)
