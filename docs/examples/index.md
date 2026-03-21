# Examples

Welcome to the Ruleur examples section. Here you'll find practical, real-world examples of using Ruleur to solve common business logic problems.

## Featured Examples

### [Permission Rules](./permissions)
Implement role-based access control and complex permission logic.

**Use Cases:**
- Role-based access control (RBAC)
- Resource ownership checks
- Hierarchical permissions
- Feature flags and entitlements

### [Workflow Automation](./workflow)
Build approval workflows and state machine logic.

**Use Cases:**
- Document approval workflows
- Order processing pipelines
- Multi-step validation flows
- State transitions

### [Dynamic Pricing](./pricing)
Calculate prices, discounts, and fees based on business rules.

**Use Cases:**
- Tiered pricing models
- Dynamic discounts
- Shipping cost calculation
- Promotional rules

### [Real-World Cases](./real-world)
Complete examples from production systems.

**Use Cases:**
- E-commerce order validation
- SaaS feature access
- Insurance policy evaluation
- Content moderation

## Quick Examples

### Simple Permission Check

```ruby
engine = Ruleur.define do
  rule "admin_access" do
    when_all(user(:admin?))
    allow! :access
  end

  rule "owner_update" do
    when_all(user(:owner?, record))
    allow! :update
  end
end

result = engine.run(user: current_user, record: @post)
can_update = result[:update] # => true or nil
```

### Discount Calculation

```ruby
engine = Ruleur.define do
  rule "bulk_discount", salience: 10 do
    when_all(order(:total).greater_than(500))
    action { set :discount, 0.15 }
  end
  
  rule "vip_discount", salience: 20 do
    when_all(customer(:vip?))
    action { set :discount, 0.20 }
  end
end

result = engine.run(order: order, customer: customer)
discount = result[:discount] # Higher salience wins
```

### Workflow State Transition

```ruby
engine = Ruleur.define do
  rule "can_submit" do
    when_all(
      document(:draft?),
      document(:complete?),
      not(document(:submitted?))
    )
    action { allow! :submit }
  end
  
  rule "can_approve" do
    when_all(
      user(:approver?),
      document(:submitted?),
      not(document(:approved?))
    )
    action { allow! :approve }
  end
end
```

## Example Patterns

### Fact Checking Pattern

Check conditions and set result flags:

```ruby
rule "validation" do
  when_all(
    user(:authenticated?),
    user(:email_verified?),
    not(user(:banned?))
  )
  action { set :user_valid, true }
end
```

### Calculation Pattern

Compute values based on inputs:

```ruby
rule "calculate_total" do
  when_all(order(:items).present)
  action do
    order = context[:order]
    subtotal = order.items.sum(&:price)
    tax = subtotal * 0.08
    shipping = calculate_shipping(order)
    
    set :subtotal, subtotal
    set :tax, tax
    set :shipping, shipping
    set :total, subtotal + tax + shipping
  end
end
```

### Chaining Pattern

Rules that depend on other rules' results:

```ruby
rule "step1" do
  when_all(input(:valid?))
  action { set :step1_complete, true }
end

rule "step2" do
  when_all(
    flag(:step1_complete),
    input(:ready?)
  )
  action { set :step2_complete, true }
end
```

## Loading Examples

All examples are available in the repository:

```bash
git clone https://github.com/tagliala/ruleur.git
cd ruleur/examples
```

## Try It Yourself

Each example includes:
- Complete working code
- Test cases
- YAML versions
- Variations and alternatives

## Need Help?

- Check the [Guide](/guide/) for concepts
- See the [API Reference](/api/) for details
- Join discussions on [GitHub](https://github.com/tagliala/ruleur/discussions)

## Contributing Examples

Have a great example? We'd love to include it! See our [Contributing Guide](https://github.com/tagliala/ruleur/blob/main/CONTRIBUTING.md).
