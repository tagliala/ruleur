# Installation

## Requirements

- Ruby 3.2 or higher
- Optional: ActiveRecord (for database persistence)

## Install via Gemfile

Add Ruleur to your `Gemfile`:

```ruby
gem 'ruleur'
```

Then run:

```bash
bundle install
```

## Install via gem command

```bash
gem install ruleur
```

## Verify Installation

Create a test file `test_ruleur.rb`:

```ruby
require 'ruleur'

engine = Ruleur.define do
  rule 'hello' do
    conditions do
      any?(truthy?(true))
    end
    actions do
      set :greeting, 'Hello Ruleur!'
    end
  end
end

ctx = engine.run
puts ctx[:greeting] # => "Hello Ruleur!"
```

Run it:

```bash
ruby test_ruleur.rb
```

If you see "Hello Ruleur!", you're ready to go!

## Optional: Database Setup

If you plan to store rules in a database with version tracking, you'll need ActiveRecord:

```ruby
# Gemfile
gem 'activerecord'
gem 'pg' # or your database adapter
```

Generate migrations:

```ruby
require 'ruleur/generators/migration_generator'

Ruleur::Generators::MigrationGenerator.write_migrations('db/migrate')
```

This creates:
- `create_ruleur_rules.rb` - Main rules table
- `create_ruleur_rule_versions.rb` - Version history table

Run migrations:

```bash
bundle exec rake db:migrate
```

## Project Structure

For a typical Rails project:

```
your_app/
├── app/
├── config/
│   └── rules/          # YAML rule files
│       ├── permissions/
│       └── workflows/
├── lib/
│   └── rules/          # Ruby DSL rules (if not using YAML)
└── spec/
    └── rules/          # Rule tests
```

For non-Rails projects:

```
your_project/
├── rules/
│   ├── dsl/            # Ruby DSL rule definitions
│   └── yaml/           # YAML rule files
├── lib/
└── spec/
```

## Next Steps

Now that Ruleur is installed, let's create your first rule:

[Your First Rule →](./first-rule)
