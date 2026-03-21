Rule execution metrics

The engine records per-run timing and predicate evaluation metrics. These are important system metrics and are returned with each run and aggregated on the Engine instance.

Context debug schema (`ctx.debug`)
- `ctx.debug` is an Array of Hash entries appended during rule evaluation. Typical entries:
  - Rule-level entry: `{ rule: String, salience: Integer, duration_ms: Float, changed: [Symbol] }`
  - Predicate-level entry: `{ predicate: Symbol, rule: String, duration_ms: Float }`

Engine aggregated stats (`engine.stats`)
- `engine.stats` is a Hash with two keys: `:rules` and `:predicates`.
  - `:rules` maps rule name => `{ total_ms: Float, count: Integer }`.
  - `:predicates` maps predicate name (Symbol) => `{ total_ms: Float, count: Integer }`.

Computing averages
- Averages are not stored explicitly, but can be computed as `avg_ms = total_ms.to_f / count` when `count > 0`.

Example

Given `engine` returned from the DSL and a run:

```ruby
ctx = engine.run(record: obj, user: user)
puts ctx.debug # per-run entries
puts engine.stats[:rules]['allow_create'] # => { total_ms: 1.23, count: 2 }
avg = engine.stats[:rules]['allow_create'][:total_ms] / engine.stats[:rules]['allow_create'][:count]
```
