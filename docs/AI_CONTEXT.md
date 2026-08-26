# PolyTools AI Context

PolyTools is a Godot 4 editor for authoring topology-based 2D assets and
deriving mesh data from them. The current product surface is intentionally
small and database-oriented.

## Visible modules

The left rail is always expanded and exposes exactly these categories:

- `Create`: `Character`, `Props`, `Weapons`, `Terrain`, `Icon`, `Symbols`
- `Mesh`: `Sampling`, `Seeding`, `Meshing`
- `Style`: `Weighting`

Only one module is active at a time, even though all categories remain open.
Motion authoring is retained internally for future work but is not selectable
or restored as an active editor category. Transform and Effects are not product
categories. Texture and Material authoring are not part of the application.

## Asset kinds

All six Create modules use the same Asset, Component, Guide, canvas, and
Inspector implementation. An Asset stores one stable `asset_type` value:
`character`, `props`, `weapons`, `terrain`, `icon`, or `symbols`. Create views filter the Outliner by
that value. Documents without an `asset_type` normalize to `character`.

Mesh and Style show a shared multi-select Asset filter above the Outliner
search field. Character, Props, Weapons, Terrain, Icon, and Symbols are checked by default;
search text and checked types are combined. The filter is an editor-state
preference, not a document mutation.

The field is written to `asset.json` and to the engine-neutral runtime manifest.
This is the current export contract for distinguishing product modules;
module-specific behavior can be layered on top later without changing Asset
topology.

## Geometry model

Components have an explicit geometry source. Bézier Components are canonical
only as `points`, `edges`, and `chains`; `BezierTopology` owns their structural
changes and validation, and `BezierGeometry` owns cubic mathematics and handle
resolution. Primitive Components instead own a typed `primitive` record and
never store generated Bézier points, edges, chains, or samples. Authored
primitives are `{ type: "circle", center, diameter_cm }`; Scale Rebase may
derive `{ type: "ellipse", center, diameter_x_cm, diameter_y_cm }`.

`ComponentCanvas` receives immutable view copies, renders them, and emits user
intent; it never mutates World geometry directly. Polygon arrays for fill,
hit testing, sampling, meshing, and export are derived on demand from either
source. A Primitive's center handle moves its `primitive.center`; its Component
pivot remains an independent transform handle.

Components support `closed_loop`, `contour`, and `primitive` draw modes. Contours
are fill-less and may use one open or closed Chain; simulation
and construction
paths are modeled as Guides. Primitive sampling evaluates analytic Circles and Ellipses at the selected Body's
adaptive target edge length and scale-aware Curve Detail, so it has no fixed or
user-editable sample count. Guides remain independent topology records scoped to an Asset or Component. Derived
Sampling, Seeding, Meshing, UV, and Weighting records are stored separately
from source topology.

Assets may also contain editor-only Component Groups. A Group owns a stable ID,
a unique lower-snake-case name, visibility, and a local transform,
and an optional `parent_component_id`. Group membership (`group_id`) does not
replace Component parentage: the Group's Parts remain ordinary Components, and
a child inherits its ancestor's effective Group membership. A Group may be
parented below a Component only when that Component is an ancestor of every
direct Part; its transform is then applied once after that Component. Moving a
Component into or out of a Group, changing a Component parent, or reparenting a
Group through the Outliner preserves every affected Component's world transform.
Group visibility is effective for all members. Each Component exclusively owns
its individual Z Index. Runtime export does not emit Group records; it resolves
Group transforms into ordinary Component exports.

World schema 41 owns the default authored Contour stroke width in its typed
`world_settings` record. It defaults to `4 px` at the fixed `192 px/m`
reference density. Schema 45 adds an optional finite positive
`contour_stroke_width_px` to an ordinary Component. A Component inherits the
World default when the field is absent or equal to that default; a different
value is its implicit local override. The Inspector always shows the Contour
Stroke Width field, with no separate Override toggle. World-width changes
invalidate only inheriting Contour Meshes, while a local override invalidates
only its Component's stroke mesh. Schema 40 and older Worlds migrate explicitly
to 4 px.

World schema 42 adds the Asset Inspector's atomic Scale Rebase. Finite, non-zero
signed local Scale is baked around the unchanged Pivot into owned Points,
resolved handles, Component Guides, or analytic primitive axes; local Scale
becomes `(1, 1)`. Parent rebases compensate direct Child local transforms to
preserve their visible world transforms, so Child Position, Rotation, or Scale
may change. Negative axes encode a transient Mirror reflection. Non-uniform
Circles become analytic Ellipses. Zero/non-finite Scale is an explicit blocker
with no partial fallback. Asset References are excluded because their signed
Scale is an instance placement transform rather than owned geometry Scale.

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

UV and SDF services and their existing derived records remain readable Legacy
data. They are not active batch stages, Runtime dependencies, or schema-4
fields. PolyTools does not delete or silently reinterpret those records.

The persistent `Export Runtime (N)` action automatically considers every visible
Asset. Every visible Component must have one unique free-form `name`. Closed
and primitive ordinary Components require a
current Fill Mesh and current centered Contour Stroke Mesh. Open Contours
require only that Stroke and export no Fill. Asset References instead export
their local Component name, signed instance transform, and the referenced
Asset's derived `source_asset_key`; they do not duplicate the referenced
geometry. The editor retains `source_asset_id` only as its internal source link.
The batch writes a versioned engine-neutral Manifest to
the active World-local
`res://worlds/<world_key>/PolyToolsRuntimeExports/<asset_key>/` directory and
updates the World-root `catalog.json` with the currently valid Runtime set.
Packages are staged, verified, and replaced atomically per Asset; an invalid
Asset retains its older package and no fallback geometry is generated, but is
excluded from that Catalog until it validates again.
Runtime Manifest schema 4 exports `contour_stroke_mesh` independently from the
unchanged Fill Mesh. It contains no UV, SDF, mask, or Carrier compatibility
fields; schema-3 consumers must reject it.
The normative field-level package and consumer rules live in
`docs/RUNTIME_EXPORT_CONTRACT.md`; other documents must not redefine them.

The active Mesh and Runtime batch stages use the same compact tooltip summary. A
`Pending` section lists actionable work, while `Needs attention` lists visible
Components or Assets blocked by invalid source data, missing/stale upstream
resources, or the last failed batch attempt. Attention entries remain outside
the actionable counts. Each active Batch button draws its own
orange attention point whenever that same summary contains at least one
`Needs attention` entry; the point remains visible even if the Button itself is
disabled.

## World and export

A World persists Assets plus the currently retained motion and derived
mesh records. Assets own Components, Guides, reference-image settings, their
Asset pivot and `asset_type`. World schema 40 retains the schema-39
free-form Component names and replaces legacy Ribbons with open Contours. Names
are unique within an Asset and are the authored runtime-target bindings. The World `name` is its stable technical
key and owns its directory and main JSON filename. A separate persisted
`world_name` stores the human-facing title and does not need to be visible in
the current UI. New persistence must not add display polygons or reverse
synchronization into Component topology. The former Godot-scene Export module
is retired; runtime export is a batch operation over accepted derived data.

`catalog.json` has its own schema version and is derived automatically from
visible Assets. Each `asset_key` is the lower-snake-case derivation of the full
Asset display name and is never authored independently. Creation and rename
reject collisions across all Assets, including hidden Assets. The Catalog and
runtime contract expose no internal Asset IDs; the Catalog is the authoritative
closed export set, so consumers do not discover packages by directory listing.

## Component naming

Component names are free-form and unique within each Asset. Runtime animation
configs bind generic targets such as `target01` to these names per Asset.

References classify borrowed geometry locally: for example, Barde may use
the Orb Asset through its stable Asset ID in `source_asset_id` while assigning the local
`name = "belly"`. Runtime export resolves that internal link to
`source_asset_key = "orb"`. Duplicate maps the known pairs `eye_left` /
`eye_right` and `eyebrow_left` / `eyebrow_right` automatically. Every other
copied Component requires an explicit picker choice before the duplicate is
committed.

Asset References retain `source_asset_id` as their internal source link.

Guides are not Component Semantic Keys.

## Verification

After geometry changes run:

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --editor --quit
git diff --check
```

Files below `worlds/` are user data and must not be rewritten as fixtures.
