# YAML Rules

Ruleur supports defining rules in YAML format, enabling database-first rule management. This is essential for:

- Storing rules in databases
- Loading rules dynamically at runtime
- Version controlling rules separately from code
- Non-developers authoring rules

## Loading YAML Rules

### Single File

```ruby
require 'ruleur'

rule = Ruleur::Persistence::YAMLLoader.load_file('config/rules/allow_create.yml')
engine = Ruleur::Engine.new(rules: [rule])
```

### Multiple Files (Directory)

```ruby
rules = Ruleur::Persistence::YAMLLoader.load_directory('config/rules/*.yml')
engine = Ruleur::Engine.new(rules: rules)
```

### From String

```ruby
yaml_string = File.read('my_rule.yml')
rule = Ruleur::Persistence::YAMLLoader.load_string(yaml_string)
```

## YAML Format

### Basic Structure

```yaml
name: rule_name
salience: 0          # Optional: priority (default 0)
tags: []             # Optional: array of tags
no_loop: false       # Optional: prevent infinite loops
condition:
  # Condition tree (see below)
action:
  # Action specification (see below)
```

### Simple Example

```yaml
name: allow_admin_access
salience: 10
tags:
  - permissions
  - admin
no_loop: true
condition:
  type: pred
  op: truthy
  left:
    type: call
    recv:
      type: ref
      root: user
      path: []
    method: admin?
    args: []
  right: null
action:
  set:
    allow_access: true
```

## Condition Types

### Predicate (`pred`)

Evaluates a comparison between two values:

```yaml
condition:
  type: pred
  op: eq              # Operator: eq, ne, gt, gte, lt, lte, truthy, etc.
  left:
    # Value specification
  right:
    # Value specification (can be null)
```

### All (`all`)

All child conditions must be true (AND logic):

```yaml
condition:
  type: all
  children:
    - type: pred
      op: truthy
      left: { type: ref, root: user, path: [roles] }
      right: null
    - type: pred
      op: eq
      left: { type: ref, root: record, path: [status] }
      right: { type: lit, value: draft }
```

### Any (`any`)

At least one child condition must be true (OR logic):

```yaml
condition:
  type: any
  children:
    - type: pred
      op: truthy
      left:
        type: call
        recv: { type: ref, root: user }
        method: admin?
      right: null
    - type: pred
      op: truthy
      left:
        type: call
        recv: { type: ref, root: user }
        method: moderator?
      right: null
```

### Not (`not`)

Negates a condition:

```yaml
condition:
  type: not
  child:
    type: pred
    op: blank
    left: { type: ref, root: record, path: [deleted_at] }
    right: null
```

## Value Types

### Literal (`lit`)

A static value:

```yaml
type: lit
value: 42              # Can be number, string, boolean, null
```

### Reference (`ref`)

Access a fact from context:

```yaml
type: ref
root: user             # Root object name
path: [profile, email] # Optional: nested path
```

### Method Call (`call`)

Call a method on an object:

```yaml
type: call
recv:
  type: ref
  root: record
  path: []
method: active?        # Method name
args: []               # Optional: method arguments
```

## Action Specifications

Currently, only `set` actions are supported for YAML rules:

```yaml
action:
  set:
    allow_create: true
    allow_update: false
    approval_required: true
```

Multiple facts can be set in a single action.

## Complete Examples

### Permission Rule

```yaml
name: allow_create
salience: 10
tags:
  - permissions
  - create
no_loop: true
condition:
  type: any
  children:
    # Admin can always create
    - type: pred
      op: truthy
      left:
        type: call
        recv:
          type: ref
          root: user
          path: []
        method: admin?
        args: []
      right: null
    # Or: updatable AND draft
    - type: all
      children:
        - type: pred
          op: truthy
          left:
            type: call
            recv:
              type: ref
              root: record
              path: []
            method: updatable?
            args: []
          right: null
        - type: pred
          op: truthy
          left:
            type: call
            recv:
              type: ref
              root: record
              path: []
            method: draft?
            args: []
          right: null
action:
  set:
    allow_create: true
```

### Workflow Rule

```yaml
name: auto_approve_small_amounts
salience: 5
tags:
  - workflow
  - approval
condition:
  type: all
  children:
    # Amount less than 1000
    - type: pred
      op: lt
      left:
        type: call
        recv:
          type: ref
          root: invoice
        method: amount
      right:
        type: lit
        value: 1000
    # Already reviewed
    - type: pred
      op: truthy
      left:
        type: call
        recv:
          type: ref
          root: invoice
        method: reviewed?
      right: null
action:
  set:
    auto_approved: true
    approval_status: approved
```

## Exporting DSL Rules to YAML

You can convert DSL-defined rules to YAML:

```ruby
# Define rule with DSL
engine = Ruleur.define do
  rule 'my_rule', salience: 10 do
    match do
      any?(user(:admin?))
    end
    execute do allow! :access end
  end
end

# Export to YAML file
Ruleur::Persistence::YAMLLoader.save_file(
  engine.rules.first,
  'config/rules/my_rule.yml',
  include_metadata: true  # Adds helpful comments
)

# Or get YAML string
yaml_string = Ruleur::Persistence::YAMLLoader.to_yaml(engine.rules.first)
puts yaml_string
```

### With Metadata

When `include_metadata: true`, the YAML file includes helpful comments:

```yaml
# Ruleur Rule: my_rule
# Salience: 10
# Tags: permissions
# No-loop: true
# Generated: 2026-03-20T10:30:00Z

name: my_rule
salience: 10
tags:
  - permissions
no_loop: true
condition:
  # ...
action:
  # ...
```

## Validating YAML

### Structural Validation

Validate YAML syntax and basic structure:

```ruby
result = Ruleur::Persistence::YAMLLoader.validate_file('config/rules/my_rule.yml')

if result[:valid]
  puts "Rule is valid!"
else
  puts "Errors: #{result[:errors].join(', ')}"
end
```

### Full Validation

For comprehensive validation including semantics and test execution:

```ruby
rule = Ruleur::Persistence::YAMLLoader.load_file('config/rules/my_rule.yml')
result = Ruleur::Validation.validate_rule(rule)

if result.valid?
  puts "Rule is valid!"
  puts "Warnings: #{result.warnings}" unless result.warnings.empty?
else
  puts "Errors:"
  result.errors.each { |error| puts "  - #{error}" }
end
```

See [Validation](./validation) for more details.

## Loading from Database

Typical workflow for database-backed rules:

```ruby
# Store YAML in database
class RuleRecord < ActiveRecord::Base
  # has columns: name, yaml_content, active
end

# Load and parse
active_rules = RuleRecord.where(active: true).map do |record|
  Ruleur::Persistence::YAMLLoader.load_string(record.yaml_content)
end

# Create engine
engine = Ruleur::Engine.new(rules: active_rules)
```

Or use the built-in [VersionedActiveRecordRepository](./versioning) for full version tracking.

## YAML Best Practices

### ✅ Do

- **Use descriptive names**: `allow_admin_create` not `rule1`
- **Add meaningful tags**: Group related rules
- **Set appropriate salience**: Higher priority rules fire first
- **Validate before storing**: Always validate YAML before saving
- **Version control**: Track YAML files in git
- **Document complex logic**: Add comments to explain why

### ❌ Don't

- **Don't store arbitrary code**: YAML rules can't contain Ruby lambdas
- **Don't nest too deeply**: Keep condition trees manageable
- **Don't use dynamic values**: YAML is static (no interpolation)
- **Don't skip validation**: Invalid rules will fail at runtime
- **Don't forget error handling**: Wrap loading in begin/rescue

### Example: Well-Structured Rule

```yaml
# Purpose: Allow document editing for admins and authors of drafts
# Dependencies: Requires user.admin? and document.draft? methods
# Author: alice@example.com
# Created: 2026-03-20

name: allow_document_edit
salience: 10
tags:
  - documents
  - permissions
  - edit
no_loop: true

condition:
  type: any
  children:
    # Rule 1: Admins can always edit
    - type: pred
      op: truthy
      left:
        type: call
        recv: { type: ref, root: user }
        method: admin?
      right: null

    # Rule 2: Authors can edit their drafts
    - type: all
      children:
        - type: pred
          op: eq
          left:
            type: call
            recv: { type: ref, root: document }
            method: author_id
          right:
            type: call
            recv: { type: ref, root: user }
            method: id
        - type: pred
          op: truthy
          left:
            type: call
            recv: { type: ref, root: document }
            method: draft?
          right: null

action:
  set:
    allow_edit: true
```

## Troubleshooting

### Common Errors

**"Invalid YAML syntax"**
- Check for proper indentation (2 spaces)
- Ensure colons have space after them
- Quote strings with special characters

**"Missing required field: condition"**
- Every rule must have name, condition, and action
- Check spelling and nesting

**"Unknown operator: xyz"**
- See [Operators](./operators) for valid operators
- Check spelling (case-sensitive)

**"Invalid condition type"**
- Valid types: `pred`, `all`, `any`, `not`
- Check spelling and nesting structure

## Next Steps

- [Validation](./validation) - Learn to validate YAML rules
- [Versioning](./versioning) - Track YAML rule changes
- [API Reference: YAMLLoader](/api/yaml-loader) - Detailed API docs

[← Back to Guide](./index) | [Next: Validation →](./validation)
