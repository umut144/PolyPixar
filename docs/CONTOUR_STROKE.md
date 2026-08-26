# Authored Contour Stroke

PolyTools treats the final authored Bezier boundary as the exact centerline of
the visible art contour. A contour is derived geometry and never replaces or
mutates Component `points`, `edges`, or `chains`.

## Slices 1–5: geometry and World-authored width

`ContourStrokeService` derives a deterministic indexed triangle mesh from
exactly one closed outer/hole Chain or one fill-less open Contour Chain.
Consecutive Edges with
`render_outline = true` form one visible run. Hidden Edges split those runs and
the adjacent visible centerlines end exactly at their authored Points with butt
caps. A Component with no visible Edges is a valid permanent no-outline result
with no stroke geometry.

The authored `contour` draw mode is persisted in World schema 40. Its accepted
`contour_stroke` Component Mesh is a derived Bake and does not become source
topology. Runtime Manifest schema 4 exports this typed art-stroke role directly;
open Contours omit Fill geometry.

World schema 41 adds the required typed `world_settings` record:

```json
{
  "reference_pixels_per_meter": 192.0,
  "contour_stroke_width_px": 4.0
}
```

The width is one World-authored value shared by every Asset and Component. A
non-reference Component may store a finite positive `contour_stroke_width_px`;
it is an implicit local override only when it differs from the World value.
The Inspector always exposes the width field and has no separate Override
toggle. Schema 40 and older Worlds migrate explicitly to `4 px`. A schema-41
World with a missing or invalid record fails loading instead of receiving a
fallback. Changing the value invalidates Contour Mesh fingerprints and their
dependent Bakes.

The fixed technical semantics are:

- authored reference density: `192 px/m`;
- new-World default width: `4 px` = `0.03125 m`;
- centered offset: `stroke_width_px / 192 / 2` meters on each side;
- adaptive Bezier sampling deviation: at most `0.25 px`;
- joins: miter with limit `4.0`, then bevel;
- caps: butt (an uninterrupted closed loop has no cap).

Every centerline sample and derived mesh vertex retains stable `edge_id` and
`curve_t` provenance. Hitting a sampling bound is an explicit validation
failure, not a quality fallback.

The version-3 stroke tessellator validates every emitted index and triangle for
finite coordinates, positive area, in-range indices, and consistent winding.
It places miter/bevel geometry on the exposed side of both convex and concave
turns. The four-half-width miter limit remains an authored rule rather than a
numeric recovery path.

Proper crossings in an open authored Contour remain renderable: they represent
an intentional drawn-line crossing and are counted in typed geometry
diagnostics. Likewise, non-adjacent centerline sections closer than one full
stroke width remain independent and report their minimum local clearance and
coverage-overlap count. PolyTools never merges nearby boundaries by epsilon.
Exact 180-degree reversals and non-adjacent collinear path overlap are rejected
as ambiguous offset geometry with explicit errors; there is no silent repair or
alternate triangulation fallback. Closed outer and Hole boundaries must remain
simple loops, so their self-intersections also fail explicitly. Pairwise
robustness validation has a fixed upper work bound and reports exhaustion as an
error instead of skipping checks.

Each result lists its visible runs with deterministic IDs, ordered source Edge
IDs, open/closed state, cap semantics, centerline provenance, and exact
vertex/index ranges in the combined mesh. The Hole role is preserved explicitly
for downstream consumers but does not alter the centered stroke construction.

Closed outer and Hole chains use the same validation and tessellation rules.
Wizard-like tips, small eye-scale returns, holes, and visually adjacent lines
are regression fixtures for this contract. Slice 7 stores a current Contour
Stroke Bake beside the Fill Bake for closed and Primitive Components. Runtime
schema 4 exports the centered stroke with typed width, join/cap, run, and
symmetric offset metadata. UV/SDF/Carrier data is not part of that contract.
Schema 39 and older Ribbons
migrate explicitly to open Contours; their legacy strip Bakes never qualify as
current Contour Stroke Bakes.
