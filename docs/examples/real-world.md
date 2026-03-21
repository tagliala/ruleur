# Real-World Cases

Complete, production-ready examples from real-world use cases.

## Overview

These examples demonstrate:
- Complete implementations
- Production patterns
- Error handling
- Testing strategies
- Performance considerations

## Case 1: E-commerce Order Validation

### Business Requirements

An e-commerce platform needs to validate orders before processing:
- Check inventory availability
- Validate customer eligibility
- Apply business rules for special cases
- Handle regional restrictions

### Implementation

```ruby
class OrderValidationEngine
  def self.engine
    @engine ||= Ruleur.define do
      # Inventory Check
      rule "check_inventory", salience: 100 do
        match do
          all?(
            order(:items).present,
            order(:items_in_stock?)
          )
        end
        execute do
          set :inventory_valid, true
          set :validation_step, "inventory_passed"
        end
      end
      
      rule "insufficient_inventory", salience: 100 do
        match do
          all?(
            order(:items).present,
            not?(order(:items_in_stock?))
          )
        end
        execute do
          items = context[:order].out_of_stock_items
          set :validation_failed, true
          set :error_code, "INSUFFICIENT_INVENTORY"
          set :error_message, "Items out of stock: #{items.join(', ')}"
        end
      end
      
      # Customer Validation
      rule "validate_customer", salience: 90 do
        match do
          all?(
            flag(:inventory_valid),
            customer(:active?),
            not?(customer(:suspended?))
          )
        end
        execute do
          set :customer_valid, true
          set :validation_step, "customer_passed"
        end
      end
      
      rule "suspended_customer", salience: 90 do
        match do
          all?(customer(:suspended?))
        end
        execute do
          set :validation_failed, true
          set :error_code, "CUSTOMER_SUSPENDED"
          set :error_message, "Customer account is suspended"
        end
      end
      
      # Payment Method Validation
      rule "validate_payment", salience: 80 do
        match do
          all?(
            flag(:customer_valid),
            order(:payment_method).present,
            order(:payment_valid?)
          )
        end
        execute do
          set :payment_valid, true
          set :validation_step, "payment_passed"
        end
      end
      
      # Regional Restrictions
      rule "check_shipping_restrictions", salience: 70 do
        match do
          all?(
            flag(:payment_valid),
            order(:shipping_address).present
          )
        end
        execute do
          address = context[:order].shipping_address
          restricted = context[:order].has_restricted_items?(address.country)
          
          if restricted
            set :validation_failed, true
            set :error_code, "SHIPPING_RESTRICTED"
            set :error_message, "Some items cannot be shipped to #{address.country}"
          else
            set :shipping_valid, true
            set :validation_step, "shipping_passed"
          end
        end
      end
      
      # Business Days Check
      rule "business_days_validation", salience: 60 do
        match do
          all?(
            flag(:shipping_valid),
            order(:expedited_shipping?)
          )
        end
        execute do
          today = Date.today
          is_business_day = (1..5).include?(today.wday)
          
          if is_business_day
            set :expedited_available, true
          else
            set :expedited_available, false
            set :warning_message, "Expedited shipping not available on weekends"
          end
        end
      end
      
      # Final Validation
      rule "order_valid", salience: 10 do
        match do
          all?(
            flag(:inventory_valid),
            flag(:customer_valid),
            flag(:payment_valid),
            flag(:shipping_valid),
            not?(flag(:validation_failed))
          )
        end
        execute do
          set :order_valid, true
          set :ready_to_process, true
        end
      end
    end
  end
  
  ValidationResult = Struct.new(:valid, :errors, :error_code, :warnings, keyword_init: true)

  def self.validate(order, customer)
    result = engine.run(order: order, customer: customer)
    
    ValidationResult.new(
      valid: result[:order_valid] == true,
      errors: result[:validation_failed] ? [result[:error_message]] : [],
      error_code: result[:error_code],
      warnings: result[:warning_message] ? [result[:warning_message]] : []
    )
  end
end

# Usage in controller
class OrdersController < ApplicationController
  def create
    @order = Order.new(order_params)
    
    validation = OrderValidationEngine.validate(@order, current_user)
    
    if validation.valid?
      @order.save
      redirect_to @order, notice: "Order created successfully"
    else
      flash.now[:error] = validation.errors.join(", ")
      render :new
    end
  end
end
```

## Case 2: SaaS Feature Access Control

### Business Requirements

A SaaS platform needs to control feature access based on:
- Subscription tier
- Usage limits
- Trial status
- Add-on purchases

### Implementation

```ruby
class FeatureAccessEngine
  def self.engine
    @engine ||= Ruleur.define do
      # Basic Features (All tiers)
      rule "basic_features", salience: 100 do
        match do
          all?(user(:subscription, :active?))
        end
        execute do
          allow! :dashboard
          allow! :basic_reports
          allow! :profile
          set :max_projects, 3
          set :storage_gb, 5
        end
      end
      
      # Pro Features
      rule "pro_features", salience: 90 do
        match do
          all?(
            user(:subscription, :tier).in(["pro", "enterprise"]),
            user(:subscription, :active?)
          )
        end
        execute do
          allow! :advanced_analytics
          allow! :custom_reports
          allow! :api_access
          allow! :integrations
          set :max_projects, 25
          set :storage_gb, 100
          set :api_rate_limit, 1000
        end
      end
      
      # Enterprise Features
      rule "enterprise_features", salience: 80 do
        match do
          all?(
            user(:subscription, :tier).eq?("enterprise"),
            user(:subscription, :active?)
          )
        end
        execute do
          allow! :sso
          allow! :audit_logs
          allow! :white_label
          allow! :priority_support
          allow! :custom_contracts
          set :max_projects, Float::INFINITY
          set :storage_gb, 1000
          set :api_rate_limit, 10000
        end
      end
      
      # Trial Limitations
      rule "trial_limitations", salience: 110 do
        match do
          all?(
            user(:subscription, :trial?),
            user(:subscription, :active?)
          )
        end
        execute do
          allow! :dashboard
          allow! :basic_reports
          set :max_projects, 1
          set :storage_gb, 1
          set :trial_days_remaining, (user.subscription.trial_end - Date.today).to_i
        end
      end
      
      # Add-on: Extra Storage
      rule "storage_addon", salience: 70 do
        match do
          all?(user(:has_addon?, "extra_storage"))
        end
        execute do
          current_storage = context[:storage_gb] || 5
          set :storage_gb, current_storage + 50
        end
      end
      
      # Add-on: API Access for Basic Users
      rule "api_addon", salience: 70 do
        match do
          all?(
            user(:subscription, :tier).eq?("basic"),
            user(:has_addon?, "api_access")
          )
        end
        execute do
          allow! :api_access
          set :api_rate_limit, 100
        end
      end
      
      # Usage Limits
      rule "check_project_limit", salience: 50 do
        match do
          all?(
            flag(:max_projects).present,
            user(:projects_count).gte?(flag(:max_projects))
          )
        end
        execute do
          deny! :create_project
          set :limit_reached, "projects"
          set :upgrade_required, true
        end
      end
      
      rule "check_storage_limit", salience: 50 do
        match do
          all?(
            flag(:storage_gb).present,
            user(:storage_used_gb).gte?(flag(:storage_gb))
          )
        end
        execute do
          deny! :upload_files
          set :limit_reached, "storage"
          set :upgrade_required, true
        end
      end
      
      # Expired Subscription
      rule "expired_subscription", salience: 120 do
        match do
          all?(not?(user(:subscription, :active?)))
        end
        execute do
          allow! :dashboard
          allow! :billing
          deny! :create_project
          deny! :upload_files
          deny! :api_access
          set :subscription_expired, true
        end
      end
    end
  end
  
  def self.check_access(user, feature)
    result = engine.run(user: user)
    result[:"allow_#{feature}"] == true
  end
  
  LimitsResult = Struct.new(:max_projects, :storage_gb, :api_rate_limit, :upgrade_required, keyword_init: true)

  def self.get_limits(user)
    result = engine.run(user: user)
    
    LimitsResult.new(
      max_projects: result[:max_projects],
      storage_gb: result[:storage_gb],
      api_rate_limit: result[:api_rate_limit],
      upgrade_required: result[:upgrade_required] == true
    )
  end
end

# Usage in application
class ProjectsController < ApplicationController
  before_action :check_project_limit, only: [:create]
  
  def check_project_limit
    unless FeatureAccessEngine.check_access(current_user, :create_project)
      limits = FeatureAccessEngine.get_limits(current_user)
      redirect_to upgrade_path, alert: "Project limit reached (#{limits.max_projects})"
    end
  end
end
```

## Case 3: Content Moderation System

### Business Requirements

A social platform needs automated content moderation:
- Flag inappropriate content
- Auto-approve trusted users
- Queue suspicious content for review
- Handle different content types

### Implementation

```ruby
class ContentModerationEngine
  def self.engine
    @engine ||= Ruleur.define do
      # Trusted User Auto-Approve
      rule "trusted_user_auto_approve", salience: 100 do
        match do
          all?(
            user(:trusted?),
            user(:violations_count).eq?(0),
            content(:type).in(["text", "image"])
          )
        end
        execute do
          set :moderation_action, "approve"
          set :auto_approved, true
          set :reason, "Trusted user with clean history"
        end
      end
      
      # Spam Detection
      rule "spam_detection", salience: 110 do
        match do
          all?(
            any?(
              content(:contains_spam_keywords?),
              content(:excessive_links?),
              content(:repetitive_content?)
            )
          )
        end
        execute do
          set :moderation_action, "reject"
          set :flag_reason, "Potential spam detected"
          set :notify_user, true
        end
      end
      
      # Profanity Check
      rule "profanity_check", salience: 105 do
        match do
          all?(content(:contains_profanity?))
        end
        execute do
          severity = context[:content].profanity_severity
          
          if severity >= 8
            set :moderation_action, "reject"
            set :flag_reason, "Severe profanity"
          else
            set :moderation_action, "review"
            set :flag_reason, "Mild profanity - manual review"
          end
        end
      end
      
      # New User Content
      rule "new_user_review", salience: 90 do
        match do
          all?(
            user(:account_age_days).lt?(7),
            not?(flag(:auto_approved)),
            not?(flag(:moderation_action).present)
          )
        end
        execute do
          set :moderation_action, "review"
          set :flag_reason, "New user - pending review"
          set :review_priority, "low"
        end
      end
      
      # Sensitive Content
      rule "sensitive_content", salience: 95 do
        match do
          all?(
            content(:type).in(["image", "video"]),
            content(:ai_flagged?)
          )
        end
        execute do
          confidence = context[:content].ai_confidence
          
          if confidence >= 0.9
            set :moderation_action, "reject"
            set :flag_reason, "AI detected policy violation (#{confidence})"
          elsif confidence >= 0.5
            set :moderation_action, "review"
            set :flag_reason, "AI flagged for review (#{confidence})"
            set :review_priority, "high"
          end
        end
      end
      
      # Copyright Claims
      rule "copyright_check", salience: 100 do
        match do
          all?(
            content(:type).in(["image", "video", "audio"]),
            content(:copyright_match?)
          )
        end
        execute do
          set :moderation_action, "remove"
          set :flag_reason, "Copyright violation detected"
          set :dmca_takedown, true
          set :notify_user, true
        end
      end
      
      # Rate Limiting
      rule "rate_limit_exceeded", salience: 120 do
        match do
          all?(user(:posts_last_hour).gt?(10))
        end
        execute do
          set :moderation_action, "rate_limit"
          set :flag_reason, "Posting too frequently"
          set :cooldown_minutes, 60
        end
      end
      
      # Default: Queue for Review
      rule "default_review", salience: 1 do
        match do
          all?(not?(flag(:moderation_action).present))
        end
        execute do
          set :moderation_action, "review"
          set :flag_reason, "Standard review process"
          set :review_priority, "normal"
        end
      end
    end
  end
  
  def self.moderate(content, user)
    result = engine.run(content: content, user: user)
    
    ModerationResult.new(
      execute: result[:moderation_action],
      reason: result[:flag_reason],
      auto_approved: result[:auto_approved] == true,
      review_priority: result[:review_priority],
      notify_user: result[:notify_user] == true,
      metadata: result.to_h
    )
  end
end

# Usage
class PostsController < ApplicationController
  def create
    @post = current_user.posts.build(post_params)
    
    moderation = ContentModerationEngine.moderate(@post, current_user)
    
    case moderation.action
    when "approve"
      @post.approved!
      redirect_to @post, notice: "Post published"
    when "reject"
      flash[:error] = "Post rejected: #{moderation.reason}"
      render :new
    when "review"
      @post.pending_review!
      ModerationQueue.enqueue(@post, priority: moderation.review_priority)
      redirect_to root_path, notice: "Post submitted for review"
    when "rate_limit"
      flash[:error] = moderation.reason
      render :new
    end
  end
end
```

## Case 4: Insurance Policy Evaluation

### Business Requirements

An insurance company needs to evaluate policy applications:
- Calculate risk scores
- Determine eligibility
- Set premium rates
- Flag for manual underwriting

### Implementation

```ruby
class InsurancePolicyEngine
  def self.engine
    @engine ||= Ruleur.define do
      # Base Risk Assessment
      rule "age_risk_low", salience: 100 do
        match do
          all?(
            applicant(:age).gte?(25),
            applicant(:age).lte?(60)
          )
        end
        execute { set :age_risk_score, 0 }
      end
      
      rule "age_risk_high", salience: 100 do
        match do
          all?(
            any?(
              applicant(:age).lt?(25),
              applicant(:age).gt?(60)
            )
          )
        end
        execute { set :age_risk_score, 20 }
      end
      
      # Driving History
      rule "clean_driving_record", salience: 90 do
        match do
          all?(
            applicant(:accidents_last_5_years).eq?(0),
            applicant(:violations_last_3_years).eq?(0)
          )
        end
        execute do
          set :driving_risk_score, 0
          set :safe_driver_discount, 0.15
        end
      end
      
      rule "moderate_driving_risk", salience: 90 do
        match do
          all?(
            applicant(:accidents_last_5_years).in([1, 2]),
            applicant(:violations_last_3_years).lt?(3)
          )
        end
        execute { set :driving_risk_score, 30 }
      end
      
      rule "high_driving_risk", salience: 90 do
        match do
          all?(
            any?(
              applicant(:accidents_last_5_years).gt?(2),
              applicant(:violations_last_3_years).gte?(3),
              applicant(:dui_history?)
            )
          )
        end
        execute do
          set :driving_risk_score, 100
          set :requires_underwriting, true
        end
      end
      
      # Credit Score Impact
      rule "excellent_credit", salience: 85 do
        match do
          all?(
            applicant(:credit_score).gte?(750)
          )
        end
        execute do
          set :credit_risk_score, -10
          set :credit_discount, 0.10
        end
      end
      
      rule "poor_credit", salience: 85 do
        match do
          all?(
            applicant(:credit_score).lt?(600)
          )
        end
        execute { set :credit_risk_score, 25 }
      end
      
      # Calculate Total Risk Score
      rule "calculate_risk", salience: 50, no_loop: true do
        match do
          all?(
            flag(:age_risk_score).present,
            flag(:driving_risk_score).present
          )
        end
        execute do
          age = context[:age_risk_score]
          driving = context[:driving_risk_score]
          credit = context[:credit_risk_score] || 0
          
          total_risk = age + driving + credit
          set :total_risk_score, total_risk
        end
      end
      
      # Eligibility Determination
      rule "eligible_standard", salience: 40 do
        match do
          all?(
            flag(:total_risk_score).lt?(50),
            not?(flag(:requires_underwriting))
          )
        end
        execute do
          set :eligible, true
          set :policy_tier, "standard"
        end
      end
      
      rule "eligible_high_risk", salience: 40 do
        match do
          all?(
            flag(:total_risk_score).gte?(50),
            flag(:total_risk_score).lt?(80),
            not?(flag(:requires_underwriting))
          )
        end
        execute do
          set :eligible, true
          set :policy_tier, "high_risk"
        end
      end
      
      rule "requires_manual_review", salience: 40 do
        match do
          all?(
            any?(
              flag(:total_risk_score).gte?(80),
              flag(:requires_underwriting)
            )
          )
        end
        execute do
          set :eligible, false
          set :manual_underwriting_required, true
          set :reason, "Risk score too high - manual review needed"
        end
      end
      
      # Premium Calculation
      rule "calculate_premium", salience: 30 do
        match do
          all?(
            flag(:eligible),
            flag(:policy_tier).present
          )
        end
        execute do
          base_premium = 1000
          risk_score = context[:total_risk_score]
          tier = context[:policy_tier]
          
          # Risk multiplier
          risk_multiplier = 1 + (risk_score / 100.0)
          
          # Tier multiplier
          tier_multiplier = tier == "high_risk" ? 1.5 : 1.0
          
          premium = base_premium * risk_multiplier * tier_multiplier
          
          # Apply discounts
          safe_driver = context[:safe_driver_discount] || 0
          credit = context[:credit_discount] || 0
          total_discount = safe_driver + credit
          
          final_premium = premium * (1 - total_discount)
          
          set :monthly_premium, final_premium.round(2)
          set :annual_premium, (final_premium * 12).round(2)
          set :discounts_applied, total_discount
        end
      end
    end
  end
  
  def self.evaluate(applicant)
    result = engine.run(applicant: applicant)
    
    PolicyEvaluation.new(
      eligible: result[:eligible] == true,
      policy_tier: result[:policy_tier],
      risk_score: result[:total_risk_score],
      monthly_premium: result[:monthly_premium],
      annual_premium: result[:annual_premium],
      discounts: result[:discounts_applied],
      requires_review: result[:manual_underwriting_required] == true,
      reason: result[:reason]
    )
  end
end

# Usage
evaluation = InsurancePolicyEngine.evaluate(applicant)

if evaluation.eligible?
  # Show quote
  render :quote, locals: { evaluation: evaluation }
elsif evaluation.requires_review?
  # Queue for underwriter
  UnderwritingQueue.enqueue(applicant)
  render :pending_review
else
  # Declined
  render :declined, locals: { reason: evaluation.reason }
end
```

## Testing Real-World Rules

```ruby
RSpec.describe ContentModerationEngine do
  describe ".moderate" do
    it "auto-approves trusted users" do
      user = build(:user, :trusted, violations_count: 0)
      content = build(:post, :text)
      
      result = ContentModerationEngine.moderate(content, user)
      
      expect(result.action).to eq("approve")
      expect(result.auto_approved).to be true
    end
    
    it "rejects spam content" do
      user = build(:user)
      content = build(:post, spam_keywords: true)
      
      result = ContentModerationEngine.moderate(content, user)
      
      expect(result.action).to eq("reject")
      expect(result.reason).to include("spam")
    end
    
    it "queues new user content for review" do
      user = build(:user, created_at: 2.days.ago)
      content = build(:post, :text)
      
      result = ContentModerationEngine.moderate(content, user)
      
      expect(result.action).to eq("review")
      expect(result.review_priority).to eq("low")
    end
  end
end
```

## Performance Considerations

### Caching Rules

```ruby
class CachedRuleEngine
  def self.engine
    @engine ||= Rails.cache.fetch("rule_engine/#{cache_key}", expires_in: 1.hour) do
      load_engine
    end
  end
  
  def self.cache_key
    Rule.maximum(:updated_at)&.to_i || 0
  end
  
  def self.reload!
    @engine = nil
    Rails.cache.delete("rule_engine/#{cache_key}")
  end
end
```

### Async Processing

```ruby
class AsyncModerationJob < ApplicationJob
  def perform(content_id, user_id)
    content = Content.find(content_id)
    user = User.find(user_id)
    
    result = ContentModerationEngine.moderate(content, user)
    
    content.update(
      moderation_status: result.action,
      moderation_reason: result.reason
    )
  end
end
```

## See Also

- [Permission Rules](./permissions) - Authorization patterns
- [Workflow Automation](./workflow) - Process automation
- [Dynamic Pricing](./pricing) - Pricing rules
- [Performance Guide](/guide/advanced) - Optimization techniques
