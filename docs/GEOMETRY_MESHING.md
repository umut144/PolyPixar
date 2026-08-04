# AssetFlow2D – Geometry Meshing

**Status:** Meshing MVP contract.

## Observable result

In `Geometry → Meshing`, the user selects one Component, chooses Constrained
Delaunay or Organic Relaxed through `CMD/Ctrl + 1 · Method`, selects one of the
Component's persisted Seeding Bakes, previews the generated triangles, and
explicitly bakes the accepted Mesh. Each Component retains one Mesh Bake per
Meshing method for direct comparison in the Outliner.

## Ownership and dependency

Component `points`, `edges`, and `chains` remain the only canonical authored
geometry. A Mesh is derived Component-local data and is never synchronized
back into Component topology. The selected Seeding Bake identifies its exact
Sampling Bake, so Meshing never combines unrelated upstream results.

```text
canonical Bézier topology → Sampling Bake → Seeding Bake → Meshing Bake
```

Each Mesh Bake stores both upstream Bake IDs and fingerprints. Canonical
topology changes, Sampling changes, Guide changes, or manual Seed edits make a
dependent Mesh Bake stale without deleting or rewriting it.

## Methods

- **Constrained Delaunay** uses all sampled boundary vertices as fixed
  constraints and all selected Seeds as interior vertices. It has no artistic
  tuning parameter beyond `Seed Source`.
- **Organic Relaxed** starts from the same constrained result and exposes only
  `Relaxation` and `Passes`. It moves interior derived vertices toward their
  local neighbourhood and retriangulates after each pass. Boundary vertices,
  holes, and Preserve Points remain fixed.

Both methods are deterministic for identical inputs and recipes.

## Generate, Bake, and comparison

Method, Seed Source, Relaxation, and Pass changes automatically run Generate.
Generate produces a temporary preview that does not participate in history.
Bake accepts only a valid preview matching the current recipe and upstream
fingerprints; the accepted derived result participates in Undo/Redo and
Workspace persistence.

The Geometry Outliner displays available Mesh Bakes beneath their Component.
Switching Method selects its matching Bake and restores its recipe parameters.
One Bake is retained per method; multiple input variants of the same method
are deferred.

Mesh vertices carry stable IDs. Triangles refer to those IDs instead of owning
copies of positions, establishing the downstream identity required by UV
Mapping and later Inner Animation without making the Mesh canonical geometry.

## Component Mesh output

A Component explicitly selects one current Mesh Bake through `Use as Component
Mesh`. This persistent reference stores the Bake ID, method, and fingerprint;
it is never inferred from the currently viewed or most recently generated
method. Downstream Weighting and later export consume only this selected output.

The output status is `Missing` until selected, `Ready` while its exact Bake and
upstream chain are current, and `Stale` when that Bake is replaced or any input
fingerprint changes. Existing Mesh Bakes and the selected reference are retained
for inspection instead of being silently rewritten.

## Deferred

Manual Mesh editing, quality heatmaps, multiple variants per method, automatic
refinement controls, UV coordinates, export consumption, Animation weights,
and reverse synchronization are outside this MVP.
