# Your First Rule

Let's build a simple permission system to understand how Ruleur works.

## The Scenario

We're building a document management system where:
- Admins can do anything
- Regular users can only update their own draft documents

## Step 1: Define Domain Objects

First, let's create simple test objects:

```ruby
require 'ruleur'

class Document
  attr_reader :author_id, :status

  def initialize(author_id:, status:)
    @author_id = author_id
    @status = status
  end

  def draft?
    status == 'draft'
  end
end

class User
  attr_reader :id, :role

  def initialize(id:, role:)
    @id = id
    @role = role
  end

  def admin?
    role == 'admin'
  end
end
```

## Step 2: Create Rules (Grant Access Only)

Ruleur follows **deny by default** - you only define when access is granted:

```ruby
engine = Ruleur.define do
  rule 'admin_update' do
    when_any(user(:admin?))
    set :update, true
  end

  rule 'author_draft_update' do
    when_all(
      record(:draft?),
      eq(record_val(:author_id), user_val(:id))
    )
    set :update, true
  end
end
```

### DSL Helpers Explained

- `user(:admin?)` - checks if `user.admin?` returns truthy
- `record(:draft?)` - checks if `record.draft?` returns truthy
- `set :update, true` - grants update permission
- `salience` - priority (higher fires first)

## Step 3: Run the Engine

```ruby
admin = User.new(id: 1, role: 'admin')
doc = Document.new(author_id: 2, status: 'published')

ctx = engine.run(user: admin, record: doc)
ctx[:update]  # => true (admin_update fired)

author = User.new(id: 2, role: 'user')
draft = Document.new(author_id: 2, status: 'draft')

ctx = engine.run(user: author, record: draft)
ctx[:update]  # => true (author_draft_update fired)

other_user = User.new(id: 3, role: 'user')
ctx = engine.run(user: other_user, record: draft)
ctx[:update]  # => nil (denied by default)
```

## Step 4: Add More Complex Logic

```ruby
engine = Ruleur.define do
  rule 'admin_update' do
    when_any(user(:admin?))
    set :update, true
  end

  rule 'author_draft_update' do
    when_all(
      record(:draft?),
      eq(record_val(:author_id), user_val(:id))
    )
    set :update, true
  end

  rule 'published_requires_admin' do
    when_all(
      not(record(:draft?)),
      user(:admin?)
    )
    set :update, true
  end
end
```

## Complete Example

```ruby
require 'ruleur'

class Document
  attr_reader :author_id, :status
  def initialize(author_id:, status:)
    @author_id = author_id
    @status = status
  end
  def draft? = status == 'draft'
end

class User
  attr_reader :id, :role
  def initialize(id:, role:)
    @id = id
    @role = role
  end
  def admin? = role == 'admin'
end

engine = Ruleur.define do
  rule 'admin_update' do
    when_any(user(:admin?))
    set :update, true
  end

  rule 'author_draft_update' do
    when_all(
      record(:draft?),
      eq(record_val(:author_id), user_val(:id))
    )
    set :update, true
  end
end

admin = User.new(id: 1, role: 'admin')
author = User.new(id: 2, role: 'user')
doc = Document.new(author_id: 2, status: 'draft')

puts engine.run(user: admin, record: doc)[:update]     # => true
puts engine.run(user: author, record: doc)[:update]    # => true
puts engine.run(user: User.new(id: 3, role: 'user'), record: doc)[:update]  # => nil
```

## Understanding Rule Execution

When you run `engine.run()`:

1. **Context is created** with the provided facts (user, record)
2. **Eligible rules are identified** - rules whose conditions match
3. **Rules fire in priority order** (salience: highest first)
4. **Actions grant permissions** - only explicit grants set flags
5. **Access is denied by default** - no grant means no access

## Debugging with Trace

Enable tracing to see which rules fire:

```ruby
engine = Ruleur::Engine.new(rules: engine.rules, trace: true)
ctx = engine.run(user: admin, record: doc)

# Output:
# [Ruleur] Firing: admin_update (salience=10)
# [Ruleur] Facts changed: update
```

## Security: Deny by Default

Ruleur follows the **deny by default** security principle:

> *"The default rule should always be: deny access unless explicitly permitted."*
> — [OWASP Access Control](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/)

With Ruleur, you only define **when access is granted**. If no rule sets a permission, access is implicitly denied.

```ruby
engine = Ruleur.define do
  rule 'admin_update' do
    when_any(user(:admin?))
    set :update, true
  end
  # No rule for guest? => access denied by default
end

ctx = engine.run(user: guest, record: doc)
ctx[:update]  # => nil (denied, no rule granted access)
```

This is more secure than explicitly denying - you can't accidentally forget to deny something.

## What's Next?

Now you understand the basics! Explore:

- [**Guide: DSL Basics**](/guide/dsl-basics) - Learn all DSL helpers and operators
- [**Guide: YAML Rules**](/guide/yaml-rules) - Store rules in YAML files
- [**Guide: Validation**](/guide/validation) - Validate rules before execution
- [**Examples: Permission Rules**](/examples/permissions) - More complex permission scenarios

## Try It Yourself

Experiment with:
1. Adding more rules (e.g., editors can update)
2. Using different operators (`gt`, `lt`, `includes`)
3. Chaining conditions with `all` and `any`
4. Creating rules that depend on other rule outcomes

[Continue to Guide →](/guide/)
