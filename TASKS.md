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

## Optional Later — Editor diagnostics and topology hardening

The recent Mirror, Fuse, Hole, and parent-to-child snapping work has no known
functional blocker. These items are follow-up diagnostics, manual validation,
or defensive hardening rather than current bug fixes.

### DIAG-01 — Opt-in editor session trace

- **Status:** Optional / Later
- **Risk:** Medium — traces may contain authored document details
- Record a bounded, opt-in sequence of editor intents, selected IDs, topology
  validation results, and undo/redo transitions so a hard-to-reproduce session
  can be reconstructed after an error.
- Keep the trace diagnostic-only: it must not become a second document format
  or change editor behaviour.
- Provide an explicit export/reset action and document which authored data may
  appear in the trace before enabling it.

### TOPO-OPT-01 — Potion workflow smoke test

- **Status:** Optional / Later
- **Risk:** None; manual verification
- Exercise Potion after save and reload through Mirror, Fuse, parent-to-child
  Point snapping, ordinary Hole constraints, and Auto Mesh at its intended
  smaller scale.
- Confirm that topology and Mesh diagnostics remain clean without rewriting the
  Asset as a test fixture.

### TOPO-OPT-02 — Additional defensive interaction tests

- **Status:** Optional / Later
- **Risk:** None to the product; test-only
- Add explicit rejected-action Redo coverage and Same-Chain Fuse coverage for
  manual `mirrored` and `aligned` Points.
- Strengthen the Cross-Chain orientation fixture with assertions on absolute
  cubic control positions, independent of the implementation's Handle-key
  selection.
- Keep this optional unless a related regression appears; current topology and
  Handle invariants are already covered by the main suite.

### TOPO-OPT-03 — Transactional closed-loop Mirror merge

- **Status:** Optional / Later; currently unreachable through validated input
- **Risk:** Low
- Remove the theoretical partial-mutation path in
  `_merge_coincident_closed_loop`: if its Chain join ever becomes rejectable,
  no reflected Handles may be applied before success is known.
- Preserve the current directed Handle result after Chain reversal; merely
  moving the existing Handle calls behind the join is insufficient because the
  joined seam Point is no longer necessarily an endpoint.

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

## Optional Later — Discriminator vocabulary cleanup

Three slices already landed: Component draw-mode/topology-role constants in
`WorldDocumentService` (commit 82fd3af), the Guide scope vocabulary in
`AssetGuide` plus `ComponentHierarchy.guide_world_transform` (d929665), and
the `ASSET_TYPE_*` constants in `WorldDocumentService` (d12d314). Each
replaced a literal string discriminator, hand-compared at every call site,
with named constants and predicates so a misspelling is a parse error
instead of a silent fallback. What follows is what the same pass over the
codebase turned up as still open, ordered by how it was found rather than
by size.

### DISC-01 — Guide scope-kind literals left in `main.gd`

- **Status:** Ready
- **Risk:** Low
- `_create_weapon_guide` and `_create_region` (`main.gd:7704`, `7729`) take a
  `scope_kind: String` parameter and compare it against raw `"component"` /
  `"group"` literals instead of `AssetGuide.SCOPE_COMPONENT` /
  `AssetGuide.SCOPE_GROUP`.
- `component_add_menu.set_meta("scope_kind", "component"/"group")`
  (`main.gd:7434`, `7452`) and every `get_meta("scope_kind", "component")`
  reader (`7463`, `7479`, `7486`, `7490`) do the same.
- `main.gd:8940` builds `guide["scope"] = {"kind": "component",
  "component_id": component_id}` by hand — missed during the d929665 slice.
  Should read `{"kind": AssetGuide.SCOPE_COMPONENT, "component_id":
  component_id}`, or go through `AssetGuide.create()`/`create_weapon_frame()`
  if the surrounding code allows it.
- Rename the local `scope_kind` parameters only if needed to avoid shadowing
  `AssetGuide.scope_kind()` — they are on a different class (`main.gd`), so
  no shadowing risk today, but check again if any of this logic ever moves
  into `AssetGuide` itself.

### DISC-02 — Component `type` discriminator (`component`/`guide`/`region`/`reference`)

- **Status:** Optional / Later
- **Risk:** Medium — largest of the four, touches ~10 files and 30+ call sites
- `WorldDocumentService.is_region()` and `is_reference_component()` already
  exist, but the `"guide"` check (components arrays can still hold
  migrated-legacy Guide records; see `AI_CONTEXT.md` on the
  Guides-once-stored-among-Components migration) is hand-rolled as
  `str(x.get("type", "component")) == "guide"` / `!= "guide"` throughout
  `component_hierarchy.gd`, `asset_scale_rebase_service.gd`,
  `component_scale_rebase_service.gd`, `main.gd`, `outliner_view.gd`,
  `create_inspector_view.gd` and `world_document_service.gd` itself.
- Candidate shape: `COMPONENT_TYPE_COMPONENT`/`_GUIDE`/`_REGION`/`_REFERENCE`
  constants on `WorldDocumentService`, plus an `is_guide_record()` predicate
  next to the existing `is_region()`/`is_reference_component()`, with call
  sites switched over one file at a time.
- Comparable in size to the original draw-mode/topology-role slice; do this
  one in its own session rather than folding it into a smaller slice.

### DISC-03 — Region type literal (`region_type`: attack/hurt/collision)

- **Status:** Ready
- **Risk:** Low
- `WorldDocumentService.REGION_TYPES` already exists, but
  `runtime_export_service.gd:187` and `:457` re-declare
  `["attack", "hurt", "collision"]` instead of referencing it.
- The `"attack"` default literal is duplicated five times:
  `editor_widgets.gd:173-174` (twice), `main.gd:2461`, `11846`, `11877`, and
  `outliner_view.gd:686`, `691`.
- Straightforward: add `REGION_TYPE_ATTACK`/`_HURT`/`_COLLISION` constants
  (or reuse `REGION_TYPES[0]` for the default) and point every site at them.

### DISC-04 — Sampling input kind (`"component"` vs `"guide"`)

- **Status:** Optional / Later; may not be worth its own slice
- **Risk:** Low
- `selected_sampling_input_kind` and the `input_kind` parameter threaded
  through `_get_sampling_input`, `_sampling_input_display_name`, and
  `_sampling_input_kind_for_seeding_role` (`main.gd`, around lines
  6909-6945, 8995-9010) compare against raw `"component"`/`"guide"`
  strings.
- Confined to `main.gd`, unlike the other three items here. Consider folding
  this into DISC-02 rather than doing it alone, since both concern the same
  Component-vs-Guide distinction from different entry points.

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

### TEST-01 — One driver for the wiring tests

- **Status:** Done
- `_check_view_wiring` in `tests/test_case.gd` carries the routing half and the
  emission half; the six wiring tests (the five listed here plus
  `_test_runtime_export_view_wiring`, which the count had missed) hand it a
  routing table, probe cases and a probe builder. The duplicated part was about
  250 lines rather than the 600 estimated: the per-view fixtures and probe
  builders are not duplicates and stayed where they were.
- Done at the same time: `run_tests.gd` is a runner over five suites that
  extend `tests/test_case.gd`, finds tests with `get_method_list()`, and
  attributes every engine `ERROR` and `SCRIPT ERROR` to the test that was
  running through a `Logger`, so the pass line no longer depends on a
  `SCRIPT ERROR` happening to reach an assertion.

### REPO-01 — Repository size below `worlds/`

- **Status:** Optional / Later
- **Risk:** Low, but it touches user data — analyse before changing anything
- `worlds/` is 125 MB across 212 tracked files, of which 65 are images.
  Reference images dominate. `catalog.json` and `PolyToolsRuntimeExports/` are
  already untracked as one generated publication unit.
- Files below `worlds/` are user data. Establish what is authored and what is
  derived before proposing anything, and never rewrite them as fixtures.

### REPO-02 — Curate pending World and Item Asset changes

- **Status:** User-controlled / Later
- **Risk:** High if files are classified incorrectly
- Review the pending authored and generated changes below `worlds/world01/`,
  including the new Potion and Vial Asset data, before deciding what belongs in
  version control.
- Keep generated Geometry separate from authored Asset intent and do not let an
  automated cleanup, test, or documentation commit absorb these files.
