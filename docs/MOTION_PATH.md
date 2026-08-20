# PolyTools – Motion Path

**Status:** Phase 11 open Path authoring and Wizard travel preview.

## Observable result

In `Motion → Path`, the user can create a Path, place an open chain of Points,
edit its curve, and press Play to move the Wizard contours along it. The Path
is an independent World resource; the Wizard is only a preview subject.

## Geometry ownership

A Path owns exactly one open ordered topology:

```text
topology
├── points: id, position, mode, handle_in, handle_out
└── segments: id, start_point_id, end_point_id
```

`MotionPathTopology` exclusively creates stable IDs, connects adjacent Points,
deletes and reconnects Points, normalizes JSON data, and validates order.
`MotionPathWorkspace` renders immutable copies and emits user intent. It never
mutates the World document or Component `points/edges/chains`.

Phase 11 deliberately supports one open curve per Path. Closing, branching,
multiple curves, Segment insertion, marquee selection, and snapping are not in
this MVP.

## Tools

- `Draw Path` appends linear Points and the Segments between them.
- `Edit Path` selects and moves Points. Selecting a Point reveals incoming and
  outgoing handles; dragging one promotes that Point to a free manual Bézier
  Point.
- Backspace/Delete removes the selected Point and reconnects the remaining
  ordered Points.

All topology mutations participate in World Undo/Redo.

## Sampling

`MotionPathSampler` samples every cubic Segment into a small cumulative-length
table. Normalized Phase selects a distance on that table, producing:

```text
valid, position, tangent rotation, progress, length
```

This approximation gives visibly even movement across differently sized
Segments. It is deterministic and geometry-independent; adaptive production
sampling remains deferred.

## Preview

The Inspector chooses a Preview Asset, defaulting to an Asset whose name
contains `Wizard`. Its visible Component contours are copied, sampled, centred
on the evaluated Path position, and optionally rotated to the tangent. Neither
the Asset nor its Component transforms and Bézier topology are changed.

The Preview Asset ID belongs to World editor state, not `path.json`.
Persisted Path playback settings are Duration, Loop, and Orient Along Path.
The Context Bar owns Draw/Edit, Play/Pause, and the normalized Phase scrubber.

Animation is intentionally not combined in this module. Phase 12 Sequence will
compose Path travel with an Asset Animation State through stable references.
