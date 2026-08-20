# PolyTools Agent Guide

Read `docs/AI_CONTEXT.md`, `docs/ARCHITECTURE.md`, and
`docs/BEZIER_MODEL.md` before changing editor geometry.

## Geometry ownership

- Component geometry is stored only as `points`, `edges`, and `chains`.
- `BezierTopology` owns structural operations and topology validation.
- `BezierGeometry` owns cubic Bézier mathematics and handle resolution.
- `ComponentCanvas` renders immutable view copies and emits user intent. It
  must not mutate World document topology.
- Polygon arrays used by fill, hit testing, or the current export are derived
  on demand and are never stored in a Component.

Do not reintroduce `outer_shape`, Component-level `closed`, the old Line tool,
or reverse synchronization from a display polygon into Bézier topology.

## Verification

Run both commands after geometry changes:

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --editor --quit
```

Also run `git diff --check`. Files below `worlds/` are user data and must
not be rewritten as test fixtures.
