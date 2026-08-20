# PolyTools – Motion UI Contract

**Status:** Motion is separated into Animation, Path, Act, and Sequence while
retaining State/Transition playback and visible Outer Bob sampling.

The Motion category presents its four workspaces as a clearly separated second
navigation level: Animation, Path, Act, and Sequence remain sibling buttons, with
one strong visual separator before Sequence. Animation, Path, and Act therefore
read as the Core group, while Sequence reads as the Extended group. The
separator communicates workspace ownership only; it does not change module
selection or persistence.

## Purpose

`Motion → Animation` authors asset-local, timeline-free animation through a
horizontal board of named States. The first UI slice exists to validate the
workflow before mesh generation and Guide authoring are introduced.

## Confirmed vocabulary

- **Animation:** Asset-local collection of States.
- **State:** Named playback context such as `IDLE`, `WALK`, or `RUN`. These are
  editable default names, not fixed State types.
- **Motion:** One primitive animation contribution inside a State. Multiple
  Motions combine to form the State's movement.
- **Primitive:** An asset-local Animation contribution such as Bob or Spine
  Sway. Travelling through space belongs to `Motion → Path`, not this catalog.
- **Domain:** `Outer` for Component transform deltas or `Inner` for future mesh
  deformation.
- **Transition:** Ordered directed change from its owning source State to a
  target State.
- **Marker:** Event at a normalized State phase.
- **Phase:** Normalized playback position from `0` to `1`; it is not a timeline.
- **Simulation Contract:** Persisted declaration of typed runtime parameters
  available to Transition Rules, with a future external import boundary.

## State board

The centre workspace is one horizontally scrollable board. A new Animation
begins with three editable States named `IDLE`, `WALK`, and
`RUN`. Each State presents three compact sections:

1. Motion
2. Transitions
3. Markers

Selecting a State or one of its entries drives the Inspector. The board keeps
entries compact and does not expose a keyframe track.

## Motion authoring

A Motion owns exactly one Primitive in the MVP. Motions can be added to a State,
selected, renamed, enabled/disabled, and removed. They have a
stable monotonic ID, Domain, target Component reference, Primitive kind, phase
offset, and the selected Primitive's parameters. Their list order is currently
their creation order; Motion drag-and-drop is not part of the workflow.

The first authoring catalog is deliberately bounded:

- `Outer`: Bob
- `Inner`: Spine Sway

Outer Motion can target `Entire Asset` or one Component. Inner Motion remains
Component-only. New Outer Bob Motions default to `Entire Asset`, which makes a
multi-Component Wizard preview animate immediately.

Changing Domain filters the Primitive enum and selects a compatible default.
Bob exposes distance and cycles; Spine Sway exposes strength and cycles. Inner
Motion displays its future Animation Guide dependency and remains `Not
Previewable` until mesh and Spine foundations exist.

States, Motions, Transitions, and Markers belong to the Asset's persisted
`animation` document and participate in World Save/Load and Undo/Redo.

## State authoring

An older Asset without Animation data is migrated in memory to a document with
`IDLE`, `WALK`, and `RUN`. States can be added, renamed, and removed. Names are
unique within the Asset Animation, IDs remain stable and monotonic across
Save/Load, and edits participate in the editor's Undo/Redo history.

## Transitions

Transition list order is priority: the first eligible Transition wins. The
Transition Inspector contains a target State, Exit Policy, Entry Mode, and
blend duration. Arrow buttons change priority without drag-and-drop. The
`Rules · ALL` uses conjunction semantics: every Rule must match. An empty list
is true, so Exit Policy alone controls eligibility. Rules can be added and
removed and reference Contract parameters by stable ID. Number parameters
offer numeric comparison operators and a value; Bool parameters offer `is
true` and `is false` without a value field.

Exit Policy controls when the source may be left:

- `Any Phase`
- `After Phase`
- `At Loop End`

Entry Mode controls only target phase initialization:

- `Restart`
- `Preserve Phase`

The target State does not own separate enter conditions. Runtime parameters are
declared by a Simulation Contract; normalized phase remains an internal
animation value.

## Simulation Contract

Selecting the Animation Asset exposes its Contract in the Inspector.
Parameters can be added, renamed, typed as `Number` or `Bool`, and removed when
no Rule references them. `speed` and `grounded` provide useful defaults for the
IDLE/WALK/RUN document. Changing a parameter type normalizes dependent Rules to
a compatible operator. The formal future host/import boundary is documented in
[`SIMULATION_CONTRACT.md`](SIMULATION_CONTRACT.md).

## Markers

Markers are ordered State-local event declarations with a stable monotonic ID,
an editable Event ID, a kind (`Event`, `SFX`, or `VFX`), and normalized phase.
Marker phases are rendered as ticks beneath the phase scrubber. This is an
authoring preview only: no event is dispatched and the scrubber does not yet
evaluate Motion.

## Player preview

The collapsible `Animation Preview` Inspector group contains a fitted preview
of the Asset's visible Component Bézier contours, followed by the contextual
authoring fields. It replaces the previous text-only Asset identification and
uses immutable geometry copies. The Context Bar provides Play/Pause, current
runtime State, normalized phase scrubbing, Loop, and Marker ticks. Selecting a
State while paused chooses the preview State. The Asset Inspector exposes
runtime-only Contract values for driving typed Rules. State cycle duration
controls normalized phase speed. Player semantics are documented in
[`MOTION_PLAYER.md`](MOTION_PLAYER.md).

The Preview applies enabled Outer Bob Motions visibly. Multiple Bobs add,
State transitions blend their source/target transform samples, and the fitted
camera remains based on rest geometry. Sampling details are documented in
[`MOTION_SAMPLER.md`](MOTION_SAMPLER.md).

## Motion module boundary

The Motion category is a vertical module rail with three independent contexts:

- `Animation` owns asset-local States, Motions, Transitions, and Markers.
- `Path` owns reusable World-level travel geometry and playback settings.
- `Sequence` will compose stable Asset, Animation State, and Path references.

Path and Sequence have separate Outliners, Inspectors, centre workspaces,
stable resource IDs, persistence, and Undo/Redo. Phase 11 adds the first Path
Draw/Edit workflow and Wizard travel preview. Phase 12 adds a bounded Sequence
Entry plus separate `Composition` and `Player` views. The ownership and runtime contracts are recorded in
[`MOTION_COMPOSITION.md`](MOTION_COMPOSITION.md).

Legacy Animation Motions whose primitive was `path_follow` are removed from
the Animation State during normalization and retained verbatim in
`legacy_path_follow_motions`. The Asset Inspector reports this archive. This
keeps old intent recoverable without continuing the obsolete ownership model.

## Current boundary

The current slice persists State/Motion/Transition/Marker authoring, Transition
priority, typed `ALL` Rules, and the Simulation Contract inside the Asset.
Animation mutations are included in Undo/Redo, and validation reports broken
State, Component, Contract, Rule, and Marker references. It does not add
Contract file import, external live Simulation values, multi-Entry Sequence
playback, Guide persistence, mesh generation, Inner deformation, or animation
export data. Path authoring remains intentionally limited to one open curve per Path;
see [`MOTION_PATH.md`](MOTION_PATH.md).
