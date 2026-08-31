# PolyTools Architecture

## Product shell

`scripts/main.gd` composes the editor shell and routes user intent between the
Outliner, canvas/workspaces, Inspector, persistence, and export. The left rail
contains always-expanded Create, Mesh, and Style categories. A single
`active_module` plus its category-specific submodule identifies the one active
workspace.

Create has six database views over the same Asset implementation:
`Character`, `Props`, `Weapons`, `Terrain`, `Icon`, and `Symbols`. Their stable persisted discriminator
is `asset_type`; missing or invalid values normalize to `character`.

Mesh and Style share a multi-select Outliner Asset filter. Its six checkbox
states are persisted in `editor_state`; the filter is applied together with
the Outliner search and does not alter the selected Asset or document data.

Mesh is the user-facing name of the derived geometry pipeline. Existing
internal `geometry_*` identifiers remain technical names, while UI copy uses
Mesh. Style currently contains only Weighting. Motion code is retained but its
category is disabled. Transform and Effects categories do not exist.

The Create toolbar's optional `Frame` guide is editor-only canvas state. It
stores `visible`, `half_extent`, and `offset` under `editor_state`, draws around
the canvas origin, and never enters Asset topology, derived geometry, or Runtime
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

Pointer-based `P` Pivot placement is intercepted by `main.gd` during the early
input phase because focused Inspector controls may consume printable keys
before unhandled input. Routing requires the pointer inside the visible Canvas
and a selected Asset, Group, or Component. `ComponentCanvas` converts the
pointer to the appropriate snapped coordinate and emits intent; Draw state and
Guide selection reject the command.

Each Component declares a geometry source. Bézier sources contain only
`points`, `edges`, and `chains`; primitive sources contain one typed primitive
definition: authored `circle` with `center` and `diameter_cm`, or an `ellipse`
with `center`, `diameter_x_cm`, and `diameter_y_cm` produced by Scale Rebase. Generated
primitive contours, samples, fill, and hit-test polygons are derived and are
never persisted. Do not add `outer_shape`, Component-level `closed`, the old
Line tool, or synchronization from a display polygon back into source geometry.

Closed-loop Components also carry a persisted `topology_role`: `outer` by
default or `hole` when authored as a hole. A Symbol Reference owns its role
independently from the referenced Symbol, so the reference may be `hole` while
the source Symbol remains `outer`.

## Documents

An Asset contains:

- stable ID, name, visibility, and `asset_type`;
- typed Asset-level `authored_facing` presentation metadata (`left`, `right`,
  `neutral`, `top`, or `down`);
- Asset pivot and reference-image settings;
- Components, Groups, and Guides;
- retained asset-local animation data.

A Component contains its geometry source, hierarchy reference, local transform,
visibility/layer settings, draw mode, optional Contour stroke-width override,
catch-parent reference, and point number display setting. It carries a free-form `name`, unique within its Asset.
The name is the authored identity used by runtime animation bindings. It has
no Material assignment.

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
container while preserving those Parts and their world transforms. Groups are editor-only containers: runtime
export emits ordinary Components and resolves the Group transform into their
canonical exported transforms.

`z_index` is authoritative only as an asset-local semantic order across the
complete Component set. Runtime Manifest `z_order.scope = "global"` means
global within that Asset, not global across a consuming game scene. Consumers
may use any strictly monotonic local depth spacing and position the complete
Asset range contextually relative to other Assets without rewriting its
internal order.

Derived mesh documents are keyed by Asset and Component IDs. Sampling feeds
Seeding, Seeding feeds Meshing, and accepted Bakes remain separate from source
Component geometry. Weighting styles reference accepted mesh data without
becoming Component topology.

Sampling owns one adaptive Body recipe. Its Outer boundary, referenced Hole
inputs, and scoped Cut Guides inherit the Body target edge length and Curve
Detail; Hole and Cut inputs may apply a boundary-density factor from `0.25×`
through `16×`. Values below `1×` coarsen all adaptive criteria, while values
above `1×` refine them. Primitive Circles and Ellipses
remain analytic through sampling, including their transform into Body-local
space. A debounced transient Preview is generated once per settled recipe and
an explicit Bake copies that exact Preview without regenerating it.

Seeding derives a shared constraint domain from that accepted Sampling Bake.
Outer and Hole contours bound valid Seed positions, while open Cuts are
two-sided internal barriers. Poisson Fill applies automatic constraint
clearance; Spine Flow clips rows against the same constraints and combines all
enabled Sampler Spines into one deterministic globally spaced result. Seeding
also uses debounced Preview plus explicit exact Preview Bake. Its Artistic
recipe derives Across from Seed Spacing and Along from Spacing times Flow
Stretch while retaining explicit technical overrides for compatibility. Manual
editing is available only on a current accepted Bake.

Meshing exposes one constrained recipe for closed Body Components. `Mesh
Character` derives the relaxation strength and pass count along a Structured to
Organic continuum. `Optimize Mesh` gates existing-point relocation as an exact
raw-CDT A/B comparison; optional Advanced Optimization overrides preserve exact
legacy or technical control. The service triangulates Sampling boundaries plus
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

New Constrained Mesh recipes default to `Mesh Character = 0.64`, which derives
Strength `0.402` and three quality-checked passes. Existing persisted recipes
retain their exact Character and override values.

## Persistence

`worlds/<world_name>/<world_name>.json` indexes Assets by stable ID plus retained motion/derived
resources. Its canonical technical `name` owns the directory and filename,
while the separate persisted `world_name` is the human-facing World title and
need not be shown by the current UI. Each Asset is stored below a sanitized visible-name directory with
a matching JSON filename, for example `assets/Wizard/Wizard.json`. The stable
ID remains inside the JSON and in the World index. Older ID-based paths
such as `assets/asset_1/asset.json` remain readable as a migration fallback;
older Assets without `asset_type` load as `character`. Editor
state persists the active Create/Mesh/Style module and valid selection, but it
does not restore disabled Motion as the active category.

`authored_facing` is edited only on the Asset root in the Inspector's `Initial
Pose` group. The in-memory model uses the typed `AssetPresentation.AuthoredFacing`
enum; Asset JSON serializes its stable lower-case value. Older Assets without
the field load as `neutral`, while normal saves always write it explicitly.
The existing whole-document history snapshots provide Dirty-state invalidation
and Undo/Redo for this property. It has no geometry, Canvas, or transform
behavior.

The World-root `catalog.json` is an independently versioned derived index, not
an authored identity store. It lists currently runtime-exportable visible Assets
by the `asset_key` mechanically derived from each complete display name. A
visible Asset blocked by Runtime validation is omitted, so it cannot prevent
valid siblings from publishing; its retained package remains unadvertised until
the Asset validates again. The derivation cannot be overridden, and creation or
rename rejects collisions across visible and hidden Assets. Internal stable
Asset IDs remain in editor persistence only; neither the Catalog nor runtime
manifests expose them.

Undo/Redo snapshots copy canonical documents and stable selections. Derived
previews are transient and are recomputed after restoration.

Schema 31 consolidates legacy `constrained_delaunay` and `organic_relaxed`
recipes/bakes into `constrained_mesh`. If both legacy Bakes exist, the accepted
Component Mesh wins, then the active recipe, then a deterministic fallback.
Legacy Organic parameters load as Artistic Character plus exact Advanced
Relaxation overrides. Old mesh results remain readable but stale until rebuilt
with the current constrained-mesh algorithm version.

Schema 32 stores arranged Cut fragments. Sampling owns PSLG junction creation
and clipping against Outer/Holes; Seeding consumes the resulting fragments as
independent barriers. Meshing validates the PSLG and delegates only constrained
triangulation to the pinned macOS-arm64 `artem-ogre/CDT` GDExtension. PolyTools
continues to own document data, stable IDs, domain filtering, diagnostics,
relaxation, and Cut-seam duplication.

Schema 33 stores the optimization recipe switch plus compact baseline
triangles, accepted Seed movements, and before/after quality metrics. These are
derived diagnostics for the Optimization and Quality views and never become
Component topology.

Schema 34 removes the editor-only open-curve Component mode. Existing World
assets were converted to Ribbons; Ribbon widths normalize to a practical minimum
of 1 px.

Schema 35 stores semantic Component Mesh build provenance in the derived
Geometry document. The persistent `Update Meshes (N)` action rebuilds only
meshable Components across all Create Asset types whose effective geometry,
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
diagnostics rather than imposing a shape-dependent global threshold. Every
attempt and effective recipe is retained in automatic build provenance. Manual
recipes are evaluated exactly once and never use these fallback adjustments.

The Meshing Inspector derives `Auto Build Diagnostics` directly from the current
recipe resolution and stored provenance. It shows automatic/manual ownership,
pending model migration, Area/Perimeter/Feature metrics, current effective
spacings, fixed limits and last
usage, per-attempt scope/outcome/reason, and accepted quality metrics. This is a
read-only projection and introduces no second source of pipeline state.
Regression coverage uses canonical synthetic Components and broad invariant or
range checks rather than exact mesh snapshots or documents below `worlds/`.

Build provenance records `recipe_mode`, automatic recipe version, and a hash of
the normalized Sampling/Seeding/Meshing recipes. Matching automatic recipes can
be recalibrated; any later recipe edit breaks that hash and transfers ownership
to exact manual settings. Legacy calibrated profiles migrate automatically.
Untouched legacy UI defaults migrate only when both perimeter and area place a
Component clearly beyond the normal Asset range, leaving small defaults intact.
Numeric geometry is compared
with a scale-aware tolerance against that accepted snapshot; topology,
constraints, recipes, and algorithm versions remain exact. Failed Components
are isolated and retain their previous valid Component Mesh. Components with
invalid source topology remain outside the actionable count and surface the
specific validation issue in the Meshing Inspector.

Schema 36 makes the accepted Component Mesh the sole UV Mapping input. It adds
deterministic UV Padding, exact Vertex-ID mapping validation, Ribbon Strip UV
support, and the persistent `Update UVs (N)` batch. Existing manual recipes are
preserved, pre-schema-36 unpadded Bakes retain Padding `0` and therefore become
stale against the new padded default, and a failed batch attempt never replaces
an older valid UV Bake.

Schema 37 adds a derived single-channel SDF stage after accepted UV Mapping.
`Update SDFs (N)` rasterizes the accepted Mesh triangles in their exact UV space,
derives signed distance from the resulting silhouette boundary, and stores a
linear L8 PNG beside the Component Geometry document. The JSON Bake contains
only compact interpretation metadata, source fingerprints, pixel hash, and the
relative `contour_sdf.png` reference. Missing files and changed Mesh, UV, recipe,
or algorithm inputs make the Bake stale; no image data becomes Component topology.
SDF validation measures UV collapse relative to each Triangle's own longest-edge
scale. It rejects truly collinear mappings without misclassifying small,
well-shaped normalized UV Triangles as degenerate. Its failure-retry signature
is versioned independently from the pixel algorithm, allowing repaired
validation failures to retry without invalidating every accepted SDF image.
Runtime Manifest schema 4 later retires UV/SDF from the active build and
package path. These services and records remain readable Legacy data and are
not deleted or reinterpreted.

Schema 38 adds the Component-level `semantic_role` field. It retires the
standalone Godot-scene Export workspace in favor of the persistent
`Export Runtime (N)` batch, which automatically considers every visible Asset.
The Mesh, UV, SDF, and Runtime Export batch tooltips share compact `Pending` and
`Needs attention` sections so blocked records remain discoverable without being
treated as executable derived-build candidates. `BatchStatusButton` consumes
the same summary and draws a per-Button attention point independently of the
Button's enabled state; it never maintains a separate warning flag.
All four Buttons consume one UI-only Batch-status snapshot. Selection and
render-only changes reuse it; document mutations invalidate it and coalesced
edits refresh it after a short debounce. Batch execution never trusts the UI
cache and recomputes authoritative candidates before mutating derived data.

Schema 43 restores free-form Component names. New and renamed names use
`lower_snake_case`; the vocabulary remains unrestricted. The Component dialog
and Inspector reject invalid names before committing. Existing names are preserved;
older Semantic Key fields are used only as a deterministic one-time migration
fallback, and case-insensitive name collisions receive numbered suffixes.
Names remain unique within an Asset. Asset References retain their internal
`source_asset_id`; runtime export resolves that link to `source_asset_key`.

Weapon Components use the namespaced keys `weapon_body`, `weapon_collar`,
`weapon_grip`, `weapon_head`, `weapon_head_left`, `weapon_rear`, `weapon_shaft`, and
`weapon_string`.

Schema 40 replaces the authored `ribbon` draw mode with the fill-less open
`contour` mode. Loading schema 39 or older converts Ribbon centerline topology
explicitly; current-schema Ribbon values are invalid and receive no fallback.
Component-local Ribbon widths are discarded. Legacy `ribbon_strip` Bakes remain readable records but
are never current for a Contour and must be rebuilt as `contour_stroke`.

Schema 41 renames the toolbar surface to `World Settings` and introduces one
typed authored default Contour width shared by every Asset. The required
`world_settings` record fixes reference density at `192 px/m` and stores a
finite positive `contour_stroke_width_px`, defaulting to `4 px` for new Worlds.
The World Settings summary expresses the shared `1 m` game Tile as `100 cm`,
or twenty default `5 cm` Grid Boxes; Tile size does not alter Component
geometry or the persisted World scale contract.
Schema 40 and older Worlds migrate explicitly to that default; schema-41 data
never receives a silent missing/invalid-value fallback. Schema 45 permits an
optional finite positive `contour_stroke_width_px` on each Component. An
ordinary Component inherits the World default when the field is absent or
equal; a differing value is its implicit local override. On an Asset Reference,
the same field applies uniformly to every Contour part of its source Asset
without changing the source. The Inspector always shows the width field,
without a separate Override toggle. A World-width change affects only
inheriting Components, while an ordinary override change affects only that
Component. The effective width participates in Contour Mesh fingerprints and
build signatures, so downstream Bakes become stale without changing Component topology.

Schema 42 adds atomic Asset-level Component Scale Rebase and analytic Ellipses.
The service bakes finite, non-zero signed Scale into owned Bézier geometry,
resolved handles, Component-scoped Guides, or primitive axes around the
unchanged Pivot before setting local Scale to `(1, 1)`. Negative axes preserve
Mirror reflections in source geometry; analytic primitive diameters remain
positive. A parent Rebase compensates direct Child local transforms to preserve
the Child subtree's visible world transform, so Child Position, Rotation, or
Scale may change; hierarchy and animation data remain untouched. Zero/non-finite
Scale blocks the whole operation. See
[`SCALE_REBASE.md`](SCALE_REBASE.md).

Schema 48 removes `z_index` from editor-only Group records. Each Component is
the sole owner of its integer `z_index`; legacy Group layer values are ignored
on load and are not written again.

Schema 49 permits a fill-less `contour` Component to own either one open Chain
or one closed Chain. Closed Contours retain only their centered Stroke as the
visible Component Mesh and never request or export a Fill Mesh. Their accepted
Contour build also carries a separate derived Boundary triangulation for
Runtime `closed_region_mesh`; hidden Stroke runs do not remove any part of that
complete region.

World schema 52 distinguishes visual Components, curve-based spine Guides,
transform-based Weapon Guides, and optional semantic Regions. A Weapon Guide stores a
stable role, Component-or-Group scope, and a local position/rotation frame;
non-uniform scale is inherited from its scope and is never authored on the
frame. A Region is stored as a nonvisual `type: "region"` Component backed by
canonical `points`, `edges`, and `chains`; it is excluded from visual Mesh
processing and exported in the separate Runtime `regions` array.

World schema 53 adds an authoring-only, positive Asset-root Scale. Its X and Y
axes are independent (legacy scalar values are read as equal axes). Canvas
presentation prefixes every Asset-space transform with that scale around the
unchanged Asset Pivot, while inspector fields continue to expose canonical
source coordinates. The atomic Root Scale Rebase multiplies each local
translation, owned Bézier coordinate/handle, primitive axis, Guide coordinate,
and Weapon-frame translation exactly once per axis. Root placements are scaled
around the Asset Pivot; nested placements are scaled around their local origin.
Reference geometry uses its instance scale, so its transform Pivot remains
unchanged during the bake. Component Scale is not modified, keeping schema
42's independent Component Scale Rebase valid before or after this operation.
Non-default Motion is an explicit blocker. Accepted derived data is not
rewritten and becomes stale through its existing source fingerprints.

World schema 58 adds an authoring-only Asset-root Position. Canvas presentation
prefixes Asset-space transforms with translation followed by the existing
independent X/Y scale around the Asset Pivot. The shared atomic Asset Transform Rebase
adds translation exactly once to root-scoped Components, Groups, Asset Guides,
and Weapon frames while preserving nested local placement, resets Root Position
to zero, and also normalizes Root Scale as described above. The Asset Pivot is
not moved by the bake.

World schema 54 extends transform-based Weapon Guides with
`reach_limit_primary`. It shares the existing frame data, scope inheritance,
Canvas gizmo, Inspector, history, Scale Rebase, and persistence paths; it does
not infer its position from a visual Component. Runtime Manifest schema 10
exports this fourth optional Attachment Frame role and rejects schema 9.

World schema 55 extends transform-based Weapon Guides with `grip_secondary`.
It is a second weapon-local hand-contact frame for an attack regrip and stays
semantically distinct from the character-owned `weapon_socket_primary`, the
carried `grip_primary`, and the maximum endpoint `reach_limit_primary`.
Runtime Manifest schema 11 exports this fifth optional Attachment Frame role
and rejects schema 10.

Schema 56 adds a visible-Component-only `projection_depth_cm` authoring field.
It defaults to `10 cm`, is persisted and exported independently of Component
and Asset Scale, and is not owned by Groups or the Asset root. Runtime Manifest
schema 15 carries the metric `projection_depth_meters` value and ordered
local-meter `projection_depth_corners` for authored Bézier points in `corner`
handle mode.

World schema 60 restores optional semantic gameplay Region records. Existing
documents without Regions remain valid and consumers retain their existing
Component-based fallback behavior.

World schema 59 persists Asset-root `root_scale` as a two-axis vector and
exposes separate `Scale X` and `Scale Y` Inspector controls. Legacy scalar
root scales load as equal axes; Runtime Export requires both axes to be `1`.

Sampling results carry their own algorithm version independently of the
World schema. The junction-aware version invalidates pre-arrangement flat
Cut Bakes at Sampling, which in turn makes Seeding stale before Meshing can
consume an incompatible PSLG.

## Export contract

The normative serialized package and consumer contract is
[`RUNTIME_EXPORT_CONTRACT.md`](RUNTIME_EXPORT_CONTRACT.md). The summary below
describes how the editor produces that contract.

`RuntimeExportService` builds Manifest schema 15 exclusively from current
accepted Fill and Contour Stroke Mesh Bakes. For a closed Contour, the current
Stroke Bake must also contain its current complete-Boundary region
triangulation. It rejects missing or stale inputs,
invalid or duplicate Component Names, non-rebased Scale, unresolved
Asset References, and incomplete or cyclic visible hierarchies. Ordinary
Components never derive replacement geometry during export. References emit an
`asset_reference` record containing the local `name`, signed placement
transform, and actual `source_asset_key`, without copying geometry into the owner.

Every schema-15 Manifest also exports the Asset-level presentation metadata as
`presentation.authored_facing`, oriented Asset-local Weapon Attachment Frames,
and geometry-only closed Contour boundaries. Authored semantic Regions are
exported separately as optional triangulated Asset-local meter geometry.

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
Schema 15 contains no UV/SDF/Carrier fields and carries an optional authored
semantic gameplay Region array.

Each visible Asset is exported to the active World-local
`res://worlds/<world_key>/PolyToolsRuntimeExports/<asset_key>/` directory as
`manifest.json`. The batch verifies a staging package
before atomically replacing the prior package; validation or I/O failure leaves
the prior package intact. Once all required packages are current, the same batch
atomically updates World-root Asset Catalog schema 1. The Catalog is the closed
consumer set; generated directories absent from it are ignored and pruned only
after every listed package is current and the new Catalog has been committed. Package freshness is derived by comparing the expected
Manifest bytes, not by persisting export diagnostics in the Asset.

## Testing

The headless suite covers topology, derived geometry, navigation state, and UI
contracts. Geometry changes require the test runner, a headless editor parse,
and `git diff --check`. World data is never used as a mutable test fixture.
