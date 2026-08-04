# AssetFlow2D – Animation Spines

**Status:** Persistent authoring foundation.

## Observable result

An Asset Component can own an `Animation Spine` Guide alongside Body Flow and
Sampler Spine Guides. It is authored with the same open Spine tools, persisted
with the Asset, and may be duplicated with `CMD/Ctrl + D`.

## Semantic separation

```text
Sampler Spine   → Geometry / Seeding input
Animation Spine → Motion / runtime-only Inner Animation input
```

The two Spine types share the same local Point/Edge/Chain topology contract,
but they are never interchangeable. Seeding accepts only Sampler Spines;
Animation Spines do not create or invalidate Geometry Bakes by themselves.

## Type changes and duplication

Guide Type is editable at any time. Changing a Sampler Spine to an Animation
Spine leaves its topology untouched and makes any dependent Spine Flow Bake
ineligible or stale until a valid Sampler Spine is selected again.

`CMD/Ctrl + D` duplicates the selected Guide with a new stable Guide ID, a
unique copy name, and independently remapped Point, Edge, and Chain IDs. The
copy remains scoped to the same Component and can change type independently of
the original.

## Deferred

Animation Spine weighting, Mesh Vertex binding, deformation evaluation,
runtime caches, and export are deferred. The first Inner Animation slice will
reference an Animation Spine by stable Guide ID and evaluate temporary vertex
positions without mutating persisted Mesh Bakes or Component topology.
