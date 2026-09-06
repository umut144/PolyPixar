# PolyTools Tasks

This file tracks only current, next, blocked, or deliberately deferred outcomes.
Completed implementation history remains available in Git.

## Active Tasks

| ID | Area | Outcome | Status |
|---|---|---|---|
| `DISC-01` | Discriminator vocabulary | Replace guide scope-kind literals (`"component"`/`"group"`) with `AssetGuide.SCOPE_COMPONENT`/`SCOPE_GROUP` constants in `main.gd` and component_add_menu. | **Ready** |
| `DISC-03` | Discriminator vocabulary | Replace region type literals (`"attack"`, `"hurt"`, `"collision"`) with `REGION_TYPE_ATTACK`/`_HURT`/`_COLLISION` constants across six call sites. | **Ready** |

## Optional Later — Auto Mesh

The current Auto Mesh baseline is complete. No further Auto Mesh slice is currently required.

| ID | Area | Outcome | Status |
|---|---|---|---|
| `AM-OPT-01` | Auto Mesh | Replace Sampling error-text check with stable machine-readable failure codes while preserving user-facing text and automatic retry behavior. Add compatibility tests for diagnostic wording changes. | **Optional / Later** |
| `AM-OPT-02` | Auto Mesh | Derive local curvature, narrow-width, and proximity indicators for large Components in shadow mode, exposed only through diagnostics. Validate against synthetic fixtures without persisting as topology. | **Optional / Later** |
| `AM-OPT-03` | Auto Mesh | Apply local refinement only after AM-OPT-02 evidence demonstrates repeatable benefit over global version-3 calibration, with fallback to current behavior and no Asset-type branches. | **Optional / Later** |
| `AM-OPT-04` | Auto Mesh | Extend synthetic corpus with representative primitives and compound constraint layouts; report Spacing, Samples, Seeds, Triangles, quality metrics and elapsed time as developer diagnostics. | **Optional / Later** |

## Optional Later — Editor diagnostics and topology hardening

Recent Mirror, Fuse, Hole, and parent-to-child snapping work has no known functional blocker.

| ID | Area | Outcome | Status |
|---|---|---|---|
| `DIAG-01` | Editor diagnostics | Record bounded, opt-in editor session trace (intents, topology validation, undo/redo) for hard-to-reproduce sessions; keep diagnostic-only with explicit export/reset and clear data-privacy documentation. | **Optional / Later** |
| `TOPO-OPT-01` | Topology | Exercise Potion after save/reload through Mirror, Fuse, parent-to-child snapping, Hole constraints, and Auto Mesh at smaller scale; confirm topology and Mesh diagnostics remain clean without test fixtures. | **Optional / Later** |
| `TOPO-OPT-02` | Topology | Add explicit rejected-action Redo coverage and Same-Chain Fuse coverage for manual `mirrored` and `aligned` Points; strengthen Cross-Chain orientation fixture with absolute cubic control assertions. | **Optional / Later** |
| `TOPO-OPT-03` | Topology | Remove theoretical partial-mutation path in `_merge_coincident_closed_loop` if Chain join becomes rejectable; preserve directed Handle result after Chain reversal. | **Optional / Later** |

## Optional Later — Architecture

Remaining `main.gd` extraction candidates after `CreateInspectorView` inventory.

| ID | Area | Outcome | Status |
|---|---|---|---|
| `ARCH-01` | Architecture | Extract Mesh batch build (12 functions, 481 lines: candidate selection, recipe resolution, atomic commit) with geometry regression fixtures and build-provenance comparison as verification layer. | **Optional / Later** |
| `ARCH-02` | Architecture | Extract Bézier point, edge and face editing (38 functions, 627 lines, 21 signals); largest reduction but most dangerous. Requires topology invariants and Canvas comparison before starting. | **Optional / Later** |
| `ARCH-03` | Architecture | Dialogs and context menus (54 functions, 961 lines over 30 blocks, 71 global fields) deliberately left alone; extraction would move lines without buying ownership boundary. | **Deliberately left alone** |
| `ARCH-04` | Architecture | RuntimeExportView transient run state (`consumer_sync` label set by batch paths) remains context-dependent after `set_context`+`rebuild`; documented deviation from snapshot-pure model. | **Known deviation, deliberate** |

## Optional Later — Discriminator vocabulary cleanup

Three slices landed (draw-mode/topology-role, Guide scope, ASSET_TYPE constants). Below is what remains.

| ID | Area | Outcome | Status |
|---|---|---|---|
| `DISC-02` | Discriminator vocabulary | Add `COMPONENT_TYPE_COMPONENT`/`_GUIDE`/`_REGION`/`_REFERENCE` constants and `is_guide_record()` predicate; replace ~30 hand-rolled `"guide"` checks across 6 files with named constants (comparable size to original slice; do in own session). | **Optional / Later** |
| `DISC-04` | Discriminator vocabulary | Replace `"component"`/`"guide"` string literals in `selected_sampling_input_kind` and related `main.gd` sampling functions with named constants; consider folding into DISC-02 since both concern Component-vs-Guide distinction. | **Optional / Later** |

## Optional Later — Persistence

| ID | Area | Outcome | Status |
|---|---|---|---|
| `PERF-01` | Persistence | Add dirty tracking on Geometry documents to reduce no-op save from 1,520 ms (1,042 ms serialization + 295 ms catalog build) to ~490 ms; requires explicit decisions on Save As, New World, Load, migrations, history, and failed saves (no autosave). | **Optional / Later** |

## Optional Later — Tests and repository

| ID | Area | Outcome | Status |
|---|---|---|---|
| `TEST-01` | Tests | One driver for the wiring tests (routing half + emission half consolidated into `_check_view_wiring` in `test_case.gd`); runner attributes engine errors to active test via `Logger`. | **Done** |
| `REPO-01` | Repository | Analyze worlds/ (125 MB, 212 tracked files, 65 images, reference dominance); establish what is authored vs. derived before proposing changes; `catalog.json` and `PolyToolsRuntimeExports/` already untracked. | **Optional / Later** |
| `REPO-02` | Repository | Review pending World and Item Asset changes below `worlds/world01/` (new Potion and Vial data); keep generated Geometry separate from authored Asset intent; do not absorb into automated cleanup, test or docs commits. | **User-controlled / Later** |

## Tracker rules

- Keep at most one task **In progress**.
- Describe an observable outcome, not an implementation diary.
- Add acceptance detail only when needed to decide task completion.
- Remove completed rows after the immediate handoff; Git preserves their history.
