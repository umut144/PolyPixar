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

Example: the first editable shapes use closed polylines. Bézier curves are not
part of that step because no accepted MVP outcome requires them yet.

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
`Create` is a category and `Shapes` / `Layers` are its current modules.

An Asset is a container for independently editable Components. Drawing is
performed on a selected Component, never directly on the Asset container. The
first `Create → Shapes` drawing tool is named `Line`; despite the name, it is a
Polyline tool that stores each ordered point immediately. `Enter` confirms an
open line, while clicking the first point after at least three points marks it
as a closed contour for outer-shape semantics. Bézier editing and other contour
types are deferred.

The next validated use of the currently empty categories is the **Stone Floor
Bloom** slice. It introduces one deliberately narrow module in each of two
areas:

- `Style → Material` binds a Workspace Texture to a Component and exposes only
  the mapping and appearance values required by that slice.
- `Motion → Sequence` stages time-based relationships between independently
  editable Assets, a local Guide Shape, and Material parameters.

These names are confirmed for the slice, not a commitment to a universal
material system or general animation graph.

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

The Outliner presents Assets and Textures in separate groups. Both groups are
alphabetically ordered and share a compact search field plus `All`, `Assets`,
and `Textures` filters. Expanded Assets display `Components` and, when Guide
data exists, a separate `Guides` group. Expanded Textures display separate
`Import Elements` and `Generator Elements` groups. These are navigation groups
over one typed child collection, not separate persistence models.

`New → Texture` creates a named Texture with the default 512×512 canvas. Each
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
intersection of the full horizontal and vertical axes. Component
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
Main Toolbar            global tools and direct actions; currently `New ▼` with
                        `Asset` and `Texture` entries, plus a right-aligned
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

The current first data flow is `New → Asset` or category-aware `New → Material`:
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
header row: the name button expands/selects the Asset and a compact `Add`
button creates a Component. Component rows appear below it with an empty left
placeholder to make the parent/child relationship visible. Module navigation
lives in the left rail, so category modules do not appear in the Outliner.

An Asset name button is a parent button. Clicking it selects the Asset and
toggles the visibility of its immediate Component rows. The empty placeholder
is the only intentional indentation aid; no tree icon or glyph is used.

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
└── textures/<texture_id>/texture.json
```

Every JSON document contains a numeric `schema_version`. The current MVP
schema is version `8`. Workspace metadata references Asset, Texture, and
Material IDs. Each Asset document stores its Components, their contour
points, and optional Material IDs; each Texture document stores its dimensions, origin convention,
Elements, and an optional `final_output_element_id`. Each Material is an
independent Workspace resource with a Texture reference, tint, and opacity.
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
Material Texture references. Mesh resources, advanced UV mapping, and reusable
external material resources follow later.

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

### Internal meshing and future Advanced tooling

Meshing is shared implementation infrastructure, not a creative category. The
authored Component contour remains authoritative; an internal triangulator and
UV mapper derive a render mesh whenever the contour, transform, morph, or
mapping changes. Invalid contours must fail visibly and safely rather than
crashing or silently replacing the authored data.

A future optional `Advanced` area may expose mesh diagnostics, triangle and
vertex inspection, manual mesh overrides, and manually authored triangulation
or UV guides. These are overrides and debugging aids; they do not replace the
standard contour workflow and are outside the MVP.

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
