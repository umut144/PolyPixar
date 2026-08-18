# Bézier Topology Model

For Bézier draw modes, Component geometry has exactly one persisted source of
truth: ordered Bézier topology stored in `points`, `edges`, and `chains`.
Primitive draw mode is a separate source model and is documented below; it
does not serialize generated Bézier topology.

## Point

```text
id: String
position: Vector2
mode: linear | aligned | free | mirrored | corner
preserve_point: bool
handle_source: auto | manual
handle_in: Vector2
handle_out: Vector2
```

Handles are vectors relative to `position`. A Corner defaults to
`preserve_point = true`. Closing a Chain also preserves its first and last
authored Points.

## Edge

```text
id: String
start_point_id: String
end_point_id: String
render_outline: bool
```

An Edge references two existing Points. Its direction must match its position
inside the owning Chain.

## Chain

```text
id: String
point_ids: Array[String]
edge_ids: Array[String]
closed: bool
topology_role: outer | hole | cut | seam
```

For an open Chain, `edge_ids.size() == point_ids.size() - 1`. For a closed
Chain, both sizes are equal and the final Edge connects the last Point to the
first. A closed Chain requires at least three Points.

Closed-loop Components also store `topology_role: outer | hole`. New Closed
Loops default to `outer`; changing a Component to `hole` updates its closed
contour Chain role as well. Symbol References own this role independently from
the referenced Symbol.

## Closed Loop drafts

Closed Loop validation requires exactly one closed Chain. While authoring, a
Mirror Y operation may temporarily create a second open Chain from a selected
contiguous run of the sole open source Chain. Mirror never connects or closes
these Chains. The author joins their endpoints explicitly, then closes the
remaining endpoints into the final single Chain. A closed Chain cannot be
mirrored.

## Ribbon mesh derivation

A Ribbon Component keeps its canonical source as one open Bézier Chain. Its
derived `Ribbon Strip` mesh is sampled deterministically in `Mesh →
Meshing`, offsets paired vertices by the persisted `ribbon_width_px` (8 px =
0.625 internal units, displayed as 6.25 cm at 128 px/m and 10 cm per internal
unit), and triangulates each
consecutive pair into a strip.
The derived mesh never modifies Points, Edges, or Chains.

## Ownership

`BezierTopology` creates IDs, adds and removes Points, splits Edges, closes
Chains, rebuilds ordered Edge references, and validates invariants.
`BezierGeometry` resolves handles and performs cubic curve mathematics.
`ComponentCanvas` receives copies for presentation and emits intent using
stable IDs.

## Primitive geometry

A `primitive` Component owns a typed `primitive` record rather than Bézier
topology. The first supported form is `{ type: "circle", center, diameter_cm }`.
Its render contour, mesh samples, hit-test polygon, and export polygon are all
derived deterministically from those parameters. The Circle center handle moves
`center`; the Component pivot remains independent. Primitive Components cannot
be edited with Bézier point, edge, or face tools.

The current fill and Godot export derive a control polygon from the outer
Chain. Production mesh sampling is intentionally separate and may later
replace that derived polygon without changing authored topology.
