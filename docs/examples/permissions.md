# Permission Rules

Learn how to implement authorization and access control using Ruleur.

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
    action { allow! :admin_access }
  end
end

result = engine.run(user: current_user)
is_admin = result[:allow_admin_access]
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
    action { allow! :staff_access }
  end
end
```

## Resource Ownership

### Owner Can Edit

```ruby
engine = Ruleur.define do
  rule "owner_edit" do
    when_all(
      user(:owns?, record),
      not(record(:locked?))
    )
    action { allow! :edit }
  end
end

result = engine.run(user: current_user, record: post)
can_edit = result[:allow_edit]
```

### Admin or Owner

```ruby
engine = Ruleur.define do
  rule "can_delete" do
    when_any(
      user(:admin?),
      all(
        user(:owns?, record),
        record(:deletable?)
      )
    )
    action { allow! :delete }
  end
end
```

## Hierarchical Permissions

### Tiered Access

```ruby
engine = Ruleur.define do
  # Read access - anyone authenticated
  rule "read_access" do
    when_all(user(:authenticated?))
    action { allow! :read }
  end
  
  # Write access - contributors and above
  rule "write_access" do
    when_any(
      user(:contributor?),
      user(:maintainer?),
      user(:admin?)
    )
    action { allow! :write }
  end
  
  # Delete access - maintainers and admins
  rule "delete_access" do
    when_any(
      user(:maintainer?),
      user(:admin?)
    )
    action { allow! :delete }
  end
end
```

## Complex Permission Logic

### Multi-Factor Authorization

```ruby
engine = Ruleur.define do
  rule "approve_document", salience: 10 do
    when_all(
      # Must be approver
      user(:role).in(["approver", "admin"]),
      
      # Must not be the author
      not(user(:id).equals(document(:author_id))),
      
      # Document must be ready
      document(:status).equals("pending_approval"),
      document(:complete?),
      
      # Business hours check
      lit(Time.current.hour).greater_than_or_equal(9),
      lit(Time.current.hour).less_than(17)
    )
    action do
      allow! :approve
      set :approval_type, "standard"
    end
  end
  
  rule "emergency_approve", salience: 20 do
    when_all(
      user(:admin?),
      document(:status).equals("pending_approval"),
      flag(:emergency_mode)
    )
    action do
      allow! :approve
      set :approval_type, "emergency"
    end
  end
end
```

## Feature Flags

### Tiered Features

```ruby
engine = Ruleur.define do
  rule "basic_features" do
    when_all(user(:subscription, :active?))
    action do
      allow! :basic_export
      allow! :basic_analytics
    end
  end
  
  rule "premium_features" do
    when_all(
      user(:subscription, :tier).in(["premium", "enterprise"]),
      user(:subscription, :active?)
    )
    action do
      allow! :advanced_export
      allow! :custom_reports
      allow! :api_access
    end
  end
  
  rule "enterprise_features" do
    when_all(
      user(:subscription, :tier).equals("enterprise"),
      user(:subscription, :active?)
    )
    action do
      allow! :white_label
      allow! :sso
      allow! :audit_logs
    end
  end
end

result = engine.run(user: current_user)
has_api_access = result[:allow_api_access]
```

## Time-Based Permissions

### Business Hours

```ruby
engine = Ruleur.define do
  rule "business_hours_access" do
    when_all(
      user(:employee?),
      lit(Time.current.wday).in([1, 2, 3, 4, 5]), # Mon-Fri
      lit(Time.current.hour).greater_than_or_equal(9),
      lit(Time.current.hour).less_than(17)
    )
    action { allow! :system_access }
  end
  
  rule "after_hours_admin" do
    when_all(user(:admin?))
    action { allow! :system_access }
  end
end
```

## YAML Example

```yaml
# config/rules/permissions/can_edit.yml
name: can_edit
salience: 10
tags: [permissions, edit]
condition:
  type: any
  children:
    # Admin can always edit
    - type: pred
      op: truthy
      left:
        type: call
        recv: { type: ref, root: user }
        method: admin?
    
    # Owner can edit if not locked
    - type: all
      children:
        - type: pred
          op: call
          left:
            type: call
            recv: { type: ref, root: user }
            method: owns?
          args:
            - type: ref
              root: record
        - type: not
          child:
            type: pred
            op: truthy
            left:
              type: call
              recv: { type: ref, root: record }
              method: locked?
action:
  set:
    allow_edit: true
    edit_reason: "User has edit permissions"
```

## Real-World Example: Blog Authorization

```ruby
class BlogPermissions
  def self.engine
    @engine ||= Ruleur.define do
      # Anyone can view published posts
      rule "view_published" do
        when_all(post(:published?))
        action { allow! :view }
      end
      
      # Authors can view their drafts
      rule "view_own_draft" do
        when_all(
          user(:owns?, post),
          post(:draft?)
        )
        action { allow! :view }
      end
      
      # Authors can edit their own posts if not published
      rule "edit_own_draft" do
        when_all(
          user(:owns?, post),
          post(:draft?),
          not(post(:locked?))
        )
        action do
          allow! :edit
          allow! :delete
        end
      end
      
      # Editors can edit any post
      rule "editor_access" do
        when_all(
          user(:role).in(["editor", "admin"]),
          not(post(:archived?))
        )
        action do
          allow! :edit
          allow! :publish
          allow! :unpublish
        end
      end
      
      # Admins can do everything
      rule "admin_full_access" do
        when_all(user(:admin?))
        action do
          allow! :edit
          allow! :delete
          allow! :publish
          allow! :unpublish
          allow! :lock
        end
      end
    end
  end
  
  def self.check(user, post, action)
    result = engine.run(user: user, post: post)
    result[:"allow_#{action}"] == true
  end
end

# Usage
if BlogPermissions.check(current_user, @post, :edit)
  # Allow editing
else
  # Deny access
end
```

## Testing Permissions

```ruby
RSpec.describe "Blog Permissions" do
  let(:engine) { BlogPermissions.engine }
  
  describe "view access" do
    it "allows viewing published posts" do
      user = User.new
      post = Post.new(published: true)
      
      result = engine.run(user: user, post: post)
      expect(result[:allow_view]).to be true
    end
    
    it "allows authors to view their drafts" do
      user = User.new(id: 1)
      post = Post.new(author_id: 1, published: false)
      
      result = engine.run(user: user, post: post)
      expect(result[:allow_view]).to be true
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

## See Also

- [Workflow Automation](./workflow) - Approval workflows
- [Conditions Guide](/guide/conditions) - Complex conditions
- [DSL Basics](/guide/dsl-basics) - DSL syntax
