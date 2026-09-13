# Authored Contour Stroke

PolyTools treats the final authored Bezier boundary as the geometric reference
of the visible art contour, and by default as its exact centerline. A contour is
derived geometry and never replaces or mutates Component `points`, `edges`, or
`chains`.

## Slices 1–5: geometry and World-authored width

`ContourStrokeService` derives a deterministic indexed triangle mesh from
exactly one closed outer/hole Chain, whether it belongs to a Closed Loop or a
fill-less Contour, or one fill-less open Contour Chain.
Consecutive Edges with
`render_outline = true` form one visible run. Hidden Edges split those runs and
the adjacent visible centerlines end exactly at their authored Points with butt
caps. A Component with no visible Edges is a valid permanent no-outline result
with no stroke geometry.

The authored `contour` draw mode is persisted in World schema 40. Its accepted
`contour_stroke` Component Mesh is a derived Bake and does not become source
topology. Runtime Manifest schema 10 exports this typed art-stroke role directly;
Contours omit Fill geometry whether their Chain is open or closed.

For a closed Contour, the same accepted build separately samples every authored
Edge with the Stroke's adaptive centerline criteria, regardless of
`render_outline`, and triangulates that complete unoffset Boundary as
`closed_region_mesh`. Stroke width, offsets, joins, caps, and visible run
splitting never affect it. The region is engine-neutral geometry without
material, color, transparency, UV, rendering, or Fill semantics, and PolyTools
does not draw it on the Canvas, in Preview, or as the Component Mesh.

World schema 41 adds the required typed `world_settings` record:

```json
{
  "reference_pixels_per_meter": 192.0,
  "contour_stroke_width_px": 4.0
}
```

The width is one World-authored value shared by every Asset and Component. A
Component may store a finite positive `contour_stroke_width_px`; on an Asset
Reference it is instance-local and applies to every Contour part of the source
Asset without changing the source;
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
- one-sided offset: the full `stroke_width_px / 192` meters on one side and nothing on the other;
- adaptive Bezier sampling deviation: at most `0.25 px`;
- joins: miter only at interior angles of at least `75°` and with limit `4.0`, then bevel;
- caps: butt (an uninterrupted closed loop has no cap).

Every centerline sample and derived mesh vertex retains stable `edge_id` and
`curve_t` provenance. Hitting a sampling bound is an explicit validation
failure, not a quality fallback.

The stroke tessellator validates every emitted index and triangle for
finite coordinates, positive area, in-range indices, and consistent winding.
It places miter/bevel geometry on the exposed side of both convex and concave
turns. An angle-aware fallback bevels interior angles below `75°` before their
otherwise legal miters become visually dominant needles; broader corners still
use the four-half-width miter limit as a second deterministic guard.

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
Stroke Bake beside the Fill Bake for Closed Loop and Primitive Components.
Runtime schema 10 exports the centered stroke with typed width, join/cap, run, and
symmetric offset metadata. UV/SDF/Carrier data is not part of that contract.
Schema 39 and older Ribbons
migrate explicitly to open Contours; their legacy strip Bakes never qualify as
current Contour Stroke Bakes.

## Stroke alignment

A Component may place the width on one side of its Boundary instead of across
it, through the optional `contour_stroke_alignment`: `inside`, `centered`, or
`outside`. Centered is the default and the absence of a decision, so an
existing World keeps exactly the geometry it had. There is no World-level
alignment; unlike the width, it is authored per Component.

Which side is which comes from the drawing, not from a convention. The signed
area of the authored Point order gives the loop its winding, and the left normal
`(-dy, dx)` points into the enclosed area along a counter-clockwise loop, so the
same shape drawn the other way round answers with the same two sides. A Hole
encloses a void rather than material, so the side its loop calls outward is the
one with material on it and the two swap; a Primitive follows its own topology
role the same way. The side is decided once per Chain rather than per visible
run: a hidden Edge splits the ribbon into open runs but does not change which
side of the shape has material on it.

An open Contour encloses nothing, so inside and outside have no meaning there.
It stays centered whatever is authored, reports itself as centered, and derives
the identical mesh either way. The Inspector keeps the control visible on an
open Contour and disables it, so the reason is readable rather than guessed at.

Two consequences are worth knowing before choosing a one-sided alignment. The
authored Boundary is then an edge of the ribbon rather than its middle, which is
what the exported `inner_offset_meters` and `outer_offset_meters` report; the
`centerline` field still names the Boundary, because that is what the geometry
is derived from. And the tessellator lets consecutive segment quads overlap on
the inner side rather than trimming them, which a centered stroke hides within
half a width: pushed fully to one side the overlap reaches a full width, so a
concavity tighter than the full stroke width renders as a filled corner rather
than a clean ribbon. A centered stroke of width `w` tolerates a curvature radius
down to `w/2`; a one-sided one needs `w`. The joins themselves stay exact — the
corner wedge is filled with the reach the ribbon has on that side, and where an
alignment leaves that side at zero the segments already meet on the Boundary and
no wedge is emitted.


## Holes draw the edge they cut

An ordinary Hole Component owns a Contour Stroke. It has no Fill — the Parent
it cuts owns the body, and Sampling and Meshing have already taken the Hole's
boundary out of it — but the edge left behind is drawn, at a width the Hole
authors itself under the same World default and Component override every other
width follows. That is why `is_constraint_only_hole` became
`is_hole_component`: owning no Fill and owning nothing at all had been the same
question, and they are not.

The alignment reads on a Hole the way the drawing does rather than the way the
loop does. A Hole encloses a void, so its `inside` is the material of the
Parent around it and grows away from the loop, while its `outside` reaches into
the void it cut. A Hole whose Parent is set to `outside` and which is set to
`outside` itself therefore has both strokes growing away from their own
material, which is a choice and not an accident: the two are authored
separately and neither inherits from the other.

Two things a Hole still does not have. It owns no Fill and no
`closed_region_mesh`, so it never enters Sampling, Seeding or Meshing as a Body
and has no row of its own in the Mesh module — its Stroke Bake rides along with
Update Meshes like every other one. And nothing is parented beneath it; it
remains a cut in its Parent rather than a body that can carry children.

This changes what an existing World exports. Before this, a Hole was omitted
entirely; now every visible Hole publishes a Stroke at the World width unless
it overrides one. Assets that were drawn expecting an unstroked cut edge will
show one.
