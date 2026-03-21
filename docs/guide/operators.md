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
rule "adult_only" do
  when_all(
    eq(rec_val(:age), 18)
  )
  allow! :access
end
```

**YAML:**
```yaml
condition:
  type: pred
  op: eq
  left:
    type: call
    recv: { type: ref, root: record, path: [] }
    method: age
  right:
    type: lit
    value: 18
```

**Examples:**
```ruby
eq(lit(5), 5)           # => true
eq(lit("hello"), "hello") # => true
eq(rec_val(:status), "active") # => true/false depending on record.status
```

### `ne` - Not Equals

Checks if two values are not equal using Ruby's `!=` operator.

```ruby
rule "exclude_archived" do
  when_all(
    ne(rec_val(:status), "archived")
  )
  allow! :view
end
```

**Examples:**
```ruby
ne(lit(5), 10)          # => true
ne(lit("draft"), "published") # => true
ne(rec_val(:status), "archived") # => true if status != "archived"
```

### `gt` - Greater Than

Checks if left value is greater than right value. Returns `false` if either value is `nil`.

```ruby
rule "senior_discount" do
  when_all(
    gt(rec_val(:age), 65)
  )
  set :discount, 0.15
end
```

**Safety:** Returns `false` if either operand is `nil` to prevent comparison errors.

**Examples:**
```ruby
gt(lit(10), 5)          # => true
gt(lit(5), 10)          # => false
gt(lit(10), 10)         # => false
gt(rec_val(:age), 18)   # => true if age > 18
```

### `gte` - Greater Than or Equal

Checks if left value is greater than or equal to right value. Returns `false` if either value is `nil`.

```ruby
rule "voting_age" do
  when_all(
    gte(rec_val(:age), 18)
  )
  allow! :vote
end
```

**Examples:**
```ruby
gte(lit(10), 5)         # => true
gte(lit(10), 10)        # => true
gte(lit(5), 10)         # => false
gte(rec_val(:age), 21)  # => true if age >= 21
```

### `lt` - Less Than

Checks if left value is less than right value. Returns `false` if either value is `nil`.

```ruby
rule "child_ticket" do
  when_all(
    lt(rec_val(:age), 12)
  )
  set :ticket_price, 5.00
end
```

**Examples:**
```ruby
lt(lit(5), 10)          # => true
lt(lit(10), 5)          # => false
lt(lit(10), 10)         # => false
lt(rec_val(:price), 100) # => true if price < 100
```

### `lte` - Less Than or Equal

Checks if left value is less than or equal to right value. Returns `false` if either value is `nil`.

```ruby
rule "standard_shipping" do
  when_all(
    lte(rec_val(:weight), 50)
  )
  set :shipping_method, "standard"
end
```

**Examples:**
```ruby
lte(lit(5), 10)         # => true
lte(lit(10), 10)        # => true
lte(lit(10), 5)         # => false
lte(rec_val(:quantity), 100) # => true if quantity <= 100
```

## Collection Operators

### `in` - Value in Collection

Checks if left value is included in the right collection. The right operand must respond to `include?`.

```ruby
rule "valid_status" do
  when_all(
    in_(rec_val(:status), ['draft', 'pending', 'published'])
  )
  set :edit, true
end
```

**Examples:**
```ruby
in_(ref(:record), ['draft', 'published'])  # => true if record is in array
in_(rec_val(:status), ['active', 'pending']) # => true if status in array
```

### `includes` - Collection Includes Value

Checks if left collection includes the right value. The left operand must respond to `include?`. This is the inverse of `in`.

```ruby
rule "has_permission" do
  when_all(
    includes(rec_val(:permissions), "admin")
  )
  allow! :delete
end
```

**Use case:** When the record has an array and you want to check if it contains a value.

**Examples:**
```ruby
includes(lit(['admin', 'editor']), lit('admin'))  # => true
includes(lit([1, 2, 3]), lit(4))  # => false
includes(rec_val(:roles), 'admin') # => true if roles.include?('admin')
```

### `matches` - Regular Expression Match

Checks if a string matches a regular expression pattern.

```ruby
rule "email_domain_check" do
  when_all(
    matches(rec_val(:email), lit(/\@example\.com$/))
  )
  set :internal_user, true
end
```

**Requirements:**
- Left operand must be a String
- Right operand must be a Regexp

**Examples:**
```ruby
matches(lit("hello@example.com"), lit(/\@example\.com$/)) # => true
matches(lit("test@gmail.com"), lit(/\@example\.com$/))    # => false
matches(rec_val(:phone), lit(/^\d{3}-\d{3}-\d{4}$/))      # => true if phone matches format
```

## Predicate Operators

Predicate operators check the state or presence of a single value. The second operand is typically `nil` or ignored.

### `truthy` - Truthy Check

Checks if a value is truthy (not `nil` and not `false`).

```ruby
rule "published_only" do
  when_all(
    truthy(rec(:published?))
  )
  allow! :view
end
```

::: tip
The `rec(method)` and `usr(method)` helpers use `truthy` automatically:

```ruby
rec(:admin?)  # Equivalent to: truthy(ref(:record).call(:admin?))
usr(:verified?)  # Equivalent to: truthy(ref(:user).call(:verified?))
```
:::

**Examples:**
```ruby
truthy(lit(true))        # => true
truthy(lit(false))       # => false
truthy(lit(nil))         # => false
truthy(lit(0))           # => true (0 is truthy in Ruby)
truthy(lit(""))          # => true (empty string is truthy)
truthy(rec(:admin?))     # => true if record.admin? is truthy
```

### `falsy` - Falsy Check

Checks if a value is falsy (`nil` or `false`).

```ruby
rule "unpublished_draft" do
  when_all(
    falsy(rec(:published?))
  )
  allow! :edit
end
```

**Examples:**
```ruby
falsy(lit(false))        # => true
falsy(lit(nil))          # => true
falsy(lit(0))            # => false (0 is truthy)
falsy(lit(""))           # => false (empty string is truthy)
falsy(rec(:locked?))     # => true if record.locked? is nil or false
```

### `present` - Presence Check

Checks if a value is present (not `nil` and not empty). Similar to Rails' `present?`.

```ruby
rule "requires_description" do
  when_all(
    present(rec_val(:description))
  )
  allow! :publish
end
```

**Behavior:**
- Returns `false` if value is `nil`
- Returns `false` if value responds to `empty?` and is empty
- Returns `true` otherwise

**Examples:**
```ruby
present(lit(nil))         # => false
present(lit(""))          # => false
present(lit([]))          # => false
present(lit({}))          # => false
present(lit("hello"))     # => true
present(lit([1, 2, 3]))   # => true
present(rec_val(:name))   # => true if name is not nil/empty
```

### `blank` - Blank Check

Checks if a value is blank (`nil` or empty). Similar to Rails' `blank?`.

```ruby
rule "set_default_title" do
  when_all(
    blank(rec_val(:title))
  )
  set :title, "Untitled"
end
```

**Behavior:**
- Returns `true` if value is `nil`
- Returns `true` if value responds to `empty?` and is empty
- Returns `false` otherwise

**Examples:**
```ruby
blank(lit(nil))          # => true
blank(lit(""))           # => true
blank(lit([]))           # => true
blank(lit({}))           # => true
blank(lit("hello"))      # => false
blank(lit([1, 2, 3]))    # => false
blank(rec_val(:name))    # => true if name is nil or empty
```

## Using Operators in DSL

### With Helper Methods

The simplest way to use operators with the DSL helpers:

```ruby
rule "simple_check" do
  when_all(
    rec(:admin?),           # truthy check on record.admin?
    usr(:verified?)         # truthy check on user.verified?
  )
  allow! :access
end
```

### With Explicit Operators

For more complex comparisons, use operators directly:

```ruby
rule "age_and_status" do
  when_all(
    gte(rec_val(:age), 18),
    in_(rec_val(:status), ['active', 'premium'])
  )
  set :purchase, true
end
```

### Combining Multiple Operators

```ruby
rule "complex_eligibility" do
  when_all(
    gte(rec_val(:age), 21),                    # Age >= 21
    in_(rec_val(:country), ['US', 'CA']),     # Country is US or CA
    present(rec_val(:email)),                   # Email is present
    matches(rec_val(:email), /\@example\.com$/), # Email domain check
    ne(rec_val(:status), 'banned')             # Not banned
  )
  set :vip_access, true
end
```

## Operator Reference Table

| Operator | Category | Description | Example |
|----------|----------|-------------|---------|
| `eq` | Comparison | Equals | `eq(rec_val(:age), 18)` |
| `ne` | Comparison | Not equals | `ne(rec_val(:status), 'archived')` |
| `gt` | Comparison | Greater than | `gt(rec_val(:price), 100)` |
| `gte` | Comparison | Greater than or equal | `gte(rec_val(:age), 18)` |
| `lt` | Comparison | Less than | `lt(rec_val(:stock), 10)` |
| `lte` | Comparison | Less than or equal | `lte(rec_val(:weight), 50)` |
| `in_` | Collection | Value in collection | `in_(rec_val(:status), ['draft', 'pending'])` |
| `includes` | Collection | Collection includes value | `includes(rec_val(:tags), 'featured')` |
| `matches` | Collection | Regex match | `matches(rec_val(:email), /\@example\.com$/)` |
| `truthy` | Predicate | Is truthy | `truthy(rec(:published?))` |
| `falsy` | Predicate | Is falsy | `falsy(rec(:locked?))` |
| `present` | Predicate | Not nil/empty | `present(rec_val(:name))` |
| `blank` | Predicate | Nil or empty | `blank(rec_val(:description))` |

## Custom Operators

You can register your own operators using `Ruleur::Operators.register`:

```ruby
# Register a custom operator
Ruleur::Operators.register(:between) do |value, range|
  range.is_a?(Range) && range.include?(value)
end

# Use in a rule
rule "age_range" do
  when_all(
    predicate do
      left = rec_val(:age)
      right = lit(18..65)
      Ruleur::Operators.call(:between, left, right)
    end
  )
  allow! :insure
end
```

::: warning
Custom operators won't serialize to YAML unless you handle deserialization separately.
:::

## Nil Safety

Comparison operators (`gt`, `gte`, `lt`, `lte`) return `false` when either operand is `nil`:

```ruby
rule "safe_comparison" do
  when_all(
    gt(rec_val(:age), 18)  # Returns false if age is nil
  )
  allow! :access
end
```

This prevents `NoMethodError` exceptions during comparison.

## Type Coercion

Operators don't perform type coercion. Values are compared as-is:

```ruby
eq(lit(5), "5")        # => false (Integer vs String)
eq(lit("5"), "5")      # => true
```

Ensure types match when using comparison operators:

```ruby
# Good
rule "numeric_check" do
  when_all(
    gt(rec_val(:age).to_i, 18)  # Coerce in DSL if needed
  )
end

# Or handle in your models
class User
  def age
    @age.to_i  # Always return integer
  end
end
```

## Best Practices

### 1. Use Appropriate Operators

Choose the operator that best expresses your intent:

```ruby
# Good - clear intent
rule "has_role" do
  when_all(
    includes(rec_val(:roles), 'admin')
  )
end

# Less clear - works but awkward
rule "has_role" do
  when_all(
    eq(rec_val(:roles).include?('admin'), true)
  )
end
```

### 2. Use `rec`/`usr` for Boolean Methods

For simple boolean checks, use the helpers:

```ruby
# Good - concise
rule "admin_check" do
  when_all(usr(:admin?))
end

# Verbose
rule "admin_check" do
  when_all(
    truthy(ref(:user).call(:admin?))
  )
end
```

### 3. Use `rec_val`/`usr_val` for Value Comparisons

When comparing actual values, use the `_val` variants:

```ruby
# Good
rule "status_check" do
  when_all(
    eq(rec_val(:status), "published")
  )
end

# Wrong - rec(:status) checks truthiness, not value
rule "status_check" do
  when_all(
    rec(:status)  # This checks if status is truthy, not if it equals "published"
  )
end
```

### 4. Handle Nil Cases

Use `present`/`blank` to handle nil values explicitly:

```ruby
rule "requires_fields" do
  when_all(
    present(rec_val(:title)),
    present(rec_val(:description)),
    gte(rec_val(:price), 0)
  )
  allow! :publish
end
```

### 5. Use Literals for Constants

For clarity, use literal values directly:

```ruby
rule "status_check" do
  when_all(
    in_(rec_val(:status), ['draft', 'pending', 'published'])
  )
end
```

## Next Steps

- **[Conditions](./conditions.md)**: Combine operators with composable conditions
- **[DSL Basics](./dsl-basics.md)**: Learn DSL shortcuts and patterns
- **[YAML Rules](./yaml-rules.md)**: See operators in YAML format

## Related API

- [Ruleur::Operators Module](../api/operators.md)
- [Condition::Predicate Class](../api/condition.md#predicate)
