# AssetFlow2D – MVP Checklist

**Status:** Asset, Component, Transform, Workspace, and UV-Texture foundations
are functional. The next implementation target is Slice 4: Stone Floor Bloom.
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
      Texture initially remained inert until its own phase began.
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
- [x] Delete the selected Component with `Backspace` when no editing state is
      active; keep point deletion available inside Edit state.
- [x] Add the initial Texture document model with independent `elements`,
      canvas dimensions, versioned serialization, and workspace loading.
- [x] Add separate Assets and Textures Outliner groups with alphabetical
      ordering, search filtering, and an All/Assets/Textures filter.
- [x] Create Textures through `New → Texture`, add named Elements with
      fallback names, select them in the Outliner, and persist their names.
- [x] Keep the initial Texture Context Bar limited to the UV `Origin` menu;
      drawing and generation are intentionally deferred.
- [x] Filter Outliner searches by Asset/Texture names and their
      Component/Element child names, expanding matching parents.
- [x] Add the initial UV Texture Canvas with `Bottom Left`, `Top Left`, and
      `Center` Origin modes and persist the selected mode per Texture.
- [x] Keep UV Origin presentation subtle with a compact U/V-colored origin
      gizmo; pan with `A/S/D/W` and zoom with `Q/E` after focusing the Texture
      canvas.
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
- [x] Persist every placed Line point immediately and confirm an open line
      with `Enter` without requiring closure.
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
- [x] Persist and restore Outliner selection and Asset expansion state.
- [x] Add hidden snapshot-based Undo/Redo with `CMD/Ctrl + Z` and
      `CMD/Ctrl + Shift + Z`; coalesce continuous drag edits and keep the
      history in memory only.
- [x] Transform & Snap Foundation: mark the world origin and full canvas axes.
- [x] Add a persistent Snap popover with On/Off, Grid Step, and Rotation Step.
- [x] Store Component position, rotation, scale, pivot, visibility, and z-index
      in schema-versioned Workspace JSON.
- [x] Expose Component transform, visibility, and z-index fields in the
      Inspector.
- [x] Display and drag the selected Component's local Pivot with Snap support.
- [x] Add the Transform state with `CMD/Ctrl + 3` and Transform/Rotate/Scale
      submodes, displaying the initial gizmo at the Pivot.
- [x] Translate a Component from the Pivot with free, X-axis, and Y-axis
      gizmo handles using Snap.
- [x] Rotate a Component around its Pivot with the Rotate ring and Rotation
      Step snapping.
- [x] Uniformly scale a Component with Scale corner handles.
- [x] Apply Component transforms, visibility, and z-index to Asset-level
      composition and select transformed reference contours.
- [x] Show an empty, scrollable Inspector on the right.
- [x] Let users resize the Outliner and Inspector independently with split
      handles while keeping the module rail fixed.
- [x] Show a compact, empty bottom status strip.
- [x] Use a 1920×1200 (16:10) letterboxed reference workspace and a custom
      AssetFlow2D project icon.
- [ ] Add a contextual time area only with the first real time-based feature.
- [ ] Review the skeleton UX before implementing real asset editing.
- [ ] Create an Asset, add a Component, select `Draw → Line`, and draw a
      Polyline whose points persist immediately; optionally close it to mark
      the shape as an outer contour.

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

## Slice 4 – Stone Floor Bloom

Goal: demonstrate an imported, hand-drawn texture used as a material on an
independent floor Asset, then use a local Guide to stage a glow followed by a
separately authored flower growing from that place.

This slice deliberately validates the connection between `Create → Texture`,
`Style → Material`, and `Motion → Sequence`. It does not require a general VFX
system, particle system, or universal animation graph.

### A. Source assets and guide

- [ ] Create a simple Stone Floor Asset with a rectangular floor Component.
- [ ] Create an independent Flower Asset with its own editable Components.
- [ ] Add a non-rendered Guide Shape to the Stone Floor that defines the local
      bloom area; it must remain editable and persist with the floor Asset.
- [ ] Keep the Flower independent of the Stone Floor: it must not store a
      permanent dependency on the Guide or floor Asset.

### B. Create → Texture: import pipeline

- [ ] Add `Import Texture` to the Texture Context Bar; importing a raster image
      must not require creating Texture Elements.
- [ ] Preserve an imported texture as a named Workspace Texture and restore it
      when the Workspace is loaded.
- [ ] Provide a first background treatment that can isolate the dark ink from a
      light paper/background (for example, a white-to-alpha or ink-mask mode).
- [ ] Retain the derived ink/alpha information separately from the base colour
      wherever that is necessary for later material shading.
- [ ] Show a repeat/tile preview so a floor texture can be judged in context.

### C. Style → Material

- [ ] Add the first `Material` module under Style.
- [ ] Bind a Workspace Texture to the Stone Floor Component without embedding
      or copying the Texture into the Asset.
- [ ] Provide the smallest useful texture mapping controls: repeat, scale, and
      offset.
- [ ] Provide a base colour/tint and an independent ink/line strength control.
- [ ] Provide a glow colour and intensity parameter that can be targeted by the
      first Sequence.

### D. Motion → Sequence

- [ ] Add the first `Sequence` module under Motion and show its contextual time
      area only while that module is active.
- [ ] Create a Sequence that deliberately references the Stone Floor, its
      Guide Shape, and the independent Flower Asset by stable IDs.
- [ ] Animate the Guide-area glow from inactive to visible and back down.
- [ ] Animate the Flower from hidden/small to visible at the Guide location
      using its pivot and uniform scale.
- [ ] Preview the intended order: floor is normal → local guide area glows →
      flower grows from that area.
- [ ] Save and reload the Workspace; the imported Texture, Material binding,
      Guide reference, and Sequence must restore correctly.

## Explicitly deferred

These may become valuable later, but they are not implementation targets until
a verified slice requires them.

- Bézier curve editing
- Full material, map, and texture authoring beyond Slice 4's import, material,
  and tile-preview requirements
- General-purpose rigging
- Universal particle or node-graph systems
- Generic scene, multi-sequence, or universal animation-graph data model
- Production export formats, atlases, and spritesheets
- Advanced undo/redo and project version migration
