# Authored Contour Stroke

PolyTools treats the final authored Bezier boundary as the exact centerline of
the visible art contour. A contour is derived geometry and never replaces or
mutates Component `points`, `edges`, or `chains`.

## Slices 1–3: closed boundaries, visible runs, and open Contours

`ContourStrokeService` derives a deterministic indexed triangle mesh from
exactly one closed outer/hole Chain or one fill-less open Contour Chain.
Consecutive Edges with
`render_outline = true` form one visible run. Hidden Edges split those runs and
the adjacent visible centerlines end exactly at their authored Points with butt
caps. A Component with no visible Edges is a valid permanent no-outline result
with no stroke geometry.

The authored `contour` draw mode is persisted in World schema 40. Its accepted
`contour_stroke` Component Mesh is a derived Bake and does not become source
topology. Runtime manifest schema 3 has no matching art-stroke role, so open
Contours are visibly blocked from Runtime Export rather than serialized as
Fill Meshes.

The fixed technical semantics are:

- authored reference density: `128 px/m`;
- current fixed World default width: `4 px` = `0.03125 m`;
- centered offset: `0.015625 m` on each side of the source boundary;
- adaptive Bezier sampling deviation: at most `0.25 px`;
- joins: miter with limit `4.0`, then bevel;
- caps: butt (an uninterrupted closed loop has no cap).

Every centerline sample and derived mesh vertex retains stable `edge_id` and
`curve_t` provenance. Hitting a sampling bound is an explicit validation
failure, not a quality fallback.

Each result lists its visible runs with deterministic IDs, ordered source Edge
IDs, open/closed state, cap semantics, centerline provenance, and exact
vertex/index ranges in the combined mesh. The Hole role is preserved explicitly
for downstream consumers but does not alter the centered stroke construction.

Editable World settings and the typed Runtime Export role belong to later
slices. Schema 39 and older Ribbons migrate explicitly to open Contours; their
legacy strip Bakes never qualify as current Contour Stroke Bakes.
