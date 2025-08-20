# Ruleur

A tiny, composable Business Rules Engine (BRMS) for Ruby with:
- Composable boolean conditions (all/any/not + predicates)
- A small, readable Ruby DSL
- Forward-chaining engine with salience and no-loop
- Optional persistence (serialize/deserialize rules) with a memory or ActiveRecord-backed repository

Status: PoC.

## Why

Separate changing business logic (rules) from code where possible, keep policies small, and make rules testable and inspectable. One use case is replacing complex Pundit checks with rules, but Ruleur is generic.

## Quick start

```ruby
require "ruleur"

MockRecord = Struct.new(:updatable, :draft) do
  def updatable? = !!updatable
  def draft? = !!draft
end

MockUser = Struct.new(:admin) do
  def admin? = !!admin
end

engine = Ruleur.define do
  rule "allow_create", no_loop: true do
    when_any(
      usr(:admin?),
      all(rec(:updatable?), rec(:draft?))
    )
    action { allow! :create }
  end

  rule "allow_update", no_loop: true do
    when_all(
      rec(:updatable?),
      any(
        usr(:admin?),
        all(rec(:draft?), flag(:create))
      )
    )
    action { allow! :update }
  end
end

ctx = engine.run(record: MockRecord.new(true, true), user: MockUser.new(false))
ctx[:allow_create] # => true
ctx[:allow_update] # => true
```

DSL helpers:
- rec(:method_name) => truthy(record.method_name)
- usr(:method_name) => truthy(user.method_name)
- flag(:name) => truthy(:allow_name)
- allow!(:name) => set :allow_name => true
- You can still use eq/gt/lt/includes/matches, all/any/not_ for more complex cases.

## Persistence

Rules can be serialized to a JSON-able structure (condition AST + action_spec) and stored in a database.

- Memory repository:

```ruby
repo = Ruleur::Persistence::MemoryRepository.new
engine.rules.each { |r| repo.save(r) }

loaded_engine = Ruleur::Engine.new(rules: repo.all)
```

- ActiveRecord repository (optional):

Create a table (recommended jsonb for payload):

```ruby
class CreateRuleurRules < ActiveRecord::Migration[7.0]
  def change
    create_table :ruleur_rules do |t|
      t.string :name, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :ruleur_rules, :name, unique: true
  end
end
```

Then:

```ruby
repo = Ruleur::Persistence::ActiveRecordRepository.new
engine.rules.each { |r| repo.save(r) }
rules = repo.all
engine = Ruleur::Engine.new(rules: rules)
```

Note: Only a constrained action_spec is persisted (e.g., `{ set: { allow_update: true } }`). Arbitrary Ruby actions are intentionally not serializable.

## Is storing rules in a DB a good practice?

Yes, when you need runtime configurability. Ensure:
- Pre-validation and compilation of rules before activation
- Versioning and audit trail
- Strong typing/constraints on permitted actions (no arbitrary code)
- Staged rollout and safe rollback
- Tests that exercise serialized rules

For simpler deployments or when rules are tightly coupled to code, keeping them in code may be preferable.

## Development

- Minimal RSpec suite in `spec/`
- Example script in `examples/policy_poc.rb`
- Engine tracing: `Ruleur::Engine.new(trace: true)`

## Roadmap

- Rule groups/agenda groups, conflict strategies
- Richer DSL proxies (method-chained refs), temporal ops
- YAML loader for authoring rules outside Ruby
- Better explanations/tracing (why a rule did/didn't fire)