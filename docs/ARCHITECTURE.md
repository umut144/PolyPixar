# PolyTools Architecture

## Product shell

`scripts/main.gd` composes the editor shell and routes user intent between the
Outliner, canvas/workspaces, Inspector, persistence, and export. The left rail
contains always-expanded Create, Mesh, Style, and Export categories. A single
`active_module` plus its category-specific submodule identifies the one active
workspace.

Create has four database views over the same Asset implementation:
`Character`, `Props`, `Terrain`, and `Icon`. Their stable persisted discriminator
is `asset_type`; missing or invalid values normalize to `character`.

Mesh and Style share a multi-select Outliner Asset filter. Its four checkbox
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
- `ComponentHierarchy` owns parent/child normalization and world/local
  transform conversion.
- `ComponentCanvas` renders immutable copies and emits user intent.
- `main.gd` applies intent to the selected Workspace document and records
  history.

Component geometry contains only `points`, `edges`, and `chains`. Fill and hit
test polygons are derived. Do not add `outer_shape`, Component-level `closed`,
the old Line tool, or synchronization from a display polygon back into source
topology.

## Documents

An Asset contains:

- stable ID, name, visibility, and `asset_type`;
- Asset pivot and reference-image settings;
- Components and Guides;
- retained asset-local animation data.

A Component contains its topology, hierarchy reference, local transform,
visibility/layer settings, draw mode, widths, catch-parent reference, and point
number display setting. It has no Material assignment.

Derived mesh documents are keyed by Asset and Component IDs. Sampling feeds
Seeding, Seeding feeds Meshing, and accepted Bakes remain separate from source
Component geometry. Weighting styles reference accepted mesh data without
becoming Component topology.

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
- `asset_type`: `character`, `props`, `terrain`, or `icon`.

Component hierarchy becomes nested `Node2D` nodes. Closed-loop geometry is
derived from Bézier topology; Ribbon geometry uses a matching accepted Ribbon
mesh. Open edges do not emit fill geometry.

## Testing

The headless suite covers topology, derived geometry, navigation state, and UI
contracts. Geometry changes require the test runner, a headless editor parse,
and `git diff --check`. Workspace data is never used as a mutable test fixture.
