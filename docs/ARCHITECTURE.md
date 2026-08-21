# PolyTools Architecture

## Product shell

`scripts/main.gd` composes the editor shell and routes user intent between the
Outliner, canvas/workspaces, Inspector, persistence, and export. The left rail
contains always-expanded Create, Mesh, and Style categories. A single
`active_module` plus its category-specific submodule identifies the one active
workspace.

Create has five database views over the same Asset implementation:
`Character`, `Props`, `Terrain`, `Icon`, and `Symbols`. Their stable persisted discriminator
is `asset_type`; missing or invalid values normalize to `character`.

Mesh and Style share a multi-select Outliner Asset filter. Its five checkbox
states are persisted in `editor_state`; the filter is applied together with
the Outliner search and does not alter the selected Asset or document data.

Mesh is the user-facing name of the derived geometry pipeline. Existing
internal `geometry_*` identifiers remain technical names, while UI copy uses
Mesh. Style currently contains only Weighting. Motion code is retained but its
category is disabled. Transform and Effects categories do not exist.

## Ownership boundaries

- `BezierTopology` owns changes to points, edges, chains, IDs, ordering, and
  topology validation.
- `BezierGeometry` owns cubic Bézier evaluation, flattening, and handle
  resolution.
- `PrimitiveGeometryService` owns typed primitive validation and deterministic
  derived contours. It does not create or own Bézier topology.
- `ComponentHierarchy` owns parent/child normalization and world/local
  transform conversion.
- `ComponentCanvas` renders immutable copies and emits user intent.
- `main.gd` applies intent to the selected World document and records
  history.

Each Component declares a geometry source. Bézier sources contain only
`points`, `edges`, and `chains`; primitive sources contain one typed primitive
definition, currently `circle` with `center` and `diameter_cm`. Generated
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
- Asset pivot and reference-image settings;
- Components and Guides;
- retained asset-local animation data.

A Component contains its geometry source, hierarchy reference, local transform,
visibility/layer settings, draw mode, widths, catch-parent reference, and point
number display setting. It carries one required `semantic_key`, which is both
its registry identity and its only authored name. Keys must be registered and
unique within an Asset. It has no Material assignment.

Derived mesh documents are keyed by Asset and Component IDs. Sampling feeds
Seeding, Seeding feeds Meshing, and accepted Bakes remain separate from source
Component geometry. Weighting styles reference accepted mesh data without
becoming Component topology.

Sampling owns one adaptive Body recipe. Its Outer boundary, referenced Hole
inputs, and scoped Cut Guides inherit the Body target edge length and Curve
Detail; Hole and Cut inputs may apply a boundary-density factor from `0.25×`
through `16×`. Values below `1×` coarsen all adaptive criteria, while values
above `1×` refine them. Primitive Circles
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
Seeding vertices, recovers Outer/Hole/Cut constraints, and accepts a relocation
pass only when measured quality improves without a material minimum-angle
regression. It retriangulates after each candidate and only then duplicates the
Cut seam. Boundary vertices never move and this phase neither adds nor removes
vertices. Meshing uses the same debounced transient Preview and exact Preview
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

The World-root `catalog.json` is an independently versioned derived index, not
an authored identity store. It lists visible Assets by the `asset_key`
mechanically derived from each complete display name. The derivation cannot be
overridden, and creation or rename rejects collisions across visible and hidden
Assets. Internal stable Asset IDs remain in editor persistence only; neither the
Catalog nor runtime manifests expose them.

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
New automatic recipes retain the calibrated `0.55` spacing for normal contours
but scale it upward when Component area would exceed the automatic interior
density budget. This keeps large simple Assets responsive without rewriting an
existing manual recipe.
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

Schema 39 replaces the provisional free-form `name` / `semantic_role` pair with
one required `semantic_key`. `configs/semantic_keys.json` owns the independent
Semantic Registry schema 1. The registry is read-only in the application;
creation uses a searchable alphabetical picker, while Inspector reassignment
places that searchable list in a compact dropdown. Unknown links display as
`missing_semantic (<key/source>)`. Pre-schema-39 data
migrates through the explicitly reviewed legacy mapping. Known left/right pairs
are mirrored automatically during duplication; all other copied Components
must receive an explicit available key before the duplicate is committed.
Asset References use the same local Semantic picker but retain the borrowed
Asset in internal `source_asset_id`, so local classification never erases
geometry origin. Runtime export resolves that editor link to `source_asset_key`.

Schema 40 replaces the authored `ribbon` draw mode with the fill-less open
`contour` mode. Loading schema 39 or older converts Ribbon centerline topology
explicitly; current-schema Ribbon values are invalid and receive no fallback.
Component-local Ribbon widths are discarded because Contours use the fixed
World stroke default. Legacy `ribbon_strip` Bakes remain readable records but
are never current for a Contour and must be rebuilt as `contour_stroke`.

Sampling results carry their own algorithm version independently of the
World schema. The junction-aware version invalidates pre-arrangement flat
Cut Bakes at Sampling, which in turn makes Seeding stale before Meshing can
consume an incompatible PSLG.

## Export contract

The normative serialized package and consumer contract is
[`RUNTIME_EXPORT_CONTRACT.md`](RUNTIME_EXPORT_CONTRACT.md). The summary below
describes how the editor produces that contract.

`RuntimeExportService` builds manifest schema 3 exclusively from current
accepted Component Mesh, UV, and SDF Bakes. It rejects missing or stale inputs,
missing/corrupt mask resources, invalid or duplicate Semantic Keys, unresolved
Asset References, and incomplete or cyclic visible hierarchies. Ordinary
Components never derive replacement geometry during export. References emit an
`asset_reference` record containing the local `semantic_key` and actual
`source_asset_key`, without copying a second Mesh or contour mask into the owner.

The contract is engine-neutral: X points right, Y points up, lengths are meters,
positive rotations are counter-clockwise radians, and one Tool unit equals
0.1 m. Component local transforms mean
`T(position) * R(rotation) * S(scale) * T(-pivot)`. Components are listed in
global ascending `(z_index, component_id)` order from back to front. Accepted
Mesh Vertex order is retained, Triangle Vertex IDs become compact indices, and
UVs are aligned to that same order through stable Vertex IDs. Each ordinary
Component also exports a separate padded Contour Carrier rectangle and the
typed local SDF domain, silhouette UV bounds, and SDF-pixel/metre outside
padding. The unchanged fill Mesh is never used to clip that Carrier.

Each visible Asset is exported to the active World-local
`res://worlds/<world_key>/PolyToolsRuntimeExports/<asset_key>/` directory as `manifest.json` plus relative
`masks/<component_id>.sdf.png` resources. The batch verifies a staging package
before atomically replacing the prior package; validation or I/O failure leaves
the prior package intact. Once all required packages are current, the same batch
atomically updates World-root Asset Catalog schema 1. The Catalog is the closed
consumer set; generated directories absent from it are ignored and pruned only
after every listed package is current and the new Catalog has been committed. Package freshness is derived by comparing the expected
manifest and mask hashes, not by persisting export diagnostics in the Asset.

## Testing

The headless suite covers topology, derived geometry, navigation state, and UI
contracts. Geometry changes require the test runner, a headless editor parse,
and `git diff --check`. World data is never used as a mutable test fixture.
