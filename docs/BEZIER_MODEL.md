# Bézier Topology Model

For Bézier draw modes, Component geometry has exactly one persisted source of
truth: ordered Bézier topology stored in `points`, `edges`, and `chains`.
Primitive draw mode is a separate source model and is documented below; it
does not serialize generated Bézier topology.

Optional Attack, Hurt, and Collision Regions reuse the same canonical
`points`/`edges`/`chains` representation as Bézier Components. They are
nonvisual records and their sampled polygon/triangulation is derived only for
validation and Runtime Export when `region_geometry_source` is `authored`.
Every Region is attached to one Component. With `region_geometry_source =
component`, the attached Component is the active geometry owner and the
Region's own topology remains dormant but persisted for a lossless switch back
to Free Draw. No Component geometry is copied into the Region.
Weapon Guides are instead oriented transform frames and intentionally contain
no Bézier topology.

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

An `auto` handle is not authored data: it is derived from the neighbouring
Point positions, and `BezierGeometry.resolve_auto_handles` re-derives every one
of them when a document is read. A record must therefore store handles that its
own loader agrees with, which `WorldDocumentService.serialize_component_topology`
guarantees by resolving on the way out. This matters beyond tidiness, because
`GeometrySamplingService.source_fingerprint` hashes the stored handles verbatim:
a record whose handles the loader would recompute comes back from its own file
changed, and every Bake built against it reports itself stale after a restart
although nothing was edited. A transform that touches Point positions must
re-derive the automatic handles rather than transform them alongside — the two
agree in real arithmetic but not in the 32-bit floats a Vector2 holds.

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
first. A closed Chain requires at least three Points. A Point ID may occur only
once across the complete Component topology; separate Chains never share a
Point identity and must be joined explicitly before they share a seam.

`Fuse Point` collapses Points in the same Chain only when they are direct
neighbours, including the last/first pair of a closed Chain. The two endpoints
of an open Chain may also fuse to close it when at least three Points remain.
All other same-Chain matches are rejected before mutation, and a two-Point open
Chain is never collapsed to one Point. When a manual seam Handle is contributed
to a retained `mirrored` or `aligned` Point, the opposite Handle follows that
Point's mode just as it does during a normal Handle edit; `free` and `corner`
Handles remain independent, while `linear` Points remain handleless.

Closed-loop Components and analytic Primitives also store
`topology_role: outer | hole`. New Components default to `outer`; changing a
Bézier Component to `hole` updates its closed contour Chain role as well, while
changing a Primitive updates only its metadata and never creates Bézier topology.
An Asset Reference owns this role independently from the Asset it instances. An
ordinary Component authored as `hole` is a visible, editable constraint of its
direct outer Parent rather than an independent Mesh body; hiding it disables
the constraint. It cannot live at Asset root, accept Component children, or
participate in Style Weighting. A Hole Reference still instances its source Asset at Runtime
but owns no Fill or Contour Stroke Mesh of its own.

## Closed Loop drafts

Closed Loop validation requires exactly one closed Chain. While authoring, a
Mirror operation may create a second open Chain from a selected contiguous
run of the sole open source Chain. The Create context bar offers it as one
`Mirror` menu with two commands that differ only in axis orientation: Mirror Y
reflects across a vertical axis, Mirror X across a horizontal one. The axis
direction is fixed by the chosen command, so the user places only the axis line
itself and confirms it with a click or Enter. The axis snaps to authored Points
before it snaps to the grid: where it runs decides whether the two halves join,
an axis through the end of the mirrored run reflects that Point onto itself,
and an endpoint that does not sit on a raster line would otherwise be out of
reach. If both
mirrored endpoints coincide with
the source endpoints, Mirror automatically joins and closes the two halves
into the final single Chain. A single coincident endpoint remains an open
joined Chain so the remaining endpoint can be authored manually. Where no
endpoint coincides, the second Chain stays, and the author brings the two
halves together by dragging one endpoint onto the other - Point snapping now
offers the Component's own Points for that - and fusing them, which is also
what makes the Component mirrorable again. A closed
Chain cannot be mirrored. Mirror command availability checks only source
topology and the contiguous Point selection because no axis exists yet. Preview
and apply validate the chosen axis separately and reject an interior selected
Point on that axis; only open Chain endpoints may be coincident there.
`SelectionMirrorService` itself still reflects across any axis given as two
distinct Points, so a freely oriented axis remains possible without a service
change.

## Fill boundary sampling

For closed fill boundaries, Adaptive Sampling may insert additional derived
curve samples on the longer side of an authored corner when the two adjacent
sampled segment lengths differ by more than `3×`. The deterministic pass uses
the owning Chain to resolve source-to-source and closing intervals and rejects
spatially degenerate insertions. It is best effort, with at most 64 additional
samples per Chain and an explicit incomplete diagnostic. These samples preserve
the exact cubic curve, are not authored Points, and exist only to give
constrained Meshing a gradual Boundary edge-size transition on narrow geometry.

## Contour mesh derivation

A Contour Component keeps its canonical source as one Bézier Chain, either open
or closed. Its derived `Contour Stroke` mesh is sampled deterministically in
`Mesh → Meshing` using the same centered stroke construction as closed loops. World
Settings own one width for all Assets, defaulting to 4 authored px (`0.0208333 m`
at `192 px/m`), with Miter joins, a limit of `4.0`, Bevel fallback, and Butt
caps. An ordinary Component may store a local width override; an Asset
Reference may store an instance-local override that applies to every Contour
part of its source Asset without changing the source. It has no Fill Mesh.
The derived mesh never modifies Points, Edges, or Chains. Robustness analysis
keeps intentional open-Contour crossings and narrow coverage overlaps visible
and diagnosed, while ambiguous collinear overlap, exact reversals, and
self-intersecting closed Chains fail explicitly without a topology fallback.

A closed Contour's accepted build also derives a deterministic triangulated
region from the complete ordered, unoffset Boundary using the Stroke service's
adaptive centerline sampling before visibility splitting and width/join/cap
construction. This region is exported only as engine-neutral Runtime geometry;
it has no visible Fill, material, color, alpha, UV, or rendering semantics.
Open Contours, Closed Loops, Primitives, and Asset References do not receive
this additional field.

## Ownership

`BezierTopology` creates IDs, adds and removes Points, splits Edges, closes
Chains, rebuilds ordered Edge references, and validates invariants.
`BezierGeometry` resolves handles and performs cubic curve mathematics.
`ComponentCanvas` receives copies for presentation and emits intent using
stable IDs.

## Primitive geometry

A `primitive` Component owns a typed `primitive` record rather than Bézier
topology. Authored Circles use `{ type: "circle", center, diameter_cm }`.
An anisotropic Scale Rebase preserves them as
`{ type: "ellipse", center, diameter_x_cm, diameter_y_cm }`. Authored
Rectangles use `{ type: "rectangle", center, width_cm, length_cm }` and
authored Triangles `{ type: "triangle", center, width_cm, height_cm }`, every
extent a full one reaching equally in both directions from `center`. A Triangle
is isosceles, its base along the bottom of that box and its apex centred on the
top. Render contours,
mesh samples, hit-test polygons, and export polygons are derived
deterministically from those parameters. The primitive center handle moves
`center`; the Component pivot remains independent. Primitive Components cannot
be edited with Bézier point, edge, or face tools.

Scale Rebase is the sole normalization path for finite, non-zero signed
non-unit Component Scale. It affinely bakes Points, resolved handles, analytic
primitive axes, and Component-scoped Guides around the unchanged Pivot, then
sets Scale to `(1, 1)`. A parent Rebase compensates direct Child local
transforms to preserve the Child subtree's visible world transform. Negative
axes preserve transient Mirror reflections in the owned geometry. See
[`SCALE_REBASE.md`](SCALE_REBASE.md).

The current fill and Godot export derive a control polygon from the outer
Chain. Production mesh sampling is intentionally separate and may later
replace that derived polygon without changing authored topology.
