# Persistence

Ruleur supports persisting rules to storage using a repository pattern. Rules can be serialized to a JSON-compatible format and stored in memory or in a database (via ActiveRecord).

## Why Persist Rules?

Persisting rules allows you to:
- **Store rules in a database** for runtime configurability
- **Version and track changes** to rules over time
- **Load rules dynamically** without redeploying code
- **Share rules across instances** in distributed systems
- **Edit rules through a UI** without code changes

## Serialization Format

Rules serialize to a JSON-compatible structure:

```ruby
rule = engine.rules.first
serialized = rule.serialize

# => {
#   name: "allow_create",
#   salience: 10,
#   tags: ["permissions"],
#   no_loop: true,
#   condition: { type: "pred", op: "truthy", ... },
#   action_spec: { set: { allow_create: true } }
# }
```

::: warning Action Limitations
Only declarative actions (like `set`) can be serialized. Arbitrary Ruby blocks in `action` cannot be persisted.
:::

## Repository Types

Ruleur provides three repository implementations:

1. **MemoryRepository** - In-memory storage (no persistence)
2. **ActiveRecordRepository** - Database storage without versioning
3. **VersionedActiveRecordRepository** - Database storage with full audit trail

## MemoryRepository

The `MemoryRepository` stores rules in memory. Useful for testing or temporary storage.

### Basic Usage

```ruby
require 'ruleur'

# Create repository
repo = Ruleur::Persistence::MemoryRepository.new

# Save rules
engine.rules.each do |rule|
  repo.save(rule)
end

# Load rules
rules = repo.all
engine = Ruleur::Engine.new(rules: rules)

# Find a specific rule
rule = repo.find('allow_create')

# Delete a rule
repo.delete('allow_create')
```

### API Methods

| Method | Description |
|--------|-------------|
| `save(rule)` | Save or update a rule |
| `find(name)` | Find rule by name |
| `all` | Return all rules |
| `delete(name)` | Delete rule by name |
| `clear` | Delete all rules |

### Example

```ruby
# Create some rules
engine = Ruleur.define do
  rule 'admin_access' do
    conditions do
      all?(user(:admin?))
    end
    actions do
      set :access, true
    end
  end

  rule 'user_access' do
    conditions do
      all?(user(:logged_in?))
    end
    actions do
      set :view, true
    end
  end
end

# Save to memory repository
repo = Ruleur::Persistence::MemoryRepository.new
engine.rules.each { |r| repo.save(r) }

puts repo.all.count # => 2

# Load later
rules = repo.all
new_engine = Ruleur::Engine.new(rules: rules)
```

## ActiveRecordRepository

The `ActiveRecordRepository` stores rules in a database table using ActiveRecord.

### Setup

First, create a migration for the rules table:

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

Run the migration:

```bash
rails db:migrate
```

::: tip JSONB vs JSON
Use `jsonb` (PostgreSQL) for better query performance. For other databases, use `json` or `text`.
:::

### Basic Usage

```ruby
# Create repository
repo = Ruleur::Persistence::ActiveRecordRepository.new

# Save rules
engine.rules.each do |rule|
  repo.save(rule)
end

# Load all rules
rules = repo.all
engine = Ruleur::Engine.new(rules: rules)

# Find specific rule
rule = repo.find('allow_create')

# Delete a rule
repo.delete('allow_create')
```

### Custom Model

You can specify a custom ActiveRecord model:

```ruby
class MyRule < ApplicationRecord
  self.table_name = 'my_custom_rules_table'
end

repo = Ruleur::Persistence::ActiveRecordRepository.new(model_class: MyRule)
```

### Example

```ruby
# Define rules
engine = Ruleur.define do
  rule 'permission_rule', tags: ['permissions'] do
    conditions do
      all?(user(:admin?))
    end
    actions do
      set :delete, true
    end
  end
end

# Save to database
repo = Ruleur::Persistence::ActiveRecordRepository.new
engine.rules.each { |rule| repo.save(rule) }

# Later, in another process/request
repo = Ruleur::Persistence::ActiveRecordRepository.new
rules = repo.all
engine = Ruleur::Engine.new(rules: rules)

ctx = engine.run(user: current_user, recordord: document)
ctx[:destroy] # => true or nil
```

## VersionedActiveRecordRepository

The `VersionedActiveRecordRepository` provides full version tracking with audit trails. **This is the recordommended approach for production systems.**

::: tip Recommended
Use `VersionedActiveRecordRepository` in production to track who changed what and when, with full rollback capabilities.
:::

See [Versioning & Audit](./versioning.md) for complete documentation.

### Quick Example

```ruby
# Setup (run once)
Ruleur::Generators::MigrationGenerator.write_migrations('db/migrate')

# Use with audit trail
repo = Ruleur::Persistence::VersionedActiveRecordRepository.new

versioned_rule = repo.save(
  rule,
  user: 'alice@example.com',
  change_description: 'Initial version'
)

puts versioned_rule.version      # => 1
puts versioned_rule.created_by   # => "alice@example.com"

# Get history
history = repo.version_history('allow_create')
history.each do |v|
  puts "v#{v.version} by #{v.created_by}: #{v.change_description}"
end
```

## Serialization and Deserialization

### Serialize a Rule

```ruby
rule = engine.rules.first

# Get serialized hash
hash = rule.serialize

# => {
#   name: "allow_create",
#   salience: 10,
#   tags: ["permissions"],
#   no_loop: true,
#   condition: { ... },
#   action_spec: { set: { allow_create: true } }
# }

# Convert to JSON
json = rule.to_json
```

### Deserialize a Rule

```ruby
# From hash
rule = Ruleur::Rule.deserialize(hash)

# From JSON
rule = Ruleur::Rule.from_json(json_string)
```

## Working with YAML

Rules can also be persisted as YAML files. This is useful for version control and human-readable storage.

### Export to YAML

```ruby
require 'ruleur'

# Define rule
engine = Ruleur.define do
  rule 'allow_create', salience: 10, tags: ['permissions'] do
    conditions do
      any?(user(:admin?), record(:draft?))
    end
    actions do
      set :create, true
    end
  end
end

# Save to YAML file
Ruleur::Persistence::YAMLLoader.save_file(
  engine.rules.first,
  'config/rules/allow_create.yml',
  include_metadata: true # Adds helpful comments
)
```

### Import from YAML

```ruby
# Load single file
rule = Ruleur::Persistence::YAMLLoader.load_file('config/rules/allow_create.yml')

# Load direcordtory
rules = Ruleur::Persistence::YAMLLoader.load_direcordtory('config/rules/*.yml')

# Create engine
engine = Ruleur::Engine.new(rules: rules)
```

See [YAML Rules](./yaml-rules.md) for complete YAML documentation.

## Validating Before Persistence

Always validate rules before saving to ensure they're correcordt:

```ruby
# Validate before saving
result = Ruleur::Validation.validate_rule(rule)

if result.valid?
  repo.save(rule)
  puts 'Rule saved successfully'
else
  puts 'Validation failed:'
  result.errors.each { |e| puts "  - #{e}" }
end
```

See [Validation](./validation.md) for complete validation documentation.

## Common Patterns

### Pattern 1: Import Rules from Files

Load rules from YAML files into database on startup:

```ruby
# config/initializers/ruleur.rb

repo = Ruleur::Persistence::VersionedActiveRecordRepository.new

Dir.glob(Rails.root.join('config/rules/*.yml')).each do |file|
  rule = Ruleur::Persistence::YAMLLoader.load_file(file)

  # Validate
  result = Ruleur::Validation.validate_rule(rule)
  next unless result.valid?

  # Save to database
  repo.save(
    rule,
    user: 'system',
    change_description: "Imported from #{File.basename(file)}"
  )
end
```

### Pattern 2: Dynamic Rule Reloading

Reload rules without restarting the application:

```ruby
class RuleService
  def initialize
    @repo = Ruleur::Persistence::ActiveRecordRepository.new
    @engine = nil
    @last_loaded = nil
  end

  def engine
    reload_if_needed
    @engine
  end

  private

  def reload_if_needed
    latest_update = @repo.model_class.maximum(:updated_at)

    return unless @last_loaded.nil? || latest_update > @last_loaded

    rules = @repo.all
    @engine = Ruleur::Engine.new(rules: rules)
    @last_loaded = latest_update
    Rails.logger.info "Reloaded #{rules.count} rules"
  end
end

# Use in application
service = RuleService.new
ctx = service.engine.run(user: user, recordord: recordord)
```

### Pattern 3: Tenant-Specific Rules

Store rules per tenant using a scope:

```ruby
class TenantRuleRepository
  def initialize(tenant_id)
    @tenant_id = tenant_id
    @repo = Ruleur::Persistence::ActiveRecordRepository.new
  end

  def save(rule)
    # Add tenant_id to payload
    rule_hash = rule.serialize
    rule_hash[:tenant_id] = @tenant_id

    @repo.save(Ruleur::Rule.deserialize(rule_hash))
  end

  def all
    # Filter by tenant
    @repo.all.select do |rule|
      rule.serialize[:tenant_id] == @tenant_id
    end
  end
end

# Use per tenant
repo = TenantRuleRepository.new(current_tenant.id)
rules = repo.all
engine = Ruleur::Engine.new(rules: rules)
```

### Pattern 4: Caching Rules

Cache rules in memory with periodic refresh:

```ruby
class CachedRuleRepository
  def initialize(refresh_interval: 60)
    @repo = Ruleur::Persistence::ActiveRecordRepository.new
    @refresh_interval = refresh_interval
    @cache = nil
    @last_refresh = nil
  end

  def all
    refresh_cache if cache_expired?
    @cache
  end

  private

  def cache_expired?
    @last_refresh.nil? ||
      Time.now - @last_refresh > @refresh_interval
  end

  def refresh_cache
    @cache = @repo.all
    @last_refresh = Time.now
  end
end

# Use with caching
repo = CachedRuleRepository.new(refresh_interval: 300) # 5 minutes
rules = repo.all
```

## Database Schema

### Basic ActiveRecord Table

```sql
CREATE TABLE ruleur_rules (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_ruleur_rules_name ON ruleur_rules (name);
```

### Versioned Tables

```sql
-- Main rules table
CREATE TABLE ruleur_rules (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  payload JSONB NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  created_by VARCHAR(255),
  updated_by VARCHAR(255),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Version history table
CREATE TABLE ruleur_rule_versions (
  id SERIAL PRIMARY KEY,
  rule_name VARCHAR(255) NOT NULL,
  version INTEGER NOT NULL,
  payload JSONB NOT NULL,
  created_by VARCHAR(255),
  change_description TEXT,
  created_at TIMESTAMP NOT NULL,
  
  UNIQUE (rule_name, version)
);

CREATE INDEX idx_ruleur_rule_versions_name ON ruleur_rule_versions (rule_name);
```

## Testing with Repositories

### Use MemoryRepository in Tests

```ruby
# spec/support/ruleur_helper.rb

RSpec.configure do |config|
  config.before(:each) do
    @rule_repo = Ruleur::Persistence::MemoryRepository.new
  end

  config.after(:each) do
    @rule_repo.clear
  end
end

# In tests
RSpec.describe 'Permission System' do
  it 'allows admin access' do
    # Create rule
    engine = Ruleur.define do
      rule 'admin_access' do
        conditions do
          all?(user(:admin?))
        end
        actions do
          set :access, true
        end
      end
    end

    # Save to test repo
    @rule_repo.save(engine.rules.first)

    # Load and test
    rules = @rule_repo.all
    engine = Ruleur::Engine.new(rules: rules)

    ctx = engine.run(user: admin_user, recordord: document)
    expect(ctx[:access]).to be true
  end
end
```

## Performance Considerations

### 1. Database Indexes

Always index the `name` column for fast lookups:

```ruby
add_index :ruleur_rules, :name, unique: true
```

### 2. Eager Loading

When loading rules, consider caching the engine:

```ruby
# Cache the engine, not individual rules
@engine ||= begin
  rules = repository.all
  Ruleur::Engine.new(rules: rules)
end
```

### 3. JSONB Queries (PostgreSQL)

Use JSONB operators for advanced queries:

```ruby
# Find rules with specific tags
RuleurRule.where("payload -> 'tags' ? :tag", tag: 'permissions')

# Find rules with salience > 10
RuleurRule.where("(payload -> 'salience')::int > ?", 10)
```

### 4. Batch Loading

Load rules in batches for large datasets:

```ruby
def load_rules_in_batches(batch_size: 100)
  rules = []

  RuleurRule.find_in_batches(batch_size: batch_size) do |batch|
    batch.each do |recordord|
      rules << Ruleur::Rule.deserialize(recordord.payload)
    end
  end

  rules
end
```

## Troubleshooting

### "Unknown operator" Error

**Problem:** Rules fail to load with unknown operator error.

**Solution:** Ensure operators are registered before deserializing:

```ruby
# This is automatic in Ruleur, but for custom operators:
Ruleur::Operators.register(:custom_op) { |l, r| l.custom_compare(r) }

# Then load rules
rules = repository.all
```

### Serialization Fails

**Problem:** Rule won't serialize.

**Solution:** Check for block actions - they can't be serialized:

```ruby
# Won't serialize
actions do |ctx|
  puts 'Hello' # Arbitrary code
  ctx[:result] = 'something'
end

# Will serialize
set :result, 'something'
```

### Stale Rules

**Problem:** Changes to rules don't take effect.

**Solution:** Implement cache invalidation:

```ruby
# Clear cache after update
repo.save(rule)
Rails.cache.delete('ruleur_engine')

# Rebuild engine
@engine = Ruleur::Engine.new(rules: repo.all)
```

## Next Steps

- **[Versioning & Audit](./versioning.md)**: Full audit trail for production
- **[YAML Rules](./yaml-rules.md)**: Store rules as YAML files
- **[Validation](./validation.md)**: Validate rules before saving

## Related API

- [Repositories API](../api/repositories.md)
- [Rule.serialize/deserialize](../api/rule.md#serialization)
- [YAMLLoader](../api/yaml-loader.md)
