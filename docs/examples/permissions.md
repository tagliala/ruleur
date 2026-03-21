# Permission Rules

Learn how to implement authorization and access control using Ruleur.

## Access Control Principle: Deny by Default

In access control, the default should always be **deny**. Only grant access when conditions are explicitly met:

```ruby
engine = Ruleur.define do
  # Access is only granted if this rule fires
  rule "admin_update" do
    when_all(user(:admin?))
    set :update, true
  end
end

result = engine.run(user: guest, record: doc)
result[:update]  # => nil (no rule matched, so denied)
```

This is a fundamental security principle: assume no access unless explicitly granted.

## Overview

Permission rules help you:
- Implement role-based access control (RBAC)
- Check resource ownership
- Enforce hierarchical permissions
- Combine multiple authorization factors

## Basic Permission Check

### Simple Role Check

```ruby
engine = Ruleur.define do
  rule "admin_access" do
    when_all(user(:admin?))
    set :admin_access, true
  end
end

result = engine.run(user: current_user)
result[:admin_access]  # => true or nil
```

### Multiple Roles

```ruby
engine = Ruleur.define do
rule "staff_access" do
  when_any(
    user(:admin?),
    user(:moderator?),
    user(:support?)
  )
  set :staff_access, true
end
end
```

## Resource Ownership

### Owner Can Update

```ruby
engine = Ruleur.define do
rule "owner_update" do
  when_all(
    user(:owns?, record),
    not(record(:locked?))
  )
  set :update, true
end
end

result = engine.run(user: current_user, record: post)
result[:update]  # => true or nil
```

### Admin or Owner

```ruby
engine = Ruleur.define do
rule "admin_or_owner_destroy" do
  when_any(
    user(:admin?),
    all(
      user(:owns?, record),
      record(:deletable?)
    )
  )
  set :destroy, true
end
end
```

## Hierarchical Permissions

### Tiered Access

```ruby
engine = Ruleur.define do
rule "authenticated_show" do
  when_all(user(:authenticated?))
  set :show, true
end

rule "contributor_update" do
  when_any(
    user(:contributor?),
    user(:maintainer?),
    user(:admin?)
  )
  set :update, true
end

rule "maintainer_destroy" do
  when_any(
    user(:maintainer?),
    user(:admin?)
  )
  set :destroy, true
end
end
```

## Complex Permission Logic

### Multi-Factor Authorization

```ruby
engine = Ruleur.define do
rule "standard_approve", salience: 10 do
  when_all(
    user(:role).in(["approver", "admin"]),
    not(eq(record_val(:author_id), user_val(:id))),
    eq(record_val(:status), "pending_approval"),
    record(:complete?),
    gte(lit(Time.current.hour), 9),
    lt(lit(Time.current.hour), 17)
  )
  set :approve, true
end

rule "emergency_approve", salience: 20 do
  when_all(
    user(:admin?),
    eq(record_val(:status), "pending_approval"),
    flag(:emergency_mode)
  )
  set :approve, true
end
end
```

## Feature Flags

### Tiered Features

```ruby
engine = Ruleur.define do
rule "basic_features" do
  when_all(user(:subscription, :active?))
  set :basic_export, true
  set :basic_analytics, true
end

rule "premium_features" do
  when_all(
    user(:subscription, :tier).in(["premium", "enterprise"]),
    user(:subscription, :active?)
  )
  set :advanced_export, true
  set :custom_reports, true
  set :api_access, true
end

rule "enterprise_features" do
  when_all(
    user(:subscription, :tier).equals("enterprise"),
    user(:subscription, :active?)
  )
  set :white_label, true
  set :sso, true
  set :audit_logs, true
end
end
```

## Time-Based Permissions

### Business Hours

```ruby
engine = Ruleur.define do
rule "business_hours_access" do
  when_all(
    user(:employee?),
    in(lit(Time.current.wday), [1, 2, 3, 4, 5]),
    gte(lit(Time.current.hour), 9),
    lt(lit(Time.current.hour), 17)
  )
  set :system_access, true
end

rule "after_hours_admin" do
  when_all(user(:admin?))
  set :system_access, true
end
end
```

## Real-World Example: Blog Authorization

```ruby
class BlogPolicy
  def self.engine
    @engine ||= Ruleur.define do
rule "published_show" do
  when_all(record(:published?))
  set :show, true
end

rule "own_draft_show" do
  when_all(
    user(:owns?, record),
    record(:draft?)
  )
  set :show, true
end

rule "own_draft_update" do
  when_all(
    user(:owns?, record),
    record(:draft?),
    not(record(:locked?))
  )
  set :update, true
  set :destroy, true
end

rule "editor_update" do
  when_all(
    user(:role).in(["editor", "admin"]),
    not(record(:archived?))
  )
  set :update, true
  set :publish, true
end

rule "admin_crud" do
  when_all(user(:admin?))
  set :show, true
  set :update, true
  set :destroy, true
  set :publish, true
end
    end
  end

  def self.authorize(user, record, action)
    result = engine.run(user: user, record: record)
    result[action] == true
  end
end

if BlogPolicy.authorize(current_user, @post, :update)
  # Allow updating
else
  # Deny access (implicit by default)
end
```

## Testing Permissions

```ruby
RSpec.describe BlogPolicy do
  let(:engine) { BlogPolicy.engine }

  describe ":update" do
    it "grants update to owner of draft" do
      user = User.new(id: 1)
      record = Post.new(author_id: 1, status: 'draft')

      result = engine.run(user: user, record: record)
      expect(result[:update]).to be true
    end

    it "denies update to non-owner of published post" do
      user = User.new(id: 1)
      record = Post.new(author_id: 2, status: 'published')

      result = engine.run(user: user, record: record)
      expect(result[:update]).to be_nil
    end
  end
end
```

## Complex Pundit Comparison

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
class DocumentPolicy < ApplicationPolicy
  def create?
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
end
```

**Problems with this approach:**

1. **Logic duplication**: Similar checks appear in multiple methods
2. **Hidden dependencies**: Private helpers aren't obvious
3. **Impossible to audit**: Where do you even start to understand what an "admin" can do?
4. **Testing nightmare**: Complex mocks required
5. **No versioning**: Changing one rule might break another silently
6. **Business analysts can't read it**: Ruby code isn't business-friendly

### The Ruleur Approach

With Ruleur, you only define **when a value is set**. If no rule matches, the value remains unset:

```ruby
engine = Ruleur.define do
rule "admin_crud", salience: 100, no_loop: true, tags: [:admin] do
  when_all(user(:admin?))
  set :show, true
  set :create, true
  set :update, true
  set :destroy, true
end

rule "draft_owner_crud", salience: 50, no_loop: true, tags: [:ownership, :draft] do
  when_all(
    record(:draft?),
    eq(record_val(:owner_id), user_val(:id))
  )
  set :show, true
  set :update, true
  set :destroy, true
end

rule "review_owner_update", salience: 50, no_loop: true, tags: [:lifecycle, :review] do
  when_all(
    record(:in_review?),
    eq(record_val(:owner_id), user_val(:id))
  )
  set :update, true
end

rule "review_approver_update", salience: 45, no_loop: true, tags: [:lifecycle, :review] do
  when_all(
    record(:in_review?),
    user(:approver?),
    eq(record_val(:department_id), user_val(:department_id))
  )
  set :update, true
end

rule "published_show", salience: 50, no_loop: true, tags: [:lifecycle, :published] do
  when_all(record(:published?))
  set :show, true
end

rule "published_owner_destroy", salience: 45, no_loop: true, tags: [:lifecycle, :published] do
  when_all(
    record(:published?),
    eq(record_val(:owner_id), user_val(:id))
  )
  set :destroy, true
end

rule "owner_crud", salience: 40, no_loop: true, tags: [:ownership] do
  when_all(eq(record_val(:owner_id), user_val(:id)))
  set :show, true
  set :update, true
  set :destroy, true
end

rule "department_show", salience: 30, no_loop: true, tags: [:department] do
  when_all(
    record(:visible_to_department?),
    eq(record_val(:department_id), user_val(:department_id))
  )
  set :show, true
end

rule "shared_show", salience: 25, no_loop: true, tags: [:sharing] do
  when_all(record(:shared_with_user))
  set :show, true
end

rule "public_show", salience: 20, no_loop: true, tags: [:visibility] do
  when_all(record(:public?))
  set :show, true
end
end
```

### Pundit Integration with Ruleur

```ruby
class DocumentPolicy < ApplicationPolicy
  def create?
    ctx[:create] == true
  end

  def show?
    ctx[:show] == true
  end

  def update?
    ctx[:update] == true
  end

  def destroy?
    ctx[:destroy] == true
  end

  private

  def ctx
    @ctx ||= Ruleur::Config.engine.run(record: record, user: user)
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
| **Security** | Easy to miss implicit denies | Deny-by-default is explicit |

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
RSpec.describe "Document Permissions" do
  let(:engine) { DocumentPolicy.engine }

  it "grants update to owner of draft" do
    result = engine.run(user: owner, record: draft_doc)
    expect(result[:update]).to be true
  end

  it "denies update to non-owner of published" do
    result = engine.run(user: other_user, record: published_doc)
    expect(result[:update]).to be_nil
  end

  it "grants update to admin regardless of document state" do
    result = engine.run(user: admin, record: published_doc)
    expect(result[:update]).to be true
  end
end
```

## Security Best Practices

### 1. Set Values Explicitly

Only set values when conditions are met. Don't use `set :key, false`:

```ruby
# Avoid: Using false values
rule "not_authenticated" do
  when_all(not(user(:authenticated?)))
  set :update, false
end

# Better: Only set when true
rule "authenticated_update" do
  when_all(user(:authenticated?))
  set :update, true
end
```

### 2. Order Conditions by Cost

Place cheap/fast checks before expensive ones. This avoids unnecessary work:

```ruby
# Bad: Expensive check first
rule "check_permission" do
  when_all(
    expensive_database_query(:has_permission?),  # Expensive - do last
    user(:admin?)                              # Cheap - check first
  )
  set :update, true
end

# Good: Cheap checks first
rule "check_permission" do
  when_all(
    user(:admin?),                             # Cheap - check first
    expensive_database_query(:has_permission?)   # Expensive - only if needed
  )
  set :update, true
end
```

### 3. Use Salience for Priority

Place high-priority rules (like admin bypass) at high salience so they fire first:

```ruby
rule "admin_crud", salience: 100 do
  when_all(user(:admin?))
  set :show, true
  set :create, true
  set :update, true
  set :destroy, true
end
```

### 4. Test Both Set and Unset Cases

```ruby
it "grants update to admin" do
  expect(engine.run(user: admin, record: doc)[:update]).to be true
end

it "denies update to guest" do
  expect(engine.run(user: guest, record: doc)[:update]).to be_nil
end
```

### 5. Audit Your Rules

Ruleur makes it easy to review all access rules in one place. Regularly audit:
- Are all permission grants intentional?
- Is the salience ordering correct?
- Are there any gaps in coverage?

## See Also

- [OWASP: Broken Access Control](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/) - Security principle
- [Workflow Automation](./workflow) - Approval workflows
- [Conditions Guide](/guide/conditions) - Complex conditions
- [DSL Basics](/guide/dsl-basics) - DSL syntax
