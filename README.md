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

## Why Ruleur Over If-Then-Else? A Real-World Pundit Comparison

Let's compare Pundit's traditional if-then-else approach with a Business Rules Management System using a complex, real-world scenario.

### The Scenario: Enterprise Document Permissions

Imagine a document management system with complex permission rules:

- Admins have full access
- Editors can modify documents they own or documents in their department
- Viewers can see documents shared with them or public documents
- Documents have lifecycle states: draft, review, published, archived
- Special rules for confidential documents
- Department-specific overrides
- Time-based rules (documents expire after certain dates)
- Audit requirements for sensitive operations

### The Pundit Approach (If-Then-Else)

```ruby
# app/policies/document_policy.rb
class DocumentPolicy < ApplicationPolicy
  def create?
    # Simple: authenticated users can create
    user.present?
  end

  def show?
    return true if user.admin?
    return false if record.confidential? && !user_clearance?
    return true if record.public?
    return true if record.owner == user
    return true if user.department == record.department && record.visible_to_department?
    return user.document_accesses.exists?(document_id: record.id)
  end

  def update?
    return false if record.archived?
    return true if user.admin?

    if record.draft?
      return record.owner == user
    elsif record.in_review?
      return user.reviewer? || record.owner == user
    elsif record.published?
      return record.owner == user if user.editor?
      return false
    end

    false
  end

  def destroy?
    return true if user.admin?
    return false if record.published?
    return record.owner == user
  end

  def download?
    return false if record.expired?
    return true if user.admin?
    return true if record.owner == user
    return user.document_accesses.exists?(document_id: record.id)
  end

  private

  def user_clearance?
    user.clearance_level >= record.clearance_level
  end
end
```

**Problems with this approach:**

1. **Logic duplication**: Similar checks appear in multiple methods (`user.admin?`, clearance checks)
2. **Hidden dependencies**: Methods call private helpers that aren't obvious
3. **Impossible to audit**: Where do you even start to understand what an "admin" can do?
4. **Testing nightmare**: You need to mock the entire User and Document models
5. **No versioning**: Changing one rule might break another silently
6. **Business analysts can't read it**: Ruby code isn't business-friendly
7. **State explosion**: Adding a new document state requires updating every method

### The Ruleur Approach

```ruby
# config/rules/document_permissions.rb
engine = Ruleur.define do
  # Highest priority: Admins bypass everything
  rule "admin_full_access", salience: 100, no_loop: true, tags: [:admin, :bypass] do
    when_all(usr(:admin?))
    set :can_create, true
    set :can_read, true
    set :can_update, true
    set :can_delete, true
    set :can_download, true
  end

  # Confidentiality rules
  rule "deny_highly_confidential", salience: 90, no_loop: true, tags: [:confidentiality] do
    when_all(
      rec(:confidential?),
      not_(usr(:high_clearance?))
    )
    set :can_read, false
    set :can_download, false
  end

  rule "deny_expired_documents", salience: 85, no_loop: true, tags: [:lifecycle] do
    when_all(
      rec(:expired?)
    )
    set :can_read, false
    set :can_download, false
  end

  # Document lifecycle: Draft state
  rule "draft_owner_full_control", salience: 50, no_loop: true, tags: [:lifecycle, :draft] do
    when_all(
      rec(:draft?),
      eq(rec_val(:owner_id), usr_val(:id))
    )
    set :can_update, true
    set :can_delete, true
  end

  # Document lifecycle: Review state
  rule "review_owner_can_update", salience: 50, no_loop: true, tags: [:lifecycle, :review] do
    when_all(
      rec(:in_review?),
      eq(rec_val(:owner_id), usr_val(:id))
    )
    set :can_update, true
  end

  rule "review_approver_can_update", salience: 45, no_loop: true, tags: [:lifecycle, :review] do
    when_all(
      rec(:in_review?),
      usr(:approver?),
      eq(rec_val(:department_id), usr_val(:department_id))
    )
    set :can_update, true
  end

  # Document lifecycle: Published state
  rule "published_read_only", salience: 50, no_loop: true, tags: [:lifecycle, :published] do
    when_all(rec(:published?))
    set :can_update, false
    set :can_delete, false
  end

  rule "published_owner_can_archive", salience: 45, no_loop: true, tags: [:lifecycle, :published] do
    when_all(
      rec(:published?),
      eq(rec_val(:owner_id), usr_val(:id))
    )
    set :can_delete, true
  end

  # Archived documents: read-only for everyone
  rule "archived_read_only", salience: 50, no_loop: true, tags: [:lifecycle, :archived] do
    when_all(rec(:archived?))
    set :can_update, false
    set :can_delete, false
  end

  # Ownership rules
  rule "owner_full_control", salience: 40, no_loop: true, tags: [:ownership] do
    when_all(eq(rec_val(:owner_id), usr_val(:id)))
    set :can_read, true
    set :can_update, true
    set :can_delete, true
    set :can_download, true
  end

  # Department access
  rule "department_access", salience: 30, no_loop: true, tags: [:department] do
    when_all(
      rec(:visible_to_department?),
      eq(rec_val(:department_id), usr_val(:department_id))
    )
    set :can_read, true
    set :can_download, true
  end

  # Explicit document sharing
  rule "explicit_sharing", salience: 25, no_loop: true, tags: [:sharing] do
    when_all(
      rec(:shared_with_user)
    )
    set :can_read, true
    set :can_download, true
  end

  # Public documents
  rule "public_read_access", salience: 20, no_loop: true, tags: [:visibility] do
    when_all(rec(:public?))
    set :can_read, true
  end

  # Default: deny everything
  rule "default_deny", salience: 0, no_loop: true, tags: [:default] do
    when_any(truthy(true))
    set :can_create, false
    set :can_read, false
    set :can_update, false
    set :can_delete, false
    set :can_download, false
  end
end
```

### Pundit Integration with Ruleur

```ruby
# app/policies/document_policy.rb
class DocumentPolicy < ApplicationPolicy
  class Config
    attr_accessor :engine

    def self.rules
      @rules ||= Ruleur.define do
        # ... rules from above ...
      end
    end
  end

  def create?
    ctx[:can_create]
  end

  def show?
    ctx[:can_read]
  end

  def update?
    ctx[:can_update]
  end

  def destroy?
    ctx[:can_delete]
  end

  def download?
    ctx[:can_download]
  end

  private

  def ctx
    @ctx ||= begin
      facts = {
        record: record,
        user: user,
        rec: record,
        usr: user
      }
      Config.rules.run(facts)
    end
  end
end
```

### Benefits of the BRMS Approach

| Aspect | Pundit (If-Then-Else) | Ruleur (BRMS) |
|--------|------------------------|---------------|
| **Readability** | Logic buried in Ruby code | Business rules in declarative DSL |
| **Auditability** | Scattered across methods | All rules visible in one place |
| **Testability** | Need complex mocks | Test rules in isolation with simple data |
| **Versioning** | Git diffs are unreadable | Dedicated versioning with audit trail |
| **Business User Access** | Requires developer | YAML/UI makes it accessible |
| **Conflict Resolution** | Implicit (first match wins) | Explicit via salience |
| **Testing** | Integration tests required | Unit test each rule independently |
| **Debugging** | Step through code | Trace which rules fired |

### Testing: Pundit vs Ruleur

**Pundit test (complex setup required):**

```ruby
RSpec.describe DocumentPolicy do
  let(:user) { User.new(admin: false, department: dept) }
  let(:document) { Document.new(owner: user, state: :draft) }

  describe "#update?" do
    context "when user is owner and document is draft" do
      it { expect(subject.update?).to be true }
    end

    context "when document is published" do
      let(:document) { Document.new(owner: user, state: :published) }
      it { expect(subject.update?).to be false }
    end
    # ... dozens more contexts
  end
end
```

**Ruleur test (simple, focused):**

```ruby
RSpec.describe "Document Lifecycle Rules" do
  let(:engine) { Ruleur::Config.rules }
  let(:ctx) { |ex| engine.run(record: ex.description[:record], user: ex.description[:user]) }

  it "allows owner to update draft documents", record: draft_doc, user: owner do
    expect(ctx[:can_update]).to be true
  end

  it "denies updates on published documents", record: published_doc, user: owner do
    expect(ctx[:can_update]).to be false
  end

  it "allows admins to update published documents", record: published_doc, user: admin do
    expect(ctx[:can_update]).to be true
  end
end
```

### When to Use Ruleur

**Good fit:**
- Complex permission logic with many conditions
- Rules that change frequently
- Requirements for audit trails
- Business users who need to review/approve rules
- Multiple similar policies that could share rules

**Not needed:**
- Simple yes/no permissions
- Rules that rarely change
- Small number of conditions

### Conclusion

While Pundit's if-then-else approach works well for simple authorization, complex enterprise scenarios benefit from a Business Rules Management System that provides:

1. **Declarative rules** that business analysts can read
2. **Salience-based conflict resolution** that makes priority explicit
3. **Audit trails** for compliance requirements
4. **Independent testability** of each rule
5. **Versioning** for safe rule changes
6. **Centralized logic** that avoids duplication

Ruleur lets you separate *what* the rules are (business logic) from *how* they're evaluated (engine), making your authorization system maintainable as requirements grow.

## License

This gem is licensed under the [MIT License](LICENSE).

## Credits

This gem was co-authored by Geremia Taglialatela and ChatGPT, an AI language
model developed by OpenAI.
