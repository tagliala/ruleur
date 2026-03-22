# Repositories

Repositories provide persistence for rules with version management and audit trails.

## Overview

Ruleur provides repository implementations for:
- In-memory storage (development/testing)
- ActiveRecord database storage (production)
- Versioned storage with audit trails

## Base: `Ruleur::Persistence::Repository::Base`

Abstract base class for repositories.

### Instance Methods

#### `#save(rule)`

Saves a rule.

```ruby
repository.save(rule)
```

**Parameters:**
- `rule` (Ruleur::Rule) - Rule to save

**Returns:**
- Saved rule with ID

#### `#find(id)`

Finds a rule by ID.

```ruby
rule = repository.find(123)
```

**Parameters:**
- `id` - Rule identifier

**Returns:**
- `Ruleur::Rule` or `nil`

#### `#find_by_name(name)`

Finds a rule by name.

```ruby
rule = repository.find_by_name('discount_rule')
```

**Parameters:**
- `name` (String) - Rule name

**Returns:**
- `Ruleur::Rule` or `nil`

#### `#all`

Returns all rules.

```ruby
rules = repository.all
```

**Returns:**
- `Array\<Ruleur::Rule\>`

#### `#delete(id)`

Deletes a rule.

```ruby
repository.delete(123)
```

**Parameters:**
- `id` - Rule identifier

**Returns:**
- `Boolean` - Success status

## Memory Repository

In-memory storage for development and testing.

### Class: `Ruleur::Persistence::Repository::Memory`

```ruby
repository = Ruleur::Persistence::Repository::Memory.new
repository.save(rule)
```

**Use Cases:**
- Testing
- Development
- Temporary rule storage
- Non-persistent engines

## ActiveRecord Repository

Database storage using ActiveRecord.

### Class: `Ruleur::Persistence::Repository::ActiveRecord`

```ruby
repository = Ruleur::Persistence::Repository::ActiveRecord.new
repository.save(rule)
```

### Setup

Generate migration:

```bash
rails generate ruleur:migration
rails db:migrate
```

### Configuration

```ruby
# config/initializers/ruleur.rb
Ruleur.configure do |config|
  config.repository = Ruleur::Persistence::Repository::ActiveRecord.new
end
```

### Additional Methods

#### `#find_by_tags(tags)`

Finds rules by tags.

```ruby
rules = repository.find_by_tags(%i[permissions admin])
```

#### `#active`

Returns only active rules.

```ruby
rules = repository.active
```

## Versioned ActiveRecord Repository

Database storage with full version history.

### Class: `Ruleur::Persistence::Repository::VersionedActiveRecord`

```ruby
repository = Ruleur::Persistence::Repository::VersionedActiveRecord.new
```

### Features

- Full version history
- Change tracking
- Rollback support
- Audit trail (who/when)

### Versioning Methods

#### `#save_version(rule, metadata = {})`

Saves a new version of a rule.

```ruby
repository.save_version(
  rule,
  changed_by: current_user.id,
  reason: 'Updated discount threshold'
)
```

**Parameters:**
- `rule` (Ruleur::Rule) - Rule to save
- `metadata` (Hash) - Version metadata
  - `changed_by` - User ID
  - `reason` - Change reason
  - Custom fields

#### `#versions(rule_id)`

Gets all versions of a rule.

```ruby
versions = repository.versions(123)
versions.each do |version|
  puts "Version #{version.version_number} by #{version.changed_by}"
end
```

**Returns:**
- `Array\<RuleVersion\>` - All versions, newest first

#### `#version(rule_id, version_number)`

Gets a specific version.

```ruby
rule_v2 = repository.version(123, 2)
```

**Parameters:**
- `rule_id` - Rule identifier
- `version_number` (Integer) - Version number

**Returns:**
- `Ruleur::Rule` - Rule at that version

#### `#rollback(rule_id, version_number)`

Rolls back to a previous version.

```ruby
repository.rollback(123, 2)
```

**Parameters:**
- `rule_id` - Rule identifier
- `version_number` (Integer) - Target version

**Returns:**
- `Ruleur::Rule` - Restored rule

#### `#diff(rule_id, from_version, to_version)`

Shows differences between versions.

```ruby
changes = repository.diff(123, 1, 2)
```

**Returns:**
- `Hash` - Change description

## Examples

### Basic Usage with ActiveRecord

```ruby
# Initialize repository
repo = Ruleur::Persistence::Repository::ActiveRecord.new

# Save a rule
rule = Ruleur.define do
  rule 'discount' do
    conditions do
      all?(order(:total).gt?(100))
    end
    actions do
      set :discount, 0.1
    end
  end
end.rules.first

saved_rule = repo.save(rule)

# Find rule
found = repo.find(saved_rule.id)
found = repo.find_by_name('discount')

# Load all rules into engine
rules = repo.all
engine = Ruleur::Engine.new(rules: rules)
```

### Versioned Repository

```ruby
repo = Ruleur::Persistence::Repository::VersionedActiveRecord.new

# Save initial version
rule = create_discount_rule(threshold: 100)
repo.save_version(
  rule,
  changed_by: user.id,
  reason: 'Initial version'
)

# Update rule
rule = create_discount_rule(threshold: 150)
repo.save_version(
  rule,
  changed_by: user.id,
  reason: 'Increased threshold to 150'
)

# View history
versions = repo.versions(rule.id)
versions.each do |v|
  puts "v#{v.version_number}: #{v.reason} by #{v.changed_by}"
end

# Rollback if needed
repo.rollback(rule.id, 1)
```

### Loading Rules from Database

```ruby
# Load all active rules
repo = Ruleur::Persistence::Repository::ActiveRecord.new
rules = repo.active

engine = Ruleur::Engine.new(rules: rules)
result = engine.run(context_data)
```

### Filtering by Tags

```ruby
# Load only permission rules
permission_rules = repo.find_by_tags([:permissions])
engine = Ruleur::Engine.new(rules: permission_rules)
```

## Database Schema

### Rules Table

```ruby
create_table :rules do |t|
  t.string :name, null: false, index: { unique: true }
  t.text :yaml_content, null: false
  t.integer :salience, default: 0
  t.string :tags, array: true, default: []
  t.boolean :active, default: true
  t.timestamps
end
```

### Rule Versions Table

```ruby
create_table :rule_versions do |t|
  t.references :rule, null: false, foreign_key: true
  t.integer :version_number, null: false
  t.text :yaml_content, null: false
  t.integer :changed_by
  t.string :reason
  t.jsonb :metadata, default: {}
  t.timestamps

  t.index %i[rule_id version_number], unique: true
end
```

## Best Practices

### Validate Before Saving

```ruby
def save_rule(rule)
  result = Ruleur::Validation.validate(rule)

  raise ValidationError, result.errors unless result.valid?

  repository.save(rule)
end
```

### Always Provide Version Metadata

```ruby
repository.save_version(
  rule,
  changed_by: current_user.id,
  reason: params[:change_reason],
  ip_address: request.ip,
  user_agent: request.user_agent
)
```

### Cache Rules in Production

```ruby
class CachedRuleRepository
  def initialize(repository)
    @repository = repository
  end

  def all
    Rails.cache.fetch('rules/all', expires_in: 5.minutes) do
      @repository.all
    end
  end

  def clear_cache
    Rails.cache.delete('rules/all')
  end
end
```

## See Also

- [Persistence Guide](/guide/persistence) - Persistence patterns
- [Versioning Guide](/guide/versioning) - Version management
- [Validation](./validation) - Rule validation
