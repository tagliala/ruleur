# API Reference

Welcome to the Ruleur API Reference documentation. This section provides detailed information about all the classes, modules, and methods available in Ruleur.

## Core Components

### [Engine](./engine)
The main execution engine for running rules against contexts.

### [Rule](./rule)
Individual rule definitions with conditions and actions.

### [Context](./context)
The execution context that holds facts and results.

### [Condition](./condition)
Conditional logic for rule evaluation.

### [Operators](./operators)
Available operators for building conditions.

## Configuration & Loading

### [DSL](./dsl)
The Domain-Specific Language for defining rules in Ruby.

### [YAML Loader](./yaml-loader)
Load and parse rules from YAML files.

### [Validation](./validation)
Rule validation and testing framework.

## Persistence

### [Repositories](./repositories)
Database storage and version management for rules.

## Getting Started

If you're new to Ruleur, we recommend starting with the [Getting Started Guide](/getting-started/) before diving into the API reference.

## Usage Pattern

```ruby
# 1. Define rules using DSL
engine = Ruleur.define do
  rule "example" do
    when_all(condition)
    action { # ... }
  end
end

# 2. Run engine with context
result = engine.run(facts: data)

# 3. Access results
result[:output]
```

## API Documentation Status

::: warning Work in Progress
This API reference is currently being developed. Each section will be populated with detailed documentation, examples, and usage patterns.
:::
