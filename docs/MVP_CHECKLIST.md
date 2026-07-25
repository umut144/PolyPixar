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
- [x] Keep Asset headers as compact rows with a left-aligned name and a right
      `Add` button; show Component children with an empty indentation
      placeholder and no tree icons.
- [x] Keep category navigation behaviour in a reusable `ModuleSection`
      component; reserve the Outliner for real content hierarchy.
- [x] Show empty structural Main Toolbar and Context Bar areas ready for real
      controls.
- [x] Add a `New` menu to the Main Toolbar with `Asset` and `Texture` entries;
      keep `Texture` inert until its phase begins.
- [x] Implement `New → Asset` with a name dialog, OK/Cancel controls, Enter
      confirmation, and Escape cancellation.
- [x] Use `asset01`, `asset02`, and so on when an Asset name is confirmed
      empty.
- [x] List created Assets in the Outliner and select them there.
- [x] Show the selected Asset's name in the Inspector and allow renaming.
- [x] Show `Add Component` below an Asset and create named Components.
- [x] Use `component01`, `component02`, and so on when a Component name is
      confirmed empty.
- [x] Select Components in the Outliner and edit their `Name` in the Inspector.
- [x] Reflect the selected Asset or Component as the active central workspace
      context without adding editable canvas content yet.
- [x] Provide a PolyPixAAA-style Shapes canvas with a dynamic grid.
- [x] Pan the canvas with `A/S/D/W` after clicking it to focus.
- [x] Zoom the canvas with `Q/E`, with `E` zooming in.
- [x] Show `Draw ▼` with a `Line` entry in the Context Bar for selected
      Components; record the selected tool without drawing yet.
- [x] Place snapped Polyline draft points with `Line` and show the next-edge
      preview toward the cursor.
- [x] Show a snapped preview point while hovering the Canvas in `Line` mode,
      even before the first point is placed.
- [x] Remove the last draft point with `Backspace` and clear the draft with
      `Escape`.
- [x] Close a draft by clicking near its first point once it has at least three
      points, then store and display it as the Component's `Outer Shape`.
- [x] Show Draw and Edit states in the Context Bar with `⌘1`/`⌘2` (Ctrl on
      non-macOS) shortcuts and dynamic subcommand hints in the Info Bar.
- [x] Select Draw/Edit subcommands with unmodified `1`, `2`, and `3` keys.
- [x] In Edit `Add` mode, highlight the nearest contour position and insert a
      point there with `Space`.
- [x] Select an outer-shape point in Edit and display draggable X/Y move gizmo
      handles.
- [x] Move selected points with the gizmo and persist the changed contour.
- [x] Move selected points freely in both axes with the central gizmo handle.
- [x] Delete the selected point with `Backspace` while preserving a minimum
      three-point contour.
- [x] Delete the selected point with `Delete` in Select mode.
- [x] Show an empty, canvas-first working area without fake asset previews.
- [x] Show all completed component contours in the selected Asset canvas.
- [x] Select a Component by clicking its contour in the Asset canvas and keep
      other components as transparent references.
- [x] Highlight selected Outliner entries yellow with black text.
- [x] Require a second click on the selected Asset to toggle its component list.
- [x] Provide an in-app Workspace menu with New, Save, and Load.
- [x] Serialize workspaces and their Assets/Components as versioned JSON files.
- [x] Include `schema_version` in Workspace, Asset, and app-config JSON files.
- [x] Store and automatically restore the last workspace through app config.
- [x] Split the bottom status bar into 17% / 64% / 17% regions.
- [x] Save the active Workspace with `CMD/Ctrl + S` and show a temporary yellow
      confirmation in the program-status region.
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
