# PolyTools – Geometry Meshing

**Status:** Constrained Meshing MVP contract.

## Observable result

In `Mesh → Meshing`, the user selects one closed Body Component, selects its
accepted Seeding source, adjusts `Mesh Character` between Structured and
Organic, inspects an automatically generated Preview, and explicitly accepts
that exact result with `Bake Preview`. The accepted Bake automatically becomes
the Component Mesh.

The Outliner presents the active dependency chain as Sampling → Seeding →
Constraints → Mesh. The Inspector exposes one method, `Constrained Mesh`, plus
view-only toggles for mesh edges, Seed points, triangle fill, and constraints.

## Ownership and dependency

Component `points`, `edges`, and `chains` remain the only canonical authored
geometry. A Mesh is derived Component-local data and is never synchronized
back into Component topology. The selected Seeding Bake identifies its exact
Sampling Bake, so Meshing never combines unrelated upstream results.

```text
canonical Bézier topology → Sampling Bake → Seeding Bake → Constrained Mesh Bake
```

The Mesh Bake stores both upstream Bake IDs and fingerprints. Canonical
topology, Sampling, Guide, or accepted Seed changes retain the previous result
as stale and request a new Preview.

## Artistic Constrained Mesh

All closed Bodies use one constrained triangulation method. Sampled Outer,
Hole, and Cut vertices are fixed constraints; accepted Seeds are interior
vertices. Hole interiors remain empty and Cuts remain recoverable two-sided
seams.

`Mesh Character` is the primary control. Structured uses the direct constrained
triangulation. Moving toward Organic derives increasing relaxation strength and
one to four relaxation/retriangulation passes. Only interior Seed vertices can
move. `Advanced Relaxation` may override strength or pass count independently
when exact technical control is required.

Relaxation and constrained retriangulation complete before Cut vertices are
duplicated into seam sides. The result reports vertex and triangle counts,
minimum angle, recovered constraints, Cut seam vertices, and degenerate
triangles. Identical inputs and recipes produce identical output.

## Preview, Bake, and Component Mesh

Parameter changes schedule one debounced transient Preview. Preview generation
does not participate in history. `Bake Preview` is enabled only for a valid
Preview matching the current recipe and upstream fingerprints; it copies that
result without regenerating it.

Accepting replaces the Component's single Constrained Mesh Bake and atomically
records its Bake ID, method, and fingerprint as `component_mesh`. Downstream UV
Mapping and Weighting consume that accepted output. There is no separate `Use
as Component Mesh` action. The output is `Ready` while the exact dependency
chain matches and `Stale` when a source or accepted Bake changes.

Mesh vertices carry stable IDs, and triangles refer to those IDs instead of
owning position copies. Cut seam duplicates keep their source identity while
remaining independent downstream vertices.

## Migration and deferred work

Schema 31 consolidates legacy Constrained Delaunay and Organic Relaxed recipes
and Bakes into one Constrained Mesh. The accepted Component Mesh wins when both
legacy Bakes exist; legacy Organic controls load as Mesh Character plus exact
Advanced Relaxation overrides. Old results remain readable but stale until
regenerated with the current algorithm version.

Manual Mesh editing, quality heatmaps, local refinement painting,
background-threaded generation, and reverse synchronization remain deferred.
