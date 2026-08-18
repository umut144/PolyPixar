# PolyTools AI Context

PolyTools is a Godot 4 editor for authoring topology-based 2D assets and
deriving mesh data from them. The current product surface is intentionally
small and database-oriented.

## Visible modules

The left rail is always expanded and exposes exactly these categories:

- `Create`: `Character`, `Props`, `Terrain`, `Icon`
- `Mesh`: `Sampling`, `Seeding`, `Meshing`
- `Style`: `Weighting`
- `Export`

Only one module is active at a time, even though all categories remain open.
Motion authoring is retained internally for future work but is not selectable
or restored as an active editor category. Transform and Effects are not product
categories. Texture and Material authoring are not part of the application.

## Asset kinds

All four Create modules use the same Asset, Component, Guide, canvas, and
Inspector implementation. An Asset stores one stable `asset_type` value:
`character`, `props`, `terrain`, or `icon`. Create views filter the Outliner by
that value. Documents without an `asset_type` normalize to `character`.

Mesh and Style show a shared multi-select Asset filter above the Outliner
search field. Character, Props, Terrain, and Icon are checked by default;
search text and checked types are combined. The filter is an editor-state
preference, not a document mutation.

The field is written to `asset.json` and to the exported Godot scene root as
the `asset_type` metadata value. This is the current export contract for
distinguishing product modules; module-specific behavior can be layered on top
later without changing Asset topology.

## Geometry model

Components have an explicit geometry source. Bézier Components are canonical
only as `points`, `edges`, and `chains`; `BezierTopology` owns their structural
changes and validation, and `BezierGeometry` owns cubic mathematics and handle
resolution. Primitive Components instead own a typed `primitive` record and
never store generated Bézier points, edges, chains, or samples. The currently
supported primitive is `{ type: "circle", center, diameter_cm }`.

`ComponentCanvas` receives immutable view copies, renders them, and emits user
intent; it never mutates Workspace geometry directly. Polygon arrays for fill,
hit testing, sampling, meshing, and export are derived on demand from either
source. A Primitive's center handle moves its `primitive.center`; its Component
pivot remains an independent transform handle.

Components support `closed_loop`, `open_edge`, `ribbon`, and `primitive` draw
modes. Primitive sampling is derived at mesh resolution, so it has no user
editable sample count. Guides remain independent topology records scoped to an Asset or Component. Derived
Sampling, Seeding, Meshing, UV, and Weighting records are stored separately
from source topology.

## Workspace and export

A Workspace persists Assets plus the currently retained motion and derived
mesh records. Assets own Components, Guides, reference-image settings, their
Asset pivot, and their `asset_type`. New persistence must not add display
polygons or reverse synchronization into Component topology.

Export validates topology before building a Godot scene. The scene root owns
the exported Asset pivot and `asset_type`; child `Node2D` records preserve the
Component hierarchy and `Polygon2D` geometry is derived from Bézier topology,
a primitive definition, or an accepted Ribbon mesh.

## Verification

After geometry changes run:

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --editor --quit
git diff --check
```

Files below `workspaces/` are user data and must not be rewritten as fixtures.
