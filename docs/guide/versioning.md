# Versioning & Audit Trail

Ruleur provides comprehensive version tracking and audit trails through `VersionedActiveRecordRepository`. Every rule change is tracked with full history and rollback support.

## Why Version Rules?

**Audit Compliance** - Know who changed what and when

**Safe Rollback** - Revert bad rules without data loss

**Change History** - See evolution of business logic over time

**Debugging** - Trace issues to specific rule versions

**Collaboration** - Multiple people can safely manage rules

## Setup

### 1. Generate Migrations

```ruby
require 'ruleur/generators/migration_generator'

Ruleur::Generators::MigrationGenerator.write_migrations('db/migrate')
```

This creates two migrations:

**`create_ruleur_rules.rb`** - Main rules table
```ruby
create_table :ruleur_rules do |t|
  t.string :name, null: false, index: { unique: true }
  t.json :payload, null: false
  t.integer :version, null: false, default: 1
  t.string :created_by
  t.string :updated_by
  t.timestamps
end
```

**`create_ruleur_rule_versions.rb`** - Version history
```ruby
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
```

### 2. Run Migrations

```bash
bundle exec rake db:migrate
```

### 3. Initialize Repository

```ruby
repo = Ruleur::Persistence::VersionedActiveRecordRepository.new
```

Or with custom models:

```ruby
repo = Ruleur::Persistence::VersionedActiveRecordRepository.new(
  model_class: MyRuleModel,
  version_model_class: MyRuleVersionModel
)
```

## Basic Usage

### Saving Rules

```ruby
rule = Ruleur::Persistence::YAMLLoader.load_file('config/rules/allow_create.yml')

# Save with audit info
versioned_rule = repo.save(
  rule,
  user: 'alice@example.com',
  change_description: 'Initial version'
)

puts versioned_rule.version       # => 1
puts versioned_rule.created_by    # => "alice@example.com"
```

### Updating Rules

```ruby
# Modify the rule
modified_rule = Ruleur::Persistence::YAMLLoader.load_file('config/rules/allow_create.yml')

# Save creates new version automatically
versioned_rule = repo.save(
  modified_rule,
  user: 'bob@example.com',
  change_description: 'Fixed permission logic for draft documents'
)

puts versioned_rule.version       # => 2
puts versioned_rule.updated_by    # => "bob@example.com"
```

### Loading Rules

```ruby
# Get all current rules (latest versions)
rules = repo.all  # Returns Array<VersionedRule>

# Get specific rule
rule = repo.find('allow_create')

# Check version info
if rule
  puts "Version: #{rule.version}"
  puts "Created: #{rule.created_at}"
  puts "Last updated: #{rule.updated_at}"
  puts "Created by: #{rule.created_by}"
  puts "Updated by: #{rule.updated_by}"
end
```

## Version History

### Viewing History

```ruby
history = repo.version_history('allow_create')

history.each do |version|
  puts "Version #{version.version}"
  puts "  Created: #{version.created_at}"
  puts "  By: #{version.created_by}"
  puts "  Changes: #{version.change_description}"
  puts "  ---"
end
```

Output:
```
Version 3
  Created: 2024-03-20 15:30:00 UTC
  By: bob@example.com
  Changes: Added draft document check
  ---
Version 2
  Created: 2024-03-20 14:15:00 UTC
  By: bob@example.com
  Changes: Fixed permission logic
  ---
Version 1
  Created: 2024-03-20 10:00:00 UTC
  By: alice@example.com
  Changes: Initial version
  ---
```

### Loading Specific Versions

```ruby
# Load version 2
old_rule = repo.find_version('allow_create', 2)

if old_rule
  puts old_rule.version           # => 2
  puts old_rule.change_description # => "Fixed permission logic"
  
  # You can run this old version
  engine = Ruleur::Engine.new(rules: [old_rule])
  ctx = engine.run(user: user, record: record)
end
```

## Rollback

### Rolling Back Changes

```ruby
# Rollback to version 2
result = repo.rollback(
  'allow_create',
  2,                              # Target version
  user: 'admin@example.com'
)

puts result.version               # => 4 (new version, not 2!)
puts result.change_description    # => "Rolled back to version 2"
```

::: tip
Rollback creates a **new version** with the content from the target version. This preserves the complete audit trail - you never lose history.
:::

### Rollback Workflow Example

```ruby
# Before rollback
history = repo.version_history('my_rule')
# v1: Initial, v2: Update 1, v3: Bad change

# Rollback to v2
repo.rollback('my_rule', 2, user: 'admin@example.com')

# After rollback
history = repo.version_history('my_rule')
# v1: Initial
# v2: Update 1
# v3: Bad change
# v4: Rolled back to version 2 (contains v2 content)
```

## VersionedRule API

Rules loaded from versioned repository include metadata:

```ruby
rule = repo.find('allow_create')

# Version information
rule.version            # Integer: version number
rule.created_at         # Time: when rule was first created
rule.updated_at         # Time: when rule was last updated
rule.created_by         # String: who created the rule
rule.updated_by         # String: who last updated the rule

# Check if versioned
rule.versioned?         # => true

# Get all metadata
info = rule.version_info
# => {
#   version: 3,
#   created_at: 2024-03-20 10:00:00 UTC,
#   updated_at: 2024-03-20 15:30:00 UTC,
#   created_by: "alice@example.com",
#   updated_by: "bob@example.com",
#   change_description: nil  # Only on historical versions
# }

# VersionedRule is still a Rule
rule.name               # Rule methods work normally
rule.condition
rule.action_spec
```

## Advanced Patterns

### Approval Workflow

```ruby
# Save as draft (not active)
rule = create_rule_from_yaml(yaml_content)
draft_rule = repo.save(
  rule,
  user: current_user.email,
  change_description: 'Proposed change for review'
)

# Store approval state separately
RuleApproval.create!(
  rule_name: draft_rule.name,
  version: draft_rule.version,
  status: 'pending',
  requester: current_user.email
)

# Approval happens later
if approved?
  # Rule is already saved, just mark as approved
  approval.update!(status: 'approved', approved_by: approver.email)
  
  # Optionally add approval note
  repo.save(
    draft_rule,
    user: 'system',
    change_description: "Approved by #{approver.email}"
  )
end
```

### Staged Rollout

```ruby
# Create new version but don't activate yet
new_rule = modify_rule(existing_rule)
staged = repo.save(
  new_rule,
  user: 'deploy@system',
  change_description: 'Staged for canary deployment'
)

# Store rollout state
Rollout.create!(
  rule_name: staged.name,
  version: staged.version,
  stage: 'canary',
  rollout_percentage: 10
)

# Load rules with rollout logic
def load_rules_for_user(user)
  current_rules = repo.all
  
  current_rules.map do |rule|
    rollout = Rollout.find_by(rule_name: rule.name, stage: 'canary')
    
    if rollout && should_use_canary?(user, rollout.rollout_percentage)
      # Use canary version
      repo.find_version(rule.name, rollout.version)
    else
      # Use production version
      rule
    end
  end
end
```

### Diff Between Versions

```ruby
require 'hashdiff'

v1 = repo.find_version('my_rule', 1)
v2 = repo.find_version('my_rule', 2)

v1_hash = Ruleur::Persistence::Serializer.rule_to_h(v1)
v2_hash = Ruleur::Persistence::Serializer.rule_to_h(v2)

diff = Hashdiff.diff(v1_hash, v2_hash)
diff.each do |change|
  puts change.inspect
end
```

### Backup and Restore

```ruby
# Backup all rules with history
backup = {
  timestamp: Time.now.utc,
  rules: {}
}

repo.all.each do |rule|
  backup[:rules][rule.name] = {
    current: Ruleur::Persistence::Serializer.rule_to_h(rule),
    history: repo.version_history(rule.name).map do |version|
      {
        version: version.version,
        payload: version.payload,
        created_at: version.created_at,
        created_by: version.created_by,
        change_description: version.change_description
      }
    end
  }
end

File.write('rules_backup.json', JSON.pretty_generate(backup))

# Restore from backup
backup = JSON.parse(File.read('rules_backup.json'))
backup['rules'].each do |name, data|
  rule = Ruleur::Persistence::Serializer.rule_from_h(data['current'].deep_symbolize_keys)
  repo.save(
    rule,
    user: 'backup-restore@system',
    change_description: "Restored from backup #{backup['timestamp']}"
  )
end
```

## Transaction Safety

All repository operations use database transactions:

```ruby
# Atomic save with version creation
repo.save(rule, user: 'alice', change_description: 'Update')
# If version creation fails, rule save is rolled back

# Delete is transactional
repo.delete('my_rule')
# Both rule and all versions deleted atomically

# Rollback is transactional
repo.rollback('my_rule', 2, user: 'admin')
# Loading old version and creating new version happen atomically
```

Row-level locking prevents race conditions:

```ruby
# Two users save at the same time
# User A: gets version 5
# User B: waits for A, then gets version 6
# No version conflicts
```

## Best Practices

### ✅ Do

- **Always provide user and description**: Essential for audit trails
- **Use semantic descriptions**: "Fixed draft check" not "Update"
- **Test before saving**: Use validation framework first
- **Regular backups**: Export version history periodically
- **Monitor version growth**: Set up alerts for rapid changes
- **Document rollback reasons**: Explain why in change description

### ❌ Don't

- **Don't skip change descriptions**: Makes history useless
- **Don't use generic users**: "system" tells you nothing
- **Don't rollback blindly**: Understand why the rule changed
- **Don't delete versions manually**: Use repo.delete() only
- **Don't save on every tiny change**: Batch related changes
- **Don't forget to test after rollback**: Old versions may have issues

### Example: Good Audit Trail

```ruby
# Bad
repo.save(rule, user: 'user', change_description: 'update')

# Good
repo.save(
  rule,
  user: "#{current_user.name} <#{current_user.email}>",
  change_description: "Fixed draft document permission check - now correctly allows authors to edit their own drafts (fixes #123)"
)
```

## Troubleshooting

### "Version conflict" errors

Use transactions and let the repository handle locking:

```ruby
# Wrong: manual version management
rule.version += 1  # Don't do this!

# Right: let repository handle it
repo.save(rule, user: user, change_description: desc)
```

### "Rollback to non-existent version"

Check version exists first:

```ruby
history = repo.version_history('my_rule')
available_versions = history.map(&:version)

if available_versions.include?(target_version)
  repo.rollback('my_rule', target_version, user: user)
else
  puts "Version #{target_version} doesn't exist!"
  puts "Available: #{available_versions.join(', ')}"
end
```

### Large version history

Consider archiving old versions:

```ruby
# Keep last 100 versions, archive rest
history = repo.version_history('my_rule')

if history.size > 100
  old_versions = history[100..-1]
  
  # Archive to S3/file storage
  archive_versions(old_versions)
  
  # Delete from database (custom SQL)
  versions_to_delete = old_versions.map(&:version)
  # ... delete logic
end
```

## Monitoring & Alerting

### Version Change Rate

```ruby
# Alert if rule changes more than 5 times in an hour
recent_versions = RuleVersion
  .where(rule_name: 'critical_rule')
  .where('created_at > ?', 1.hour.ago)

if recent_versions.count > 5
  alert "Rule #{rule_name} changed #{recent_versions.count} times in the last hour!"
end
```

### Who's Changing What

```ruby
# Report of changes by user
changes_by_user = RuleVersion
  .where('created_at > ?', 1.week.ago)
  .group(:created_by)
  .count

changes_by_user.each do |user, count|
  puts "#{user}: #{count} changes"
end
```

## Next Steps

- [Persistence](./persistence) - Learn about other repository types
- [Validation](./validation) - Validate before saving
- [API Reference: Repositories](/api/repositories) - Detailed API docs

[← Back to Guide](./index) | [Next: Advanced Topics →](./advanced)
