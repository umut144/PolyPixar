# PolyTools AI Context

PolyTools is a Godot 4 editor for authoring topology-based 2D assets and
deriving mesh data from them. The current product surface is intentionally
small and database-oriented.

## Visible modules

The left rail is always expanded and exposes exactly these categories:

- `Create`: `Character`, `Props`, `Terrain`, `Icon`, `Symbols`
- `Mesh`: `Sampling`, `Seeding`, `Meshing`
- `Style`: `Weighting`

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

The field is written to `asset.json` and to the engine-neutral runtime manifest.
This is the current export contract for distinguishing product modules;
module-specific behavior can be layered on top later without changing Asset
topology.

## Geometry model

Components have an explicit geometry source. Bézier Components are canonical
only as `points`, `edges`, and `chains`; `BezierTopology` owns their structural
changes and validation, and `BezierGeometry` owns cubic mathematics and handle
resolution. Primitive Components instead own a typed `primitive` record and
never store generated Bézier points, edges, chains, or samples. The currently
supported primitive is `{ type: "circle", center, diameter_cm }`.

`ComponentCanvas` receives immutable view copies, renders them, and emits user
intent; it never mutates World geometry directly. Polygon arrays for fill,
hit testing, sampling, meshing, and export are derived on demand from either
source. A Primitive's center handle moves its `primitive.center`; its Component
pivot remains an independent transform handle.

Components support `closed_loop`, `contour`, and `primitive` draw modes. Contours
are fill-less and are the sole visible open-curve Component form; simulation
and construction
paths are modeled as Guides. Primitive sampling evaluates the analytic Circle at the selected Body's
adaptive target edge length and scale-aware Curve Detail, so it has no fixed or
user-editable sample count. Guides remain independent topology records scoped to an Asset or Component. Derived
Sampling, Seeding, Meshing, UV, and Weighting records are stored separately
from source topology.

World schema 41 owns one authored Contour stroke width for every Asset in its
typed `world_settings` record. It defaults to `4 px` at the fixed `128 px/m`
reference density, has no Component override, and invalidates derived Contour
Meshes when changed. Schema 40 and older Worlds migrate explicitly to 4 px.

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

The persistent `Update UVs (N)` action consumes only current accepted Component
Meshes, including Contour Strokes, and accepts deterministic Bounds / Planar UVs
for visible Components with missing or stale mappings. New recipes reserve a
calibrated UV border for later contour-mask derivation; small Components expand
that border deterministically to at least 0.1875 m (16 Game00 reference pixels)
outside the silhouette. UV results remain keyed
one-to-one by stable Mesh Vertex ID and never alter Component topology or Meshes.

The persistent `Update SDFs (N)` action consumes only current accepted Component
Meshes and UV Bakes. It derives a deterministic 256×256 single-channel signed
distance image for each visible Component, with a spread raised deterministically
when necessary to cover the metric outside border and values above
0.5 inside the triangulated silhouette. Bake metadata remains in the Geometry
document while `contour_sdf.png` is stored beside it. Mesh, UV, recipe, algorithm,
or missing-resource changes make the SDF stale without changing source topology.

The persistent `Export Runtime (N)` action automatically considers every visible
Asset. Every visible Component must have one unique
registered `semantic_key`. Closed and primitive ordinary Components require
current accepted Mesh, UV, and SDF resources. Open Contours remain visibly
blocked until the Runtime contract gains a typed art-stroke role. Asset
References instead export their local Semantic Key
plus the referenced Asset's derived `source_asset_key`; they do not duplicate
the referenced geometry. The editor retains `source_asset_id` only as its
internal link to the actual authored source Asset.
The batch writes a versioned engine-neutral manifest plus copied SDF masks to
the active World-local
`res://worlds/<world_key>/PolyToolsRuntimeExports/<asset_key>/` directory and
updates the World-root `catalog.json`. Packages are
staged, verified, and replaced atomically per Asset; an invalid Asset retains
its older package and no fallback geometry is generated.
Runtime manifest schema 3 additionally exports an independently renderable
padded Contour Carrier for each ordinary Component, together with its typed
local SDF domain and outside-padding metadata; the Fill Mesh is unchanged.
The normative field-level package and consumer rules live in
`docs/RUNTIME_EXPORT_CONTRACT.md`; other documents must not redefine them.

All four persistent batch buttons use the same compact tooltip summary. A
`Pending` section lists actionable work, while `Needs attention` lists visible
Components or Assets blocked by invalid source data, missing/stale upstream
resources, or the last failed batch attempt. Attention entries remain outside
the actionable Mesh, UV, and SDF button counts. Each Batch button draws its own
orange attention point whenever that same summary contains at least one
`Needs attention` entry; the point remains visible even if the Button itself is
disabled.

## World and export

A World persists Assets plus the currently retained motion and derived
mesh records. Assets own Components, Guides, reference-image settings, their
Asset pivot and `asset_type`. World schema 40 retains the schema-39
`semantic_key` contract and replaces legacy Ribbons with open Contours. The key
remains the required, sole authored Component designation and registry identity,
visible name, search term, and runtime target; no independent Component label or
free-form runtime role is persisted. The World `name` is its stable technical
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

## Semantic Registry workflow

`configs/semantic_keys.json` is the independently versioned, read-only Semantic
Registry. Its schema version is currently `1`; keys are unique, stable,
alphabetically sorted `lower_snake_case` values. The editor provides no inline
add, rename, or delete action. Component and Asset-Reference creation require a
choice from the searchable registry picker, and the Inspector uses the same
searchable list inside a compact dropdown. A key may occur only once inside an
Asset.

References classify the borrowed geometry locally: for example, Barde may use
the Orb Asset through its stable Asset ID in `source_asset_id` while assigning the local
`semantic_key = "belly"`. Runtime export resolves that internal link to
`source_asset_key = "orb"`. Duplicate maps the known pairs `eye_left` /
`eye_right` and `eyebrow_left` / `eyebrow_right` automatically. Every other
copied Component requires an explicit picker choice before the duplicate is
committed.

Registry changes are a Mensch-AI maintenance operation. Before adding or
replacing a key, inspect all World, Motion, export, test, and documentation
uses; then update the registry and every affected reference atomically. Do not
silently repurpose an existing key. A removed or unknown link must remain
visible as `missing_semantic (<key/source>)` and block runtime export until a
valid replacement is chosen.

## Verification

After geometry changes run:

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --editor --quit
git diff --check
```

Files below `worlds/` are user data and must not be rewritten as fixtures.
