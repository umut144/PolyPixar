# PolyTools – Geometry Meshing

**Status:** Constrained Meshing MVP contract.

## Observable result

In `Mesh → Meshing`, the user selects one closed Body Component, selects its
accepted Seeding source, adjusts `Mesh Character` between Structured and
Organic, optionally switches `Optimize Mesh` on or off for an exact A/B
comparison, inspects an automatically generated Preview, and explicitly
accepts that exact result with `Bake Preview`. The accepted Bake automatically
becomes the Component Mesh.

The Outliner presents the active dependency chain as Sampling → Seeding →
Constraints → Mesh. The Inspector exposes one method, `Constrained Mesh`, plus
view-only toggles for mesh edges, Seed points, triangle fill, constraints,
Optimization, and Quality.

## Ownership and dependency

Component `points`, `edges`, and `chains` remain the only canonical authored
geometry. A Mesh is derived Component-local data and is never synchronized
back into Component topology. The selected Seeding Bake identifies its exact
Sampling Bake, so Meshing never combines unrelated upstream results.

Closed Contours remain outside the visible Fill-meshing pipeline. Their
accepted Contour build keeps the centered Stroke as the only visible Component
Mesh and separately derives a deterministic Runtime region triangulation from
the complete adaptive, unoffset Boundary. That `closed_region_mesh` is
engine-neutral geometry with no material, color, alpha, UV, rendering, or Fill
semantics. It is invalidated by the same Point, handle, Chain, and Scale-Rebase
source provenance as its Contour build, while Stroke visibility and width do
not change the region geometry.

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

Sampling first arranges Cut intersections into shared PSLG junctions and
removes Cut spans inside Holes. Meshing validates that graph for coincident
vertices, zero-length or duplicate constraints, unsplit vertices on a segment,
and intersections without a shared endpoint. Diagnostics name the affected
role and segment rather than reporting a generic triangulation failure.

The validated vertices and constraint-index pairs cross a narrow synchronous
GDExtension boundary into pinned `artem-ogre/CDT` 1.4.5. The native adapter
does not own PolyTools data, retain pointers, infer domain semantics, or mutate
the document. It catches native exceptions and returns copied indices;
PolyTools verifies every fixed edge, filters triangles against Outer and Holes,
canonicalizes output order, and remains owner of seam duplication and IDs.

`Mesh Character` is the primary control. Structured uses the direct constrained
triangulation. Moving toward Organic derives increasing relocation strength and
one to four optimization/retriangulation passes. `Optimize Mesh` gates the
whole stage: off returns the exact raw CDT, while on evaluates every candidate
pass against minimum angle, worst aspect ratio, mean normalized triangle
quality, and degeneracy count. A pass with a material minimum-angle regression
is rejected; unsuccessful passes retry at reduced strength before stopping.
Only interior Seed vertices can move. `Advanced Optimization` may override
strength or pass count independently when exact technical control is required.
New recipes use the accepted default profile of 64% Mesh Character, which
derives approximately Strength 0.40 and three passes. Existing recipes are not
rewritten.

Optimization and constrained retriangulation complete before Cut vertices are
duplicated into seam sides. The result reports vertex and triangle counts,
minimum angle, worst aspect ratio, recovered constraints, Cut seam vertices,
degenerate triangles, accepted movements, and before/after metrics. The
Optimization view overlays the raw baseline, final mesh, and Seed movement
vectors. Its yellow baseline is deliberately translucent so dense final edges
remain legible. The Quality view colors final triangles from poor to strong. Identical
inputs and recipes produce identical output.

Minimum angles below `5°` and worst aspect ratios above `25` are displayed as
orange quality warnings in the Inspector. They remain diagnostic because a
global angle threshold would reject otherwise valid shape-dependent boundary
features; complete Constraint coverage and zero degenerate Triangles remain the
hard validity requirements. Closed Bézier Sampling reduces avoidable warnings
before Meshing by balancing abrupt derived edge-length transitions at authored
corners. If Sampling cannot complete that best-effort pass within its per-Chain
limit, the Result and Auto Build Diagnostics show a separate orange Boundary
Refinement warning without changing Mesh validity.

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

Schema 32 adds persisted Cut fragments. Meshing algorithm version 3 replaces
the former Godot Delaunay plus custom edge-flip recovery with the qualified
native CDT backend, so older Mesh Bakes remain visible but stale until baked
again. The checked-in macOS-arm64 debug framework supports the pinned Godot
Mono 4.7.1 authoring environment. Linux is supported as a build-from-source
target for headless verification, without a checked-in product. Native rebuild
instructions and exact dependency commits live in
`native/polytools_cdt/README.md`.

Schema 33 and Meshing algorithm version 4 add conservative existing-point
optimization diagnostics. This first optimizer phase never inserts or removes
Steiner points; selective removal remains a separately testable future phase.

Manual Mesh editing, local refinement painting, Seed removal during
optimization, background-threaded generation, and reverse synchronization
remain deferred.
