# PolyTools Agent Guide

Read `docs/AI_CONTEXT.md`, `docs/ARCHITECTURE.md`, and
`docs/BEZIER_MODEL.md` before changing editor geometry.

## Geometry ownership

- Component geometry is stored only as `points`, `edges`, and `chains`.
- `BezierTopology` owns structural operations and topology validation.
- `BezierGeometry` owns cubic Bézier mathematics and handle resolution.
- `ComponentCanvas` renders immutable view copies and emits user intent. It
  must not mutate Workspace document topology.
- Polygon arrays used by fill, hit testing, or the current export are derived
  on demand and are never stored in a Component.

Do not reintroduce `outer_shape`, Component-level `closed`, the old Line tool,
or reverse synchronization from a display polygon into Bézier topology.

## Verification

Always run `git diff --check` before handoff. Files below `workspaces/` are
user data and must not be rewritten as test fixtures, staged, or committed
unless the user explicitly requests it.

For geometry, topology, undo/redo, transform, hierarchy, or export changes:

- Add or update only the smallest focused regression test when the behavior
  could plausibly regress. Do not add tests for straightforward UI wiring,
  labels, layout, or already-covered behavior.
- Run both commands:

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --editor --quit
```

For purely visual or copy/UI changes, skip the full suite and provide concise
manual test steps instead. Run the parse check only when a script changed.

## Efficient, low-data workflow

- Implement only the requested behavior; do not refactor unrelated code.
- Search with `rg` first and read only narrow relevant ranges. Avoid broad file
  dumps, verbose diffs, redundant status checks, and unnecessary tool calls.
- Keep shell output compact with output limits. Do not surface build logs,
  file listings, or diffs unless they contain an error or a decision-relevant
  result.
- Keep commentary and final handoffs concise: outcome, relevant verification,
  and any remaining manual test only. Do not provide an implementation diary.
- Prefer local repository inspection and local tests. Do not browse, download,
  install dependencies, or make network requests unless the user explicitly
  asks or the task cannot be completed without them.
- Do not spawn subagents unless the user explicitly asks for delegation.

## Git and decisions

- Commit completed, verified source changes with a concise capability-focused
  message. Never include `workspaces/` data or generated user assets by
  default.
- Ask before implementation only when a product decision is genuinely
  unresolved. Otherwise make the smallest compatible assumption and state it
  briefly at handoff.
