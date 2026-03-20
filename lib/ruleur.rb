# frozen_string_literal: true

require_relative 'ruleur/version'
require_relative 'ruleur/context'
require_relative 'ruleur/operators'
require_relative 'ruleur/condition'
require_relative 'ruleur/rule'
require_relative 'ruleur/engine'
require_relative 'ruleur/dsl'
require_relative 'ruleur/persistence/serializer'
require_relative 'ruleur/persistence/repository'

# Ruleur is a composable Business Rules Management System (BRMS) for Ruby.
# It provides a forward-chaining engine with composable conditions, salience-based
# conflict resolution, and optional rule persistence.
module Ruleur
  # Convenience to build an engine from a block using the DSL
  def self.define(&)
    DSL.build(&)
  end
end
