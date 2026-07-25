# AssetFlow2D – AI Context

**Read this file before making changes.** For stable product decisions, see
[`ARCHITECTURE.md`](ARCHITECTURE.md). For the current result-based work items,
see [`MVP_CHECKLIST.md`](MVP_CHECKLIST.md).

## Product in one sentence

AssetFlow2D is a canvas-first 2D asset creation tool built through small,
testable vertical slices rather than a complete feature set up front.

## Current phase

The repository currently contains the reviewed UI skeleton, the Asset creation
flow, and the first in-memory Asset/Component hierarchy. The next goal is to
add the Component Canvas while preserving the result-based workflow. Empty
panes are preferred to invented asset content.

The current implementation target is not a functional morphing engine.

## Technology baseline

- Engine: **Godot 4.7.1**
- Project layout: `project.godot`, `scenes/main.tscn`, and `scripts/main.gd`
- Editor workspace and default window: 1920×1200 (16:10); preview uses preserved
  aspect ratio (`keep`) so the UI proportions remain stable
- Project icon: `assets/assetflow_icon.png`

## Confirmed vocabulary

- **Asset:** An independently editable visual object.
- **Morph:** A separately designed transition between a source and a target
  asset.
- **Category:** A visible creative area such as Create, Style, or Motion.
- **Module:** A concrete working context inside a category, such as Shapes or
  Layers.
- **Create / Style / Motion / Transform / Effects:** Current categories.
- **Export:** A dedicated final output area.
- **Timeline:** A contextual view owned by the active time-based work area,
  never a permanent global UI level.

Do not use `Scene`, `Sequence`, or `Stage` as a settled data-model term. Their
need and name are open.

## Scope guardrails

- Build the next observable result, not expected future features.
- Prefer the smallest usable implementation over a general framework.
- Keep data types generic enough to avoid example-specific code. A closed
  `PolylineContour` is appropriate; a `WizardHatShape` is not.
- Assets contain independently editable Components. The `Line` tool in
  `Create → Shapes` creates closed Polyline contours on the selected Component;
  it does not draw directly on the Asset container.
- Do not add Bézier editing, maps, full materials, a node graph, generic
  rigging, or export pipelines until a confirmed checklist item requires them.
- Treat dummy UI data as dummy UI data. Do not let it quietly become a rigid
  domain model.
- When a product or UX decision is unclear, ask before deciding it in code.

## UI skeleton target

The skeleton should demonstrate the following navigation state changes without
invented asset content:

```text
category accordion → module selection → Main Toolbar → Context Bar → workspace state
```

It includes a scrollable Outliner, a scrollable Inspector, a central workspace,
and a compact bottom status grid. Time controls are added only with the first
real time-based interaction.

The UI must follow the compact PolyTexture-inspired editor aesthetic: retain
the fixed vertical module rail, but use nested resizable split panes for the
Outliner, centre workspace, and Inspector. Avoid decorative cards; the canvas
must be the visual focus.

The UI is dynamically assembled in GDScript from editor state and small
definition lists; the `tscn` scene remains a root host. Do not build a large,
manually maintained Control hierarchy for the module-specific UI.

Keep the initial skeleton visually sparse. The Outliner and Inspector may have
small contextual panel labels; avoid decorative descriptions and status values.

Use PolyPixAAA as the visual reference: standard Godot control styling, 1px
outer margin, 1px separation between major panels, and resizable split panes. Do not add
custom button font/hover colours in the initial skeleton.

The Outliner is `ScrollContainer` + an edge-to-edge vertical list of direct
button rows, not Godot's `Tree` control. Module navigation is handled by
reusable expandable sections in the left module rail; modules do not appear in
the Outliner. The Outliner uses vertical Asset containers with a name header,
an `Add` button, and Component child rows with an empty indentation placeholder.
The rail behaves as an accordion: at most one category is expanded at a time.
The active module uses a yellow background with black text, including its
hover state. No tree icons or glyphs are used.

Only Create has modules in the current shell. Style, Motion, Transform,
Effects, and Export are present as empty category sections until their own
work begins.

The Main Toolbar contains a `New ▼` menu with `Asset` and `Texture` entries.
`New → Asset` opens a name dialog with OK/Cancel, Enter, and Escape handling,
creates an in-memory Asset, lists it in the Outliner, and exposes its editable
name in the Inspector. `Texture` remains inert. Components can now be added
below an Asset, selected, and renamed in the Inspector. The central workspace
identifies whether the Asset or a Component is the active context. The empty
Shapes canvas now provides a PolyPixAAA-style grid with click-to-focus `A/S/D/W`
pan and `Q/E` zoom controls (`E` zooms in); it still contains no asset data.
When a Component is selected, the Context Bar shows `⌘1 Draw ▼` and `⌘2 Edit ▼`
(Ctrl is accepted as the equivalent modifier on non-macOS systems). The lower
Info Bar lists the available subcommands dynamically. Draw exposes `1: Line`;
Edit exposes `1: Select`, `2: Move`, and `3: Delete`. Draw uses the Line
Polyline tool. Edit defaults to point selection; clicking a point reveals a
move gizmo with X/Y handles plus a central free-move handle that can be dragged
on the canvas. Add mode (`2`)
highlights the nearest position on a contour segment and inserts a point there
when `Space` is pressed. `Backspace` deletes the selected point when at least
three points remain; `Delete` is also available in Select mode. The modifier shortcut selects a state, and the unmodified
number selects its subcommand.
Clicks place snapped Polyline draft points, a yellow preview point appears on
hover, and `Escape` clears the draft or selection.
Clicking near the first point closes a draft with at least three points; the
closed Polyline is stored as the Component's `Outer Shape` and rendered in
cyan. This is still in-memory only.

When an Asset (rather than a Component) is selected, the Shapes canvas shows
all of its completed component contours together. Clicking inside a contour or
near one of its edges selects that Component. The selected Component then
renders as the active contour while the other components remain visible as
transparent background references.

Outliner selection uses explicit yellow/black selected-button styling. Selecting
an unselected Asset only changes selection; clicking that already selected Asset
again toggles its component list open or closed.

Workspace persistence uses the project-local `workspaces/` directory. The
Workspace menu provides `New`, `Save`, and `Load`; New uses an in-app naming
dialog with `workspace01` fallback, Save overwrites the active workspace, and
Load uses an in-app list of existing workspace folders. Each workspace has a
`workspace.json` plus one `assets/<asset_id>/asset.json` per Asset. The latest
loaded or saved workspace name is stored in `configs/app_config.json` and is
loaded automatically on startup. Every workspace, asset, and config JSON uses
the numeric `schema_version` field; the current schema is version `2`. The
bottom status bar is divided into 17% program status, 64% contextual tool
information, and 17% reserved space. `CMD/Ctrl + S` saves the active workspace;
the canvas suppresses ASDW panning while that modifier is held.
Workspace `editor_state` also restores the selected Asset, selected Component,
and expanded Outliner containers when the Workspace is reopened.

The current Transform & Snap Foundation milestone begins with the world origin
`(0, 0)` defined by full horizontal/vertical canvas axes. Phase 2 adds the
left-aligned Snap popover with On/Off, Grid Step, and Rotation Step controls;
the settings are workspace-persistent. Phase 3 stores Component transform data
(position, rotation, scale, pivot) plus visibility and z-index. Phase 4 exposes
these values in the Component Inspector. Phase 5 displays and edits the local
Pivot with Snap support. Phase 6 exposes `CMD/Ctrl + 3` with `1: Transform`,
`2: Rotate`, and `3: Scale`; the gizmo is drawn at the Pivot and the Transform
submode supports free, X-axis, and Y-axis translation with Snap. Rotate and
Scale interaction remain later steps.

## Documentation maintenance

- Update `ARCHITECTURE.md` when a stable product boundary is decided.
- Update `MVP_CHECKLIST.md` when a result is accepted, changed, or split.
- Keep this file short and current; it is operational context, not history.
- Mark unresolved questions as open instead of silently resolving them.

## Current open questions

- Should empty future categories remain non-expandable until they receive their
  first module?
- How much of the lower status grid should be interactive in the prototype?
- What fixed minimum and maximum pane widths should be used around the 16:10
  reference layout?
