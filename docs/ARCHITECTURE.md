# PolyTools Architecture

## Product shell

`scripts/main.gd` composes the editor shell and routes user intent between the
Outliner, canvas/workspaces, Inspector, persistence, and export. The left rail
contains always-expanded Create, Mesh, Style, and Export categories. A single
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
- `main.gd` applies intent to the selected Workspace document and records
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
number display setting. It has no Material assignment.

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

`workspace.json` indexes Assets by stable ID plus retained motion/derived
resources. Each Asset is stored below a sanitized visible-name directory with
a matching JSON filename, for example `assets/Wizard/Wizard.json`. The stable
ID remains inside the JSON and in the workspace index. Older ID-based paths
such as `assets/asset_1/asset.json` remain readable as a migration fallback;
older Assets without `asset_type` load as `character`. Editor
state persists the active Create/Mesh/Style module and valid selection, but it
does not restore disabled Motion as the active category.

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

Schema 34 removes the editor-only open-curve Component mode. Existing workspace
assets were converted to Ribbons; Ribbon widths normalize to a practical minimum
of 1 px.

Schema 35 stores semantic Component Mesh build provenance in the derived
Geometry document. The persistent `Update Meshes (N)` action rebuilds only
meshable Components across all Create Asset types whose effective geometry,
constraints, or recipes differ meaningfully from their last successful build.
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

Sampling results carry their own algorithm version independently of the
Workspace schema. The junction-aware version invalidates pre-arrangement flat
Cut Bakes at Sampling, which in turn makes Seeding stale before Meshing can
consume an incompatible PSLG.

## Export contract

Export first runs topology validation, including chain continuity and point
number ordering. A successful build creates a Godot scene whose root stores:

- `asset_pivot`: the exported pivot in Godot coordinates;
- `asset_type`: `character`, `props`, `terrain`, `icon`, or `symbols`.

Component hierarchy becomes nested `Node2D` nodes. Closed-loop geometry is
derived from Bézier topology, while primitive geometry is derived from its
typed definition. Ribbon geometry uses a matching accepted Ribbon mesh. Open
paths used by simulation or construction are Guides rather than Components.
Exported Component nodes preserve `topology_role` metadata. For Symbol
References, the reference node preserves its selected role and expanded source
Components preserve their own roles independently.

## Testing

The headless suite covers topology, derived geometry, navigation state, and UI
contracts. Geometry changes require the test runner, a headless editor parse,
and `git diff --check`. Workspace data is never used as a mutable test fixture.
