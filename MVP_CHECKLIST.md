# AssetFlow2D – MVP Checklist

**Status:** Initial result-based plan.  
**Rule:** A box is checked only after the result can be demonstrated in the
editor. Writing code alone is not completion.

## Definition of done

A result is done when it is:

- visible and usable through the editor UI;
- manually verified against its stated outcome;
- saved and restored when persistence is part of that result;
- documented if it changes an architectural boundary.

## Milestone 0 – UI skeleton and UX review

Goal: test the navigation and workspace model with dummy content before
implementing real creation tools.

- [ ] Create the minimal Godot application/project structure.
- [ ] Create the UI shell dynamically from code and dummy state definitions;
      do not depend on a hand-authored module-specific Control tree.
- [ ] Show a narrow left module rail with Create, Style, Motion, Transform,
      Effects, and Export.
- [ ] Selecting a module puts its dummy submodule buttons at the top of the
      current Outliner without adding a second global module menu.
- [ ] Show a scrollable current-context Outliner in the left workspace panel
      using narrow button rows rather than Godot's `Tree` control.
- [ ] Keep every Outliner row as one direct, left-aligned button without
      margins, padding, indentation placeholders, or expand/collapse icons.
- [ ] Make a dummy parent row toggle visibility of its immediate child rows and
      show an expanded/collapsed state.
- [ ] Show a top toolbar whose dummy tools change with the selected submodule.
- [ ] Show a context/action bar whose dummy contents change with the active
      tool or operation.
- [ ] Show a central working area with recognisably different placeholder
      states for Create, Motion, Transform, and Effects.
- [ ] Show a scrollable Inspector on the right with placeholder properties for
      the current selection.
- [ ] Show a compact bottom status grid with document, contextual information,
      and coordinate/viewport placeholders.
- [ ] Motion and Transform demonstrate an expandable dummy time area; Create
      and Style do not show one by default.
- [ ] Review the skeleton UX before implementing real asset editing.

## Slice 1 – Wizard Hat to Star

Goal: demonstrate independent assets connected by a designed transition.

- [ ] Create two independent assets: Wizard Hat and Star.
- [ ] Edit a simple closed polyline contour for each asset.
- [ ] Give the Wizard Hat a local Sway motion.
- [ ] Give the Star a local Jitter motion.
- [ ] Create a separate Hat-to-Star Morph referencing both assets.
- [ ] Deliberately edit the basic correspondence and timing of that morph.
- [ ] Add manually placed Star-tip anchors.
- [ ] Add a trail effect that follows the selected Star-tip anchors.
- [ ] Preview the intended progression: Hat/Sway → Morph → Star/Jitter with
      trails.

## Slice 2 – Procedural Root Growth

Goal: demonstrate a deterministic, time-based procedural effect.

- [ ] Add a Root Growth effect with a selectable origin and maximum radius.
- [ ] Generate a simple branching result from an explicit seed.
- [ ] Expose a Growth Progress value from 0% to 100%.
- [ ] Animate or otherwise time-control Growth Progress in the relevant
      workspace.
- [ ] Verify that the same parameters and seed reproduce the same result.

## Slice 3 – Stone to Monster

Goal: demonstrate a deliberately designed transition between assets with
different visible structure.

- [ ] Create independent Stone and Stone Monster assets.
- [ ] Create a separate Stone-to-Monster Morph.
- [ ] Map at least one source shape to a target shape deliberately.
- [ ] Support at least one target part that has no direct source counterpart.
- [ ] Design at least one intermediate transition state.
- [ ] Give the Monster a local post-transition motion.
- [ ] Preview the complete transition and post-transition motion.

## Explicitly deferred

These may become valuable later, but they are not implementation targets until
a verified slice requires them.

- Bézier curve editing
- Full material, map, and texture authoring
- General-purpose rigging
- Universal particle or node-graph systems
- Generic scene/sequence data model
- Production export formats, atlases, and spritesheets
- Advanced undo/redo and project version migration
