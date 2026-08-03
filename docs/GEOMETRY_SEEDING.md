# AssetFlow2D – Geometry Seeding

**Status:** Seeding MVP contract.

## Observable result

In `Geometry → Seeding`, the user selects one Component whose Sampling result
is currently baked, adjusts a deterministic Poisson Fill recipe, sees an
automatically generated interior preview, and explicitly bakes the accepted
Seeds. `CMD/Ctrl + 2 · Edit Seeds` then allows a baked Seed to be added, moved,
or removed.

## Ownership and dependency

Seeding consumes exactly one current Sampling Bake. It never evaluates or
changes Component `points`, `edges`, or `chains`, and it never modifies the
Sampling recipe or result. A changed or stale Sampling Bake makes the Seeding
result stale and blocks editing until a current result is generated and baked.

```text
canonical Bézier topology → Sampling Bake → Seeding Bake → future Meshing
```

The Seeding Bake stores the stable Sampling Bake ID and a fingerprint of its
sampled boundary. CDT and triangulator-generated refinement vertices belong to
the future Meshing module, not to Seeding.

## Poisson Fill

The first method exposes only `Spacing` and integer `Seed`. It uses deterministic
Poisson-disk placement inside the sampled outer Chain and outside sampled hole
Chains. Boundary clearance is derived as half of Spacing. Parameters use
Auto-Generate; Bake remains explicit.

## Edit Seeds

Edit Seeds is available only for a current baked result:

1. Select / Move
2. Add
3. Remove

If a valid Preview is currently visible, invoking Edit Seeds explicitly accepts
that Preview as the new Bake and enters editing immediately. This keeps manual
mutations on persistent data without requiring a separate Bake click first.

Manual mutations participate in Undo/Redo and update the bake in place. Added
Seeds use `origin: manual`; moved generated Seeds become `manual_adjusted`.
Regeneration never silently overwrites an edited bake. Replacing it with a new
preview requires explicit confirmation.

## Deferred

Sampler Spine authoring, Spine Flow, Animation Spines, further Guide types,
CDT, mesh-quality refinement, and manual Boundary editing are outside this MVP.
