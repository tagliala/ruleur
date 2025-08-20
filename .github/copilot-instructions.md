# GitHub Copilot Instructions for Ruleur

## Project Overview

Ruleur is a Ruby gem that implements a Business Rule Management System (BRMS) using the Rete algorithm. The gem allows you to manage business rules in a scalable and efficient manner.

### Core Architecture

The Rete algorithm implementation consists of:

- **Network**: Implements the algorithm using nodes
  - **Alpha Nodes**: Filter facts based on conditions
  - **Beta Nodes**: Match filtered facts to activate rules
- **Rule Set**: Top-level container for all rules
- **Rules**: Business rules with conditions and actions
- **Facts**: Data processed by the system
- **Working Memory**: Maintains current state of facts

## Development Guidelines

### Branching Strategy

This project follows the git-flow branching model:

- `main` branch: Latest published version
- `develop` branch: Official development branch for next release

**Pull Request Guidelines:**
- Bug fixes and documentation: target `main` branch
- New features: target `develop` branch
- Keep changes simple and small
- Avoid unintended changes

### Code Style and Standards

#### Ruby Style

- Follow the [Ruby Style Guide](https://github.com/rubocop/ruby-style-guide)
- Use RuboCop for code linting (configuration in `.rubocop.yml`)
- Target Ruby version: 3.1+
- Use `frozen_string_literal: true` in all Ruby files

#### Code Patterns

- Use descriptive method and variable names
- Prefer explicit over implicit code
- Follow single responsibility principle
- Use dependency injection for testability

### Testing Requirements

- **Test-First Development**: Write failing tests before implementing features
- Use RSpec for all tests
- Test files located in `spec/` directory
- Follow existing test patterns and naming conventions
- Maintain high test coverage

#### Test Structure

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruleur::ClassName do
  describe '#method_name' do
    # Test cases here
  end
end
```

### Commit Message Format

Follow the guidelines from [How to Write a Git Commit Message](https://cbea.ms/git-commit/#seven-rules):

1. Separate subject from body with a blank line
2. Limit the subject line to 50 characters
3. Capitalize the subject line
4. Do not end the subject line with a period
5. Use the imperative mood in the subject line
6. Wrap the body at 72 characters
7. Use the body to explain what and why vs. how

**Examples:**
```
Add alpha node filtering capability

Implement condition evaluation for facts in alpha nodes
to support basic rule filtering functionality.
```

```
Fix memory leak in working memory

Remove unused fact references after rule evaluation
to prevent accumulation of stale data.
```

### File Organization

- Main library code: `lib/ruleur/`
- Test files: `spec/ruleur/`
- Entry point: `lib/ruleur.rb`
- Version info: `lib/ruleur/version.rb`

### Dependencies and Configuration

- Use Bundler for dependency management
- RuboCop configuration in `.rubocop.yml`
- RSpec configuration in `spec/spec_helper.rb`
- Rake tasks defined in `Rakefile`

### Code Review Considerations

When suggesting code changes:

1. **Minimal Changes**: Make the smallest possible changes to achieve the goal
2. **Preserve Existing Functionality**: Don't break working code
3. **Follow Existing Patterns**: Match the style and structure of existing code
4. **Add Tests**: Include tests for new functionality
5. **Update Documentation**: Update relevant documentation for changes

### Common Patterns in Ruleur

- Node classes inherit from base `Node` class
- Use factory patterns for creating complex objects
- Implement visitor pattern for network traversal
- Use functional programming concepts where appropriate
- Prefer composition over inheritance

### Performance Considerations

- The Rete algorithm is designed for performance
- Avoid unnecessary object creation in hot paths
- Use memoization for expensive operations
- Consider memory usage in long-running processes

## License

All contributions must be compatible with the MIT License. By contributing, you agree to license your contribution under the same terms.