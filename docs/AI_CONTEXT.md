# PolyTools AI Context

PolyTools is a Godot 4 editor for authoring topology-based 2D assets and
deriving mesh data from them. The product surface is intentionally small and
database-oriented. This file is the entry point; it says what the product is,
where the rules live, and in which order to read them. It repeats nothing
that another document owns.

## Visible modules

The left rail is always expanded and exposes exactly these categories:

- `Create`: `Single`, `Set`, `Palette`
- `Mesh`: `Sampling`, `Seeding`, `Meshing`
- `Style`: `Weighting`

Only one module is active at a time, even though all categories remain open.
Motion authoring is retained internally for future work but is not selectable
or restored as an active editor category. Transform and Effects are not
product categories. Texture and Material authoring are not part of the
application, and UV and SDF have no authoring surface any more.

What an Asset is and how it is composed are two persisted fields. `asset_type`
— the seven categories — says what kind of thing it is; `asset_category`
— `single`, `set`, `palette` — says how it is put together, and that is what
picks the Create module. A Bridge is therefore `props` and a Set. Inside
`Single`, the Outliner search and the shared multi-select Asset filter select
among the seven types. `Set` is a different thing, not an eighth category: a
Set is an Asset whose visible Components are References to its members, each
with the role it plays in the assembly. `Palette` is the third: several equally
valid, interchangeable Assets the presentation chooses among freely, sharing
one category and carrying no arrangement at all. Members and variants are
ordinary Assets, authored from the composition that owns them, and `Single`
lists only what is placed on its own. Mesh is the user-facing name of the
derived geometry pipeline; the `geometry_*` identifiers in code are its
technical names.

## What the data is

An Asset owns Components, Groups and Guides. Component geometry is stored only
as Bézier `points`, `edges` and `chains`, or as one typed analytic primitive;
everything a renderer, a hit test or an export needs is derived from that on
demand and never stored back. Sampling, Seeding and Meshing produce derived
documents that are keyed by Asset and Component ID and kept beside, never
inside, the source topology. Runtime Export publishes accepted Meshes as
engine-neutral Manifests plus one Catalog per World. The full current model is
in `ARCHITECTURE.md`; how it got there, schema by schema, is in
`SCHEMA_HISTORY.md`.

## Rules that do not bend

- `outer_shape`, a Component-level `closed`, the old Line tool, and any
  reverse synchronization from a display polygon into Bézier topology stay
  gone. Do not reintroduce them.
- Views — `ComponentCanvas`, `OutlinerView`, the Inspector views,
  `RuntimeExportView` — render what `main.gd` pushes in and emit intent. They
  hold no editor state and mutate no document.
- Services are static and hold no editor state. A service returns
  `{valid, errors, ...}` rather than raising; `main.gd` decides what to do.
- Persistence never adds display polygons or derived data to Assets. A
  migration below a schema step is explicit; at or above it there is no
  silent fallback.
- Files below `worlds/` are user data, never test fixtures. The generated
  `catalog.json` and `PolyToolsRuntimeExports/` are the one untracked
  exception.

## Reading order

1. `AGENTS.md` — workflow, verification, Git rules. Read in full.
2. `ARCHITECTURE.md` — the shell, the ownership boundaries, the documents as
   they are, the derived pipeline, persistence and export.
3. `BEZIER_MODEL.md` — before any change to Component geometry.
4. The topic documents when the change touches them: `GEOMETRY_SAMPLING.md`,
   `GEOMETRY_SEEDING.md`, `GEOMETRY_MESHING.md`, `CONTOUR_STROKE.md`,
   `SCALE_REBASE.md`, `STYLE_WEIGHTING.md`, `RUNTIME_EXPORT_CONTRACT.md`
   (normative for the package format; no other document redefines its
   fields), the `MOTION_*.md` files, `UI_CONTEXT_COMMANDS.md`.
5. `SCHEMA_HISTORY.md` — only when a change touches persistence or an older
   document must be read.

`TASKS.md` lists what is deliberately left open and why; check it before
proposing a refactor that it already records as not worth doing.

## Verification

After every change run:

```bash
tools/verify.sh
```

It runs the headless editor parse, the native CDT smoke test, the test suite
and `git diff --check`, and fails on the same lines CI fails on.
