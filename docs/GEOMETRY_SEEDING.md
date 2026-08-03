# AssetFlow2D – Geometry Seeding

**Status:** Seeding MVP contract.

## Observable result

In `Geometry → Seeding`, the user selects one Component whose Sampling result
is currently baked, chooses deterministic Poisson Fill or Sampler-Spine-driven
Spine Flow, sees an automatically generated interior preview, and explicitly
bakes the accepted Seeds. `CMD/Ctrl + 2 · Edit Seeds` then allows a baked Seed
to be added, moved, or removed.

## Ownership and dependency

Every method consumes exactly one current Sampling Bake. Spine Flow additionally
consumes one authored `sampler_spine` Guide scoped to the same Component.
Seeding never changes Component `points`, `edges`, or `chains`, and it never
modifies the Sampling recipe or result. A changed input makes the Seeding result
stale and blocks editing until a current result is generated and baked.

```text
canonical Bézier topology → Sampling Bake ─┐
                                           ├→ Seeding Bake → future Meshing
Component Sampler Spine ───────────────────┘
```

The Seeding Bake stores the stable Sampling Bake ID and a fingerprint of its
sampled boundary. Spine Flow additionally stores the stable Guide ID and a
fingerprint of its Guide topology. Changing either input marks the Bake stale.
CDT and triangulator-generated refinement vertices belong to the future
Meshing module, not to Seeding.

## Poisson Fill

The first method exposes only `Spacing` and integer `Seed`. It uses deterministic
Poisson-disk placement inside the sampled outer Chain and outside sampled hole
Chains. Boundary clearance is derived as half of Spacing. Parameters use
Auto-Generate; Bake remains explicit.

## Spine Flow

Spine Flow exposes `Sampler Spine`, `Along Spacing`, `Across Spacing`,
`Boundary Clearance`, `Stagger`, and optional `Fill Gaps`. It samples the Guide
uniformly along its length, derives the local tangent and normal at each
station, and intersects both normal directions with the sampled Component
boundary. Steiner Points are placed between the Spine and those intersections.
Alternating stations offset their cross-section rows by `Stagger`, producing an
organic rather than rectilinear distribution.

`Fill Gaps` uses deterministic Poisson completion around the preserved Spine
Flow rows. Seeds remain inside the outer boundary, outside hole Chains, and at
least `Boundary Clearance` away from sampled contours. The Sampler Spine itself
is shown in yellow in the Seeding workspace. A curve that leaves the valid
Component region fails Generate visibly.

## Edit Seeds

Edit Seeds is available only for a current baked result:

1. Select / Move
2. Add
3. Remove

If a valid Preview is currently visible, invoking Edit Seeds explicitly accepts
that Preview as the new Bake and enters editing immediately. This keeps manual
mutations on persistent data without requiring a separate Bake click first.

Each Component persists one Seeding Bake per method. The Geometry Outliner
shows those Bakes as children of the Component, and switching Method selects
the matching child and restores its method parameters for direct comparison.
Therefore Poisson Fill and Spine Flow never overwrite one another. Re-baking
the same method may still require explicit confirmation when that method's Bake
contains manual edits.

Manual mutations participate in Undo/Redo and update the active method Bake in place. Added
Seeds use `origin: manual`; moved generated Seeds become `manual_adjusted`.
Regeneration never silently overwrites an edited Bake of the same method.

## Deferred

Animation deformation, further Guide types, CDT, mesh-quality refinement, and
manual Boundary editing remain outside this MVP.
