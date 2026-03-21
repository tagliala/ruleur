# Operators

Operators are the building blocks of rule conditions in Ruleur. They compare values, check predicates, and evaluate collection membership. All operators are pluggable and registered in the `Ruleur::Operators` registry.

## Operator Categories

Ruleur provides three categories of operators:

1. **Comparison Operators**: Compare two values (`eq`, `ne`, `gt`, `gte`, `lt`, `lte`)
2. **Collection Operators**: Check membership and patterns (`in`, `includes`, `matches`)
3. **Predicate Operators**: Check truthiness and presence (`truthy`, `falsy`, `present`, `blank`)

## Comparison Operators

### `eq` - Equals

Checks if two values are equal using Ruby's `==` operator.

```ruby
rule 'adult_only' do
  match do
    all?(
      eq?(record_value(:age), 18)
    )
  end
  execute do
    allow! :access
  end
end
```

**YAML:**
```yaml
condition:
  type: pred
  op: eq
  left:
    type: call
    recordv: { type: ref, root: record, path: [] }
    method: age
  right:
    type: lit
    value: 18
```

**Examples:**
```ruby
eq?(literal(5), 5) # => true
eq?(literal('hello'), 'hello') # => true
eq?(record_value(:status), 'active') # => true/false depending on record.status
```

### `ne` - Not Equals

Checks if two values are not equal using Ruby's `!=` operator.

```ruby
rule 'exclude_archived' do
  match do
    all?(
      not_eq?(record_value(:status), 'archived')
    )
  end
  execute do
    allow! :view
  end
end
```

**Examples:**
```ruby
not_eq?(literal(5), 10) # => true
not_eq?(literal('draft'), 'published') # => true
not_eq?(record_value(:status), 'archived') # => true if status != "archived"
```

### `gt` - Greater Than

Checks if left value is greater than right value. Returns `false` if either value is `nil`.

```ruby
rule 'senior_discount' do
  match do
    all?(
      gt?(record_value(:age), 65)
    )
  end
  execute do
    set :discount, 0.15
  end
end
```

**Safety:** Returns `false` if either operand is `nil` to prevent comparison errors.

**Examples:**
```ruby
gt?(literal(10), 5)          # => true
gt?(literal(5), 10)          # => false
gt?(literal(10), 10)         # => false
gt?(record_value(:age), 18) # => true if age > 18
```

### `gte` - Greater Than or Equal

Checks if left value is greater than or equal to right value. Returns `false` if either value is `nil`.

```ruby
rule 'voting_age' do
  match do
    all?(
      gte?(record_value(:age), 18)
    )
  end
  execute do
    allow! :vote
  end
end
```

**Examples:**
```ruby
gte?(literal(10), 5)         # => true
gte?(literal(10), 10)        # => true
gte?(literal(5), 10)         # => false
gte?(record_value(:age), 21) # => true if age >= 21
```

### `lt` - Less Than

Checks if left value is less than right value. Returns `false` if either value is `nil`.

```ruby
rule 'child_ticket' do
  match do
    all?(
      lt?(record_value(:age), 12)
    )
  end
  execute do
    set :ticket_price, 5.00
  end
end
```

**Examples:**
```ruby
lt?(literal(5), 10)          # => true
lt?(literal(10), 5)          # => false
lt?(literal(10), 10)         # => false
lt?(record_value(:price), 100) # => true if price < 100
```

### `lte` - Less Than or Equal

Checks if left value is less than or equal to right value. Returns `false` if either value is `nil`.

```ruby
rule 'standard_shipping' do
  match do
    all?(
      lte?(record_value(:weight), 50)
    )
  end
  execute do
    set :shipping_method, 'standard'
  end
end
```

**Examples:**
```ruby
lte?(literal(5), 10)         # => true
lte?(literal(10), 10)        # => true
lte?(literal(10), 5)         # => false
lte?(record_value(:quantity), 100) # => true if quantity <= 100
```

## Collection Operators

### `in` - Value in Collection

Checks if left value is included in the right collection. The right operand must respond to `include?`.

```ruby
rule 'valid_status' do
  match do
    all?(
      include?(record_value(:status), %w[draft pending published])
    )
  end
  execute do
    set :edit, true
  end
end
```

**Examples:**
```ruby
include?(ref(:record), %w[draft published]) # => true if record is in array
include?(record_value(:status), %w[active pending]) # => true if status in array
```

### `includes` - Collection Includes Value

Checks if left collection includes the right value. The left operand must respond to `include?`. This is the inverse of `in`.

```ruby
rule 'has_permission' do
  match do
    all?(
      includes(record_value(:permissions), 'admin')
    )
  end
  execute do
    allow! :delete
  end
end
```

**Use case:** When the record has an array and you want to check if it contains a value.

**Examples:**
```ruby
includes(literal(%w[admin editor]), literal('admin')) # => true
includes(literal([1, 2, 3]), literal(4)) # => false
includes(record_value(:roles), 'admin') # => true if roles.include?('admin')
```

### `matches` - Regular Expression Match

Checks if a string matches a regular expression pattern.

```ruby
rule 'email_domain_check' do
  match do
    all?(
      matches(record_value(:email), literal(/@example\.com$/))
    )
  end
  execute do
    set :internal_user, true
  end
end
```

**Requirements:**
- Left operand must be a String
- Right operand must be a Regexp

**Examples:**
```ruby
matches(literal('hello@example.com'), literal(/@example\.com$/)) # => true
matches(literal('test@gmail.com'), literal(/@example\.com$/))    # => false
matches(record_value(:phone), literal(/^\d{3}-\d{3}-\d{4}$/)) # => true if phone matches format
```

## Predicate Operators

Predicate operators check the state or presence of a single value. The second operand is typically `nil` or ignored.

### `truthy` - Truthy Check

Checks if a value is truthy (not `nil` and not `false`).

```ruby
rule 'published_only' do
  match do
    all?(
      truthy?(record(:published?))
    )
  end
  execute do
    allow! :view
  end
end
```

::: tip
The `record(method)` and `user(method)` helpers use `truthy` automatically:

```ruby
record(:admin?) # Equivalent to: truthy?(ref(:record).call(:admin?))
user(:verified?) # Equivalent to: truthy?(ref(:user).call(:verified?))
```
:::

**Examples:**
```ruby
truthy?(literal(true))        # => true
truthy?(literal(false))       # => false
truthy?(literal(nil))         # => false
truthy?(literal(0))           # => true (0 is truthy in Ruby)
truthy?(literal(''))          # => true (empty string is truthy)
truthy?(record(:admin?)) # => true if record.admin? is truthy
```

### `falsy` - Falsy Check

Checks if a value is falsy (`nil` or `false`).

```ruby
rule 'unpublished_draft' do
  match do
    all?(
      falsy?(record(:published?))
    )
  end
  execute do
    allow! :edit
  end
end
```

**Examples:**
```ruby
falsy?(literal(false))        # => true
falsy?(literal(nil))          # => true
falsy?(literal(0))            # => false (0 is truthy)
falsy?(literal(''))           # => false (empty string is truthy)
falsy?(record(:locked?)) # => true if record.locked? is nil or false
```

### `present` - Presence Check

Checks if a value is present (not `nil` and not empty). Similar to Rails' `present?`.

```ruby
rule 'requires_description' do
  match do
    all?(
      present?(record_value(:description))
    )
  end
  execute do
    allow! :publish
  end
end
```

**Behavior:**
- Returns `false` if value is `nil`
- Returns `false` if value responds to `empty?` and is empty
- Returns `true` otherwise

**Examples:**
```ruby
present?(literal(nil))         # => false
present?(literal(''))          # => false
present?(literal([]))          # => false
present?(literal({}))          # => false
present?(literal('hello'))     # => true
present?(literal([1, 2, 3]))   # => true
present?(record_value(:name)) # => true if name is not nil/empty
```

### `blank` - Blank Check

Checks if a value is blank (`nil` or empty). Similar to Rails' `blank?`.

```ruby
rule 'set_default_title' do
  match do
    all?(
      blank?(record_value(:title))
    )
  end
  execute do
    set :title, 'Untitled'
  end
end
```

**Behavior:**
- Returns `true` if value is `nil`
- Returns `true` if value responds to `empty?` and is empty
- Returns `false` otherwise

**Examples:**
```ruby
blank?(literal(nil))          # => true
blank?(literal(''))           # => true
blank?(literal([]))           # => true
blank?(literal({}))           # => true
blank?(literal('hello'))      # => false
blank?(literal([1, 2, 3]))    # => false
blank?(record_value(:name)) # => true if name is nil or empty
```

## Using Operators in DSL

### With Helper Methods

The simplest way to use operators with the DSL helpers:

```ruby
rule 'simple_check' do
  match do
    all?(
      record(:admin?), # truthy check on record.admin?
      user(:verified?) # truthy check on user.verified?
    )
  end
  execute do
    allow! :access
  end
end
```

### With Explicit Operators

For more complex comparisons, use operators direcordtly:

```ruby
rule 'age_and_status' do
  match do
    all?(
      gte?(record_value(:age), 18),
      include?(record_value(:status), %w[active premium])
    )
  end
  execute do
    set :purchase, true
  end
end
```

### Combining Multiple Operators

```ruby
rule 'complex_eligibility' do
  match do
    all?(
      gte?(record_value(:age), 21), # Age >= 21
      include?(record_value(:country), %w[US CA]), # Country is US or CA
      present?(record_value(:email)), # Email is present
      matches(record_value(:email), /@example\.com$/), # Email domain check
      not_eq?(record_value(:status), 'banned') # Not banned
    )
  end
  execute do
    set :vip_access, true
  end
end
```

## Operator Reference Table

| Operator | Category | Description | Example |
|----------|----------|-------------|---------|
| `eq` | Comparison | Equals | `eq?(record_value(:age), 18)` |
| `ne` | Comparison | Not equals | `not_eq?(record_value(:status), 'archived')` |
| `gt` | Comparison | Greater than | `gt?(record_value(:price), 100)` |
| `gte` | Comparison | Greater than or equal | `gte?(record_value(:age), 18)` |
| `lt` | Comparison | Less than | `lt?(record_value(:stock), 10)` |
| `lte` | Comparison | Less than or equal | `lte?(record_value(:weight), 50)` |
| `include?` | Collection | Value in collection | `include?(record_value(:status), ['draft', 'pending'])` |
| `includes` | Collection | Collection includes value | `includes(record_value(:tags), 'featured')` |
| `matches` | Collection | Regex match | `matches(record_value(:email), /\@example\.com$/)` |
| `truthy` | Predicate | Is truthy | `truthy?(record(:published?))` |
| `falsy` | Predicate | Is falsy | `falsy?(record(:locked?))` |
| `present` | Predicate | Not nil/empty | `present?(record_value(:name))` |
| `blank` | Predicate | Nil or empty | `blank?(record_value(:description))` |

## Custom Operators

You can register your own operators using `Ruleur::Operators.register`:

```ruby
# Register a custom operator
Ruleur::Operators.register(:between) do |value, range|
  range.is_a?(Range) && range.include?(value)
end

# Use in a rule
rule 'age_range' do
  match do
    all?(
      predicate do
        left = record_value(:age)
        right = literal(18..65)
        Ruleur::Operators.call(:between, left, right)
      end
    )
  end
  execute do
    allow! :insure
  end
end
```

::: warning
Custom operators won't serialize to YAML unless you handle deserialization separately.
:::

## Nil Safety

Comparison operators (`gt`, `gte`, `lt`, `lte`) return `false` when either operand is `nil`:

```ruby
rule 'safe_comparison' do
  match do
    all?(
      gt?(record_value(:age), 18) # Returns false if age is nil
    )
  end
  execute do
    allow! :access
  end
end
```

This prevents `NoMethodError` exceptions during comparison.

## Type Coercion

Operators don't perform type coercion. Values are compared as-is:

```ruby
eq?(literal(5), '5')        # => false (Integer vs String)
eq?(literal('5'), '5')      # => true
```

Ensure types match when using comparison operators:

```ruby
# Good
rule 'numeric_check' do
  match do
    all?(
      gt?(record_value(:age).to_i, 18) # Coerce in DSL if needed
    )
  end
end

# Or handle in your models
class User
  def age
    @age.to_i # Always return integer
  end
end
```

## Best Practices

### 1. Use Appropriate Operators

Choose the operator that best expresses your intent:

```ruby
# Good - clear intent
rule 'has_role' do
  match do
    all?(
      includes(record_value(:roles), 'admin')
    )
  end
end

# Less clear - works but awkward
rule 'has_role' do
  match do
    all?(
      eq?(record_value(:roles).include?('admin'), true)
    )
  end
end
```

### 2. Use `record`/`user` for Boolean Methods

For simple boolean checks, use the helpers:

```ruby
# Good - concise
rule 'admin_check' do
  match do
    all?(user(:admin?))
  end
end

# Verbose
rule 'admin_check' do
  match do
    all?(
      truthy?(ref(:user).call(:admin?))
    )
  end
end
```

### 3. Use `record_value`/`user_val` for Value Comparisons

When comparing actual values, use the `_val` variants:

```ruby
# Good
rule 'status_check' do
  match do
    all?(
      eq?(record_value(:status), 'published')
    )
  end
end

# Wrong - record(:status) checks truthiness, not value
rule 'status_check' do
  match do
    all?(
      record(:status) # This checks if status is truthy, not if it equals "published"
    )
  end
end
```

### 4. Handle Nil Cases

Use `present`/`blank` to handle nil values explicitly:

```ruby
rule 'requires_fields' do
  match do
    all?(
      present?(record_value(:title)),
      present?(record_value(:description)),
      gte?(record_value(:price), 0)
    )
  end
  execute do
    allow! :publish
  end
end
```

### 5. Use Literals for Constants

For clarity, use literal values direcordtly:

```ruby
rule 'status_check' do
  match do
    all?(
      include?(record_value(:status), %w[draft pending published])
    )
  end
end
```

## Next Steps

- **[Conditions](./conditions.md)**: Combine operators with composable conditions
- **[DSL Basics](./dsl-basics.md)**: Learn DSL shortcuts and patterns
- **[YAML Rules](./yaml-rules.md)**: See operators in YAML format

## Related API

- [Ruleur::Operators Module](../api/operators.md)
- [Condition::Predicate Class](../api/condition.md#predicate)
