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

## See Also

- [Workflow Automation](./workflow) - Approval workflows
- [Conditions Guide](/guide/conditions) - Complex conditions
- [DSL Basics](/guide/dsl-basics) - DSL syntax
