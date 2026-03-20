# Getting Started with Ruleur

Ruleur is a composable Business Rules Management System (BRMS) for Ruby that helps you separate changing business logic from your codebase.

## What is Ruleur?

Ruleur provides a forward-chaining rules engine that allows you to:

- **Define business rules** using a readable Ruby DSL or YAML
- **Compose complex conditions** with all/any/not operators
- **Store rules in databases** with full version tracking
- **Validate rules** before execution
- **Track changes** with comprehensive audit trails

## Key Concepts

### Rules

A rule consists of:
- **Name**: Unique identifier for the rule
- **Condition**: When the rule should fire (composable boolean logic)
- **Action**: What the rule should do when it fires
- **Metadata**: Salience (priority), tags, no-loop flag

### Engine

The engine:
- Evaluates rules against a context (facts)
- Fires rules in priority order (salience)
- Propagates facts between rules
- Supports no-loop to prevent infinite firing

### Context

The context holds:
- Input facts (data passed to the engine)
- Output facts (results from rule actions)
- References to domain objects

## When to Use Ruleur

✅ **Good use cases:**
- Permission systems (replace complex Pundit policies)
- Workflow automation
- Dynamic pricing rules
- Eligibility checks
- Approval processes
- Configuration-driven behavior

❌ **Not recommended for:**
- Simple if/else logic (use regular Ruby)
- Performance-critical paths (rules have overhead)
- One-time calculations (use functions)

## Next Steps

<div style="display: flex; gap: 1rem; margin-top: 2rem;">
  <a href="./installation" style="flex: 1; padding: 1rem; border: 1px solid var(--vp-c-divider); border-radius: 8px; text-decoration: none;">
    <h3 style="margin-top: 0;">Installation →</h3>
    <p style="margin-bottom: 0; color: var(--vp-c-text-2);">Install Ruleur and set up your project</p>
  </a>
  
  <a href="./first-rule" style="flex: 1; padding: 1rem; border: 1px solid var(--vp-c-divider); border-radius: 8px; text-decoration: none;">
    <h3 style="margin-top: 0;">Your First Rule →</h3>
    <p style="margin-bottom: 0; color: var(--vp-c-text-2);">Build your first business rule</p>
  </a>
</div>
