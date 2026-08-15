# PolyTools – Geometry Sampling

**Status:** Sampling MVP contract.

## Observable result

In `Geometry → Sampling`, the user selects one Component, chooses Adaptive or
Even Spacing, adjusts the method's small parameter set, generates a temporary
boundary preview, and explicitly bakes an accepted result. Every Component owns
an independent recipe and bake.

## Ownership

Component `points`, `edges`, and `chains` remain the only canonical authored
geometry. `GeometrySamplingService` consumes an immutable Component copy and
returns ordered, Component-local boundary samples. It never changes Bézier
topology, Component transforms, Motion documents, or the existing
`MotionSampler` contract.

Sampling recipes and bakes are component-scoped derived Geometry records keyed
by stable Asset and Component IDs. A bake records a fingerprint of its source
topology. A changed fingerprint makes that bake stale; derived data is never
synchronized back into authored topology.

## Methods

- **Adaptive** exposes `Spacing` (default `1.00` local units) and `Feature Detail`. It recursively subdivides
  cubic edges from chord length, flatness, and tangent turn.
- **Even Spacing** exposes only `Spacing` and uses an approximate arc-length
  table per cubic edge.

Both methods are deterministic. Closed Chains omit a duplicate copy of their
first sample at the end.

## Preserve Point

Every Bézier edge endpoint participates in sampling. A Point with
`preserve_point: true` additionally carries an explicit preserved guarantee:
it remains at its exact authored position and may not be removed or merged by
later simplification. Coincident preserved Points are a validation concern,
not permission to erase authored intent.

## Generate and Bake

Changing a method or parameter automatically runs `Generate` and updates the
temporary preview; the generated preview does not participate in document
history. `Bake` accepts only a valid preview matching the current recipe and
source fingerprint, then persists the derived result and participates in
Undo/Redo. Recipe or topology changes make the previous bake stale.

## Deferred

`CMD/Ctrl + 0 · Analysis`, `CMD/Ctrl + 2 · Edit Sample Point`, manual sample
overrides, Seeding, Meshing, UV Mapping, Animation Spines, Inner deformation,
and export consumption are outside this module MVP.
