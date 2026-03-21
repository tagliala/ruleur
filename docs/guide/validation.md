# Rule Validation

Ruleur provides a comprehensive validation framework to catch errors before rules are stored or executed. This helps ensure rules are correct, well-formed, and safe to run.

## Why Validate Rules?

When rules are stored in a database or loaded from YAML files, you want to catch errors early:
- **Structural errors**: Missing fields, invalid node types, malformed conditions
- **Semantic errors**: Unknown operators, invalid references, unsupported actions
- **Runtime errors**: Rules that fail to execute due to logic errors

Validation catches these issues before they cause problems in production.

## Quick Example

```ruby
require 'ruleur'

# Load a rule from YAML
rule = Ruleur::Persistence::YAMLLoader.load_file('config/rules/my_rule.yml')

# Validate the rule
result = Ruleur::Validation.validate_rule(rule)

if result.valid?
  puts 'Rule is valid!'
  puts "Warnings: #{result.warnings.join(', ')}" unless result.warnings.empty?
else
  puts 'Validation failed!'
  result.errors.each { |error| puts "  - #{error}" }
end
```

## Validation Methods

The `Ruleur::Validation` module provides four main validation methods:

### `validate_rule(rule, test_context: nil)`

Validates a complete `Ruleur::Rule` object with structural, semantic, and optional execution tests.

```ruby
rule = Ruleur.define do
  rule 'test_rule' do
    match do
      all?(user(:admin?))
    end

    execute do
      allow! :delete
    end
  end
end.rules.first

result = Ruleur::Validation.validate_rule(rule)

puts result.valid?    # => true
puts result.errors    # => []
puts result.warnings  # => []
```

**Parameters:**
- `rule`: A `Ruleur::Rule` instance
- `test_context`: (Optional) A hash or `Context` to test execution

**Returns:** `ValidationResult` with `valid?`, `errors`, and `warnings`

### `validate_hash(rule_hash)`

Validates a rule hash (serialized format) before deserialization. Useful for validating YAML before loading.

```ruby
rule_hash = {
  name: 'test_rule',
  condition: { type: 'pred', op: 'truthy', left: { type: 'ref', root: 'user' }, right: nil },
  execute: { set: { test: true } }
}

result = Ruleur::Validation.validate_hash(rule_hash)

if result.valid?
  rule = Ruleur::Rule.deserialize(rule_hash)
  # Safe to use rule
end
```

**Parameters:**
- `rule_hash`: A hash in Ruleur's serialization format

**Returns:** `ValidationResult`

### `validate_condition(condition)`

Validates a condition node (structural and semantic checks).

```ruby
condition = Ruleur::DSL::Condition::Builders.all?(
  Ruleur::DSL::Condition::Builders.truthy?(
    Ruleur::DSL::Condition::Builders.ref(:user, :admin?)
  )
)

result = Ruleur::Validation.validate_condition(condition)
```

**Parameters:**
- `condition`: A `Condition::Node` instance

**Returns:** `ValidationResult`

### `validate_action(action_spec)`

Validates an action specification.

```ruby
action_spec = { set: { allow_create: true, priority: 'high' } }

result = Ruleur::Validation.validate_action(action_spec)

if result.valid?
  # Action spec is safe to use
end
```

**Parameters:**
- `action_spec`: A hash describing actions

**Returns:** `ValidationResult`

## Validating YAML Files

The `YAMLLoader` includes a convenience method for validating YAML files directly:

```ruby
# Quick validation (structural only)
result = Ruleur::Persistence::YAMLLoader.validate_file('config/rules/my_rule.yml')

if result[:valid]
  puts 'YAML is structurally valid'
else
  puts "Errors: #{result[:errors].join(', ')}"
end
```

For comprehensive validation, load the rule first and use `validate_rule`:

```ruby
# Load from YAML
rule = Ruleur::Persistence::YAMLLoader.load_file('config/rules/my_rule.yml')

# Comprehensive validation
result = Ruleur::Validation.validate_rule(rule)

if result.valid?
  # Safe to save to database
  repository.save(rule)
end
```

## ValidationResult Object

All validation methods return a `ValidationResult` object with:

### `valid?`

Returns `true` if validation passed (no errors).

```ruby
result = Ruleur::Validation.validate_rule(rule)

puts 'All checks passed' if result.valid?
```

### `errors`

Array of error messages. If present, the rule is invalid.

```ruby
unless result.valid?
  result.errors.each do |error|
    puts "ERROR: #{error}"
  end
end
```

### `warnings`

Array of warning messages. Warnings don't make a rule invalid but indicate potential issues.

```ruby
if result.valid? && result.warnings.any?
  puts 'Rule is valid but has warnings:'
  result.warnings.each { |w| puts "  - #{w}" }
end
```

### `to_h`

Converts result to a hash for serialization:

```ruby
result.to_h
# => { valid: true, errors: [], warnings: ["Test execution passed"] }
```

## Test Execution Validation

To ensure a rule works with actual data, provide a test context:

```ruby
User = Struct.new(:admin)
Record = Struct.new(:status)

rule = Ruleur.define do
  rule 'admin_access' do
    match do
      all?(user(:admin))
    end

    execute do
      allow! :access
    end
  end
end.rules.first

# Validate with test data
test_context = {
  user: User.new(true),
  record: Record.new('active')
}

result = Ruleur::Validation.validate_rule(rule, test_context: test_context)

if result.valid?
  puts 'Rule validated and executed successfully'
  # Check warnings for execution feedback
  puts result.warnings # => ["Test execution passed"]
end
```

**Benefits of Test Execution:**
- Catches runtime errors (method missing, type errors)
- Verifies rule logic with sample data
- Confirms expected outcomes

**Example with failure:**

```ruby
rule = Ruleur.define do
  rule 'broken_rule' do
    match do
      all?(user(:nonexistent_method)) # This will fail
    end

    execute do
      allow! :access
    end
  end
end.rules.first

test_context = {
  user: User.new(true),
  record: Record.new('active')
}

result = Ruleur::Validation.validate_rule(rule, test_context: test_context)

puts result.valid?  # => false
puts result.errors  # => ["Test execution failed: undefined method `nonexistent_method'..."]
```

## Validation Checks

The validation framework performs multiple levels of checks:

### Structural Validation

Ensures the rule has valid structure:

- ✅ Rule name is present and non-empty
- ✅ Condition is present
- ✅ Action spec is present
- ✅ Salience is an integer
- ✅ Tags is an array
- ✅ `no_loop` is a boolean

**Example errors:**
```
- Rule name cannot be nil or empty
- Rule condition cannot be nil
- Rule action_spec cannot be nil
- Salience must be an Integer, got String
- Tags must be an Array, got String
- no_loop must be boolean, got String
```

### Condition Validation

Validates the condition tree structure:

- ✅ Valid node types: `pred`, `all`, `any`, `not`
- ✅ Predicates have operators
- ✅ Composite conditions (`all`/`any`) have children arrays
- ✅ `not` conditions have a child
- ✅ Values are valid types: `lit`, `ref`, `call`

**Example errors:**
```
- Invalid condition type: "invalid"
- Predicate missing operator
- all condition must have children array
- Not condition must have child
- Invalid value type: unknown
```

### Semantic Validation

Validates that the rule makes sense:

- ✅ Operators exist in the operator registry
- ✅ Call nodes have valid receiver (must be Ref)
- ✅ Action specs use supported actions (currently only `set`)

**Example errors:**
```
- Unknown operator: "invalid_op"
- Call receiver must be a Ref, got Lit
- Unsupported action type: execute
```

### Action Validation

Validates action specifications:

- ✅ Action spec is a non-empty hash
- ✅ `set` action contains a hash of key-value pairs
- ✅ Values are serializable types

**Example errors:**
```
- Action must be a Hash, got String
- Action cannot be empty
- Action 'set' must be a Hash
```

## Common Validation Patterns

### Pattern 1: Validate Before Saving

Always validate rules before persisting to database:

```ruby
def save_rule(rule, repository)
  # Validate first
  result = Ruleur::Validation.validate_rule(rule)

  raise "Invalid rule: #{result.errors.join(', ')}" unless result.valid?

  # Log warnings
  result.warnings.each { |w| Rails.logger.warn("Rule warning: #{w}") }

  # Safe to save
  repository.save(rule)
end
```

### Pattern 2: Validate YAML Imports

When importing rules from YAML, validate them in a pipeline:

```ruby
def import_rules_from_directory(dir_path, repository)
  Dir.glob("#{dir_path}/*.yml").each do |file|
    # Load rule
    rule = Ruleur::Persistence::YAMLLoader.load_file(file)

    # Validate
    result = Ruleur::Validation.validate_rule(rule)

    if result.valid?
      repository.save(rule)
      puts "✓ Imported: #{rule.name}"
    else
      puts "✗ Failed: #{file}"
      result.errors.each { |e| puts "  - #{e}" }
    end
  end
end
```

### Pattern 3: Validate with Test Suite

Create test cases for your rules and validate execution:

```ruby
describe 'Permission Rules' do
  it 'validates admin access rule' do
    rule = Ruleur::Persistence::YAMLLoader.load_file('rules/admin_access.yml')

    # Test case 1: Admin user
    test_context = {
      user: User.new(role: 'admin'),
      record: Document.new(status: 'draft')
    }

    result = Ruleur::Validation.validate_rule(rule, test_context: test_context)

    expect(result.valid?).to be true
  end
end
```

### Pattern 4: Continuous Validation

Periodically validate all stored rules to catch issues:

```ruby
class RuleHealthCheck
  def self.validate_all_rules(repository)
    report = { valid: 0, invalid: 0, warnings: 0, errors: [] }

    repository.all.each do |rule|
      result = Ruleur::Validation.validate_rule(rule)

      if result.valid?
        report[:valid] += 1
        report[:warnings] += result.warnings.size
      else
        report[:invalid] += 1
        report[:errors] << {
          rule: rule.name,
          errors: result.errors
        }
      end
    end

    report
  end
end

# Run in a rake task or scheduled job
report = RuleHealthCheck.validate_all_rules(repository)
puts "Valid: #{report[:valid]}, Invalid: #{report[:invalid]}"
```

## Best Practices

### 1. Always Validate Before Persistence

Never save a rule without validating it first:

```ruby
# Good
result = Ruleur::Validation.validate_rule(rule)
repository.save(rule) if result.valid?

# Bad - no validation
repository.save(rule) # Might save broken rule!
```

### 2. Use Test Context for Critical Rules

For important business rules, validate with test data:

```ruby
# Create representative test cases
test_cases = [
  { user: admin_user, record: draft_doc },
  { user: regular_user, record: published_doc },
  { user: guest_user, record: private_doc }
]

test_cases.each do |context|
  result = Ruleur::Validation.validate_rule(rule, test_context: context)
  raise 'Failed test case' unless result.valid?
end
```

### 3. Log Warnings

Even valid rules might have warnings worth investigating:

```ruby
result = Ruleur::Validation.validate_rule(rule)

if result.valid?
  repository.save(rule)

  # Log warnings for investigation
  result.warnings.each do |warning|
    Rails.logger.warn("[Rule: #{rule.name}] #{warning}")
  end
end
```

### 4. Handle Validation Errors Gracefully

Provide clear feedback when validation fails:

```ruby
def create_rule(params)
  rule = build_rule_from_params(params)
  result = Ruleur::Validation.validate_rule(rule)

  if result.valid?
    repository.save(rule)
    { success: true, rule: rule }
  else
    {
      success: false,
      errors: result.errors,
      warnings: result.warnings
    }
  end
end
```

### 5. Validate in CI/CD Pipeline

Add validation to your deployment pipeline:

```ruby
# spec/rules_spec.rb
describe 'All YAML Rules' do
  Dir.glob('config/rules/*.yml').each do |file|
    it "validates #{File.basename(file)}" do
      rule = Ruleur::Persistence::YAMLLoader.load_file(file)
      result = Ruleur::Validation.validate_rule(rule)

      expect(result.valid?).to be true,
                                  "Rule validation failed: #{result.errors.join(', ')}"
    end
  end
end
```

## Validation in Web UI

If you're building a rule management UI, integrate validation:

```ruby
class RulesController < ApplicationController
  def create
    rule_hash = params.require(:rule).permit!.to_h

    # Validate hash before deserialization
    result = Ruleur::Validation.validate_hash(rule_hash)

    if result.valid?
      rule = Ruleur::Rule.deserialize(rule_hash)

      # Further validation with test execution
      result = Ruleur::Validation.validate_rule(rule, test_context: build_test_context)

      if result.valid?
        @repository.save(rule)
        render json: { success: true, warnings: result.warnings }
      else
        render json: { success: false, errors: result.errors }, status: :unprocessable_entity
      end
    else
      render json: { success: false, errors: result.errors }, status: :bad_request
    end
  end

  private

  def build_test_context
    {
      user: User.new(role: 'test'),
      record: Document.new(status: 'test')
    }
  end
end
```

## Troubleshooting

### Common Validation Errors

**"Rule name cannot be nil or empty"**
- Ensure every rule has a non-empty name

**"Unknown operator: 'custom_op'"**
- The operator isn't registered in `Ruleur::Operators.registry`
- Check for typos (`truthy` not `trufy`)
- Use standard operators: `eq`, `ne`, `gt`, `gte`, `lt`, `lte`, `in`, `includes`, `matches`, `truthy`, `falsy`, `present`, `blank`

**"Call receiver must be a Ref, got Lit"**
- Method calls must be on references, not literals
- Bad: `call(lit(123), :to_s)`
- Good: `call(ref(:record, :id), :to_s)`

**"Test execution failed: undefined method"**
- The test context objects don't have the methods your rule expects
- Verify your test objects match your production objects

**"all condition has no children"**
- Empty composite conditions (warning, not error)
- Add child conditions or remove the composite

## Next Steps

- **[YAML Rules](./yaml-rules.md)**: Load and validate rules from YAML
- **[Versioning](./versioning.md)**: Store validated rules with audit trails
- **[Persistence](./persistence.md)**: Save validated rules to database

## Related API

- [Ruleur::Validation Module](../api/validation.md)
- [ValidationResult Class](../api/validation.md#validationresult)
- [RuleValidator Class](../api/validation.md#rulevalidator)
