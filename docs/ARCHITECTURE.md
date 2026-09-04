# PolyTools Architecture

## Product shell

`scripts/main.gd` composes the editor shell and routes user intent between the
Outliner, canvas/workspaces, Inspector, persistence, and export. The left rail
contains always-expanded Create, Mesh, and Style categories. A single
`active_module` plus its category-specific submodule identifies the one active
workspace.

Create has seven database views over the same Asset implementation:
`Character`, `Props`, `Weapons`, `Terrain`, `Items`, `Icon`, and `Symbols`. Their stable persisted discriminator
is `asset_type`; missing or invalid values normalize to `character`.

Mesh and Style share a multi-select Outliner Asset filter. Its seven checkbox
states are persisted in `editor_state`; the filter is applied together with
the Outliner search and does not alter the selected Asset or document data.

Mesh is the user-facing name of the derived geometry pipeline. Existing
internal `geometry_*` identifiers remain technical names, while UI copy uses
Mesh. Style currently contains only Weighting. Motion code is retained but its
category is disabled. Transform and Effects categories do not exist.

The Create toolbar's optional `Frame` guide is editor-only canvas state. It
stores `visible`, `half_extent`, and `offset` under `editor_state`, authored in
centimetres and hidden by default with a `10 cm` half extent, draws around the
canvas origin, and never enters Asset topology, derived geometry, or Runtime
export data.

## Ownership boundaries

- `BezierTopology` owns changes to points, edges, chains, IDs, ordering, and
  topology validation.
- `BezierGeometry` owns cubic Bézier evaluation, flattening, and handle
  resolution.
- `PrimitiveGeometryService` owns typed primitive validation and deterministic
  derived contours. It does not create or own Bézier topology.
- `ClosedRegionMeshService` owns validation and deterministic triangulation of
  the complete adaptively sampled Boundary of a closed Contour. Its result is
  derived Runtime geometry without rendering or Fill semantics.
- `ComponentHierarchy` owns parent/child normalization and world/local
  transform conversion.
- `ComponentCanvas` renders immutable copies and emits user intent.
- `main.gd` applies intent to the selected World document and records
  history.
- `OutlinerView` renders the Outliner list from a context `main.gd` pushes in
  and emits what the user did. Like `ComponentCanvas` it holds no editor state
  and mutates no document: a drop reports intent and `main.gd` applies it.
  Derived row state, such as Weighting status, is resolved by `main.gd` and
  handed over, so the view never reaches into the geometry documents. The Mesh
  tree follows the same rule as data: `main.gd` resolves the derived geometry
  state across Sampling, Seeding and Meshing into a flat list of typed rows —
  `asset`, `component`, `hole`, `guide`, `input`, `dependency`, `pipeline`
  plus labels — and the view draws them without deciding what a row says. A
  `pipeline` row carries an `action_id` rather than a callback, so the view
  stays free of editor behaviour.
- `CreateInspectorView` draws the Create module's Inspector under the same
  contract as `OutlinerView`: `main.gd` pushes a snapshot in through `set_document`,
  `set_selection`, `set_resolved_selection` and `set_mode`, `rebuild()` draws from
  that snapshot alone, and every user action leaves as one of 43 intent signals.
  The two lists that need the document to resolve — the Components of a multi
  selection and the Point ids that still exist — are computed in `main.gd` and
  handed over, so the view never resolves a stale id itself. The controls the
  editor updates without a full rebuild (`transform_fields`, the name editors,
  the two rebase buttons) belong to the view and are read from it.
  The intent signals still carry the argument lists of the handlers they replaced,
  `OptionButton` references included; giving them plain values is a separate step.
- `GeometryInspectorView` does the same for the Mesh module, with one difference
  that follows from what it draws: nearly everything on screen is derived from
  the Geometry documents and the preview caches, so `main.gd` resolves each
  submodule into one context Dictionary — `_geometry_sampling_inspector_context`,
  `_geometry_seeding_inspector_context`, `_geometry_meshing_inspector_context` —
  and the view renders that. Boundary rows and Sampler Spine rows arrive as row
  models with their labels already resolved, the same way the Outliner gets its
  Mesh tree.
- `StyleInspectorView` is the same thing at a much smaller scale: one context
  Dictionary holding the selected Component, its Weighting Style, the Mesh and
  Style status, the preview or baked result, and whether Bake is available.
- `MotionInspectorView` completes the set, with one difference stated plainly:
  it holds references to the Motion session models rather than only data.
  `motion_workspace`, `motion_player` and `motion_selection` are queried in about
  thirty places for the selected preview, display names, summaries, primitive
  options and Transition order, and they are handed in through `set_models`.
  Turning those queries into a row model, as the Mesh tree already has, is the
  step that is still open. Everything that is a document lookup does go through
  a context Dictionary, and the syncing that used to run halfway through the
  Animation render — selecting the Asset, setting the Workspace Asset, syncing
  the player document, refreshing the preview — now runs in `main.gd` around
  `rebuild()`, in the same order.

`main.gd` no longer draws an Inspector. It routes: it clears, decides which of
the four views is visible, resolves that view's context and calls `rebuild()`.
- `EditorWidgets` builds the shared widget vocabulary — panels, labels, section
  headers, buttons and their styling. It is static and purely constructive: it
  reads no editor state and knows nothing about Worlds, Assets or Components.
  A control that needs a handler receives it as a `Callable`.
  `build_number_grid` takes a grid, an array of field descriptors (`caption`,
  `property`, `value`, optionally `min`, `max`, `step`, `arrow_step`, `tooltip`
  and `silent`) and one handler bound per property, and *returns* the built
  fields keyed by property. Callers that need live updates keep that map —
  `transform_fields`, `asset_pivot_fields`, `asset_root_position_fields`,
  `asset_root_scale_fields` — instead of the builder writing into editor state
  behind their back. Read-only blocks such as the Global Transform simply drop
  the return value. `add_stacked_number_field` is the same idea for the
  Inspector's other numeric shape — a caption line above a full-width field —
  and `create_toggle_field` for its boolean rows. `create_option_field` takes a
  dropdown as a list of `{label, metadata}` entries plus the metadata to
  preselect; twelve of the editor's thirty-two dropdowns go through it, and the
  rest — Motion, Export, the world settings bar — still build their items by
  hand because no render comparison covers those states yet.
- `WorldDocumentService` owns the on-disk document format: normalization on
  load, serialization on save, and the atomic file replacement both sides use.
  It is static and holds no editor state. `deserialize_asset` turns one Asset
  document at any supported schema into the in-memory record and carries every
  load-time migration — Ribbon to Contour below schema 40, Semantic Keys to
  names, Guides once stored among the Components — so
  `_test_asset_deserialization_migrations` can exercise them on a fixture
  without a World on disk. `main.gd` keeps the orchestration — which records
  exist, when they are read and written, and what the editor does with them —
  including `_serialize_editor_state` and `_serialize_world_settings`, which
  read editor state by definition, and the Asset serialization in `_save_world`,
  which decides a Contour width override against the World default.
- `RuntimeExportView` is the Runtime Export module's work surface under the same
  contract as the Inspector views: `main.gd` resolves the Preflight into one
  context Dictionary — summary line, Consumer Sync hint, the two stages with
  their candidate counts and their pending and attention lines, and the state of
  the three action Buttons — and `rebuild()` draws that snapshot alone. It reads
  no Assets or Geometry documents, counts no candidates, checks no files, and
  runs no Export, Mesh build, Save or Consumer Sync. The three Buttons stay
  children of the shared toolbar, because re-parenting them under the view would
  nest a container inside that flat toolbar and shift the spacing of unrelated
  neighbours; `main.gd` hands them over once and from then on the view owns what
  they say and what a press means, reporting it as `build_all_requested`,
  `export_all_valid_requested` or `sync_consumers_requested`. The batch runs stay
  in `main.gd` and write their progress through the view rather than into its
  controls.
- `RuntimeExportFileService` owns the file-system mechanics behind Runtime
  Export: the Catalog and package paths below a given World root, whether what
  is on disk still matches what was built, the staged replacement of one
  package, and the removal of package directories. It is static, holds no
  editor state, and resolves nothing from the World document: the World root,
  the Asset Key, the already built Catalog or Manifest, and the set of package
  names that may stay are all passed in. Its removal is bounded strictly below
  the export root it is given, so neither that root nor anything beside it can
  be reached. `main.gd` keeps every decision that needs the document —
  `_asset_catalog_build`, `_runtime_export_build`, `_asset_key`, and which
  visible Assets keep their last valid package — plus the batch, the toolbar
  and the Consumer Sync.

Rendering is invalidation-driven. A mutation calls `_invalidate_render` with the
targets that became stale — `RENDER_OUTLINER`, `RENDER_INSPECTOR`,
`RENDER_CANVAS_CONTEXT`, `RENDER_CONTEXT_BAR`, `RENDER_INFO_BAR`, or the
`RENDER_DOCUMENT` combination of the first three — rather than naming the render
functions to call. `_flush_pending_renders` then runs the accumulated set once,
in a fixed order, before `_invalidate_render` returns.

The flush is synchronous on purpose. Several call sites consume render output in
the statements that follow: the Weighting shortcut opens a Context Bar menu that
the same render rebuilds, `_select_geometry_component` focuses a Workspace that
the Canvas render makes visible, and a handful of handlers write `canvas_view`
properties that the Canvas render also writes. Deferring the flush to the end of
the frame inverts that ordering, so it is not done. Requesting the Canvas covers
the Context Bar and Info Bar, which it renders before it can return; the reverse
does not hold, because `_render_context_bar` has exit paths that leave the Info
Bar alone.

Pointer-based `P` Pivot placement is intercepted by `main.gd` during the early
input phase because focused Inspector controls may consume printable keys
before unhandled input. Routing requires the pointer inside the visible Canvas
and a selected Asset, Group, or Component. `ComponentCanvas` converts the
pointer to the appropriate snapped coordinate and emits intent; Draw state and
Guide selection reject the command. Reference-point snapping also lets a
Parent's newly drawn or moved authored Point align to a visible Child point
after converting the Child's composed world transform into Parent-local space.
Whole Parent transforms exclude descendant snapping because those targets
inherit and move with the Parent.

Each Component declares a geometry source. Bézier sources contain only
`points`, `edges`, and `chains`; primitive sources contain one typed primitive
definition: authored `circle` with `center` and `diameter_cm`, or an `ellipse`
with `center`, `diameter_x_cm`, and `diameter_y_cm` produced by Scale Rebase. Generated
primitive contours, samples, fill, and hit-test polygons are derived and are
never persisted. A Primitive's center handle moves its `primitive.center`; its
Component pivot remains an independent transform handle. Do not add `outer_shape`, Component-level `closed`, the old
Line tool, or synchronization from a display polygon back into source geometry.

Closed-loop and Primitive Components also carry a persisted `topology_role`:
`outer` by default or `hole` when authored as a hole. A Primitive retains its
analytic source and does not create a Chain when its role changes. A Symbol
Reference owns its role independently from the referenced Symbol, so the
reference may be `hole` while the source Symbol remains `outer`.


## Documents

This section describes the documents as they are at the current World schema.
How they got here — every schema step, what it changed and how a document
below it is migrated — is in [`SCHEMA_HISTORY.md`](SCHEMA_HISTORY.md).

### World

`worlds/<world_name>/<world_name>.json` indexes Assets by stable ID plus the
retained motion and derived resources. Its canonical technical `name` owns the
directory and filename, while the separate persisted `world_name` is the
human-facing World title and need not be shown by the current UI.

The required `world_settings` record fixes reference density at `192 px/m` and
stores one finite positive `contour_stroke_width_px`, the authored default
Contour width shared by every Asset; new Worlds get `4 px`. The World Settings
summary expresses the shared `1 m` game Tile as `100 cm`, or twenty default
`5 cm` Grid Boxes; Tile size does not alter Component geometry or the
persisted World scale contract. A missing or invalid record is a load error,
not a default.

`editor_state` persists the active Create/Mesh/Style module and valid
selection, the Outliner Asset-type filters, per-Asset cameras and the `Frame`
guide; it does not restore disabled Motion as the active category.

### Asset

An Asset contains:

- stable ID, name, visibility, and `asset_type` — `character`, `props`,
  `weapons`, `terrain`, `items`, `icon`, or `symbols`; a missing or invalid
  value normalizes to `character`;
- typed Asset-level `authored_facing` presentation metadata (`left`, `right`,
  `neutral`, `top`, or `down`). It is edited only on the Asset root in the
  Inspector's `Initial Pose` group, uses the `AssetPresentation.AuthoredFacing`
  enum in memory and its stable lower-case value in JSON, and describes only
  the direction the artwork was drawn in: it has no geometry, Canvas, or
  transform behavior;
- Asset pivot and reference-image settings;
- an authoring-only root transform: `root_position` and a positive,
  independently two-axis `root_scale` (a legacy scalar reads as equal axes).
  Canvas presentation prefixes every Asset-space transform with the
  translation and then the scale around the unchanged Asset Pivot, while
  Inspector fields keep exposing canonical source coordinates. Runtime Export
  requires Position `(0, 0)` and both Scale axes `1`; it never applies a
  pending root transform silently;
- Components, Groups, and Guides;
- retained asset-local animation data.

### Component

A Component contains its geometry source, hierarchy reference, local
transform, visibility/layer settings, draw mode, optional Contour stroke-width
override, catch-parent reference, `projection_depth_cm`, and point number
display setting. It has no Material assignment.

Its `type` is `component`, `reference`, or `region`. A Reference carries
`source_asset_id` as the editor's internal link to another Asset and a signed
`reference_instance_scale`; runtime export resolves the link to
`source_asset_key` and never copies the referenced geometry.

The free-form `name` is unique within its Asset, case-insensitively, and is
the authored identity used by runtime animation bindings: runtime animation
configs bind generic targets such as `target01` to these names per Asset, and
a Reference classifies borrowed geometry locally — Barde may use the Orb
Asset through `source_asset_id` under the local name `belly`, which export
resolves to `source_asset_key = "orb"`. New and renamed
names use `lower_snake_case`; the vocabulary is unrestricted, and the
Component dialog and Inspector reject invalid names before committing. Weapon
Components use the namespaced keys `weapon_body`, `weapon_collar`,
`weapon_grip`, `weapon_head`, `weapon_head_left`, `weapon_rear`,
`weapon_shaft`, and `weapon_string`. Duplicate maps the known pairs
`eye_left` / `eye_right` and `eyebrow_left` / `eyebrow_right` automatically;
every other copied Component requires an explicit picker choice before the
duplicate is committed.

`draw_mode` is `closed_loop`, `contour`, or `primitive`. A Contour is
fill-less and owns either one open Chain or one closed Chain. A closed Contour
retains only its centered Stroke as the visible Component Mesh and never
requests or exports a Fill Mesh; its accepted Contour build also carries a
separate derived triangulation of the complete authored Boundary for the
Runtime `closed_region_mesh`, and hidden Stroke runs do not remove any part of
that region. That region is engine-neutral geometry without material, color,
transparency, UV, rendering, or Fill semantics; it is not displayed by the
Canvas, Preview, or Component Mesh and never becomes Component source data.

`contour_stroke_width_px` is optional and, when present, finite and positive.
An ordinary Component inherits the World default when the field is absent or
equal to it; a differing value is its implicit local override. On an Asset
Reference the same field applies uniformly to every Contour part of its source
Asset without changing the source. The Inspector always shows the width
field, without a separate Override toggle. A World-width change affects only
inheriting Components, an override change only that Component; the effective
width participates in Contour Mesh fingerprints and build signatures, so
downstream Bakes become stale without changing Component topology.

`projection_depth_cm` exists on visible Components only, defaults to `10 cm`,
is shown in the Component Inspector beside Contour Stroke Width and Z Order,
and is independent of Component and Asset Scale, Rebase, Z Order, and Contour
Stroke Width. Groups and the Asset root do not own it.

`z_index` is an integer each Component owns exclusively; Groups carry none.
It is authoritative only as an asset-local semantic order across the complete
Component set. Runtime Manifest `z_order.scope = "global"` means global within
that Asset, not global across a consuming game scene. Consumers may use any
strictly monotonic local depth spacing and position the complete Asset range
contextually relative to other Assets without rewriting its internal order.

### Group

A Group is an Asset-local authoring container with a stable ID, a unique
lower-snake-case name, visibility, one shared transform/pivot, and an optional
`parent_component_id`. Components retain their own transforms and `group_id`
membership; they are not children of the Group. Descendants inherit their
ancestor's effective Group membership unless explicitly assigned otherwise.
When parented, a Group transform is local to its Component Parent and is applied
once after that parent in every Part's Component chain. The parent must be an
ancestor of every direct Part, so a Group cannot be placed beneath one of its
own Parts. Group visibility is effective while each Component's individual Z
Index remains authoritative. Outliner drag-and-drop preserves each affected
Component's world transform when changing Group membership, Component
parentage, or Group parentage. Dropping a Group across Component branches
reparents its direct Parts atomically; deleting the selected Group removes the
container while preserving those Parts and their world transforms. Groups are
editor-only containers: runtime export emits ordinary Components and resolves
the Group transform into their canonical exported transforms.

### Guides

Guides are independent topology records scoped to an Asset or Component; they
are not Component Semantic Keys. Curve-based Guides — Flow, Sampler Spine,
Animation Spine and Cut — carry `points`, `edges` and `chains` like a
Component. Transform-based Weapon Guides store a stable role, a
Component-or-Group scope, and a local position/rotation frame; non-uniform
scale is inherited from the scope and is never authored on the frame. The
roles are `weapon_socket_primary`, `grip_primary`, `grip_secondary`,
`attack_point_primary` and `reach_limit_primary`. `grip_secondary` is a second
weapon-local hand contact for an attack regrip, semantically distinct from the
character-owned `weapon_socket_primary`, the carried `grip_primary` and the
maximum endpoint `reach_limit_primary`; none of them infers its position from
a visual Component. Weapon Guides are authored through the Component and
Group `+` and context-menu paths and share the frame data, scope inheritance,
Canvas gizmo, Inspector, history, Scale Rebase and persistence paths.

Ordinary outer Component and Group Outliner rows expose `+`; constraint-only
Hole rows do not, because Holes cannot own children, Guides, or Regions.

### Regions

A Region is a nonvisual `type: "region"` Component attached to a Component,
with a `region_type` of `attack`, `hurt` or `collision`, backed by canonical
`points`, `edges` and `chains`. It is excluded from visual Mesh processing and
exported in the separate Runtime `regions` array. Its `region_geometry_source`
is `authored` or `component`: `authored` reads the Region's own retained,
editable topology; `component` resolves `parent_component_id` as the live
geometry owner while leaving the authored topology dormant and intact, so
switching back is lossless. Newly created Regions default to `component`, a
missing value normalizes to `authored`. The Canvas receives only the resolved
view copy, drawing and Bézier editing are disabled while the Component source
is active, and Runtime export emits a binding rather than copied geometry.
Regions are created only from a Component's `+` menu. Documents without
Regions remain valid and consumers retain their Component-based fallback.

### Scale Rebase

Two atomic rebases exist and are independent of each other; see
[`SCALE_REBASE.md`](SCALE_REBASE.md).

The Asset Inspector's Component Scale Rebase bakes finite, non-zero signed
Component and Group Scale into owned Bézier geometry, resolved handles,
Component-scoped Guides, or analytic primitive axes around the unchanged Pivot
before setting local Scale to `(1, 1)`. Group Rebase first compensates member
transforms. Negative axes preserve Mirror reflections in source geometry;
analytic primitive diameters remain positive, and a non-uniform Circle becomes
an analytic Ellipse. A parent Rebase compensates direct Child local transforms
to preserve the Child subtree's visible world transform, so Child Position,
Rotation, or Scale may change; hierarchy and animation data remain untouched.
Zero or non-finite Scale blocks the whole operation with no partial fallback.
Asset References are excluded because their signed Scale is an instance
placement transform rather than owned geometry Scale.

The Asset root's `Rebase Asset Transform` bakes Root Position and Root Scale
together: it adds the translation exactly once to root-scoped Components,
Groups, Asset Guides and Weapon frames while preserving nested local
placement, multiplies each local translation, owned Bézier coordinate and
handle, primitive axis, Guide coordinate and Weapon-frame translation exactly
once per axis — root placements around the Asset Pivot, nested placements
around their local origin — and resets Position to `(0, 0)` and Scale to
`(1, 1)`. Reference geometry uses its instance scale, so its transform Pivot is
unchanged. The Asset Pivot is not moved, Component Scale is not modified, and
authored non-default Motion is an explicit blocker until a dedicated scale
conversion exists. Accepted derived data is not rewritten and becomes stale
through its existing source fingerprints.

### Derived documents

Derived mesh documents are keyed by Asset and Component IDs and stored below
`geometry/<asset>/<component>/geometry.json`. Sampling feeds Seeding, Seeding
feeds Meshing, and accepted Bakes remain separate from source Component
geometry. Weighting styles reference accepted mesh data without becoming
Component topology. Each document also carries the Contour Stroke build,
semantic build provenance, and the optimization diagnostics — baseline
triangles, accepted Seed movements and before/after quality metrics — for the
Optimization and Quality views; none of that ever becomes Component topology.

Sampling results carry their own algorithm version independently of the World
schema, currently 6, and Bakes from an older version are stale before Seeding
or Meshing can consume incompatible constraint identities. Meshing knows one
Fill method, `constrained_mesh`; a `contour_stroke` build exists for every
ordinary Component. UV Mapping and SDF records are Legacy data: they load,
round-trip and save unchanged through `GeometryUVMappingService` and
`GeometrySDFService`, nothing generates new ones, nothing deletes or
reinterprets old ones, and they have no Workspace, Inspector, batch, Canvas
presentation or Runtime dependency.

## Derived pipeline

Mesh is the user-facing name of this pipeline. Sampling, Seeding and Meshing
share one Preview contract: a debounced transient Preview is generated once
per settled recipe, and an explicit Bake copies that exact Preview without
regenerating it.

Sampling owns one adaptive Body recipe. Its Outer boundary, direct Hole Child
Components, and scoped Cut Guides inherit the Body target edge length and Curve
Detail. A Hole Child may be an ordinary Closed Loop or Primitive, or an Asset
Reference; its exclusion applies only to its direct outer Parent and only while
the Hole is effectively visible. Ordinary Hole Components are constraint-only:
they receive no independent Mesh pipeline and are omitted from Runtime export.
They cannot be rooted, own Component children, or receive Weighting Styles; a
visible invalid Hole is surfaced as a Mesh/Runtime validation issue, and its
Inspector keeps the invalid current Parent visible as an explicit warning
entry until it is repaired. A Hole Reference continues to export its source Asset instance, while owning no
Fill or Contour Stroke Mesh itself. Hole and Cut inputs
may apply a boundary-density factor from `0.25×` through `16×`. Values below
`1×` coarsen all adaptive criteria, while values above `1×` refine them. Primitive Circles and Ellipses
remain analytic through sampling, including their transform into Body-local
space; they are evaluated at the Body's adaptive target edge length and
scale-aware Curve Detail and have no fixed or user-editable sample count. On Bézier boundaries, a deterministic best-effort post-pass splits only
the longer derived curve segment beside an authored corner toward a maximum
adjacent-length ratio of `3×`; it never adds authored Points or changes the
curve. At most 64 derived samples are added per Chain. Untreatable intervals
and exhausted limits remain non-blocking and are exposed in diagnostics.
Sampling also owns PSLG junction creation and the clipping of Cuts against
Outer and Holes, and stores the arranged Cut fragments; Seeding consumes those
fragments as independent barriers.

Seeding derives a shared constraint domain from that accepted Sampling Bake.
Outer and Hole contours bound valid Seed positions, while open Cuts are
two-sided internal barriers. Poisson Fill applies automatic constraint
clearance; Spine Flow clips rows against the same constraints and combines all
enabled Sampler Spines into one deterministic globally spaced result. Seeding
also uses debounced Preview plus explicit exact Preview Bake. Its Artistic
recipe derives Across from Seed Spacing and Along from Spacing times Flow
Stretch while retaining explicit technical overrides for compatibility: the
exact lattice values and the optional Boundary and Stagger refinements stay
available under Advanced Pattern. Manual editing is available only on a
current accepted Bake.

Meshing exposes one constrained recipe for closed Body Components. `Mesh
Character` derives the relaxation strength and pass count along a Structured to
Organic continuum. `Optimize Mesh` gates existing-point relocation as an exact
raw-CDT A/B comparison, and the Optimization and Quality views expose the
accepted movement and a triangle heatmap; optional Advanced Optimization
overrides preserve exact legacy or technical control. The service triangulates Sampling boundaries plus
Seeding vertices, recovers Outer/Hole/Cut constraints, classifies retained faces
by flooding from the oriented Outer interior without crossing closed Outer/Hole
barriers, and accepts a relocation pass only when measured quality improves
without a material minimum-angle
regression. It retriangulates after each candidate and only then duplicates the
Cut seam. Final validation requires one retained Triangle on every Outer/Hole
constraint and two retained Triangles on every Cut constraint before seam
duplication. Boundary vertices never move and this phase neither adds nor
removes vertices. Meshing uses the same debounced transient Preview and exact Preview
Bake contract as Sampling and Seeding. Accepting the Preview atomically replaces
the single Constrained Mesh Bake and records it as the Component Mesh, so no
separate `Use as Component Mesh` action exists.
The Meshing root-Asset view derives a transient display-only aggregate by
transforming each current visible Component Mesh into Asset space. It never
persists a merged Mesh, and missing or stale Component Meshes are omitted.
Meshing validates the PSLG and delegates only the constrained triangulation to
the pinned `artem-ogre/CDT` GDExtension; PolyTools owns document data, stable
IDs, domain filtering, diagnostics, relaxation, and Cut-seam duplication.

New Constrained Mesh recipes default to `Mesh Character = 0.64`, which derives
Strength `0.402` and three quality-checked passes. Existing persisted recipes
retain their exact Character and override values.

The persistent `Update Meshes (N)` action rebuilds only
effectively visible meshable Components across all Create Asset types whose effective geometry,
constraints, or recipes differ meaningfully from their last successful build.
Automatic recipe version 3 retains version 2's Barde-derived Boundary and Seed
Spacing at `0.55` through the measured normal Character/Symbol range. Beyond
perimeter `60`, Boundary Spacing scales by `sqrt(perimeter / 60)`; Seed Spacing
is independent and is at least `sqrt(area / 750)`, subject to a narrow-feature
cap. The existing 8-to-512 boundary-sample guards still protect very small and
very large contours. This reduces avoidable interior density on Tree-scale
geometry without coarsening smaller Assets.

Automatic acceptance budgets at most 4096 total boundary/constraint Samples,
2500 interior Seeds, and 12000 Triangles. A rejected attempt first increases
only Seed Spacing. Boundary Spacing and Curve Detail may increase only after
Sampling exceeds its hard safety limit or automatic Boundary budget. Complete
final Constraint coverage and zero degenerate Triangles remain hard quality
gates; minimum angle, mean quality, and worst aspect ratio are recorded for
diagnostics rather than imposing a shape-dependent global threshold. Minimum
angles below `5°` and worst aspect ratios above `25` are surfaced as non-blocking
quality warnings. Every
attempt and effective recipe is retained in automatic build provenance. Manual
recipes are evaluated exactly once and never use these fallback adjustments.

The Meshing Inspector derives `Auto Build Diagnostics` directly from the current
recipe resolution and stored provenance. It shows automatic/manual ownership,
pending model migration, Area/Perimeter/Feature metrics, current effective
spacings, fixed limits and last
usage, per-attempt scope/outcome/reason, and accepted quality metrics. This is a
read-only projection and introduces no second source of pipeline state.
Regression coverage uses canonical synthetic Components — including a narrow
concave Item at two proportional scales — and broad invariant or range checks
rather than exact mesh snapshots or documents below `worlds/`.

Build provenance records `recipe_mode`, automatic recipe version, and a hash of
the normalized Sampling/Seeding/Meshing recipes. Matching automatic recipes can
be recalibrated; any later recipe edit breaks that hash and transfers ownership
to exact manual settings. Successful results commit atomically per
Component. Legacy calibrated profiles migrate automatically.
Untouched legacy UI defaults migrate only when both perimeter and area place a
Component clearly beyond the normal Asset range, leaving small defaults intact.
Numeric geometry is compared
with a scale-aware tolerance against that accepted snapshot; topology,
constraints, recipes, and algorithm versions remain exact. The actionable
count therefore comes from build provenance rather than a mutable dirty flag,
so selection and sub-tolerance pointer jitter never trigger the batch. Failed Components
are isolated and retain their previous valid Component Mesh. Components with
invalid source topology remain outside the actionable count and surface the
specific validation issue in the Meshing Inspector.

The Mesh and Runtime Export batch tooltips share compact `Pending` and
`Needs attention` sections so blocked records remain discoverable without being
treated as executable derived-build candidates. `BatchStatusButton` consumes
the same summary and draws a per-Button attention point independently of the
Button's enabled state; it never maintains a separate warning flag.
Both Buttons consume one UI-only Batch-status snapshot. Selection and
render-only changes reuse it; document mutations invalidate it and coalesced
edits refresh it after a short debounce. Batch execution never trusts the UI
cache and recomputes authoritative candidates before mutating derived data.

## Persistence

Each Asset is stored below a sanitized visible-name directory with a matching
JSON filename, for example `assets/Wizard/Wizard.json`. The stable ID remains
inside the JSON and in the World index. Older ID-based paths such as
`assets/asset_1/asset.json` remain readable as a migration fallback. Motion
Paths, Acts and Sequences live below `paths/`, `acts/` and `sequences/`.

Every record is written through `WorldDocumentService.write_text_atomically`:
a staging file is completed and then swapped in, so a failed write leaves the
previous content rather than a truncated file, and a `.staging` or `.backup`
residue only ever means an interrupted swap. There is no autosave; every
save is an explicit user action.

Loading normalizes every document to the current schema.
`WorldDocumentService.deserialize_asset` and the `normalize_*` functions
beside it perform the migrations, and `WorldSettingsService.decode` the World
Settings. Two kinds exist. A change that gave an existing value a new meaning
is gated on the source schema version — Ribbon to Contour below 40, the
World Settings default below 41, the Semantic Key name fallback below 43, the
Blink `anticipation_share` default through 18 — and never applies to a
document at or above that schema, which instead loads the value as it is or
fails. Everything else is discriminated by the shape of the value itself: a
scalar `root_scale` is two equal axes, a legacy Meshing method name maps to
`constrained_mesh`, a Group `z_index` is dropped, a missing `asset_type` is
`character`. `SCHEMA_HISTORY.md` lists every step with its kind, its code and
its fixture. Persistence must never add display polygons or reverse
synchronization into Component topology.

The World-root `catalog.json` is an independently versioned derived index, not
an authored identity store, and it is not tracked by Git: together with
`PolyToolsRuntimeExports/` it forms one generated publication unit that the
consumers read from the working directory. A fresh clone has neither until
`Export Runtime` has run once. It lists currently runtime-exportable visible
Assets by the `asset_key` mechanically derived from each complete display
name. A visible Asset blocked by Runtime validation is omitted, so it cannot
prevent valid siblings from publishing; its retained package remains
unadvertised until the Asset validates again. The derivation cannot be
overridden, and creation or rename rejects collisions across visible and
hidden Assets. Internal stable Asset IDs remain in editor persistence only;
neither the Catalog nor runtime manifests expose them, so consumers do not
discover packages by directory listing.

Undo/Redo snapshots copy canonical documents and stable selections; the
Geometry documents are shared copy-on-write, everything else is a deep copy.
Derived previews are transient and are recomputed after restoration. The
whole-document snapshots are also what provides Dirty-state invalidation.

## Export contract

The normative serialized package and consumer contract is
[`RUNTIME_EXPORT_CONTRACT.md`](RUNTIME_EXPORT_CONTRACT.md); other documents
must not redefine its fields. The summary below describes how the editor
produces that contract.

`RuntimeExportService` builds Manifest schema 16 exclusively from current
accepted Fill and Contour Stroke Mesh Bakes. Ordinary Hole Components are
authoring-only Sampling constraints and do not enter the Manifest. A visible
ordinary Hole with no valid direct outer Parent Body blocks export, as does a
Runtime Component loaded beneath such a Hole. For a closed Contour, the current
Stroke Bake must also contain its current complete-Boundary region
triangulation. It rejects missing or stale inputs,
invalid or duplicate Component Names, non-rebased Scale, unresolved
Asset References, and incomplete or cyclic visible hierarchies. Ordinary
Components never derive replacement geometry during export. References emit an
`asset_reference` record containing the local `name`, signed placement
transform, and actual `source_asset_key`, without copying geometry into the owner.

Every schema-16 Manifest also exports the Asset-level presentation metadata as
`presentation.authored_facing`, oriented Asset-local Weapon Attachment Frames,
and geometry-only closed Contour boundaries. Free semantic Regions are exported
as triangulated Asset-local meter geometry. Component-geometry Regions instead
export `source_component_id` without vertices, preserving the canonical
Component geometry and its Runtime deformation path.

The contract is engine-neutral: X points right, Y points up, lengths are meters,
positive rotations are counter-clockwise radians, and one Tool unit equals
0.1 m. Component local transforms mean
`T(position) * R(rotation) * S(scale) * T(-pivot)`. Components are listed in
Asset-global ascending `(z_index, component_id)` order from back to front. This
is an asset-local semantic order rather than an absolute consumer Z coordinate.
Group membership does not override a Component's individual `z_index`; the
Group Transform and visibility still apply to its members. Accepted
Mesh Vertex order is retained and Triangle Vertex IDs become compact indices.
Every ordinary Component exports a separate centered `contour_stroke_mesh`;
closed and Primitive Components additionally export their unchanged Fill Mesh,
while fill-less Contours do not invent one. A closed Contour additionally
exports `closed_region_mesh` as local-meter vertices and triangle indices. That
field is engine-neutral geometry only and has no material, color, alpha, UV,
rendering, or Fill semantics. Open Contours and Asset References omit it.
Schema 16 contains no UV/SDF/Carrier fields and carries an optional semantic
gameplay Region array.

Each visible Asset is exported to the active World-local
`res://worlds/<world_key>/PolyToolsRuntimeExports/<asset_key>/` directory as
`manifest.json`. The batch verifies a staging package
before atomically replacing the prior package; validation or I/O failure leaves
the prior package intact. Once all required packages are current, the same batch
atomically updates World-root Asset Catalog schema 1. The Catalog is the closed
consumer set; generated directories absent from it are ignored and pruned only
after every listed package is current and the new Catalog has been committed. Package freshness is derived by comparing the expected
Manifest bytes, not by persisting export diagnostics in the Asset.

The separate `Sync Consumers` action beside `Export All Valid` runs PolyTools'
owned `scripts/sync_world01_consumers.sh` workflow against the currently
published Catalog. It updates SceneMaker from that Catalog, re-exports
SceneMaker's current `world01` scene, then updates world01's runtime content
and imported map. The Export workspace retains the last Consumer Sync result
and includes command output on failure. Export and synchronization are
deliberately separate actions: a downstream failure does not alter the already
published PolyTools Runtime packages, and each consumer script remains
responsible for its own atomic target update.

## Testing

`tools/verify.sh` is the verification path; `AGENTS.md` describes what it
runs and what counts as a failure. The suite is `tests/run_tests.gd` over the
five suites that extend `tests/test_case.gd`: topology, geometry, editor,
persistence and motion. It covers topology, derived geometry, navigation
state, persistence and the UI contracts of the extracted views; the Inspector
render probe in `tools/` covers what the suite cannot. Geometry regression
coverage uses canonical synthetic Components — tiny Symbol, a narrow concave
Item at two scales, Barde-scale, Tree-scale, concave, Hole and Cut fixtures —
with invariant or range checks rather than exact mesh snapshots. World data is
never used as a mutable test fixture.
