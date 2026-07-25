# AssetFlow2D – MVP Checklist

**Status:** UI skeleton reviewed; first functional slice pending.
**Rule:** A box is checked only after the result can be demonstrated in the
editor. Writing code alone is not completion.

## Definition of done

A result is done when it is:

- visible and usable through the editor UI;
- manually verified against its stated outcome;
- saved and restored when persistence is part of that result;
- documented if it changes an architectural boundary.

## Milestone 0 – UI skeleton and UX review

Goal: test the navigation and workspace model without invented asset content
before implementing real creation tools.

- [x] Create the minimal Godot application/project structure.
- [x] Create the UI shell dynamically from code and small state definitions;
      do not depend on a hand-authored module-specific Control tree.
- [x] Show a narrow left module rail with Create, Style, Motion, Transform,
      Effects, and Export.
- [x] Keep Create as the only populated category; all other category sections
      are intentionally empty until their slice begins.
- [x] Use expandable module sections in the left rail so modules stay with
      their parent module instead of appearing in the Outliner.
- [x] Allow only one expanded category section at a time and highlight the
      active module with a yellow background and black text.
- [x] Show a scrollable current-context Outliner in the left workspace panel
      using narrow button rows rather than Godot's `Tree` control.
- [x] Keep every Outliner row as one direct, left-aligned button without
      margins, padding, indentation placeholders, or expand/collapse icons.
- [x] Keep category navigation behaviour in a reusable `ModuleSection`
      component; reserve the Outliner for real content hierarchy.
- [x] Show empty structural Main Toolbar and Context Bar areas ready for real
      controls.
- [x] Add a `New` menu to the Main Toolbar with `Asset` and `Texture` entries;
      keep `Texture` inert until its phase begins.
- [x] Implement `New → Asset` with a name dialog, OK/Cancel controls, Enter
      confirmation, and Escape cancellation.
- [x] List created Assets in the Outliner and select them there.
- [x] Show the selected Asset's name in the Inspector and allow renaming.
- [x] Show an empty, canvas-first working area without fake asset previews.
- [x] Show an empty, scrollable Inspector on the right.
- [x] Let users resize the Outliner and Inspector independently with split
      handles while keeping the module rail fixed.
- [x] Show a compact, empty bottom status strip.
- [x] Use a 1920×1200 (16:10) letterboxed reference workspace and a custom
      AssetFlow2D project icon.
- [ ] Add a contextual time area only with the first real time-based feature.
- [ ] Review the skeleton UX before implementing real asset editing.
- [ ] Create an Asset, add a Component, select `Draw → Line`, and create a
      closed Polyline contour recognized as an outer shape.

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
