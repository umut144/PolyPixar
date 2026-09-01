# PolyTools Agent Guide

Read `docs/AI_CONTEXT.md`, `docs/ARCHITECTURE.md`, and
`docs/BEZIER_MODEL.md` before changing editor geometry.

## Geometry ownership

- Component geometry is stored only as `points`, `edges`, and `chains`.
- `BezierTopology` owns structural operations and topology validation.
- `BezierGeometry` owns cubic Bézier mathematics and handle resolution.
- `ComponentCanvas` renders immutable view copies and emits user intent. It
  must not mutate World document topology.
- `OutlinerView` renders Outliner rows and emits intent. Do not give it editor
  state or let it change a document; push context in and handle its signals.
- `WorldDocumentService` owns the persisted document format and is static.
  Do not give it editor state; persistence that needs state stays in `main.gd`.
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
not be rewritten as test fixtures. Two things below `worlds/` are the
exception because they are generated rather than authored: `catalog.json` and
`PolyToolsRuntimeExports/` are produced by `Export Runtime`, are read by the
consumers from the working directory through `POLYTOOLS_WORLD_DIR`, and are not
tracked. A fresh clone needs one `Export Runtime` before the first Consumer
Sync.

Setting `SpinBox.value` in a test does not emit `value_changed` — only real
input does — so an Inspector edit is simulated by setting the value and
emitting the signal. `_edit_inspector_value` in the suite does both.

A `SCRIPT ERROR` in the test output is a failure even when the runner prints
`All PolyTools tests passed`: a runtime error aborts that test function, so its
remaining assertions never run and never increment the failure count. CI fails
the job on any such line.

`tools/inspector_render_probe.gd` renders the Inspector in 33 fixed states and
prints one line per control. Run it before and after any change that is meant to
leave the Inspector looking the same, and diff the two outputs; the file's own
header has the commands. It has caught three real regressions that the suite did
not. When a render function is added, add the state that reaches it — the header
lists what each state is for.

A view extracted from `main.gd` needs both halves checked, and the render probe
is only one of them. It proves the same controls are still drawn; it says
nothing about where a control leads. `_test_motion_inspector_wiring` is the
pattern for the other half: one table of signal-to-handler pairs checked against
`get_signal_connection_list`, and one walk that drives every control the view
builds across every state and asserts each signal is reachable and arrives with
its declared argument types. Both halves are needed — a control wired to the
wrong signal passes the routing table, and a signal wired to the wrong handler
passes the emission walk.

The `--editor --quit` run is not a full parse check: it reported clean on a
script with undeclared identifiers that the test run caught immediately. Treat
the test run, not the editor run, as the parser of record.

The same holds when `scripts/main.gd` fails to parse: every test that does
`load("res://scripts/main.gd").new()` then skips its assertions and the runner
still reports a pass. An unused local is a parse error here — warnings are
treated as errors — so check the `SCRIPT ERROR` count on *every* run, including
the deliberately broken one in a mutation test.

## Commits

After every change, create a Git commit automatically with a concise,
appropriate commit message describing the change. Do not push commits; the
user handles pushing separately. Before committing, review the staged diff
and ensure that only the intended changes are included.
