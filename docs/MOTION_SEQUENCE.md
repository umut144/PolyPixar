# PolyTools – Motion Sequence

**Status:** Phase 12 single-Entry Composition and combined Sequence Player.

## Observable result

A Sequence Entry references the Wizard Asset, one of its Animation States, and
an independent Path. The Player moves the Wizard along that Path while applying
the selected State's Outer Bob at the same time.

## Two workspace views

`CMD/Ctrl + 1` opens `Composition`. Its horizontal card shows the Entry name
and resolved Asset, State, and Path. It is a composition board, not a timeline.
Selecting the card drives the Entry Inspector. The MVP permits one Entry.

`CMD/Ctrl + 2` opens `Player`. The centre becomes a large read-only preview
with the complete Path and moving Asset. The Inspector becomes a read-only
resolved-reference and runtime report. Missing references remain visible as
blocking messages instead of being silently replaced.

The active view and `Preview Loop` are Workspace editor state. They are not
Sequence runtime data. Shortcuts are ignored while editing text.

## Entry contract

An Entry persists only:

```text
id, name, enabled, asset_id, animation_state_id, path_id
```

All relationships use stable IDs. Renaming Asset, State, or Path cannot break
the Sequence. A State must belong to the referenced Asset, and a Path must have
positive sampled length. Referenced resources are never embedded or mutated.

## Evaluation

Path Duration defines the Player's total preview duration. At elapsed time
`t`:

```text
path_phase      = t / path_duration
animation_phase = fract(t / state_cycle_duration)
```

`MotionSequenceEvaluator` returns the Path pose and the State's temporary
per-Component Outer samples. The Player composes them in this order:

```text
Sequence × Path × Animation × Component × Geometry
```

Consequently Bob remains asset-local and rotates with the Asset when the Path
uses `Orient Along Path`. Transition Rules, State switching, Markers, and Inner
deformation are not evaluated in this MVP.

## Stable framing

The Player fits its camera from the complete rest Path plus the resting Asset
extent. Runtime Path movement and Bob do not trigger refitting. This keeps the
full journey visible and prevents camera motion from cancelling the animation.

## Deferred

- Multiple simultaneous Entries
- Entry start offsets and duration overrides
- Sequence-authored orientation or placement overrides
- Transition evaluation and Marker dispatch
- Timeline tracks and keyframes
- Inner mesh deformation
