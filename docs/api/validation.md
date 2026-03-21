# Validation

The Ruleur validation framework provides comprehensive rule validation including structural checks, semantic analysis, and test execution.

## Overview

Validation types:
- **Structural Validation**: Ensures rule structure is valid
- **Semantic Validation**: Checks logical consistency
- **Test Execution**: Validates rules work with sample data

## Module: `Ruleur::Validation`

### Class Methods

#### `.validate(rule, options = {})`

Validates a rule.

```ruby
result = Ruleur::Validation.validate(rule)

if result.valid?
  puts "Rule is valid"
else
  puts result.errors.full_messages
end
```

**Parameters:**
- `rule` (Ruleur::Rule) - Rule to validate
- `options` (Hash) - Validation options
  - `level` (Symbol) - `:structural`, `:semantic`, or `:full` (default: `:full`)
  - `test_contexts` (Array\<Hash\>) - Sample contexts for testing

**Returns:**
- `Ruleur::ValidationResult` - Validation result

## Class: `Ruleur::ValidationResult`

### Instance Methods

#### `#valid?`

Returns whether the rule is valid.

```ruby
result.valid? # => true or false
```

#### `#errors`

Returns validation errors.

```ruby
result.errors # => Array of error messages
```

#### `#warnings`

Returns validation warnings.

```ruby
result.warnings # => Array of warning messages
```

## Validation Levels

### Structural Validation

Checks basic structure:
- Rule has a name
- Condition is present and well-formed
- Action is present
- YAML/DSL syntax is correct

```ruby
result = Ruleur::Validation.validate(rule, level: :structural)
```

### Semantic Validation

Checks logical consistency:
- No unreachable conditions
- No contradictory conditions
- References are consistent
- Operators are appropriate for types

```ruby
result = Ruleur::Validation.validate(rule, level: :semantic)
```

### Full Validation

Performs structural, semantic, and test execution:

```ruby
result = Ruleur::Validation.validate(
  rule,
  level: :full,
  test_contexts: [
    { user: admin_user, record: sample_record },
    { user: regular_user, record: sample_record }
  ]
)
```

## Common Validation Errors

### Structural Errors

```ruby
# Missing name
rule = Ruleur::Rule.new(name: "", condition: cond, action: act)
result = Ruleur::Validation.validate(rule)
# => Error: "Rule name cannot be blank"

# Invalid condition
# => Error: "Condition type 'invalid' is not recognized"

# Missing action
# => Error: "Action cannot be nil"
```

### Semantic Errors

```ruby
# Contradictory conditions
match do
  all?(
  user(:admin?),
  not?(user(:admin?))
)
end
# => Warning: "Contradictory conditions detected"

# Unreachable condition
match do
  all?(
  lit(false),
  user(:admin?)
)
end
# => Warning: "Unreachable condition detected"
```

## Validation in Development

### Validating DSL Rules

```ruby
engine = Ruleur.define do
  rule "example" do
    match do
      all?(user(:admin?))
    end
    execute do allow! :access end
  end
end

engine.rules.each do |rule|
  result = Ruleur::Validation.validate(rule)
  unless result.valid?
    puts "Rule '#{rule.name}' is invalid:"
    puts result.errors.full_messages
  end
end
```

### Validating YAML Rules

```ruby
rule = Ruleur::Persistence::YAMLLoader.load_file("config/rules/example.yml")
result = Ruleur::Validation.validate(rule)

if result.valid?
  puts "Rule loaded and validated successfully"
else
  puts "Validation errors:"
  result.errors.each { |error| puts "  - #{error}" }
end
```

## Test Execution Validation

Validates rules with sample data:

```ruby
# Define test scenarios
test_contexts = [
  {
    name: "Admin user",
    context: { user: admin_user, record: record },
    expected: { allow_access: true }
  },
  {
    name: "Regular user",
    context: { user: regular_user, record: record },
    expected: { allow_access: false }
  }
]

result = Ruleur::Validation.validate(
  rule,
  test_contexts: test_contexts
)

if result.valid?
  puts "All test scenarios passed"
else
  puts "Test failures:"
  result.test_failures.each do |failure|
    puts "  #{failure[:name]}: #{failure[:error]}"
  end
end
```

## Validation Helpers

### `validate_all(rules)`

Validates multiple rules:

```ruby
rules = [rule1, rule2, rule3]
results = Ruleur::Validation.validate_all(rules)

invalid_rules = results.reject(&:valid?)
if invalid_rules.any?
  invalid_rules.each do |result|
    puts "#{result.rule.name}: #{result.errors.join(', ')}"
  end
end
```

### `validate!`

Validates and raises on error:

```ruby
begin
  Ruleur::Validation.validate!(rule)
  puts "Rule is valid"
rescue Ruleur::ValidationError => e
  puts "Validation failed: #{e.message}"
end
```

## Integration with Repositories

Validate before saving:

```ruby
class RuleRepository
  def save(rule)
    result = Ruleur::Validation.validate(rule)
    
    unless result.valid?
      raise Ruleur::ValidationError, result.errors.join(", ")
    end
    
    # Save rule...
  end
end
```

## Best Practices

### Always Validate in Development

```ruby
if Rails.env.development?
  engine.rules.each do |rule|
    result = Ruleur::Validation.validate(rule, level: :full)
    raise "Invalid rule: #{rule.name}" unless result.valid?
  end
end
```

### Validate on Load

```ruby
def load_rules_from_yaml
  rules = Dir["config/rules/*.yml"].map do |file|
    rule = Ruleur::Persistence::YAMLLoader.load_file(file)
    
    result = Ruleur::Validation.validate(rule)
    if result.valid?
      rule
    else
      Rails.logger.error "Invalid rule in #{file}: #{result.errors}"
      nil
    end
  end.compact
  
  rules
end
```

### Pre-deployment Validation

```ruby
# spec/validation/rules_spec.rb
RSpec.describe "Rule Validation" do
  Dir["config/rules/*.yml"].each do |file|
    it "validates #{File.basename(file)}" do
      rule = Ruleur::Persistence::YAMLLoader.load_file(file)
      result = Ruleur::Validation.validate(rule)
      
      expect(result).to be_valid, result.errors.full_messages.join("\n")
    end
  end
end
```

## See Also

- [Validation Guide](/guide/validation) - Validation patterns
- [YAML Loader](./yaml-loader) - Loading rules
- [Repositories](./repositories) - Persisting rules
