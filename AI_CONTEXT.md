# AssetFlow2D – AI Context

**Read this file before making changes.** For stable product decisions, see
[`ARCHITECTURE.md`](ARCHITECTURE.md). For the current result-based work items,
see [`MVP_CHECKLIST.md`](MVP_CHECKLIST.md).

## Product in one sentence

AssetFlow2D is a canvas-first 2D asset creation tool built through small,
testable vertical slices rather than a complete feature set up front.

## Current phase

The repository has just been initialised. The immediate goal is a **minimal UI
skeleton** so that the interaction model can be reviewed before real asset
functionality is built. Empty panes are preferred to invented asset content.

The current implementation target is not a functional morphing engine.

## Technology baseline

- Engine: **Godot 4.7.1**
- Project layout: `project.godot`, `scenes/main.tscn`, and `scripts/main.gd`
- Editor workspace and default window: 1920×1080 (Full HD); current preview uses
  preserved aspect ratio (`keep`) for temporary letterbox evaluation

## Confirmed vocabulary

- **Asset:** An independently editable visual object.
- **Morph:** A separately designed transition between a source and a target
  asset.
- **Create / Style / Motion / Transform / Effects:** Visible creative areas.
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
- Do not add Bézier editing, maps, full materials, a node graph, generic
  rigging, or export pipelines until a confirmed checklist item requires them.
- Treat dummy UI data as dummy UI data. Do not let it quietly become a rigid
  domain model.
- When a product or UX decision is unclear, ask before deciding it in code.

## UI skeleton target

The skeleton should demonstrate the following navigation state changes without
invented asset content:

```text
module rail sections → submodule selection → toolbar/context bar → workspace state
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

Use PolyPixAAA as the visual reference: standard Godot control styling, 12px
outer margin, 8px layout separation, and resizable split panes. Do not add
custom button font/hover colours in the initial skeleton.

The Outliner is `ScrollContainer` + an edge-to-edge vertical list of direct
button rows, not Godot's `Tree` control. Module navigation is handled by
reusable expandable sections in the left module rail; submodules do not appear
in the Outliner. The rail behaves as an accordion: at most one category is
expanded at a time. The active submodule uses a yellow background with black
text, including its hover state. There are no hierarchy icons or indentation
placeholders.

Only Create is active in the current shell. Style, Motion, Transform, Effects,
and Export are inert buttons until their own work begins.

## Documentation maintenance

- Update `ARCHITECTURE.md` when a stable product boundary is decided.
- Update `MVP_CHECKLIST.md` when a result is accepted, changed, or split.
- Keep this file short and current; it is operational context, not history.
- Mark unresolved questions as open instead of silently resolving them.

## Current open questions

- Which exact submodules should appear in the first UI prototype?
- Should Export appear as a lower rail item, a top-level action, or both?
- How much of the lower status grid should be interactive in the prototype?
