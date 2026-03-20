# Your First Rule

Let's build a simple permission system to understand how Ruleur works.

## The Scenario

We're building a document management system where:
- Admins can do anything
- Regular users can only edit their own draft documents

## Step 1: Define Domain Objects

First, let's create simple test objects:

```ruby
require 'ruleur'

# Simple document model
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

# Simple user model
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

## Step 2: Create Rules with DSL

Now let's define the permission rules:

```ruby
engine = Ruleur.define do
  # Rule 1: Admins can always edit
  rule 'admin_can_edit', salience: 10 do
    when_any(
      usr(:admin?)
    )
    action { allow! :edit }
  end
  
  # Rule 2: Users can edit their own drafts
  rule 'author_can_edit_draft', salience: 5 do
    when_all(
      rec(:draft?),
      eq(
        call(rec, :author_id),
        call(usr, :id)
      )
    )
    action { allow! :edit }
  end
end
```

### DSL Helpers Explained

- `usr(:admin?)` - shorthand for "user.admin? is truthy"
- `rec(:draft?)` - shorthand for "record.draft? is truthy"
- `allow! :edit` - shorthand for "set :allow_edit to true"
- `salience` - priority (higher fires first)

## Step 3: Run the Engine

```ruby
# Test case 1: Admin user
admin = User.new(id: 1, role: 'admin')
doc = Document.new(author_id: 2, status: 'published')

ctx = engine.run(user: admin, record: doc)
puts ctx[:allow_edit]  # => true (admin_can_edit fired)

# Test case 2: Author editing their draft
author = User.new(id: 2, role: 'user')
draft = Document.new(author_id: 2, status: 'draft')

ctx = engine.run(user: author, record: draft)
puts ctx[:allow_edit]  # => true (author_can_edit_draft fired)

# Test case 3: Non-author trying to edit
other_user = User.new(id: 3, role: 'user')
ctx = engine.run(user: other_user, record: draft)
puts ctx[:allow_edit]  # => nil (no rules fired)
```

## Step 4: Add More Complex Logic

Let's add a rule for published documents:

```ruby
engine = Ruleur.define do
  rule 'admin_can_edit', salience: 10 do
    when_any(usr(:admin?))
    action { allow! :edit }
  end
  
  rule 'author_can_edit_draft', salience: 5 do
    when_all(
      rec(:draft?),
      eq(call(rec, :author_id), call(usr, :id))
    )
    action { allow! :edit }
  end
  
  # New rule: Published docs need admin approval
  rule 'published_needs_admin', salience: 8 do
    when_all(
      not_(rec(:draft?)),
      usr(:admin?)
    )
    action { set :requires_approval, true }
  end
end
```

## Complete Example

Here's the full working example:

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
  rule 'admin_can_edit', salience: 10 do
    when_any(usr(:admin?))
    action { allow! :edit }
  end
  
  rule 'author_can_edit_draft', salience: 5 do
    when_all(
      rec(:draft?),
      eq(call(rec, :author_id), call(usr, :id))
    )
    action { allow! :edit }
  end
end

# Test it
admin = User.new(id: 1, role: 'admin')
author = User.new(id: 2, role: 'user')
doc = Document.new(author_id: 2, status: 'draft')

puts engine.run(user: admin, record: doc)[:allow_edit]    # => true
puts engine.run(user: author, record: doc)[:allow_edit]   # => true
puts engine.run(user: User.new(id: 3, role: 'user'), record: doc)[:allow_edit]  # => nil
```

## Understanding Rule Execution

When you run `engine.run()`:

1. **Context is created** with the provided facts (user, record)
2. **Eligible rules are identified** - rules whose conditions match
3. **Rules fire in priority order** (salience: highest first)
4. **Actions modify context** - set facts that other rules can use
5. **Process repeats** until no more rules are eligible

## Debugging with Trace

Enable tracing to see what's happening:

```ruby
engine = Ruleur::Engine.new(rules: engine.rules, trace: true)
ctx = engine.run(user: admin, record: doc)

# Output:
# [Ruleur] Firing: admin_can_edit (salience=10)
# [Ruleur] Facts changed: allow_edit
```

## What's Next?

Now you understand the basics! Explore:

- [**Guide: DSL Basics**](/guide/dsl-basics) - Learn all DSL helpers and operators
- [**Guide: YAML Rules**](/guide/yaml-rules) - Store rules in YAML files
- [**Guide: Validation**](/guide/validation) - Validate rules before execution
- [**Examples: Permission Rules**](/examples/permissions) - More complex permission scenarios

## Try It Yourself

Experiment with:
1. Adding more rules (e.g., editors can review)
2. Using different operators (`gt`, `lt`, `includes`)
3. Chaining multiple facts (`rec(:draft?) AND rec(:reviewed?)`)
4. Creating rules that depend on other rule outcomes

[Continue to Guide →](/guide/)
