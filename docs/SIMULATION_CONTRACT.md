# PolyTools – Simulation Contract

**Status:** Phase 7 persisted Asset contract. External file import, runtime
value delivery, and Transition evaluation are not implemented yet.

## Responsibility boundary

An Animation may declare which typed inputs its Transition Rules need. The host
Simulation owns the live values. It does not expose arbitrary internal state to
the Animation, and the Animation does not write Simulation values.

The future import boundary is a versioned declaration shaped like this:

```json
{
  "contract_id": "character_locomotion",
  "version": 1,
  "parameters": [
    {"id": "parameter_speed", "name": "speed", "type": "number"},
    {"id": "parameter_grounded", "name": "grounded", "type": "bool"}
  ]
}
```

`id` is the reference key and must remain stable across display-name changes.
Names must be unique within one Contract. Phase 6 accepts `number` and `bool`.
The current Inspector-authored declaration is saved inside the Asset. A future
external import may replace its source while retaining the same normalized
shape and stable-ID semantics.

## Transition Rule shape

Rules belong to a Transition and are evaluated as an `ALL` conjunction. An
empty Rule list is true, so Exit Policy alone controls eligibility.

```json
{
  "id": "rule_walk_run_01",
  "parameter_id": "parameter_speed",
  "operator": "greater",
  "value": 0.65
}
```

Supported operators are type-dependent:

- `number`: `equal`, `not_equal`, `greater`, `greater_equal`, `less`,
  `less_equal`
- `bool`: `is_true`, `is_false`; no comparison value is required

Rules never reference a parameter by display name. Changing a parameter type
normalizes its dependent Rules to the first compatible operator. A parameter
cannot be removed while Rules still reference it.

## Future host validation

Before playback, the Simulation integration must verify:

1. Contract version and supported parameter types.
2. Unique parameter IDs and names.
3. A live value source for every parameter referenced by a Rule.
4. Runtime value types matching their declarations.
5. Rule operators compatible with the referenced parameter type.

Only after this validation may Transition evaluation begin. List order remains
Transition priority: the first Transition whose Exit Policy permits leaving
and whose Rules all match wins.
