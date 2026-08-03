# AssetFlow2D – Architecture

**Status:** Draft 0.1  
**Purpose:** Records the product decisions that are currently confirmed. It is
not a promise of every future feature and not an implementation blueprint.

## Contents

1. [Product intent](#product-intent)
2. [Technology baseline](#technology-baseline)
3. [Working rule](#working-rule-minimum-necessary-capability)
4. [Creative areas](#confirmed-creative-areas)
5. [Domain relationships](#confirmed-domain-relationship)
6. [Time and timelines](#time-and-timelines)
7. [UI architecture](#confirmed-ui-direction)
8. [Data and persistence](#data-and-persistence)
9. [MVP constraints](#architecture-constraints-for-the-mvp)
10. [Open decisions](#explicitly-open-decisions)

## Product intent

AssetFlow2D is a creative 2D asset tool. It should make the creation of
stylised game assets feel direct and playful while keeping the underlying
workflows precise enough for production use.

Development follows small, result-based vertical slices. A feature is added
only when the next demonstrable result requires it.

## Technology baseline

The MVP is built with **Godot 4.7.1**. The UI skeleton uses a minimal Godot
layout: `project.godot`, one root scene, and a dynamic GDScript UI entry point.
Workspace persistence uses versioned JSON files in the project-local
`workspaces/` directory. Application-level startup state is stored in
`configs/app_config.json`.

The editor workspace and default output window are 1920×1200 (16:10). The
preview uses preserved aspect ratio (`keep`) so non-16:10 windows show
letterboxing. This keeps the editor proportions stable across displays.

The project icon is stored at `assets/assetflow_icon.png` and is configured as
the Godot application icon.

## Working rule: minimum necessary capability

For every step, define the visible outcome first and then implement only the
smallest capability needed to reach it.

Example: authored Component contours now use ordered Bézier topology. Mesh
sampling remains separate because the current authoring outcome does not yet
require a production meshing pipeline.

This does not justify hard-coding an example. General names and relationships
are still used where they cost little, for example `Asset` and
`PolylineContour` rather than a wizard-hat-specific type.

## Confirmed creative areas

These are the user-visible areas of the editor. They describe *how a creator
works*, not necessarily objects stored in a project.

| Area | Current responsibility |
| --- | --- |
| Create | Create and arrange the visual form of an asset. |
| Style | Define its visual appearance. |
| Motion | Create motion local to an asset. |
| Transform | Design a transition between two independent assets. |
| Effects | Add visual and procedural effects. |
| Export | Preview and output a chosen result; a dedicated final area. |

The labels may gain or lose submodules as the MVP proves what is necessary.

In the UI, these areas are called **categories**. A category contains one or
more **modules** that provide the concrete working context. For example,
`Create` is a category with `Asset` and `Texture` authoring modules.
`Geometry` is a separate derived-pipeline category with modules for
`Sampling`, `Seeding`, `Meshing`, and `UV Mapping`. Sampling and Seeding are
implemented; Meshing and UV Mapping remain placeholders. Shapes editing
is the canvas workflow used by the Asset module.

An Asset is a container for independently editable Components. Drawing is
performed on a selected Component, never directly on the Asset container.
`Draw Point` creates Linear, Aligned, Free, Mirrored, or Corner Bézier Points.
Edges and Chains are maintained automatically, and clicking the first Point
after at least three Points closes the active Chain.

The next validated use of the currently empty categories is the **Stone Floor
Bloom** slice. It introduces one deliberately narrow module in each of two
areas:

- `Style → Material` binds a Workspace Texture to a Component and exposes only
  the mapping and appearance values required by that slice.
- `Motion → Sequence` stages time-based relationships between independently
  editable Assets, a local Guide Shape, and Material parameters.

These names are confirmed for the slice, not a commitment to a universal
material system or general animation graph.

`Motion` is split vertically into four ownership contexts: `Animation` owns
asset-local cyclic motion, `Path` owns reusable Workspace-level travel
geometry, `Act` owns independent action primitives, and `Sequence` composes
stable references without copying their data.

`Motion → Animation` provides a bounded asset-local workflow. Its horizontal
State board, contextual
Inspector, and normalized phase scrubber validate timeline-free asset-local
authoring. `IDLE`, `WALK`, and `RUN` States can contain editable Motions,
priority-ordered Transitions, and normalized-phase Markers. The first
Outer/Inner configuration fields, Transition Exit/Entry policies, and Marker
scrubber ticks are present. Path Follow is deliberately not an Animation
primitive.
Phase 6 adds a typed Simulation Contract and `ALL` Rule authoring. Contract parameters use stable
IDs so a future host import can validate and supply values independently of
display names. Phase 7 persists the normalized Animation document on its Asset,
adds Undo/Redo participation, and validates stable references. See
`MOTION_UI.md` and `SIMULATION_CONTRACT.md`.

Phase 8's `MotionPlayer` is a runtime-only evaluator over that document. It
owns current State/phase, Simulation values, Transition/Rule decisions, Marker
crossings, and blend progress but never mutates Asset data. This keeps Phase 9
geometry sampling and later mesh deformation downstream of one deterministic
state machine. See `MOTION_PLAYER.md`.

Phase 9's `MotionSampler` converts that runtime state into temporary
per-Component Outer transform deltas. Bob is the first implementation and may
target the Entire Asset or one Component. The Inspector Preview fits immutable
rest geometry, then applies samples, so animation never feeds back into
Point/Edge/Chain topology or stored Component transforms. See
`MOTION_SAMPLER.md`.

Phase 10 gives Path and Sequence their own centre workspaces, Outliners,
Inspectors, stable IDs, persistence, and Undo/Redo document shells. A Path has
no permanent Asset reference. A Sequence entry will own the stable Asset,
Animation State, and Path references needed for composition. Legacy
`path_follow` Animation Motions are retained in a migration archive and do not
evaluate. The formal boundary and transform order are defined in
`MOTION_COMPOSITION.md`.

Phase 11 makes Path the first spatial Motion authoring context. One Path owns
one open ordered Point/Segment curve with optional free Bézier handles.
`MotionPathSampler` maps normalized Phase to approximate arc length and returns
temporary position and tangent rotation. The Path workspace uses a selected
Asset—initially the Wizard—only as an immutable editor preview; that Asset ID
is editor state and is never persisted inside the Path. See `MOTION_PATH.md`.

Phase 12 implements the first bounded Sequence composition. One MVP Entry
references an Asset, one State from that Asset's Animation, and one independent
Path by stable ID. `Composition` is the authoring board; `Player` is a separate
large, read-only preview. Path duration drives Sequence preview duration while
the State's own cycle duration drives Animation phase. The Player applies
`Sequence × Path × Animation × Component × Geometry` without mutating any
referenced document. See `MOTION_SEQUENCE.md`.

Phase 13 establishes `Act` as an independent Workspace resource and implements
`Slide`. Phase 14 adds a deliberately bounded primitive catalog and `Jump`.
Both evaluate geometry-independent temporary transform offsets; the selected
Asset remains an immutable editor preview. Jump adds a mathematical vertical
arc without owning or generating Path geometry. See `MOTION_ACT.md`.

Phase 15 adds `Blink` as the first Act combining translation and uniform scale.
It owns a short backward anticipation, then travels from the authored Start to
End while scale contracts to a positive minimum at the spatial midpoint and
returns to one. It does not toggle visibility, create Path geometry, or mutate
the preview Asset. The accepted default timing assigns 50% to anticipation,
40% to reaching the midpoint, and the final 10% to a fast Ease-Out exit.

## Confirmed domain relationship

An asset is independently editable. A morph is a deliberately designed
relationship between two assets; it is not a permanent property or a form
state of either asset.

Textures are a second, independent Workspace document type. A Texture stores
its own canvas width and height and may contain Elements for future procedural
authoring. An imported raster Texture does **not** require Elements: it is a
source image passed through the small import pipeline required by the current
slice. Texture data is persisted below
`workspaces/<name>/textures/<id>/texture.json`. Each Element has a `type` of
`import` or `generator`; the Outliner may group these types without requiring
separate data collections.

The Texture parent stores `final_output_element_id`. It points to one ready
Element output and is the only output shown in the parent's UV Canvas. The
first processing action that succeeds selects its Element as the final output.
Older Texture documents without that field resolve their first ready Element on
load, preserving their existing result without treating a raw source as ready.

The Outliner presents Assets and Textures in separate groups. The Asset module
shows only Assets, while the Texture module shows only Textures. Both groups are
alphabetically ordered and share a compact search field. Expanded Assets display
`Components` and, when Guide
data exists, a separate `Guides` group. Expanded Textures display separate
`Import Elements` and `Generator Elements` groups. These are navigation groups
over one typed child collection, not separate persistence models.

`Create Texture` creates a named Texture with the default 512×512 canvas. Each
Texture exposes an `Add` action for named Elements, which are selected and
renamed independently in the Outliner/Inspector. Their drawing and generation
semantics remain deferred.

When a Texture or Element is selected, the Context Bar will provide the
Texture UV canvas' `Origin` menu. The initial MVP modes are `Bottom Left`,
`Top Left`, and `Center`; Draw/Generate controls are not part of this phase.
Origin changes affect the canvas coordinate presentation and export convention,
not the canonical normalized UV data. Outliner search matches document names
and child Component/Element names, expanding matching parents while a query is
active.

The initial UV Canvas is a dedicated Texture workspace. It displays a normalized
0..1 texture field, a lightweight grid, and a compact origin gizmo with
separate U/V colors; it intentionally does not yet provide drawing or
generator operations. The Texture parent is the final UV output context: it may
consume only outputs that satisfy the Element output contract. A raw Import
Element source is not itself a final output; it belongs in the Import Element
preview and processing context until its pipeline produces a valid output. The
current Import Element preview displays the copied source image without yet
claiming `ready` output status.
Its Context Bar exposes `⌘1 Previews` with `Original` and `White to Alpha`
entries. Preview selection is non-destructive; only an explicit processing
action can create a `ready` Element output.
The viewport supports focused `A/S/D/W` panning and `Q/E` zooming.

### Stone Floor Bloom relationship

The fourth vertical slice adds the first intentionally small cross-domain
relationship:

```text
Imported Texture ──binds to──> Floor Component
                                 │
                                 ├── owns local, non-rendered Guide Shape
                                 │
Sequence ──references───────────┴──> Glow parameter + independent Flower Asset
```

The Guide Shape belongs locally to the floor Asset and marks *where* the bloom
event occurs. The Flower remains an independent Asset. The Sequence, rather
than either Asset, owns the staged relation and references all participants by
stable IDs. Its first required tracks are a local glow value and the Flower's
visibility/uniform-scale growth; broader effects and animation abstractions
remain deferred.

### Texture element output contract

`Texture` is the high-level final-texture document. Its child Elements are
producers, not alternate parent documents. A Generator Element can produce a
valid texture output directly. An Import Element first exposes a raw source and
must pass through its processing pipeline before it contributes to the Parent's
final UV output. The parent composition must never silently treat a raw source
preview as a completed final texture.

```text
source Asset  <── Morph ──>  target Asset
```

Examples:

```text
Wizard Hat  <── Hat-to-Star Morph ──>  Star
Stone       <── Stone-to-Monster Morph ──>  Stone Monster
```

The morph owns only information specific to the transition, such as deliberate
correspondence and intermediate forms. The source and target remain separately
editable.

## Time and timelines

Time belongs to the object or operation currently being edited. A timeline is
therefore a contextual part of the workspace, not a permanent global editor
layer.

| Area | Timeline behaviour |
| --- | --- |
| Create | Not shown by default. |
| Style | Not shown by default; may be needed later for animated style values. |
| Motion | Shows an asset-local time view when editing movement; Slice 4 adds a contextual Sequence time view for a staged multi-object event. |
| Transform | Shows a transition-local time view when editing a morph. |
| Effects | Shows time controls only when an effect needs them. |
| Export | Does not own a timeline. |

The first MVP should not introduce a generic scene or universal animation model
until a tested slice requires one. Slice 4 is the first bounded use of a
Sequence and must implement only the references and tracks needed for its
floor-glow-to-flower-growth outcome.

## Transform & Snap Foundation

This is a separate milestone from the current asset and contour workflow. Its
first step establishes the canvas coordinate system before transform data or
gizmos are added. The world origin is `(0, 0)` and is defined by the
intersection of the full horizontal and vertical axes. The editor uses
X-positive-right and Y-positive-up coordinates; Godot Scene export converts
positions, contours, and rotation direction back to Godot's Y-down convention.
Component
geometry remains in local coordinates; later Transform data will map it into
the canvas coordinate space without rewriting the stored contour points.

The origin, Snap settings, Transform data, and Pivot phases are complete.
Transform data is stored per Component as position, rotation, scale, and pivot,
with visibility and z-index alongside it. The Inspector exposes these values as
numeric fields and a visibility toggle. The selected Component's local Pivot is
visible in the Canvas and can be dragged only in Edit state with the active
Snap settings while preserving the visible geometry. Phase 6 now
exposes `CMD/Ctrl + 3` with Translate, Rotate, and Scale submodes; its initial
gizmo is positioned at the Component Pivot. The `Transform` submode supports
free, X-axis, and Y-axis translation with Snap. The `Rotate` submode now uses
the Pivot-centered ring and Rotation Step. The `Scale` submode now supports
uniform corner scaling around the Pivot; non-uniform X/Y scaling is intentionally
excluded from the MVP. Phase 6.5 applies each Component transform when the
Asset itself is selected: visible components are rendered as ordered,
transformed references, hidden components are omitted, and clicking a
transformed reference selects the corresponding Component. The selected
Component remains a clear editing overlay in the Canvas.

Undo/Redo is intentionally implicit and has no visible UI controls. The editor
uses in-memory document snapshots, with `CMD/Ctrl + Z` for Undo and
`CMD/Ctrl + Shift + Z` for Redo. Continuous contour and transform drags are
coalesced into one history entry; the history is not persisted with a
Workspace.

Create/Line stores each placed point immediately on the Component. A Line may
remain open; clicking the first point after at least three points marks the
stored shape as `closed`, which enables polygon semantics without making
closure a prerequisite for persistence or Undo.

## Confirmed UI direction

The editor is organised around a canvas-first workspace:

```text
left module rail        expandable Create / Style / Motion / Transform / Effects sections
left context panel      current-context outliner
Main Toolbar            context-specific create action (`Create Asset`,
                        `Create Texture`, or `Create Material`), plus a right-aligned
                        `Workspace ▼` menu with `New`, `Save`, and `Load`
Context Bar             settings and actions for the active tool or operation
centre                  working area
right                   inspector for selected objects
bottom                  compact status/info grid
```

Export is a distinct, terminal action/area. The lower status grid is split into
three regions: 17% program status on the left, 64% contextual tool information
in the middle, and 17% reserved space on the right. It can expand inside
time-based workspaces when a local timeline needs more space. `CMD/Ctrl + S`
saves the active Workspace and emits a temporary yellow confirmation in the
left status area.

The visual language follows the compact, utilitarian editor style of the
PolyTexture reference: regular Godot controls, 1 px outer margin, 1 px
separation between major panels, a canvas-dominant centre, and no large
placeholder cards. The fixed module rail
remains on the left. The Outliner and Inspector are two independently
resizable panes implemented with nested `HSplitContainer`s.

### UI construction

The editor UI is assembled dynamically in GDScript from the current editor
state and small, data-driven module/submodule definitions. The `tscn` scene is
only a root host; the editor shell and context-sensitive controls are created
in code. This avoids a large, hand-maintained Control tree and lets the same
state drive the module rail, Main Toolbar, Context Bar, workspace, and
inspector.

The fixed shell is created once, while context-sensitive regions are rebuilt or
updated when the active state changes. The MVP needs only the simplest form of
this pattern; it does not need a general UI framework.

Module navigation is implemented by the reusable `ModuleSection` component.
Sections form an accordion: opening one category closes the others. The active
module is highlighted with a yellow background and black text, including its
hover state.

The current first data flow is `Create Asset` or category-aware `Create Material`:
a name dialog creates an in-memory document with a stable internal ID, the
document appears in the Outliner,
and its display name can be edited in the Inspector. An Asset can now contain
named Components with stable IDs. Workspace persistence stores these Assets
and their completed Component contours. The current Component Canvas provides
a dynamic grid, keyboard panning with `A/S/D/W`, and zooming with `Q/E`
(`E` zooms in).

The first skeleton stays visually sparse. Outliner and Inspector have small
contextual labels; otherwise text is used only where it identifies an
interactive control or current context.

The visual baseline follows PolyPixAAA: regular Godot controls and their
native hover/focus/pressed states. The active-module highlight is the current
intentional exception because it communicates the working context.

### Outliner

The Outliner does not use Godot's `Tree` control. It is a scrollable list of
data-driven Asset containers. Each Asset uses a vertical container with a
header row: a visibility checkbox, the name button, and a compact `Add` button
that creates a Component. Component rows appear below it with an indentation
placeholder and their own visibility checkbox. Module navigation
lives in the left rail, so category modules do not appear in the Outliner.

An Asset name button is a parent button. Its visibility checkbox overrides the
effective visibility of its immediate Component rows without changing their
stored visibility values. Re-enabling the Asset restores each child's own
visibility state. The same parent/child rule applies to Texture Elements.

Tool settings and object properties have separate homes:

- The Context Bar configures the active tool or a temporary operation.
- The inspector edits persistent properties of the selected object.
- A direct action executes once; it must not create an unnecessary persistent
  editor state.

## Data and persistence

The editor works on one active Workspace. A Workspace is the unit that is
created, saved, and loaded; Assets are contents of a Workspace and are not
loaded or saved independently through the top-level menu.

```text
workspaces/<workspace_name>/
├── workspace.json
├── assets/<asset_id>/asset.json
├── textures/<texture_id>/texture.json
├── materials/<material_id>/material.json
├── paths/<path_id>/path.json
├── acts/<act_id>/act.json
├── geometry/<asset_id>/<component_id>/geometry.json
└── sequences/<sequence_id>/sequence.json
```

Every JSON document contains a numeric `schema_version`. The current MVP
schema is version `20`. Workspace metadata references Asset, Texture, Material,
Path, Act, and Sequence IDs. Each Asset document stores its Components, canonical Bézier
Points/Edges/Chains, optional Material IDs, and one normalized Animation
document; each Texture document stores its dimensions, origin convention,
Elements, and an optional `final_output_element_id`. Each Material is an
independent Workspace resource with a Texture reference, tint, and opacity.
Path, Act, and Sequence are also independent Workspace resources; Sequence owns
references but never embeds an Asset Animation or Path document.
Display names remain editable and are not used as persistent references.

The Material editing context opens directly as one Graph workspace containing
a fixed `Texture Source → Material Output` GraphEdit skeleton and a small
integrated neutral Preview panel. There is no Material View switcher or
in-editor LookDev mode. The Preview shows the selected ready Texture with
Material tint, opacity, scale, and offset. The active Material remains selected
in the Outliner and is shown in the right status-bar region. Material mapping
will later become a graph concern; exporting real Godot artifacts is the
authoritative end-look validation path. Material assignment is performed in
the normal Asset Component Inspector and is stored as the Component's optional
`material_id`; the selected Component canvas uses that assignment directly.

Export is a build workflow rather than a creative canvas. The first build
workspace uses its own UI logic: a flat Source Asset Outliner without Create
hierarchies, a dedicated Build surface presenting `Source Asset → Validate →
Godot Scene`, a Build Inspector, and only Validate/Build actions in the
Context Bar. Validation requires closed, triangulable contours and valid ready
Material Texture references before Build is enabled.

The first build writes a minimal Godot 4 `.tscn` scene below `res://exports/`
for the selected Asset. It uses Godot's `Node2D`, `Polygon2D`, `PackedScene`,
and `ResourceSaver` APIs instead of manually composing `.tscn` text.
Components carry their contour, transform, visibility, z-index, and ready
Material Texture references. The initial export derives explicit UVs from each
Component's local bounding box, preventing Godot from treating contour
coordinates as texture coordinates. Mapping Scale uses one shared semantic:
larger values make the texture appear larger in the Preview, editor canvas,
and exported scene. The initial Wrap Modes are `Fit` (one normalized texture),
`Clamp` (edge pixels outside the texture), and `Repeat` (tiled texture).
Mesh resources, advanced UV mapping, and
reusable external material resources follow later.

An imported raster source is selected from the project-local
`imports/textures/` intake folder, copied into its Texture directory, and
referenced by its typed `import` Element with a relative source filename plus
its original display name. Re-importing retains prior copied sources so
Undo/Redo can safely restore an earlier Texture source reference without
depending on the intake file. Older Texture JSONs with a Texture-level
`import_source` field are migrated when loaded. New Elements carry an explicit
output state, initially `not_ready`; Phase 6's White-to-Alpha processing may
produce a `ready` output file, and only `ready` output files can contribute to
the Texture parent. The selected final output is persisted and restored with
the Texture document.

Workspace JSON also contains an `editor_state` object for the restorable editor
view: selected Asset, Component, Texture, or Element and the expanded/collapsed
state of Asset and Texture containers. On load, these IDs are validated against
the loaded data; invalid selections fall back to an empty selection.

`configs/app_config.json` is separate from Workspace content and stores the
name of the last loaded or saved Workspace. On startup, the application tries
to restore that Workspace and otherwise starts empty.

The MVP uses an in-app New dialog and an in-app Load list; it does not depend on
the operating system's file picker. Save overwrites the active Workspace.

## Architecture constraints for the MVP

### Derived Geometry pipeline

Geometry is a user-facing configuration and preview category over shared
derived services. It does not grant ownership of authored form to a mesh. The
authored Component contour remains authoritative; samplers, triangulators, and
UV mappers derive their results without reverse synchronization. Invalid
contours must fail visibly and safely rather than crashing or silently
replacing authored data.

Sampling recipes and accepted bakes are stored as Component-scoped Geometry
records keyed by stable Asset and Component IDs. A source fingerprint marks a
bake stale after canonical topology changes. Seeding recipes and accepted
bakes live in the same Component-scoped record. A Seeding Bake depends on one
stable current Sampling Bake ID and sampled-boundary fingerprint; it becomes
stale without reverse synchronization when that upstream dependency changes.
Manual Seed edits remain derived overrides and never replace the standard
contour or Sampling workflow.

- UI prototypes may use only the smallest dummy data needed to exercise a
  specific interaction. Prefer empty panes over invented asset content.
- Real functionality must be developed as vertical, user-testable slices.
- Avoid building a general node graph, plugin system, or universal rigging
  system before a slice requires one.
- Use stable references/IDs once real cross-object references are introduced;
  display names must be safe to change.
- Procedural results should be repeatable for the same input and seed once the
  procedural root slice begins.

## Explicitly open decisions

The following topics are intentionally not decided yet:

- Exact submodule names and which ones are visible in the first prototype
- Whether a future multi-asset playback container extends the first Sequence
  model or needs a distinct concept
- How animation clips are represented and stored
- How later Motion clips, Effects, and multiple Sequences share or separate
  their time data
- Export formats and packing behaviour
- Rigging depth required by the Stone-to-Monster slice

Any decision that changes one of these boundaries should be discussed, then
recorded here before it becomes a broad implementation assumption.
