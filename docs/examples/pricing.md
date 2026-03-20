# Dynamic Pricing

Implement flexible pricing rules, discounts, and fee calculations with Ruleur.

## Overview

Pricing rules help you:
- Calculate tiered pricing
- Apply dynamic discounts
- Compute shipping costs
- Handle promotional rules

## Basic Discount Rules

### Simple Percentage Discount

```ruby
engine = Ruleur.define do
  rule "vip_discount" do
    when_all(customer(:vip?))
    action { set :discount, 0.10 }
  end

  rule "bulk_discount" do
    when_all(order(:total).greater_than(500))
    action { set :discount, 0.15 }
  end
end

result = engine.run(customer: customer, order: order)
discount = result[:discount]
final_price = order.total * (1 - discount)
```

### Stacking Discounts

```ruby
engine = Ruleur.define do
  rule "base_vip_discount", salience: 10 do
    when_all(customer(:vip?))
    action { set :discount_vip, 0.10 }
  end

  rule "seasonal_discount", salience: 10 do
    when_all(lit(Date.today.month).in([11, 12]))
    action { set :discount_seasonal, 0.05 }
  end

  rule "calculate_total_discount", salience: 5 do
    when_all(
      any(
        flag(:discount_vip).present,
        flag(:discount_seasonal).present
      )
    )
    action do
      vip = context[:discount_vip] || 0
      seasonal = context[:discount_seasonal] || 0

      # Multiplicative stacking: (1-d1) * (1-d2)
      total_discount = 1 - ((1 - vip) * (1 - seasonal))
      set :discount_total, total_discount
    end
  end
end
```

## Tiered Pricing

### Volume-Based Pricing

```ruby
engine = Ruleur.define do
  rule "tier_bronze", salience: 10 do
    when_all(
      order(:quantity).greater_than_or_equal(1),
      order(:quantity).less_than(10)
    )
    action do
      set :price_per_unit, 10.00
      set :tier, "bronze"
    end
  end

  rule "tier_silver", salience: 20 do
    when_all(
      order(:quantity).greater_than_or_equal(10),
      order(:quantity).less_than(50)
    )
    action do
      set :price_per_unit, 8.50
      set :tier, "silver"
    end
  end

  rule "tier_gold", salience: 30 do
    when_all(
      order(:quantity).greater_than_or_equal(50),
      order(:quantity).less_than(100)
    )
    action do
      set :price_per_unit, 7.00
      set :tier, "gold"
    end
  end

  rule "tier_platinum", salience: 40 do
    when_all(order(:quantity).greater_than_or_equal(100))
    action do
      set :price_per_unit, 5.50
      set :tier, "platinum"
    end
  end

  rule "calculate_total", salience: 5 do
    when_all(flag(:price_per_unit).present)
    action do
      quantity = context[:order].quantity
      price = context[:price_per_unit]
      set :subtotal, quantity * price
    end
  end
end
```

### Subscription Tiers

```ruby
engine = Ruleur.define do
  rule "basic_tier" do
    when_all(
      customer(:subscription).equals("basic"),
      customer(:active?)
    )
    action do
      set :monthly_price, 29.99
      set :feature_limit, 10
      set :storage_gb, 5
    end
  end

  rule "pro_tier" do
    when_all(
      customer(:subscription).equals("pro"),
      customer(:active?)
    )
    action do
      set :monthly_price, 79.99
      set :feature_limit, 100
      set :storage_gb, 50
    end
  end

  rule "enterprise_tier" do
    when_all(
      customer(:subscription).equals("enterprise"),
      customer(:active?)
    )
    action do
      set :monthly_price, 299.99
      set :feature_limit, Float::INFINITY
      set :storage_gb, 500
    end
  end

  rule "annual_discount" do
    when_all(customer(:billing_period).equals("annual"))
    action do
      monthly = context[:monthly_price]
      annual_discount = monthly * 12 * 0.20
      set :annual_price, (monthly * 12) - annual_discount
      set :savings, annual_discount
    end
  end
end
```

## Shipping Calculation

### Distance and Weight Based

```ruby
engine = Ruleur.define do
  rule "free_shipping_threshold", salience: 100 do
    when_all(order(:total).greater_than(100))
    action do
      set :shipping_cost, 0
      set :free_shipping, true
    end
  end

  rule "local_shipping", salience: 50 do
    when_all(
      not(flag(:free_shipping)),
      order(:distance_miles).less_than(50)
    )
    action do
      weight = context[:order].weight_lbs
      base = 5.00
      per_pound = 0.50
      set :shipping_cost, base + (weight * per_pound)
    end
  end

  rule "regional_shipping", salience: 40 do
    when_all(
      not(flag(:free_shipping)),
      order(:distance_miles).greater_than_or_equal(50),
      order(:distance_miles).less_than(500)
    )
    action do
      weight = context[:order].weight_lbs
      base = 12.00
      per_pound = 0.75
      set :shipping_cost, base + (weight * per_pound)
    end
  end

  rule "national_shipping", salience: 30 do
    when_all(
      not(flag(:free_shipping)),
      order(:distance_miles).greater_than_or_equal(500)
    )
    action do
      weight = context[:order].weight_lbs
      base = 25.00
      per_pound = 1.00
      set :shipping_cost, base + (weight * per_pound)
    end
  end
end
```

## Promotional Rules

### Time-Limited Promotions

```ruby
engine = Ruleur.define do
  rule "black_friday", salience: 100 do
    when_all(
      lit(Date.today).greater_than_or_equal(lit(Date.new(2026, 11, 24))),
      lit(Date.today).less_than_or_equal(lit(Date.new(2026, 11, 29)))
    )
    action do
      set :discount, 0.25
      set :promo_code, "BLACKFRIDAY"
    end
  end

  rule "cyber_monday", salience: 100 do
    when_all(
      lit(Date.today).equals(lit(Date.new(2026, 12, 2)))
    )
    action do
      set :discount, 0.30
      set :promo_code, "CYBERMONDAY"
    end
  end

  rule "first_purchase", salience: 50 do
    when_all(
      customer(:first_purchase?),
      not(flag(:discount).present)
    )
    action do
      set :discount, 0.15
      set :promo_code, "WELCOME15"
    end
  end
end
```

### Coupon Codes

```ruby
engine = Ruleur.define do
  rule "validate_coupon", salience: 100 do
    when_all(
      coupon(:valid?),
      coupon(:not_expired?),
      not(coupon(:used?))
    )
    action do
      set :coupon_valid, true
    end
  end

  rule "percentage_coupon" do
    when_all(
      flag(:coupon_valid),
      coupon(:type).equals("percentage")
    )
    action do
      discount = context[:coupon].discount_percentage / 100.0
      set :discount, discount
      set :discount_type, "percentage"
    end
  end

  rule "fixed_amount_coupon" do
    when_all(
      flag(:coupon_valid),
      coupon(:type).equals("fixed")
    )
    action do
      amount = context[:coupon].discount_amount
      set :discount_amount, amount
      set :discount_type, "fixed"
    end
  end

  rule "free_shipping_coupon" do
    when_all(
      flag(:coupon_valid),
      coupon(:type).equals("free_shipping")
    )
    action do
      set :shipping_cost, 0
      set :free_shipping, true
      set :discount_type, "free_shipping"
    end
  end
end
```

## Dynamic Surge Pricing

### Demand-Based Pricing

```ruby
engine = Ruleur.define do
  rule "normal_pricing", salience: 10 do
    when_all(
      demand(:current_load).less_than(70)
    )
    action do
      set :surge_multiplier, 1.0
      set :pricing_tier, "normal"
    end
  end

  rule "moderate_surge", salience: 20 do
    when_all(
      demand(:current_load).greater_than_or_equal(70),
      demand(:current_load).less_than(90)
    )
    action do
      set :surge_multiplier, 1.5
      set :pricing_tier, "moderate"
    end
  end

  rule "high_surge", salience: 30 do
    when_all(
      demand(:current_load).greater_than_or_equal(90)
    )
    action do
      set :surge_multiplier, 2.0
      set :pricing_tier, "high"
    end
  end

  rule "apply_surge", salience: 5 do
    when_all(flag(:surge_multiplier).present)
    action do
      base_price = context[:service].base_price
      multiplier = context[:surge_multiplier]
      set :final_price, base_price * multiplier
    end
  end
end
```

## Complex Pricing Example

### E-commerce Order Pricing

```ruby
class OrderPricingEngine
  def self.engine
    @engine ||= Ruleur.define do
      # Step 1: Calculate base price
      rule "calculate_base", salience: 100, no_loop: true do
        when_all(order(:items).present)
        action do
          items = context[:order].items
          subtotal = items.sum { |item| item.price * item.quantity }
          set :subtotal, subtotal
        end
      end

      # Step 2: Apply member discounts
      rule "member_discount", salience: 90 do
        when_all(
          customer(:member?),
          customer(:member_tier).in(["gold", "platinum"])
        )
        action do
          discount = case context[:customer].member_tier
            when "gold" then 0.10
            when "platinum" then 0.15
            else 0
          end
          set :member_discount, discount
        end
      end

      # Step 3: Apply bulk discounts
      rule "bulk_discount", salience: 85 do
        when_all(
          flag(:subtotal).greater_than(500)
        )
        action do
          subtotal = context[:subtotal]
          discount = case
            when subtotal >= 1000 then 0.20
            when subtotal >= 500 then 0.10
            else 0
          end
          set :bulk_discount, discount
        end
      end

      # Step 4: Calculate discount amount
      rule "calculate_discount", salience: 80, no_loop: true do
        when_all(
          any(
            flag(:member_discount).present,
            flag(:bulk_discount).present
          )
        )
        action do
          member = context[:member_discount] || 0
          bulk = context[:bulk_discount] || 0

          # Take best discount (non-stacking)
          best_discount = [member, bulk].max

          subtotal = context[:subtotal]
          discount_amount = subtotal * best_discount

          set :discount_percentage, best_discount
          set :discount_amount, discount_amount
          set :price_after_discount, subtotal - discount_amount
        end
      end

      # Step 5: Calculate shipping
      rule "calculate_shipping", salience: 70, no_loop: true do
        when_all(flag(:price_after_discount).present)
        action do
          price = context[:price_after_discount]

          shipping = if price >= 100
            0
          elsif price >= 50
            5.99
          else
            9.99
          end

          set :shipping_cost, shipping
          set :free_shipping, shipping == 0
        end
      end

      # Step 6: Calculate tax
      rule "calculate_tax", salience: 60, no_loop: true do
        when_all(
          flag(:price_after_discount).present,
          order(:tax_rate).present
        )
        action do
          price = context[:price_after_discount]
          tax_rate = context[:order].tax_rate

          tax = price * tax_rate
          set :tax_amount, tax
        end
      end

      # Step 7: Calculate final total
      rule "calculate_total", salience: 50, no_loop: true do
        when_all(
          flag(:price_after_discount).present,
          flag(:shipping_cost).present,
          flag(:tax_amount).present
        )
        action do
          price = context[:price_after_discount]
          shipping = context[:shipping_cost]
          tax = context[:tax_amount]

          total = price + shipping + tax

          set :final_total, total
          set :pricing_complete, true
        end
      end
    end
  end

  def self.calculate(order, customer)
    result = engine.run(order: order, customer: customer)

    {
      subtotal: result[:subtotal],
      discount: result[:discount_amount] || 0,
      shipping: result[:shipping_cost],
      tax: result[:tax_amount],
      total: result[:final_total]
    }
  end
end

# Usage
pricing = OrderPricingEngine.calculate(@order, current_user)
@order.update(pricing)
```

## YAML Example

```yaml
# config/rules/pricing/bulk_discount.yml
name: bulk_discount
salience: 10
tags: [pricing, discount]
condition:
  type: pred
  op: greater_than
  left:
    type: call
    recv: { type: ref, root: order }
    method: total
  right:
    type: literal
    value: 500
action:
  set:
    discount: 0.15
    discount_reason: "Bulk order discount"
```

## See Also

- [Conditions Guide](/guide/conditions) - Complex conditions
- [Operators](/guide/operators) - Comparison operators
- [DSL Basics](/guide/dsl-basics) - DSL syntax
