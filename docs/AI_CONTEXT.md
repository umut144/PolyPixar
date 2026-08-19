# PolyTools AI Context

PolyTools is a Godot 4 editor for authoring topology-based 2D assets and
deriving mesh data from them. The current product surface is intentionally
small and database-oriented.

## Visible modules

The left rail is always expanded and exposes exactly these categories:

- `Create`: `Character`, `Props`, `Terrain`, `Icon`, `Symbols`
- `Mesh`: `Sampling`, `Seeding`, `Meshing`
- `Style`: `Weighting`
- `Export`

Only one module is active at a time, even though all categories remain open.
Motion authoring is retained internally for future work but is not selectable
or restored as an active editor category. Transform and Effects are not product
categories. Texture and Material authoring are not part of the application.

## Asset kinds

All five Create modules use the same Asset, Component, Guide, canvas, and
Inspector implementation. An Asset stores one stable `asset_type` value:
`character`, `props`, `terrain`, `icon`, or `symbols`. Create views filter the Outliner by
that value. Documents without an `asset_type` normalize to `character`.

Mesh and Style show a shared multi-select Asset filter above the Outliner
search field. Character, Props, Terrain, Icon, and Symbols are checked by default;
search text and checked types are combined. The filter is an editor-state
preference, not a document mutation.

The field is written to `asset.json` and to the exported Godot scene root as
the `asset_type` metadata value. This is the current export contract for
distinguishing product modules; module-specific behavior can be layered on top
later without changing Asset topology.

## Geometry model

Components have an explicit geometry source. Bézier Components are canonical
only as `points`, `edges`, and `chains`; `BezierTopology` owns their structural
changes and validation, and `BezierGeometry` owns cubic mathematics and handle
resolution. Primitive Components instead own a typed `primitive` record and
never store generated Bézier points, edges, chains, or samples. The currently
supported primitive is `{ type: "circle", center, diameter_cm }`.

`ComponentCanvas` receives immutable view copies, renders them, and emits user
intent; it never mutates Workspace geometry directly. Polygon arrays for fill,
hit testing, sampling, meshing, and export are derived on demand from either
source. A Primitive's center handle moves its `primitive.center`; its Component
pivot remains an independent transform handle.

Components support `closed_loop`, `ribbon`, and `primitive` draw modes. Ribbons
are the sole visible open-curve Component form; simulation and construction
paths are modeled as Guides. Primitive sampling evaluates the analytic Circle at the selected Body's
adaptive target edge length and scale-aware Curve Detail, so it has no fixed or
user-editable sample count. Guides remain independent topology records scoped to an Asset or Component. Derived
Sampling, Seeding, Meshing, UV, and Weighting records are stored separately
from source topology.

Seeding consumes the complete accepted Sampling constraint set. Outer bounds
the valid interior, Holes exclude regions, and Cuts are two-sided barriers with
clearance. Poisson Fill and combined multi-Spine Flow generate deterministic
previews; an explicit Bake accepts that exact result before manual Seed editing
or downstream Meshing. Spine Flow presents Seed Spacing and Flow Stretch as its
primary Artistic controls; exact lattice values and optional Boundary/Stagger
refinements remain available under Advanced Pattern.

Meshing consumes one accepted Seeding Bake and exposes one closed-Body method:
`Constrained Mesh`. Its `Mesh Character` moves continuously from Structured to
Organic by deriving optimization strength and passes while keeping every
sampled Outer, Hole, and Cut constraint fixed. `Optimize Mesh` provides an
exact raw-CDT versus optimized A/B switch. Only quality-improving relocation
passes are accepted; Optimization and Quality views expose movement and a
triangle heatmap. Advanced Optimization can override the derived technical
values. New recipes start at the accepted 64% Artistic profile, deriving
Strength 0.40 and three passes without technical overrides. A debounced Preview
is accepted with `Bake Preview`; that exact Bake
automatically becomes the Component Mesh. Cut seam vertices are duplicated
only after the final constrained triangulation and optimization.
Selecting the Asset root in Meshing presents all current visible Component
Meshes in Asset space; missing or stale Component Meshes are simply omitted.

The persistent toolbar action `Update Meshes (N)` runs Adaptive Sampling,
Poisson Seeding, Constrained Mesh, Optimization, and validation for valid
out-of-date Components across every Create Asset type. It derives calibrated
recipes for Components without existing pipeline settings, preserves manual
recipes, commits successful results atomically per Component, and never lets
one failure replace an older valid Mesh. Its count comes from semantic build
provenance rather than a mutable dirty flag, so selection and sub-tolerance
pointer jitter do not trigger the batch pipeline. Components rejected before
the batch expose their concrete source-validation issue in the Meshing
Inspector without inflating the actionable count.

## Workspace and export

A Workspace persists Assets plus the currently retained motion and derived
mesh records. Assets own Components, Guides, reference-image settings, their
Asset pivot, and their `asset_type`. New persistence must not add display
polygons or reverse synchronization into Component topology.

Export validates topology before building a Godot scene. The scene root owns
the exported Asset pivot and `asset_type`; child `Node2D` records preserve the
Component hierarchy and `Polygon2D` geometry is derived from Bézier topology,
a primitive definition, or an accepted Ribbon mesh.

## Verification

After geometry changes run:

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --editor --quit
git diff --check
```

Files below `workspaces/` are user data and must not be rewritten as fixtures.
