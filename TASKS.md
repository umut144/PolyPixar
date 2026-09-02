# PolyTools Tasks

## Optional Later — Auto Mesh

The current Auto Mesh baseline is complete: topology-based face classification,
the Barde-calibrated size model, independent Boundary/Seed Spacing, selective
automatic retries, complexity guardrails, Inspector diagnostics, and the
synthetic regression corpus are implemented and verified. No further Auto Mesh
slice is currently required.

### AM-OPT-01 — Structured retry reason codes

- **Status:** Optional / Later
- **Risk:** Low
- Replace the remaining Sampling error-text check used to select a Boundary
  retry with stable machine-readable failure codes.
- Preserve existing user-facing error text and automatic retry behavior.
- Add compatibility tests proving that diagnostic wording can change without
  changing retry scope.

### AM-OPT-02 — Local feature analysis in shadow mode

- **Status:** Optional / Later
- **Risk:** Low while analysis remains read-only
- Derive local curvature, narrow-width, and proximity indicators for large
  Components without changing Sampling, Seeding, or Meshing recipes.
- Expose the suggested local density only through Auto Build diagnostics or a
  developer report.
- Validate against synthetic narrow-feature, concave, Hole, and Cut fixtures.
- Do not persist analysis as Component topology and do not use files below
  `worlds/` as test fixtures.

### AM-OPT-03 — Feature-aware local density activation

- **Status:** Optional / Later; conditional on AM-OPT-02 evidence
- **Risk:** Medium
- Apply local refinement only after shadow-mode results demonstrate a repeatable
  benefit over the global version-3 calibration.
- Keep the current global model and selective retry behavior as the fallback.
- Avoid Asset-type branches; decisions must come from geometry metrics.
- Acceptance requires no material Triangle-count or silhouette regression for
  Barde-scale Characters and small Symbols, while preserving small details on
  large Components.

### AM-OPT-04 — Broader read-only benchmark report

- **Status:** Optional / Later
- **Risk:** Low
- Extend the synthetic corpus with additional representative primitives and
  compound constraint layouts.
- Report Spacing, Samples, Seeds, Triangles, quality metrics, and elapsed time as
  developer diagnostics.
- Keep correctness assertions based on invariants and broad ranges; do not use
  fragile exact Triangle snapshots or wall-clock pass/fail thresholds.

## Optional Later — Architecture

`main.gd` is 12.9k lines. Roughly 1.8k of that is router work that should stay
there: render context preparation, module and selection state, key and pointer
input, the Context and Info Bar, the batch status, and the signal wiring in
`_build_ui`. Another 1.4k is Motion, which waits for the Bevy runtime decisions.
What follows is what is genuinely left, measured during the CreateInspectorView
inventory.

### ARCH-01 — Extract the Mesh batch build

- **Status:** Optional / Later
- **Risk:** High — it writes `geometry_documents`
- 12 functions, 481 lines: candidate selection, recipe resolution, building and
  the atomic per-Component commit. 8 of the 12 are already named in the suite.
- 15 global fields, of which 5 are only toolbar Button references; 5 external
  callers.
- Needs the geometry regression fixtures and a build-provenance comparison as a
  second verification layer, not just the suite and the render probe.

### ARCH-02 — Extract the Bézier point, edge and face editing

- **Status:** Optional / Later
- **Risk:** Very high — it mutates document topology
- 38 functions, 627 lines, 21 incoming signals, 10 of 38 named in the suite.
- Largest line reduction available and the most dangerous. It needs topology
  invariants and a Canvas comparison before it is worth starting.

### ARCH-03 — Dialogs and context menus stay where they are

- **Status:** Deliberately left alone
- 54 functions, 961 lines, spread over 30 separate blocks and touching 71 global
  fields. Extracting them would move lines without buying an ownership boundary.
- Recorded so the size does not invite a later "obvious" refactor.

### ARCH-04 — RuntimeExportView is not fully snapshot-pure

- **Status:** Known deviation, deliberate
- `consumer_sync == ""` means "leave the label alone", because that text is
  transient run state the batch paths set through `set_consumer_sync_text`.
  After `set_context` plus `rebuild` the displayed Consumer Sync line therefore
  still depends on what happened before, not on the context alone.
- Carrying it as a real context value means carrying its colour too, and
  `main.gd` would have to hold the run state it currently does not. Do not treat
  the view as fully stateless when reworking the context.

## Optional Later — Persistence

### PERF-01 — Dirty tracking for `_save_world`

- **Status:** Optional / Later; measured, no acute need
- **Risk:** Medium — it changes when authored records are written
- Measured on world01 (19 Assets, 118 Geometry documents), 12 runs per case:
  a no-op save costs a median of 1,539 ms and rewrites 140 files and 22.5 MB
  with **zero** changed bytes. A save after one Component `z_index` change costs
  the same and changes 1 file of 140.
- Phase breakdown: serializing and stringifying the Geometry documents is 1,042
  ms of it (69 %), `_asset_catalog_build` 295 ms (19 %), and the actual writing
  only 88 ms (6 %).
- Therefore **do not** add an identical-content skip to
  `WorldDocumentService.write_text_atomically`: the expensive serialization has
  already happened by then, so it would save about 4 % while touching the path
  that guarantees authored records survive a failed write.
- Dirty tracking on the Geometry documents is the fix that works. Projection:
  about 490 ms instead of 1,520 ms.
- `_mutable_geometry_document` is the single write path, but it is **not** a
  complete specification. Save As, New World, Load World, load-time migrations,
  history restore, newly created and deleted documents, and failed saves each
  need an explicit decision before this is implemented.
- There is no autosave: all six `_save_world` callers are explicit user actions
  (⌘S, the World menu, the Eye contour width action, new-World confirmation,
  Update Meshes, Build All). That is why this is not urgent.

## Optional Later — Tests and repository

### TEST-01 — One driver for the five wiring tests

- **Status:** Optional / Later
- **Risk:** None to the product; test-only
- `_test_outliner_wiring`, `_test_geometry_inspector_wiring`,
  `_test_create_inspector_wiring`, `_test_style_inspector_wiring` and
  `_test_motion_inspector_wiring` are structurally identical: routing table,
  reverse check against `get_script_signal_list`, emission walk, argument types.
  Only the fixture and the probe builder differ.
- About 600 duplicated lines could become one driver taking
  `(view, routes, cases, probe builder)`. The payoff is that a sixth view cannot
  be rebuilt by hand and silently miss a half.

### REPO-01 — Repository size below `worlds/`

- **Status:** Optional / Later
- **Risk:** Low, but it touches user data — analyse before changing anything
- `worlds/` is 125 MB across 212 tracked files, of which 65 are images.
  Reference images dominate. `catalog.json` and `PolyToolsRuntimeExports/` are
  already untracked as one generated publication unit.
- Files below `worlds/` are user data. Establish what is authored and what is
  derived before proposing anything, and never rewrite them as fixtures.
