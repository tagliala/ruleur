---
layout: home

hero:
  name: Ruleur
  text: Business Rules Engine for Ruby
  tagline: Separate business logic from code with composable, testable rules. Forward-chaining engine with YAML authoring and full version tracking.
  image:
    src: /logo.svg
    alt: Ruleur Logo
  actions:
    - theme: brand
      text: Get Started
      link: /getting-started/
    - theme: alt
      text: View on GitHub
      link: https://github.com/tagliala/ruleur
    - theme: alt
      text: Examples
      link: /examples/

features:
  - icon: 🧩
    title: Composable Conditions
    details: Build complex business logic with all/any/not operators and predicates. Chain conditions naturally with readable DSL syntax.
    
  - icon: 📝
    title: YAML Authoring
    details: Define rules in YAML files for easy storage in databases and version control. Load rules dynamically at runtime.
    
  - icon: ✅
    title: Validation Framework
    details: Pre-execution validation with structural, semantic, and test execution checks. Catch errors before deployment.
    
  - icon: 🔄
    title: Version Tracking & Audit
    details: Full audit trail with version history, rollback support, and change tracking. Know who changed what and when.
    
  - icon: 🎯
    title: Forward-Chaining Engine
    details: Salience-based conflict resolution and no-loop support. Rules fire in priority order with fact propagation.
    
  - icon: 💾
    title: Database Persistence
    details: Memory and ActiveRecord repositories with version management. Store rules in your database safely.
    
  - icon: 🔍
    title: Inspectable & Testable
    details: Trace rule execution, serialize rules to JSON, and test rules independently. Debug with confidence.
    
  - icon: 🚀
    title: Production Ready
    details: Used in production. Zero dependencies. Minimal overhead. Comprehensive test coverage.
---

## Quick Example

```ruby
require "ruleur"

engine = Ruleur.define do
  rule "admin_create", no_loop: true do
    match do
      any?(
      user(:admin?),
      all?(record(:updatable?), record(:draft?))
    )
    end
      execute do
    set :create, true
      end
  end

  rule "draft_update", no_loop: true do
    match do
      all?(
      record(:draft?),
      flag(:create)
    )
    end
      execute do
    set :update, true
      end
  end
end

ctx = engine.run(record: record, user: user)
ctx[:create] # => true (if rule fired) or nil
ctx[:update] # => true (if rule fired) or nil
```

With Ruleur, values are only set when rules fire. If no rule matches, the value remains unset.

## Why Ruleur?

**Separate Logic from Code** - Extract changing business rules from your codebase. Update rules without deploying code.

**Testable & Inspectable** - Rules are data structures that can be serialized, tested, and debugged independently.

**Version Control** - Track every change with full audit trails. Roll back bad rules instantly.

**Replace Complex Conditionals** - Turn nested if/else and Pundit policies into declarative, composable rules.

**Database-First** - Store rules in your database with YAML authoring. Load and reload at runtime.

## What's New in v1.0

- ✅ **YAML Import/Export** - Author rules in YAML for easy database storage
- ✅ **Validation Framework** - Structural, semantic, and test execution validation  
- ✅ **Version Tracking** - Full audit trail with `VersionedActiveRecordRepository`
- ✅ **Rollback Support** - Safe rollback that preserves history
- ✅ **Migration Generator** - Easy database setup with provided generators

[Get Started →](/getting-started/)
