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
when_any(usr(:admin?), rec(:public?))

# Ownership check
when_all(
  eq(call(rec, :owner_id), call(usr, :id)),
  rec(:active?)
)

# Range check
when_all(
  gte(call(rec, :price), 100),
  lte(call(rec, :price), 1000)
)

# Array membership
includes(call(usr, :roles), 'editor')

# Pattern matching
matches(call(rec, :email), /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
```

### DSL Shortcuts

| Shortcut | Expands To |
|----------|-----------|
| `usr(:admin?)` | `truthy(call(ref(:user), :admin?))` |
| `rec(:active?)` | `truthy(call(ref(:record), :active?))` |
| `flag(:create)` | `truthy(ref(:allow_create))` |
| `allow! :edit` | `set :allow_edit, true` |

### Operators Reference

**Comparison:**
- `eq(a, b)` - Equal
- `ne(a, b)` - Not equal
- `gt(a, b)` - Greater than
- `gte(a, b)` - Greater than or equal
- `lt(a, b)` - Less than
- `lte(a, b)` - Less than or equal

**Logical:**
- `truthy(value)` - Value is truthy
- `falsy(value)` - Value is falsy
- `present(value)` - Value is present (not nil/empty)
- `blank(value)` - Value is blank (nil/empty)

**Collections:**
- `in(value, array)` - Value in array
- `includes(array, value)` - Array includes value

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
