# AssetFlow2D – Architecture

**Status:** Draft 0.1  
**Purpose:** Records the product decisions that are currently confirmed. It is
not a promise of every future feature and not an implementation blueprint.

## Product intent

AssetFlow2D is a creative 2D asset tool. It should make the creation of
stylised game assets feel direct and playful while keeping the underlying
workflows precise enough for production use.

Development follows small, result-based vertical slices. A feature is added
only when the next demonstrable result requires it.

## Technology baseline

The MVP is built with **Godot 4.7.1**. The UI skeleton uses a minimal Godot
layout: `project.godot`, one root scene, and a dynamic GDScript UI entry point.
Persistence format remains open.

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

## Confirmed domain relationship

An asset is independently editable. A morph is a deliberately designed
relationship between two assets; it is not a permanent property or a form
state of either asset.

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
| Motion | Shows an asset-local time view when editing movement. |
| Transform | Shows a transition-local time view when editing a morph. |
| Effects | Shows time controls only when an effect needs them. |
| Export | Does not own a timeline. |

The first MVP should not introduce a generic scene or sequence model unless a
tested slice actually requires one.

## Confirmed UI direction

The editor is organised around a canvas-first workspace:

```text
left module rail        expandable Create / Style / Motion / Transform / Effects sections
left context panel      current-context outliner
Main Toolbar            global tools and direct actions; currently `New ▼` with
                        `Asset` and `Texture` menu entries
Context Bar             settings and actions for the active tool or operation
centre                  working area
right                   inspector for selected objects
bottom                  compact status/info grid
```

Export is a distinct, terminal action/area. The lower status grid can expand
inside time-based workspaces when a local timeline needs more space.

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

The first skeleton stays visually sparse. Outliner and Inspector have small
contextual labels; otherwise text is used only where it identifies an
interactive control or current context.

The visual baseline follows PolyPixAAA: regular Godot controls and their
native hover/focus/pressed states. The active-module highlight is the current
intentional exception because it communicates the working context.

### Outliner

The Outliner does not use Godot's `Tree` control. It is a scrollable,
edge-to-edge vertical list of narrow button rows created from the current
context. Module navigation lives in the left rail, so submodule buttons do not
appear in the Outliner.

An entry with children is a parent button. Clicking it toggles the visibility
of its immediate child rows. No icon, glyph, indentation placeholder, margin,
or padding is added to communicate this in the initial skeleton. The
parent-button click is intentionally reserved for this toggle.

Tool settings and object properties have separate homes:

- The Context Bar configures the active tool or a temporary operation.
- The inspector edits persistent properties of the selected object.
- A direct action executes once; it must not create an unnecessary persistent
  editor state.

## Architecture constraints for the MVP

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

- Persistence format
- Exact submodule names and which ones are visible in the first prototype
- Whether a future multi-asset playback container is called Scene, Sequence,
  Stage, or is needed at all
- How animation clips are represented and stored
- Where a time-based effect stores its keyframes in later slices
- Undo/redo scope for the first functional slice
- Export formats and packing behaviour
- Rigging depth required by the Stone-to-Monster slice

Any decision that changes one of these boundaries should be discussed, then
recorded here before it becomes a broad implementation assumption.
