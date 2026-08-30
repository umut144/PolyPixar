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
