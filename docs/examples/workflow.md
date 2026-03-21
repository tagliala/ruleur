# Workflow Automation

Build approval workflows, state machines, and multi-step processes with Ruleur.

## Overview

Workflow rules help you:
- Model approval processes
- Implement state machines
- Chain dependent steps
- Track workflow state

## Basic Workflow

### Simple Approval Flow

```ruby
engine = Ruleur.define do
  rule 'can_submit' do
    match do
      all?(
        document(:draft?),
        document(:valid?),
        not?(document(:submitted?))
      )
    end
    execute do
      allow! :submit
    end
  end

  rule 'can_approve' do
    match do
      all?(
        user(:approver?),
        document(:submitted?),
        not?(document(:approved?))
      )
    end
    execute do
      allow! :approve
    end
  end

  rule 'can_reject' do
    match do
      all?(
        user(:approver?),
        document(:submitted?)
      )
    end
    execute do
      allow! :reject
    end
  end
end
```

## State Machine

### Document Lifecycle

```ruby
engine = Ruleur.define do
  # Draft -> Submitted
  rule 'submit_document', salience: 100 do
    match do
      all?(
        document(:status).eq?('draft'),
        document(:complete?),
        flag(:action_submit)
      )
    end
    execute do
      call_method document, :update_status, 'submitted'
      set :status_changed, true
      set :new_status, 'submitted'
    end
  end

  # Submitted -> Under Review
  rule 'start_review', salience: 90 do
    match do
      all?(
        document(:status).eq?('submitted'),
        user(:reviewer?),
        flag(:action_start_review)
      )
    end
    execute do
      call_method document, :update_status, 'under_review'
      call_method document, :assign_reviewer, context[:user]
      set :status_changed, true
      set :new_status, 'under_review'
    end
  end

  # Under Review -> Approved
  rule 'approve_document', salience: 80 do
    match do
      all?(
        document(:status).eq?('under_review'),
        user(:approver?),
        flag(:action_approve)
      )
    end
    execute do
      call_method document, :update_status, 'approved'
      call_method document, :set_approved_by, context[:user]
      set :status_changed, true
      set :new_status, 'approved'
    end
  end

  # Under Review -> Rejected
  rule 'reject_document', salience: 80 do
    match do
      all?(
        document(:status).eq?('under_review'),
        user(:approver?),
        flag(:action_reject),
        flag(:rejection_reason).present
      )
    end
    execute do
      call_method document, :update_status, 'rejected'
      call_method document, :add_rejection_reason, context[:rejection_reason]
      set :status_changed, true
      set :new_status, 'rejected'
    end
  end

  # Rejected -> Draft (resubmit)
  rule 'resubmit_document', salience: 70 do
    match do
      all?(
        document(:status).eq?('rejected'),
        user(:owns?, document),
        flag(:action_resubmit)
      )
    end
    execute do
      call_method document, :update_status, 'draft'
      set :status_changed, true
      set :new_status, 'draft'
    end
  end
end
```

## Multi-Step Process

### Order Processing Pipeline

```ruby
engine = Ruleur.define do
  # Step 1: Validate Order
  rule 'validate_order', salience: 100, no_loop: true do
    match do
      all?(
        order(:status).eq?('pending'),
        order(:items).present,
        order(:shipping_address).present
      )
    end
    execute do
      set :order_valid, true
      set :step_validate, 'completed'
    end
  end

  # Step 2: Check Inventory
  rule 'check_inventory', salience: 90, no_loop: true do
    match do
      all?(
        flag(:order_valid),
        order(:items_in_stock?)
      )
    end
    execute do
      set :inventory_available, true
      set :step_inventory, 'completed'
    end
  end

  # Step 3: Calculate Pricing
  rule 'calculate_pricing', salience: 80, no_loop: true do
    match do
      all?(
        flag(:inventory_available),
        order(:total).gt?(0)
      )
    end
    execute do
      order = context[:order]
      discount = calculate_discount(order)
      shipping = calculate_shipping(order)

      set :discount_amount, discount
      set :shipping_cost, shipping
      set :final_total, order.total - discount + shipping
      set :step_pricing, 'completed'
    end
  end

  # Step 4: Process Payment
  rule 'process_payment', salience: 70, no_loop: true do
    match do
      all?(
        flag(:step_pricing).eq?('completed'),
        order(:payment_method).present
      )
    end
    execute do
      # Payment processing logic
      set :payment_processed, true
      set :step_payment, 'completed'
    end
  end

  # Step 5: Fulfill Order
  rule 'fulfill_order', salience: 60, no_loop: true do
    match do
      all?(
        flag(:payment_processed),
        flag(:inventory_available)
      )
    end
    execute do
      call_method order, :fulfill!
      set :fulfillment_started, true
      set :step_fulfillment, 'completed'
    end
  end

  # Final Step: Complete Order
  rule 'complete_order', salience: 50, no_loop: true do
    match do
      all?(flag(:fulfillment_started))
    end
    execute do
      call_method order, :complete!
      set :order_complete, true
      set :completed_at, Time.current
    end
  end
end
```

## Parallel Approval

### Multi-Approver Workflow

```ruby
engine = Ruleur.define do
  rule 'technical_approval' do
    match do
      all?(
        user(:technical_lead?),
        document(:technical_review_pending?),
        flag(:action_approve_technical)
      )
    end
    execute do
      call_method document, :set_technical_approval, context[:user]
      set :technical_approved, true
    end
  end

  rule 'business_approval' do
    match do
      all?(
        user(:business_lead?),
        document(:business_review_pending?),
        flag(:action_approve_business)
      )
    end
    execute do
      call_method document, :set_business_approval, context[:user]
      set :business_approved, true
    end
  end

  rule 'final_approval' do
    match do
      all?(
        flag(:technical_approved),
        flag(:business_approved)
      )
    end
    execute do
      call_method document, :finalize_approval
      set :fully_approved, true
      set :approved_at, Time.current
    end
  end
end
```

## Conditional Workflow

### Approval Required Based on Amount

```ruby
engine = Ruleur.define do
  # Small amounts - auto-approve
  rule 'auto_approve_small', salience: 100 do
    match do
      all?(
        expense(:amount).lt?(100),
        user(:employee?),
        not?(expense(:approved?))
      )
    end
    execute do
      call_method expense, :auto_approve!
      set :approved, true
      set :approval_type, 'automatic'
    end
  end

  # Medium amounts - manager approval
  rule 'manager_approval_required', salience: 90 do
    match do
      all?(
        expense(:amount).gte?(100),
        expense(:amount).lt?(1000)
      )
    end
    execute do
      set :approval_required, 'manager'
      set :approval_level, 1
    end
  end

  # Large amounts - director approval
  rule 'director_approval_required', salience: 80 do
    match do
      all?(
        expense(:amount).gte?(1000),
        expense(:amount).lt?(10_000)
      )
    end
    execute do
      set :approval_required, 'director'
      set :approval_level, 2
    end
  end

  # Very large - CFO approval
  rule 'cfo_approval_required', salience: 70 do
    match do
      all?(expense(:amount).gte?(10_000))
    end
    execute do
      set :approval_required, 'cfo'
      set :approval_level, 3
    end
  end
end
```

## Workflow Tracking

### Progress Monitoring

```ruby
engine = Ruleur.define do
  rule 'track_progress', no_loop: true do
    match do
      all?(workflow(:in_progress?))
    end
    execute do
      workflow = context[:workflow]
      completed = workflow.steps.count(&:completed?)
      total = workflow.steps.count

      set :progress_percentage, (completed.to_f / total * 100).round
      set :steps_completed, completed
      set :steps_remaining, total - completed
      set :estimated_completion, calculate_eta(workflow)
    end
  end
end
```

## YAML Example

```yaml
# config/rules/workflow/approval_flow.yml
name: document_approval_flow
salience: 10
tags: [workflow, approval]
no_loop: true
condition:
  type: all
  children:
    # Document is submitted
    - type: pred
      op: equals
      left:
        type: call
        recv: { type: ref, root: document }
        method: status
      right:
        type: literal
        value: "submitted"

    # User is an approver
    - type: pred
      op: truthy
      left:
        type: call
        recv: { type: ref, root: user }
        method: approver?

    # Approve action requested
    - type: pred
      op: truthy
      left:
        type: ref
        root: action_approve

    # Not already approved
    - type: not
      child:
        type: pred
        op: truthy
        left:
          type: call
          recv: { type: ref, root: document }
          method: approved?

action:
  set:
    allow_approve: true
    approval_ready: true
  call:
    - object: { type: ref, root: document }
      method: set_approved_by
      args:
        - type: ref
          root: user
```

## Real-World Example: Purchase Order Workflow

```ruby
class PurchaseOrderWorkflow
  def self.engine
    @engine ||= Ruleur.define do
      # Create Purchase Order
      rule 'create_purchase_order', salience: 100 do
        match do
          all?(
            purchase_order(:draft?),
            purchase_order(:valid?),
            flag(:action_create)
          )
        end
        execute do
          call_method purchase_order, :submit
          set :purchase_order_created, true
          set :status, 'pending_approval'
        end
      end

      # Auto-approve under threshold
      rule 'auto_approve', salience: 90 do
        match do
          all?(
            purchase_order(:total).lt?(1000),
            purchase_order(:status).eq?('pending_approval'),
            user(:employee?)
          )
        end
        execute do
          call_method purchase_order, :auto_approve
          set :approved, true
          set :approval_method, 'automatic'
        end
      end

      # Manager approval
      rule 'manager_review', salience: 80 do
        match do
          all?(
            purchase_order(:total).gte?(1000),
            purchase_order(:total).lt?(10_000),
            purchase_order(:status).eq?('pending_approval')
          )
        end
        execute do
          set :requires_manager_approval, true
          set :approval_level, 'manager'
        end
      end

      # Manager approves
      rule 'manager_approves', salience: 70 do
        match do
          all?(
            flag(:requires_manager_approval),
            user(:manager?),
            flag(:action_approve)
          )
        end
        execute do
          call_method purchase_order, :approve_by, context[:user]
          set :approved, true
          set :approved_by, 'manager'
        end
      end

      # Send to vendor
      rule 'send_to_vendor', salience: 60 do
        match do
          all?(
            flag(:approved),
            not?(purchase_order(:sent_to_vendor?))
          )
        end
        execute do
          call_method purchase_order, :send_to_vendor
          set :sent_to_vendor, true
          set :sent_at, Time.current
        end
      end
    end
  end

  def self.process(purchase_order, user, action_flags = {})
    context = { purchase_order: purchase_order, user: user }.merge(action_flags)
    engine.run(context)
  end
end

# Usage
result = PurchaseOrderWorkflow.process(
  purchase_order,
  current_user,
  action_create: true
)

redirect_to purchase_order, notice: 'Purchase Order created successfully' if result[:purchase_order_created]
```

## See Also

- [Permission Rules](./permissions) - Authorization patterns
- [Conditions Guide](/guide/conditions) - Complex conditions
- [DSL Guide](/guide/dsl-basics) - DSL syntax
