# AssetFlow2D – AI Context

**Read this file before making changes.** For stable product decisions, see
[`ARCHITECTURE.md`](ARCHITECTURE.md). For the current result-based work items,
see [`MVP_CHECKLIST.md`](MVP_CHECKLIST.md).

## Product in one sentence

AssetFlow2D is a canvas-first 2D asset creation tool built through small,
testable vertical slices rather than a complete feature set up front.

## Current phase

The repository has just been initialised. The immediate goal is a **UI
skeleton with dummy data** so that the interaction model can be reviewed before
real asset functionality is built.

The current implementation target is not a functional morphing engine.

## Technology baseline

- Engine: **Godot 4.7.1**
- Project layout: `project.godot`, `scenes/main.tscn`, and `scripts/main.gd`

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

The skeleton should demonstrate the following state changes with placeholder
content:

```text
module rail → expanded submodules → toolbar/context bar → workspace state
```

It includes a scrollable Outliner, a scrollable Inspector, a central workspace,
and a compact bottom status grid. Motion and Transform may display a dummy
local timeline; Create and Style do not display one by default.

The UI is dynamically assembled in GDScript from editor state and small
definition lists. Do not build a large, manually maintained Control hierarchy
for the module-specific UI.

The Outliner is `ScrollContainer` + vertical button rows, not Godot's `Tree`
control. Hierarchy is represented initially by non-interactive indentation
placeholders to the left of child buttons. A parent button toggles visibility
of its immediate child rows; its first-skeleton click behaviour is therefore
expand/collapse rather than selection.

## Documentation maintenance

- Update `ARCHITECTURE.md` when a stable product boundary is decided.
- Update `MVP_CHECKLIST.md` when a result is accepted, changed, or split.
- Keep this file short and current; it is operational context, not history.
- Mark unresolved questions as open instead of silently resolving them.

## Current open questions

- Which exact submodules should appear in the first UI prototype?
- Should Export appear as a lower rail item, a top-level action, or both?
- How much of the lower status grid should be interactive in the prototype?
