# YAML Loader

The `Ruleur::Persistence::YAMLLoader` module provides functionality to load rules from YAML format.

## Overview

YAML rules enable:
- Storing rules in files or databases
- Non-developer rule authoring
- Version control and auditing
- Dynamic rule loading at runtime

## Module: `Ruleur::Persistence::YAMLLoader`

### Class Methods

#### `.load_file(path)`

Loads a rule from a YAML file.

```ruby
rule = Ruleur::Persistence::YAMLLoader.load_file("config/rules/discount.yml")
engine = Ruleur::Engine.new(rules: [rule])
```

**Parameters:**
- `path` (String) - Path to YAML file

**Returns:**
- `Ruleur::Rule` - Loaded rule instance

**Raises:**
- `Errno::ENOENT` - If file doesn't exist
- `Ruleur::ValidationError` - If YAML is invalid

#### `.load_string(yaml_string)`

Loads a rule from a YAML string.

```ruby
yaml = File.read("rule.yml")
rule = Ruleur::Persistence::YAMLLoader.load_string(yaml)
```

**Parameters:**
- `yaml_string` (String) - YAML content

**Returns:**
- `Ruleur::Rule` - Loaded rule instance

**Raises:**
- `Ruleur::ValidationError` - If YAML is invalid

#### `.load(hash)`

Loads a rule from a Hash (parsed YAML).

```ruby
rule_data = YAML.load_file("rule.yml")
rule = Ruleur::Persistence::YAMLLoader.load(rule_data)
```

**Parameters:**
- `hash` (Hash) - Rule data hash

**Returns:**
- `Ruleur::Rule` - Loaded rule instance

## YAML Format

### Basic Structure

```yaml
name: rule_name
salience: 10
tags: [tag1, tag2]
no_loop: true
condition:
  # condition tree
action:
  # action definition
```

### Condition Format

#### All (AND)

```yaml
condition:
  type: all
  children:
    - type: pred
      op: truthy
      left:
        type: call
        recv: { type: ref, root: user }
        method: admin?
    - type: pred
      op: truthy
      left:
        type: call
        recv: { type: ref, root: record }
        method: published?
```

#### Any (OR)

```yaml
condition:
  type: any
  children:
    - type: pred
      # ...
    - type: pred
      # ...
```

#### Not (Negation)

```yaml
condition:
  type: not
  child:
    type: pred
    # ...
```

#### Predicate with Operator

```yaml
condition:
  type: pred
  op: greater_than
  left:
    type: call
    recv: { type: ref, root: order }
    method: total
  right:
    type: literal
    value: 100
```

### Action Format

```yaml
action:
  set:
    discount: 0.15
    approved: true
    message: "Order approved"
  call:
    - object: { type: ref, root: order }
      method: apply_discount
      args: [0.15]
```

## Examples

### Simple Permission Rule

```yaml
# config/rules/admin_access.yml
name: admin_access
salience: 100
tags: [permissions, admin]
no_loop: false
condition:
  type: pred
  op: truthy
  left:
    type: call
    recv: { type: ref, root: user }
    method: admin?
action:
  set:
    allow_access: true
    access_level: "full"
```

```ruby
# Load and use
rule = Ruleur::Persistence::YAMLLoader.load_file(
  "config/rules/admin_access.yml"
)
engine = Ruleur::Engine.new(rules: [rule])
result = engine.run(user: current_user)
```

### Complex Nested Condition

```yaml
# config/rules/edit_permission.yml
name: can_edit
salience: 50
tags: [permissions, edit]
condition:
  type: any
  children:
    # Admin can always edit
    - type: pred
      op: truthy
      left:
        type: call
        recv: { type: ref, root: user }
        method: admin?
    
    # Owner can edit if not locked
    - type: all
      children:
        - type: pred
          op: call
          left:
            type: call
            recv: { type: ref, root: user }
            method: owner?
          args:
            - type: ref
              root: record
        - type: not
          child:
            type: pred
            op: truthy
            left:
              type: call
              recv: { type: ref, root: record }
              method: locked?
action:
  set:
    allow_edit: true
```

### Rule with Comparisons

```yaml
# config/rules/bulk_discount.yml
name: bulk_discount
salience: 10
tags: [pricing, discount]
no_loop: true
condition:
  type: all
  children:
    - type: pred
      op: greater_than
      left:
        type: call
        recv: { type: ref, root: order }
        method: total
      right:
        type: literal
        value: 500
    - type: pred
      op: greater_than
      left:
        type: call
        recv: { type: ref, root: order }
        method: items_count
      right:
        type: literal
        value: 10
action:
  set:
    discount: 0.15
    discount_reason: "Bulk order discount"
  call:
    - object: { type: ref, root: order }
      method: apply_discount
      args: [0.15]
```

## Loading Multiple Rules

### From Directory

```ruby
rule_files = Dir["config/rules/*.yml"]
rules = rule_files.map do |file|
  Ruleur::Persistence::YAMLLoader.load_file(file)
end

engine = Ruleur::Engine.new(rules: rules)
```

### From Database

```ruby
# Assuming rules stored as YAML strings in database
yaml_strings = Rule.where(active: true).pluck(:yaml_content)
rules = yaml_strings.map do |yaml|
  Ruleur::Persistence::YAMLLoader.load_string(yaml)
end

engine = Ruleur::Engine.new(rules: rules)
```

## Exporting to YAML

Convert DSL rules to YAML:

```ruby
# Define rule in DSL
engine = Ruleur.define do
  rule "example" do
    when_all(user(:admin?))
    action { allow! :access }
  end
end

# Export to YAML
yaml = engine.rules.first.to_yaml
File.write("config/rules/example.yml", yaml)
```

## Validation

YAML rules are validated on load:

```ruby
begin
  rule = Ruleur::Persistence::YAMLLoader.load_file("invalid.yml")
rescue Ruleur::ValidationError => e
  puts "Invalid rule: #{e.message}"
  puts e.errors.full_messages
end
```

## See Also

- [YAML Rules Guide](/guide/yaml-rules) - YAML authoring guide
- [Validation](./validation) - Rule validation
- [Repositories](./repositories) - Database persistence
