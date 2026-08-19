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

## Export contract

Export first runs topology validation, including chain continuity and point
number ordering. A successful build creates a Godot scene whose root stores:

- `asset_pivot`: the exported pivot in Godot coordinates;
- `asset_type`: `character`, `props`, `terrain`, `icon`, or `symbols`.

Component hierarchy becomes nested `Node2D` nodes. Closed-loop geometry is
derived from Bézier topology, while primitive geometry is derived from its
typed definition. Ribbon geometry uses a matching accepted Ribbon mesh. Open
edges do not emit fill geometry.
Exported Component nodes preserve `topology_role` metadata. For Symbol
References, the reference node preserves its selected role and expanded source
Components preserve their own roles independently.

## Testing

The headless suite covers topology, derived geometry, navigation state, and UI
contracts. Geometry changes require the test runner, a headless editor parse,
and `git diff --check`. Workspace data is never used as a mutable test fixture.
