# Guide

Welcome to the Ruleur guide! This section provides comprehensive documentation on all features and capabilities.

## Core Concepts

### [DSL Basics](./dsl-basics)
Learn the Ruby DSL for defining rules, including all helper methods and shortcuts.

### [Conditions](./conditions)
Master composable conditions with all/any/not operators and predicate logic.

### [Operators](./operators)
Explore all available comparison and logical operators.

## Rule Authoring

### [YAML Rules](./yaml-rules)
Define rules in YAML format for database storage and runtime loading.

### [Validation](./validation)
Validate rules before execution with structural, semantic, and test validation.

## Persistence & Versioning

### [Persistence](./persistence)
Store rules in memory or database using repositories.

### [Versioning & Audit](./versioning)
Track rule changes with full audit trails and rollback support.

## Advanced Topics

### [Advanced Topics](./advanced)
Salience, no-loop, tracing, and performance optimization.

## Quick Reference

### Common Patterns

```ruby
# Permission check
match do
  any(user(:admin?), record(:public?))
end

# Ownership check
match do
  all(
  eq?(record_value(:owner_id), user_value(:id)),
  record(:active?)
)
end

# Range check
match do
  all(
  gte?(record_value(:price), 100),
  lte?(record_value(:price), 1000)
)
end

# Array membership
includes(record_value(:roles), literal('editor'))

# Pattern matching
matches(record_value(:email), literal(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i))
```

### DSL Reference

| Method | Description | Example |
|--------|-------------|---------|
| `user(:admin?)` | Predicate on user object | `user(:admin?)` |
| `record(:active?)` | Predicate on record object | `record(:active?)` |
| `user_value(:id)` | Get field value from user | `user_value(:id)` |
| `record_value(:owner_id)` | Get field value from record | `record_value(:owner_id)` |
| `flag(:create)` | Check if permission granted | `flag(:create)` |
| `set :update, true` | Grant permission | `set :update, true` |

### Operators Reference

**Comparison:**
- `eq?(a, b)` - Equal
- `not_eq?(a, b)` - Not equal
- `gt?(a, b)` - Greater than
- `gte?(a, b)` - Greater than or equal
- `lt?(a, b)` - Less than
- `lte?(a, b)` - Less than or equal

**Logical:**
- `truthy?(value)` - Value is truthy
- `falsy?(value)` - Value is falsy
- `present?(value)` - Value is present (not nil/empty)
- `blank?(value)` - Value is blank (nil/empty)

**Collections:**
- `in?(value, array)` - Value in array
- `contains?(array, value)` - Array contains value

**Patterns:**
- `matches(string, regex)` - String matches regex

## Navigation

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1rem; margin-top: 2rem;">
  <a href="./dsl-basics" style="padding: 1rem; border: 1px solid var(--vp-c-divider); border-radius: 8px; text-decoration: none;">
    <h3 style="margin-top: 0;">DSL Basics</h3>
    <p style="margin-bottom: 0; color: var(--vp-c-text-2);">Ruby DSL syntax and helpers</p>
  </a>
  
  <a href="./yaml-rules" style="padding: 1rem; border: 1px solid var(--vp-c-divider); border-radius: 8px; text-decoration: none;">
    <h3 style="margin-top: 0;">YAML Rules</h3>
    <p style="margin-bottom: 0; color: var(--vp-c-text-2);">Define rules in YAML</p>
  </a>
  
  <a href="./validation" style="padding: 1rem; border: 1px solid var(--vp-c-divider); border-radius: 8px; text-decoration: none;">
    <h3 style="margin-top: 0;">Validation</h3>
    <p style="margin-bottom: 0; color: var(--vp-c-text-2);">Validate before execution</p>
  </a>
  
  <a href="./versioning" style="padding: 1rem; border: 1px solid var(--vp-c-divider); border-radius: 8px; text-decoration: none;">
    <h3 style="margin-top: 0;">Versioning</h3>
    <p style="margin-bottom: 0; color: var(--vp-c-text-2);">Audit trails and rollback</p>
  </a>
</div>
