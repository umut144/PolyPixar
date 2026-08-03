# AssetFlow2D – AI Context

**Read this file before making changes.** For stable product decisions, see
[`ARCHITECTURE.md`](ARCHITECTURE.md). For the current result-based work items,
see [`MVP_CHECKLIST.md`](MVP_CHECKLIST.md).

## Product in one sentence

AssetFlow2D is a canvas-first 2D asset creation tool built through small,
testable vertical slices rather than a complete feature set up front.

## Current phase

The repository contains the editor shell, Asset/Component Bézier authoring,
transforms, Workspace persistence, Texture import, Style Materials, and Godot
scene export. Component geometry uses one canonical Point/Edge/Chain topology;
see [`BEZIER_MODEL.md`](BEZIER_MODEL.md).

Slice 4 Phase 1 is implemented and awaiting manual verification: a selected
Texture can import a PNG, JPEG, or WebP through the native image picker, which
opens directly in `res://imports/textures`. The source is copied into that
Texture's active Workspace directory and persisted as a relative
`source` reference inside a typed `import` element. The Texture parent is
reserved for valid final Element outputs; the raw import source belongs in the
Import Element preview, which is now implemented as a separate image context,
and must pass through processing before contributing to the parent output.

The current implementation target is not a functional morphing engine or a
general animation/VFX framework.

The Motion category now exposes four distinct modules: asset-local
`Animation`, independent Workspace-level `Path`, independent action primitives
in `Act`, and compositional `Sequence`.
`Motion → Animation` contains persisted Asset Animation authoring
documented in [`MOTION_UI.md`](MOTION_UI.md). Each Asset starts with `IDLE`,
`WALK`, and `RUN`; States can be added, renamed, and removed while the
the Asset remains available. Motions can be added and configured as Outer Bob
or Inner Spine Sway; unavailable Guide dependencies are shown explicitly.
Ordered Transitions expose target, Exit/Entry policies, and
blend duration. Markers expose Event ID, kind, and normalized phase and appear
as ticks below the phase scrubber. The Simulation Contract supports Number/Bool
parameters and typed `ALL` Rules referencing stable parameter IDs. Phase 7
persists this entire document in the Asset, includes its mutations in Undo/Redo,
and validates broken references; see
[`SIMULATION_CONTRACT.md`](SIMULATION_CONTRACT.md). Phase 8 adds the
geometry-independent `MotionPlayer`: Play/Pause,
State phase, Marker crossings, typed Rule evaluation, Transition priority,
Exit/Entry policies, and blend progress. See
[`MOTION_PLAYER.md`](MOTION_PLAYER.md). Phase 9 adds non-destructive visible
Outer Bob sampling for
Entire Asset or Component targets in the Inspector Preview, including additive
Motions and Transition blending; see
[`MOTION_SAMPLER.md`](MOTION_SAMPLER.md). Phase 10 establishes independent Path
and Sequence resource shells with stable IDs, Save/Load, Undo/Redo, Outliners,
Inspectors, and centre workspaces. Legacy Animation Path Follow entries are
archived rather than silently discarded. Phase 11 adds open Path authoring,
Draw/Edit tools, free Bézier handles, approximate arc-length sampling, and a
Wizard contour preview with Phase, Loop, Duration, and optional tangent
orientation. The preview Asset is editor-only and never becomes Path data. See
[`MOTION_PATH.md`](MOTION_PATH.md) and
[`MOTION_COMPOSITION.md`](MOTION_COMPOSITION.md). Phase 12 adds one
bounded Sequence Composition Entry that references Asset, Animation State, and
Path IDs. `⌘1 Composition` authors those references; `⌘2 Player` shows a
large, read-only Path + Animation preview with independent Path and State phase
evaluation. Multi-Entry composition, meshes, Inner deformation, and animation
export remain deferred. See [`MOTION_SEQUENCE.md`](MOTION_SEQUENCE.md). Phase
13 adds the independent `Act` module and its first `Slide` primitive. Acts are
created in a vertical list, edited through the Inspector, and previewed against
an editor-only Asset. Phase 14 adds a bounded primitive catalog and `Jump` with
Direction, Distance, Height, Arc Shape, Duration, and Easing; see
[`MOTION_ACT.md`](MOTION_ACT.md). Phase 15 adds `Blink`: a short backward
anticipation followed by forward travel and uniform wormhole contraction to a
minimum scale at the spatial midpoint before returning to full scale. Its
default timing is 50% anticipation, 40% ingress to the midpoint, and a fast
10% exit.

## Technology baseline

- Engine: **Godot 4.7.1**
- Project layout: `project.godot`, `scenes/main.tscn`, and `scripts/main.gd`
- Editor workspace and default window: 1920×1200 (16:10); preview uses preserved
  aspect ratio (`keep`) so the UI proportions remain stable
- Project icon: `assets/assetflow_icon.png`
- Current JSON schema version: **20**

## Confirmed vocabulary

- **Asset:** An independently editable visual object.
- **Morph:** A separately designed transition between a source and a target
  asset.
- **Category:** A visible creative area such as Create, Style, or Motion.
- **Module:** A concrete working context inside a category, such as Asset or
  Texture.
- **Create / Style / Motion / Transform / Effects:** Current categories.
- **Export:** A dedicated final output area.
- **Sequence:** The first bounded Motion container for a staged event involving
  stable references to Assets, Guides, and selected parameters. It is not yet
  a general scene or animation-graph model.
- **Timeline:** A contextual view owned by the active time-based work area,
  never a permanent global UI level.

Do not use `Scene` or `Stage` as a settled data-model term. `Sequence` is the
confirmed, deliberately narrow name for Slice 4's Motion module; do not expand
it into a general scene or animation-graph abstraction prematurely.

## Scope guardrails

- Build the next observable result, not expected future features.
- Prefer the smallest usable implementation over a general framework.
- Keep data types generic enough to avoid example-specific code. A closed
  `PolylineContour` is appropriate; a `WizardHatShape` is not.
- Assets contain independently editable Components. `Draw Point` stores
  ordered Bézier Points on the selected Component and automatically maintains
  Edges and Chains; drawing never targets the Asset container directly.
- Textures are a separate Workspace document type. They will contain
  `elements`, not Components, and have their own canvas dimensions and
  PolyTexture-style editing context.
- The Create category exposes Core Asset and Texture authoring modules.
  Geometry is a separate derived-pipeline category with Sampling, Seeding,
  Meshing, and UV Mapping. Sampling is implemented per Component with Adaptive
  and Even Spacing recipes, Generate/Bake, immutable preview, derived
  persistence, and stale-source detection; the remaining modules are
  placeholders. Each implemented module's Outliner
  shows only its own document type, with a shared search field.
- Expanded Asset entries group children under `Components` and optional
  `Guides`; expanded Texture entries group typed children under `Import
  Elements` and `Generator Elements`. These are visual groups over unified
  typed child lists.
- `Create Texture` now creates a 512×512 Texture; its Outliner `Add` action
  creates named Elements with fallback names. Texture and Element selection
  and renaming are available. The UV Texture Canvas is also implemented.
- Phase 5 Texture work will use an `Origin` menu with only `Bottom Left`,
  `Top Left`, and `Center` in the initial MVP. Draw/Generate menus are removed.
  Origin is a presentation/export convention over canonical normalized UV data;
  Outliner search also matches child Component and Element names.
- The initial UV Canvas is now available for Texture and Element contexts; it
  shows the normalized field and a compact origin gizmo with separate U/V
  colors, while drawing and generation remain deferred. The canvas supports
  focused `A/S/D/W` panning and `Q/E` zooming.
- Slice 4 will add `Import Texture` to the Texture Context Bar. Imported raster
  Textures do not require Elements. Its smallest pipeline is: retain the source
  in the Workspace, isolate dark ink from a light background, retain useful
  ink/alpha data for a Material, and judge repeatability with a tile preview.
- Texture Elements follow an output contract: Generator Elements may produce a
  valid output directly, while Import Elements must distinguish raw source,
  processing preview, and valid final output. The current Phase 4 state is
  explicitly `not_ready`; Phase 6 adds the first `White to Alpha` processing
  action, which can produce a `ready` output for the Texture parent.
- A Texture persists `final_output_element_id`. The parent UV Canvas consumes
  only that ready Element output; successful processing selects the processed
  Import Element as the final output. Legacy Textures resolve a first ready
  output on load.
- Style now exposes `Material` as its first submodule. Materials can be
  created through `Create Material`, searched and selected in the Material
  Outliner, and edited in the Inspector with a ready Texture reference, tint,
  and opacity.
- Materials are included in workspace metadata, save/load, and history
  snapshots. The Material workspace opens directly as a fixed GraphEdit
  skeleton with `Texture Source → Material Output` plus a small integrated
  neutral Preview. There is no Material View switcher or in-editor LookDev.
  The selected Material remains active in the Outliner, Inspector, and right
  status-bar region. Mapping scale/offset are currently editable parameters;
  mapping will later become a graph concern. Material assignment is performed
  in the normal Asset Component Inspector and the selected Component canvas
  uses its optional `material_id`. Exported Godot artifacts are the
  authoritative end-look validation path. The first export action writes a
  minimal `res://exports/<asset>.tscn` with Polygon2D nodes and ready Texture
  references. Export is now a compact Build workspace: `Source Asset →
  Validate → Godot Scene`. It uses a flat Source Asset Outliner and dedicated
  Build surface/Inspector instead of reusing Create hierarchies or canvas
  interactions. It validates closed, triangulable contours and ready Material
  Texture references, then uses `PackedScene` plus `ResourceSaver` instead of
  composing `.tscn` text.
- Material Mapping provides `Fit`, `Clamp`, and `Repeat` wrap modes. Repeat is
  applied in the Material Preview, Component canvas, and exported Polygon2D
  scene; it is required when a scale below 1 should tile a texture.
- `Style → Material` is Slice 4's first Style module. It binds a Workspace
  Texture to a Component by stable reference and exposes only repeat, scale,
  offset, base tint, ink strength, and glow values.
- `Motion → Sequence` is Slice 4's first Motion module. It owns the deliberate
  staged relation between the floor Asset, its non-rendered local Guide Shape,
  and the independent Flower Asset. Do not make the Flower store a permanent
  link to the floor or Guide.
- An Import Element's Context Bar uses `⌘1 Previews` with `1: Original` and
  `2: White to Alpha`; unmodified `1`/`2` switch the preview directly. Preview
  selection does not by itself change `not_ready` to `ready`.
- Do not expand the current topology into meshing, generic rigging, or new
  export pipelines until a confirmed checklist item requires them.
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
the Outliner. The Outliner uses vertical Asset containers with a visibility
checkbox, name header, `Add` button, and Component child rows with their own
visibility checkboxes. Parent visibility overrides child visibility only
effectively; it does not modify stored child states. The same rule applies to
Texture Elements.
The rail behaves as an accordion: at most one category is expanded at a time.
The active module uses a yellow background with black text, including its
hover state. No tree icons or glyphs are used.

Create exposes `Asset` and `Texture`. Geometry exposes the implemented
`Sampling` module plus placeholders for `Seeding`, `Meshing`, and `UV Mapping`. Style
exposes `Material`; the remaining categories are present as empty sections.

The Main Toolbar has one context-specific action button: `Create Asset` in the
Asset module, `Create Texture` in the Texture module, and `Create Material` in
the Material module. Each action opens a name dialog with a fallback name and
creates a Workspace document.
Assets contain Components; Textures contain optional Elements. Both document
types are listed, searched, filtered, renamed, persisted, and restored through
the Outliner/Inspector. The central workspace identifies whether an Asset,
Component, Texture, or Element is the active context. The Shapes canvas uses a
PolyPixAAA-style grid with click-to-focus `A/S/D/W` pan and `Q/E` zoom controls
(`E` zooms in).
When a Component is selected, `⌘1` activates Draw Point, `⌘2` Edit Point,
`⌘3` Edit Edge, and `⌘4` Edit Face (Ctrl is accepted as the equivalent modifier
on non-macOS systems). Draw Point selects Linear, Aligned, Free, Mirrored, or
Corner Points before placement. Edit Point exposes Select, Bézier Handle, and
Set; Select supports marquee selection and a shared move gizmo. Set splits the
clicked Bézier Edge without changing its curve. Backspace/Delete removes the
selected Point set while preserving valid closed-Chain topology.

Points are persisted immediately with stable IDs. Edges and Chains are
maintained by `BezierTopology`; the Canvas never writes document geometry.
Clicking the first Point after at least three Points closes the active Chain.

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
`workspace.json` plus independent Asset, Texture, Material, Path, and Sequence
documents in their corresponding resource directories. The latest loaded or saved
workspace name is stored in `configs/app_config.json` and is loaded
automatically on startup. Every workspace, asset, texture, and config JSON
uses the numeric `schema_version` field; the current schema is version `20`.
Materials are independent Workspace resources stored below
`materials/<material_id>/material.json` and listed by ID in `workspace.json`.
The bottom status bar is divided into 17% program status, 64% contextual tool
information, and 17% reserved space. `CMD/Ctrl + S` saves the active Workspace;
the canvas suppresses ASDW panning while that modifier is held. Workspace
`editor_state` also restores selected Asset/Component/Texture/Element and
expanded Outliner containers when the Workspace is reopened.

The current Transform & Snap Foundation milestone begins with the world origin
`(0, 0)` defined by full horizontal/vertical canvas axes. The editor uses
Y-positive-up coordinates and converts to Godot's Y-down convention on export.
Phase 2 adds the
left-aligned Snap popover with On/Off, Grid Step, and Rotation Step controls;
the settings are workspace-persistent. Phase 3 stores Component transform data
(position, rotation, scale, pivot) plus visibility and z-index. Phase 4 exposes
these values in the Component Inspector. Phase 5 displays and edits the local
Pivot with Snap support. Phase 6 exposes `CMD/Ctrl + 3` with `1: Translate`,
`2: Rotate`, and `3: Scale`; the gizmo is drawn at the Pivot and the Transform
submode supports free, X-axis, and Y-axis translation with Snap. Rotate and
Scale interaction remain later steps. Phase 6.3 adds interactive Pivot-ring
rotation with the configured Rotation Step. Phase 6.4 adds uniform corner
scaling around the Pivot; non-uniform X/Y scaling is excluded from the MVP.
Pivot dragging is restricted to Edit state and adjusts the transform position
to keep the component geometry visually stable. Phase 6.5 applies component
transforms, visibility, and z-index to Asset-level composition: reference
contours are rendered in z order, invisible references are skipped, and
transformed contours remain clickable for Component selection. The selected
Component is still rendered as the active editing overlay.

## Documentation maintenance

Geometry modules author compact recipes and inspect or accept derived pipeline
results. Components still store only authored contours; sampling,
triangulation, UV generation, and render-mesh rebuilding remain derived
services shared by rendering, deformation, and morphing. Manual topology
overrides and mesh-debug tooling remain outside the MVP.

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
