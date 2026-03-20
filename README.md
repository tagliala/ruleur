# Ruleur

[![Ruby specs](https://github.com/tagliala/ruleur/actions/workflows/ruby.yml/badge.svg)](https://github.com/tagliala/ruleur/actions/workflows/ruby.yml)
[![RuboCop](https://github.com/tagliala/ruleur/actions/workflows/rubocop.yml/badge.svg)](https://github.com/tagliala/ruleur/actions/workflows/rubocop.yml)

A tiny, composable Business Rules Engine (BRMS) for Ruby with:
- Composable boolean conditions (all/any/not + predicates)
- A small, readable Ruby DSL
- Forward-chaining engine with salience and no-loop
- Optional persistence (serialize/deserialize rules) with a memory or ActiveRecord-backed repository

Status: PoC.

## Why

Separate changing business logic (rules) from code where possible, keep policies small, and make rules testable and inspectable. One use case is replacing complex Pundit checks with rules, but Ruleur is generic.

## Quick start

```ruby
require "ruleur"

MockRecord = Struct.new(:updatable, :draft) do
  def updatable? = !!updatable
  def draft? = !!draft
end

MockUser = Struct.new(:admin) do
  def admin? = !!admin
end

engine = Ruleur.define do
  rule "allow_create", no_loop: true do
    when_any(
      usr(:admin?),
      all(rec(:updatable?), rec(:draft?))
    )
    action { allow! :create }
  end

  rule "allow_update", no_loop: true do
    when_all(
      rec(:updatable?),
      any(
        usr(:admin?),
        all(rec(:draft?), flag(:create))
      )
    )
    action { allow! :update }
  end
end

ctx = engine.run(record: MockRecord.new(true, true), user: MockUser.new(false))
ctx[:allow_create] # => true
ctx[:allow_update] # => true
```

DSL helpers:
- rec(:method_name) => truthy(record.method_name)
- usr(:method_name) => truthy(user.method_name)
- flag(:name) => truthy(:allow_name)
- allow!(:name) => set :allow_name => true
- You can still use eq/gt/lt/includes/matches, all/any/not_ for more complex cases.

## YAML Rules (Database-First Approach)

Ruleur supports defining rules in YAML files for easy storage in databases and version control.

### Loading Rules from YAML

```ruby
require "ruleur"

# Load a single rule file
rule = Ruleur::Persistence::YAMLLoader.load_file('config/rules/allow_create.yml')
engine = Ruleur::Engine.new(rules: [rule])

# Load multiple rules from a directory
rules = Ruleur::Persistence::YAMLLoader.load_directory('config/rules/*.yml')
engine = Ruleur::Engine.new(rules: rules)

# Execute the engine
ctx = engine.run(record: record, user: user)
```

### YAML Rule Format

Example `config/rules/allow_create.yml`:

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

### Exporting DSL Rules to YAML

```ruby
# Create rules using DSL
engine = Ruleur.define do
  rule 'allow_create', salience: 10, tags: ['permissions'], no_loop: true do
    when_any(
      usr(:admin?),
      all(rec(:updatable?), rec(:draft?))
    )
    set :allow_create, true
  end
end

# Save to YAML file
Ruleur::Persistence::YAMLLoader.save_file(
  engine.rules.first,
  'config/rules/allow_create.yml',
  include_metadata: true  # Adds helpful comments
)

# Or get YAML string
yaml_string = Ruleur::Persistence::YAMLLoader.to_yaml(engine.rules.first)
```

## Rule Validation

Before storing or executing rules, validate them to catch errors early:

### Validating YAML Files

```ruby
# Validate a YAML file (structural validation only)
result = Ruleur::Persistence::YAMLLoader.validate_file('config/rules/my_rule.yml')

if result[:valid]
  puts "Rule is valid!"
else
  puts "Errors: #{result[:errors].join(', ')}"
end
```

### Comprehensive Rule Validation

```ruby
# Load rule
rule = Ruleur::Persistence::YAMLLoader.load_file('config/rules/my_rule.yml')

# Validate rule structure and semantics
result = Ruleur::Validation.validate_rule(rule)

if result.valid?
  puts "Rule is valid!"
  puts "Warnings: #{result.warnings.join(', ')}" unless result.warnings.empty?
else
  puts "Errors:"
  result.errors.each { |error| puts "  - #{error}" }
end
```

### Test Execution Validation

Validate that a rule actually works with sample data:

```ruby
# Validate with test context
test_context = {
  user: MockUser.new(admin: true),
  record: MockRecord.new(updatable: true, draft: false)
}

result = Ruleur::Validation.validate_rule(rule, test_context: test_context)

if result.valid?
  puts "Rule validated successfully with test data!"
else
  puts "Runtime errors: #{result.errors.join(', ')}"
end
```

### Validation Components

Ruleur provides granular validation:

```ruby
# Validate just the condition
condition_result = Ruleur::Validation.validate_condition(rule.condition)

# Validate just the action spec
action_result = Ruleur::Validation.validate_action(rule.action_spec)

# Validate a rule hash before deserialization
rule_hash = { name: 'test', condition: {...}, action: {...} }
hash_result = Ruleur::Validation.validate_hash(rule_hash)
```

### Validation Checks

The validation framework performs:

**Structural Validation:**
- Required fields present (name, condition, action)
- Valid node types (pred, all, any, not)
- Valid operators (eq, ne, gt, lt, truthy, includes, etc.)
- Proper condition tree structure

**Semantic Validation:**
- Operators exist in registry
- Call receivers are valid Ref nodes
- Action specs use supported actions (set)
- No unsupported value types

**Test Execution (Optional):**
- Rule can be evaluated with sample data
- No runtime exceptions occur
- Expected outcomes are met

## Persistence

Rules can be serialized to a JSON-able structure (condition AST + action_spec) and stored in a database.

### Memory Repository

```ruby
repo = Ruleur::Persistence::MemoryRepository.new
engine.rules.each { |r| repo.save(r) }

loaded_engine = Ruleur::Engine.new(rules: repo.all)
```

### ActiveRecord Repository (Basic)

Create a table (recommended jsonb for payload):

```ruby
class CreateRuleurRules < ActiveRecord::Migration[7.0]
  def change
    create_table :ruleur_rules do |t|
      t.string :name, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :ruleur_rules, :name, unique: true
  end
end
```

Then:

```ruby
repo = Ruleur::Persistence::ActiveRecordRepository.new
engine.rules.each { |r| repo.save(r) }
rules = repo.all
engine = Ruleur::Engine.new(rules: rules)
```

### Versioned ActiveRecord Repository (Recommended)

For production systems, use `VersionedActiveRecordRepository` to get full version tracking and audit trails.

#### Setup Migrations

Generate migrations using the provided generator:

```ruby
require 'ruleur/generators/migration_generator'

# Write migrations to db/migrate
Ruleur::Generators::MigrationGenerator.write_migrations('db/migrate')
```

Or manually create:

```ruby
# Migration 1: Main rules table
class CreateRuleurRules < ActiveRecord::Migration[7.0]
  def change
    create_table :ruleur_rules do |t|
      t.string :name, null: false, index: { unique: true }
      t.json :payload, null: false
      t.integer :version, null: false, default: 1
      t.string :created_by
      t.string :updated_by
      t.timestamps
    end
  end
end

# Migration 2: Version history table
class CreateRuleurRuleVersions < ActiveRecord::Migration[7.0]
  def change
    create_table :ruleur_rule_versions do |t|
      t.string :rule_name, null: false
      t.integer :version, null: false
      t.json :payload, null: false
      t.string :created_by
      t.text :change_description
      t.datetime :created_at, null: false

      t.index [:rule_name, :version], unique: true
      t.index :rule_name
    end
  end
end
```

#### Using the Versioned Repository

```ruby
# Initialize repository
repo = Ruleur::Persistence::VersionedActiveRecordRepository.new

# Save a rule with audit trail
rule = Ruleur::YAMLLoader.load_file('config/rules/allow_create.yml')
versioned_rule = repo.save(
  rule,
  user: 'alice@example.com',
  change_description: 'Initial version'
)

puts "Saved version #{versioned_rule.version}" # => "Saved version 1"
puts "Created by: #{versioned_rule.created_by}" # => "Created by: alice@example.com"

# Update the rule (increments version)
updated_rule = repo.save(
  modified_rule,
  user: 'bob@example.com',
  change_description: 'Fixed permission logic'
)

puts "Updated to version #{updated_rule.version}" # => "Updated to version 2"

# Load all current rules
rules = repo.all  # Returns array of VersionedRule objects
engine = Ruleur::Engine.new(rules: rules)

# Find a specific rule
rule = repo.find('allow_create')

# Get version history
history = repo.version_history('allow_create')
history.each do |version|
  puts "Version #{version.version} by #{version.created_by}: #{version.change_description}"
end

# Load a specific version
old_version = repo.find_version('allow_create', 1)

# Rollback to a previous version
repo.rollback(
  'allow_create',
  2,  # Target version
  user: 'admin@example.com'
)
```

#### VersionedRule API

Rules loaded from a versioned repository include metadata:

```ruby
rule = repo.find('allow_create')

# Version information
rule.version            # => 3
rule.created_at         # => 2026-01-15 10:30:00 UTC
rule.updated_at         # => 2026-01-20 14:45:00 UTC
rule.created_by         # => "alice@example.com"
rule.updated_by         # => "bob@example.com"

# Check if rule has version tracking
rule.versioned?         # => true

# Get all version metadata
rule.version_info       # => { version: 3, created_at: ..., updated_at: ..., ... }
```

Note: Only a constrained action_spec is persisted (e.g., `{ set: { allow_update: true } }`). Arbitrary Ruby actions are intentionally not serializable.

## Is storing rules in a DB a good practice?

Yes, when you need runtime configurability. Ruleur Phase 2 provides:
- ✅ Pre-validation and compilation of rules before activation (via Validation framework)
- ✅ Versioning and audit trail (via VersionedActiveRecordRepository)
- ✅ Strong typing/constraints on permitted actions (no arbitrary code - only `set` actions)
- ✅ Staged rollout and safe rollback (via `rollback` method)
- ✅ Tests that exercise serialized rules (YAML round-trip tested)

For simpler deployments or when rules are tightly coupled to code, keeping them in code may be preferable.

## Development

- Minimal RSpec suite in `spec/`
- Example script in `examples/policy_poc.rb`
- Engine tracing: `Ruleur::Engine.new(trace: true)`

## Roadmap

- ✅ YAML loader for authoring rules outside Ruby
- ✅ Rule validation framework (structural, semantic, test execution)
- ✅ Versioned rule storage with audit trails (VersionedActiveRecordRepository)
- Rule groups/agenda groups, conflict strategies
- Richer DSL proxies (method-chained refs), temporal ops
- Better explanations/tracing (why a rule did/didn't fire)
- Rule Builder API for programmatic construction
- CLI tools (rake tasks for validation, import/export)
- Web UI for rule management

## Contributing

To contribute to this gem, please follow the standard Git workflow
and submit a pull request. All contributions are welcome and
appreciated.

## License

This gem is licensed under the [MIT License](LICENSE).

## Credits

This gem was co-authored by Geremia Taglialatela and ChatGPT, an AI language
model developed by OpenAI.
