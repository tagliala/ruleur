# Advanced Topics

This guide covers advanced features and techniques for working with Ruleur, including salience, no-loop, tracing, and performance optimization.

## Salience (Priority)

**Salience** determines the firing order of rules when multiple rules are eligible. Higher salience rules fire first.

### Basic Salience

```ruby
engine = Ruleur.define do
  rule "low_priority", salience: 0 do
    match do
      all(user(:logged_in?))
    end
    execute do
      set :priority, "low"
    end
  end
  
  rule "high_priority", salience: 100 do
    match do
      all(user(:admin?))
    end
    execute do
      set :priority, "high"
    end
  end
end
```

**Execution order:** `high_priority` (100) fires before `low_priority` (0).

### Default Salience

Rules have salience `0` by default:

```ruby
rule "default_rule" do
  # Implicit salience: 0
end
```

### Salience Ranges

Use consistent ranges for different priority levels:

```ruby
# Critical business rules
rule "payment_validation", salience: 1000 do
  # ...
end

# Important rules
rule "permission_check", salience: 100 do
  # ...
end

# Normal rules
rule "log_activity", salience: 10 do
  # ...
end

# Cleanup rules
rule "set_defaults", salience: 0 do
  # ...
end
```

### Conflict Resolution

When multiple rules have the same salience, they're sorted alphabetically by name:

```ruby
rule "a_rule", salience: 10 do
  # Fires first (alphabetically)
end

rule "b_rule", salience: 10 do
  # Fires second
end
```

::: tip
Use descriptive names with numeric prefixes for fine-grained control:

```ruby
rule "10_validate_user", salience: 100
rule "20_check_permissions", salience: 100
rule "30_apply_rules", salience: 100
```
:::

## No-Loop Protection

The `no_loop` option prevents a rule from firing multiple times in the same execution cycle.

### Why No-Loop?

Without no-loop, a rule might fire repeatedly if its action makes its condition true again:

```ruby
# Without no_loop - could fire multiple times!
rule "increment_counter" do
  match do
    all(lt(ref(:counter), 10))
  end
  execute do |ctx|
    ctx[:counter] = (ctx[:counter] || 0) + 1
  end
end
```

### With No-Loop

```ruby
rule "increment_counter", no_loop: true do
  match do
    all(lt(ref(:counter), 10))
  end
  execute do |ctx|
    ctx[:counter] = (ctx[:counter] || 0) + 1
  end
end
```

Now the rule fires at most once per execution cycle.

### When to Use No-Loop

Use `no_loop: true` when:
- Rule actions might make the rule eligible again
- You want to prevent infinite loops
- A rule should fire once per execution

**Example: Permission chains**

```ruby
rule "grant_base_permissions", no_loop: true do
  match do
    all(user(:registered?))
  end
  execute do
    set :view, true
    set :comment, true
  end
end

rule "grant_premium_permissions", no_loop: true do
  match do
    all(
      user(:premium?),
      flag(:view)  # Depends on previous rule
    )
  end
  execute do
    set :download, true
    set :export, true
  end
end
```

## Engine Tracing

Enable tracing to debug rule execution:

```ruby
engine = Ruleur::Engine.new(trace: true)
ctx = engine.run(user: user, recordord: recordord)
```

**Output:**

```
[Ruleur] Firing: high_priority_rule (salience=100)
[Ruleur] Facts changed: allow_access
[Ruleur] Firing: medium_priority_rule (salience=50)
[Ruleur] Facts changed: allow_edit
[Ruleur] Firing: low_priority_rule (salience=0)
[Ruleur] Facts changed: allow_view
```

### Trace in Production

Control tracing via environment variable:

```ruby
trace = ENV['RULEUR_TRACE'] == 'true'
engine = Ruleur::Engine.new(rules: rules, trace: trace)
```

## Execution Cycles

Ruleur uses a forward-chaining execution model with cycles:

### How It Works

1. **Build conflict set**: Find all eligible rules
2. **Sort by salience**: Higher salience first
3. **Fire rules**: Execute actions, update facts
4. **Repeat**: If facts changed, build new conflict set
5. **Terminate**: Stop when no rules fire or max cycles reached

### Max Cycles

Prevent infinite loops with `max_cycles`:

```ruby
ctx = engine.run(user: user, max_cycles: 10)
```

Default: 100 cycles

### Detecting Cycles

Monitor execution cycles:

```ruby
cycles = 0
engine = Ruleur.define do
  rule "count_cycles", no_loop: false do
    match do
      all(lt(ref(:counter), 100))
    end
    execute do |ctx|
      ctx[:counter] = (ctx[:counter] || 0) + 1
      cycles += 1
    end
  end
end

ctx = engine.run({}, max_cycles: 5)
puts "Executed #{cycles} times"  # => 5
```

## Rule Tags

Organize rules with tags:

```ruby
engine = Ruleur.define do
  rule "admin_check", tags: ['permissions', 'admin'] do
    match do
      all() # placeholder
    end
  end
  
  rule "payment_rule", tags: ['payment', 'validation'] do
    match do
      all() # placeholder
    end
  end
end
```

### Querying by Tags

```ruby
# Find rules with specific tag
admin_rules = engine.rules.select { |r| r.tags.include?('admin') }

# Find rules with multiple tags
payment_validation = engine.rules.select do |r|
  r.tags.include?('payment') && r.tags.include?('validation')
end
```

### Tag Conventions

Use consistent tag hierarchies:

```ruby
rule "process_user", tags: ['user', 'permissions'] do
  match do
    all(user(:active?))
  end
  execute do
    set :can_access, true
  end
end

rule "process_order", tags: ['order', 'payment'] do
  match do
    all(order(:pending?))
  end
  execute do
    set :can_charge, true
  end
end
```
tags: ['production', 'critical']
tags: ['experimental', 'beta']
```

## Context Management

The execution context holds all facts and intermediate results.

### Initial Context

Provide facts when running:

```ruby
ctx = engine.run(
  user: current_user,
  recordord: document,
  custom_data: { foo: 'bar' }
)
```

### Reading Context Values

```ruby
ctx[:user]           # => User object
ctx[:recordord]         # => Document object
ctx[:access]         # => true or nil (set by rules)
```

### Context Isolation

Each engine run creates a new context:

```ruby
ctx1 = engine.run(user: user1, recordord: doc1)
ctx2 = engine.run(user: user2, recordord: doc2)

# ctx1 and ctx2 are independent
```

### Reusing Context

You can pass a Context object for incremental execution:

```ruby
ctx = Ruleur::Context.new(user: user, recordord: recordord)
engine1.run(ctx)

# Continue with same context
engine2.run(ctx)

# ctx accumulates facts from both engines
```

## Performance Optimization

### 1. Minimize Rule Count

Fewer rules = faster execution:

```ruby
# Good - single rule
rule "permission_check" do
  match do
    any(
      user(:admin?),
      user(:editor?),
      user(:owner?)
    )
  end
  execute do
    set :edit, true
  end
end

# Less efficient - three rules
rule "admin_edit" do
  match do
    all(user(:admin?))
  end
  execute do
    set :edit, true
  end
end

rule "editor_edit" do
  match do
    all(user(:editor?))
  end
  execute do
    set :edit, true
  end
end

rule "owner_edit" do
  match do
    all(user(:owner?))
  end
  execute do
    set :edit, true
  end
end
```

### 2. Optimize Condition Order

Put cheap, likely-to-fail checks first:

```ruby
# Good - cheap check first
match do
  all(
    user(:logged_in?),        # Fast boolean check
    present?(record_value(:title)), # Fast presence check
    expensive_db_query()      # Slow check last
  )
end

# Less efficient - expensive check first
match do
  all(
    expensive_db_query(),
    user(:logged_in?)
  )
end
```

### 3. Use Salience Wisely

Higher salience rules execute first - use for critical paths:

```ruby
# Execute validation first (high salience)
rule "validate_input", salience: 100 do
  # Fast validation
end

# Then business logic (normal salience)
rule "process_order", salience: 10 do
  # Heavier processing
end
```

### 4. Limit Execution Cycles

Set appropriate `max_cycles` to prevent runaway execution:

```ruby
# For simple rules that shouldn't chain
ctx = engine.run(user: user, max_cycles: 1)

# For complex workflows
ctx = engine.run(user: user, max_cycles: 50)
```

### 5. Cache Engine Instances

Reuse engines across requests:

```ruby
class RuleService
  def self.engine
    @engine ||= begin
      rules = load_rules_from_database
      Ruleur::Engine.new(rules: rules)
    end
  end
end

# Use cached engine
ctx = RuleService.engine.run(user: user)
```

### 6. Precordompute Values

Avoid expensive computations in conditions:

```ruby
# Bad - computed on every evaluation
match do
  all(
    gt?(record_value(:items).sum(&:price), 1000)
  )
end

# Good - precordompute before engine run
total = recordord.items.sum(&:price)
ctx = engine.run(user: user, recordord: recordord, total: total)

rule "high_value_order" do
  match do
    all(gt?(ref(:total), 1000))
  end
end
```

## Debugging Techniques

### 1. Trace Execution

Enable tracing to see what fires:

```ruby
engine = Ruleur::Engine.new(rules: rules, trace: true)
```

### 2. Test Conditions Manually

Evaluate conditions outside the engine:

```ruby
ctx = Ruleur::Context.new(user: user, recordord: recordord)

# Test condition
condition = all(user(:admin?), record(:published?))
result = condition.evaluate(ctx)

puts "Condition result: #{result}"  # => true/false
```

### 3. Inspect Rule Eligibility

Check if a rule would fire:

```ruby
rule = engine.rules.find { |r| r.name == "my_rule" }
ctx = Ruleur::Context.new(user: user, recordord: recordord)

if rule.eligible?(ctx)
  puts "Rule would fire"
else
  puts "Rule would not fire"
end
```

### 4. Log Context State

Inspect context before/after execution:

```ruby
ctx = Ruleur::Context.new(user: user, recordord: recordord)
puts "Before: #{ctx.facts.inspect}"

engine.run(ctx)

puts "After: #{ctx.facts.inspect}"
```

### 5. Use Validation

Validate rules to catch errors early:

```ruby
engine.rules.each do |rule|
  result = Ruleur::Validation.validate_rule(rule)
  unless result.valid?
    puts "Rule '#{rule.name}' has errors:"
    result.errors.each { |e| puts "  - #{e}" }
  end
end
```

## Custom Operators

Register custom operators for domain-specific logic:

```ruby
# Register custom operator
Ruleur::Operators.register(:within_range) do |value, range|
  range.is_a?(Range) && range.include?(value)
end

# Use in rule
rule "age_range_check" do
  match do
    all(
      predicate do
        left = record_value(:age)
        right = lit(18..65)
        Ruleur::Operators.call(:within_range, left, right)
      end
    )
  end
  execute do
    set :eligible, true
  end
end
```

::: warning
Custom operators won't serialize to YAML. Use them only for code-based rules.
:::

## Working with Large Datasets

### Batch Processing

Process recordords in batches:

```ruby
def process_batch(recordords, user)
  results = []
  
  recordords.each do |recordord|
    ctx = engine.run(user: user, recordord: recordord)
    results << { recordord_id: recordord.id, allowed: ctx[:access] }
  end
  
  results
end

# Process in chunks
Record.find_in_batches(batch_size: 100) do |batch|
  results = process_batch(batch, current_user)
  BulkProcessor.process(results)
end
```

### Parallel Processing

Use threads for parallel execution:

```ruby
require 'concurrent'

recordords = Record.all.to_a
thread_pool = Concurrent::FixedThreadPool.new(10)

futures = recordords.map do |recordord|
  Concurrent::Future.execute(executor: thread_pool) do
    engine.run(user: user, recordord: recordord)
  end
end

results = futures.map(&:value)
```

## Best Practices Summary

1. **Use salience** to control execution order
2. **Enable no-loop** to prevent infinite firing
3. **Tag rules** for organization and filtering
4. **Cache engines** for better performance
5. **Optimize conditions** (cheap checks first)
6. **Limit cycles** with `max_cycles`
7. **Enable tracing** during development
8. **Validate rules** before deployment
9. **Test conditions** independently
10. **Monitor performance** in production

## Next Steps

- **[DSL Basics](./dsl-basics.md)**: Master rule authoring
- **[Conditions](./conditions.md)**: Build complex conditions
- **[Persistence](./persistence.md)**: Store rules in database
- **[Versioning](./versioning.md)**: Track rule changes

## Related API

- [Engine Class](../api/engine.md)
- [Rule Class](../api/rule.md)
- [Context Class](../api/context.md)
- [Operators Module](../api/operators.md)
