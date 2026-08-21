# Authored Contour Stroke

PolyTools treats the final authored Bezier boundary as the exact centerline of
the visible art contour. A contour is derived geometry and never replaces or
mutates Component `points`, `edges`, or `chains`.

## Slice 1: closed outer boundary

`ContourStrokeService` derives one deterministic indexed triangle mesh from
exactly one closed outer Chain whose Edges all have `render_outline = true`.
The Slice-1 result remains an internal geometry product; it is not persisted
and does not change the Runtime Export contract.

The fixed technical semantics are:

- authored reference density: `128 px/m`;
- default test width: `4 px` = `0.03125 m`;
- centered offset: `0.015625 m` on each side of the source boundary;
- adaptive Bezier sampling deviation: at most `0.25 px`;
- joins: miter with limit `4.0`, then bevel;
- caps: butt (normative for later open runs; a closed loop has no cap).

Every centerline sample and derived mesh vertex retains stable `edge_id` and
`curve_t` provenance. Hitting a sampling bound is an explicit validation
failure, not a quality fallback.

Holes, `render_outline = false` runs, open Contours, world settings,
persistence, preview UI, and Runtime Export integration belong to later
slices and are rejected or left untouched here.
