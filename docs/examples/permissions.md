# Permission Rules

Learn how to implement authorization and access control using Ruleur.

## Security Principle: Deny by Default

**Access control is only granted when explicitly allowed.** This is a fundamental security principle:

> *"The default rule should always be: deny access unless explicitly permitted."*
> — [OWASP Access Control](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/)

With Ruleur, you only define when access is **granted**. If no rule sets a permission flag, access is implicitly denied.

```ruby
engine = Ruleur.define do
  # Access is granted only if this rule fires
  rule "admin_update" do
    when_all(user(:admin?))
    allow! :update
  end
  # No rule for guest? => access denied by default
end

result = engine.run(user: guest, record: doc)
result[:update]  # => nil (denied, no rule granted access)
```

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
    allow! :admin_access
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
    allow! :staff_access
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
    allow! :update
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
    allow! :destroy
  end
end
```

## Hierarchical Permissions

### Tiered Access

```ruby
engine = Ruleur.define do
  rule "authenticated_show" do
    when_all(user(:authenticated?))
    allow! :show
  end

  rule "contributor_update" do
    when_any(
      user(:contributor?),
      user(:maintainer?),
      user(:admin?)
    )
    allow! :update
  end

  rule "maintainer_destroy" do
    when_any(
      user(:maintainer?),
      user(:admin?)
    )
    allow! :destroy
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
    allow! :approve
  end

  rule "emergency_approve", salience: 20 do
    when_all(
      user(:admin?),
      eq(record_val(:status), "pending_approval"),
      flag(:emergency_mode)
    )
    allow! :approve
  end
end
```

## Feature Flags

### Tiered Features

```ruby
engine = Ruleur.define do
  rule "basic_features" do
    when_all(user(:subscription, :active?))
    allow! :basic_export
    allow! :basic_analytics
  end

  rule "premium_features" do
    when_all(
      user(:subscription, :tier).in(["premium", "enterprise"]),
      user(:subscription, :active?)
    )
    allow! :advanced_export
    allow! :custom_reports
    allow! :api_access
  end

  rule "enterprise_features" do
    when_all(
      user(:subscription, :tier).equals("enterprise"),
      user(:subscription, :active?)
    )
    allow! :white_label
    allow! :sso
    allow! :audit_logs
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
    allow! :system_access
  end

  rule "after_hours_admin" do
    when_all(user(:admin?))
    allow! :system_access
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
        allow! :show
      end

      rule "own_draft_show" do
        when_all(
          user(:owns?, record),
          record(:draft?)
        )
        allow! :show
      end

      rule "own_draft_update" do
        when_all(
          user(:owns?, record),
          record(:draft?),
          not(record(:locked?))
        )
        allow! :update
        allow! :destroy
      end

      rule "editor_update" do
        when_all(
          user(:role).in(["editor", "admin"]),
          not(record(:archived?))
        )
        allow! :update
        allow! :publish
      end

      rule "admin_crud" do
        when_all(user(:admin?))
        allow! :show
        allow! :update
        allow! :destroy
        allow! :publish
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

### The Ruleur Approach: Deny by Default

With Ruleur, you only define **when access is granted**. Everything else is denied by default:

```ruby
engine = Ruleur.define do
  rule "admin_crud", salience: 100, no_loop: true, tags: [:admin] do
    when_all(user(:admin?))
    allow! :show
    allow! :create
    allow! :update
    allow! :destroy
  end

  rule "draft_owner_crud", salience: 50, no_loop: true, tags: [:ownership, :draft] do
    when_all(
      record(:draft?),
      eq(record_val(:owner_id), user_val(:id))
    )
    allow! :show
    allow! :update
    allow! :destroy
  end

  rule "review_owner_update", salience: 50, no_loop: true, tags: [:lifecycle, :review] do
    when_all(
      record(:in_review?),
      eq(record_val(:owner_id), user_val(:id))
    )
    allow! :update
  end

  rule "review_approver_update", salience: 45, no_loop: true, tags: [:lifecycle, :review] do
    when_all(
      record(:in_review?),
      user(:approver?),
      eq(record_val(:department_id), user_val(:department_id))
    )
    allow! :update
  end

  rule "published_show", salience: 50, no_loop: true, tags: [:lifecycle, :published] do
    when_all(record(:published?))
    allow! :show
  end

  rule "published_owner_destroy", salience: 45, no_loop: true, tags: [:lifecycle, :published] do
    when_all(
      record(:published?),
      eq(record_val(:owner_id), user_val(:id))
    )
    allow! :destroy
  end

  rule "owner_crud", salience: 40, no_loop: true, tags: [:ownership] do
    when_all(eq(record_val(:owner_id), user_val(:id)))
    allow! :show
    allow! :update
    allow! :destroy
  end

  rule "department_show", salience: 30, no_loop: true, tags: [:department] do
    when_all(
      record(:visible_to_department?),
      eq(record_val(:department_id), user_val(:department_id))
    )
    allow! :show
  end

  rule "shared_show", salience: 25, no_loop: true, tags: [:sharing] do
    when_all(record(:shared_with_user))
    allow! :show
  end

  rule "public_show", salience: 20, no_loop: true, tags: [:visibility] do
    when_all(record(:public?))
    allow! :show
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

### 1. Deny by Default

Never explicitly deny in rules. Simply don't grant access unless the conditions are met:

```ruby
# Bad: Explicit deny
rule "deny_guests" do
  when_all(not(user(:authenticated?)))
  set :update, false  # Don't do this
end

# Good: Only grant when appropriate
rule "auth_update" do
  when_all(user(:authenticated?))
  allow! :update
end
```

### 2. Use High Salience for Admin Bypass

Place admin rules at high salience so they fire first:

```ruby
rule "admin_crud", salience: 100 do
  when_all(user(:admin?))
  allow! :show
  allow! :create
  allow! :update
  allow! :destroy
end
```

### 3. Test Both Granted and Denied Cases

```ruby
it "grants update to admin" do
  expect(engine.run(user: admin, record: doc)[:update]).to be true
end

it "denies update to guest" do
  expect(engine.run(user: guest, record: doc)[:update]).to be_nil
end
```

### 4. Audit Your Rules

Ruleur makes it easy to review all access rules in one place. Regularly audit:
- Are all permission grants intentional?
- Is the salience ordering correct?
- Are there any gaps in coverage?

## See Also

- [OWASP Top 10: Broken Access Control](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/)
- [Workflow Automation](./workflow) - Approval workflows
- [Conditions Guide](/guide/conditions) - Complex conditions
- [DSL Basics](/guide/dsl-basics) - DSL syntax
