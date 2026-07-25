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
left module rail        Create / Style / Motion / Transform / Effects
left context panel      submodule buttons and current-context outliner
top toolbar             tools and direct actions
context/action bar      settings for the active tool or operation
centre                  working area
right                   inspector for selected objects
bottom                  compact status/info grid
```

Export is a distinct, terminal action/area. The lower status grid can expand
inside time-based workspaces when a local timeline needs more space.

### UI construction

The editor UI is assembled dynamically in GDScript from the current editor
state and small, data-driven module/submodule definitions. This avoids a large,
hand-maintained Control tree and lets the same state drive the module rail,
toolbar, context/action bar, workspace, and inspector.

The fixed shell may be created once, while context-sensitive regions are
rebuilt or updated when the active state changes. The MVP needs only the
simplest form of this pattern; it does not need a general UI framework.

The first skeleton intentionally avoids standalone labels, headings,
descriptions, and status text. Text is used only on interactive buttons where
it identifies a possible action or an Outliner entry.

### Outliner

The Outliner does not use Godot's `Tree` control. It is a scrollable,
edge-to-edge vertical list of narrow button rows created from the current
context. The active module's submodule buttons appear at the top of this same
list; there is no separate submodule panel.

An entry with children is a parent button. Clicking it toggles the visibility
of its immediate child rows. No icon, glyph, indentation placeholder, margin,
or padding is added to communicate this in the initial skeleton. The
parent-button click is intentionally reserved for this toggle.

Tool settings and object properties have separate homes:

- The context/action bar configures the active tool or a temporary operation.
- The inspector edits persistent properties of the selected object.
- A direct action executes once; it must not create an unnecessary persistent
  editor state.

## Architecture constraints for the MVP

- UI prototypes may use dummy data and are allowed to be disposable.
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
