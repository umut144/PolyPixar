# PolyTools – Geometry Sampling

**Status:** Sampling MVP contract.

## Observable result

In `Mesh → Sampling`, the user selects one Body Component, adjusts one adaptive
boundary recipe, inspects an automatically generated point preview, and
explicitly bakes the accepted result. Outer, direct ordinary or referenced
Hole, and scoped Cut boundaries participate in one shared Bake. A direct Hole
affects only its immediate Parent Body and does not propagate to ancestors.

## Ownership

Component `points`, `edges`, and `chains` remain the only canonical authored
geometry. `GeometrySamplingService` consumes an immutable Component copy and
returns ordered, Component-local boundary samples. It never changes Bézier
topology, Component transforms, Motion documents, or the existing
`MotionSampler` contract.

Sampling recipes and bakes are component-scoped derived Geometry records keyed
by stable Asset and Component IDs. A bake records a fingerprint of its source
topology. A changed fingerprint makes that bake stale; derived data is never
synchronized back into authored topology.

## Adaptive recipe

Sampling exposes one method. `Target Edge Length` (persisted as `spacing`,
default `1.00` Body units) is the maximum desired boundary interval, while
`Curve Detail` (persisted as `feature_detail`) refines curved regions from an
absolute chord-error tolerance in Body units plus tangent turn. The chord-error
tolerance is scale-aware: enlarging the same curved input eventually adds
samples even when its tangent angles are unchanged. Closed Chains omit a
duplicate copy of their first sample at the end.

Outer, Hole, and Cut boundaries inherit the Body recipe. A Hole Component or
Cut Guide may optionally store a boundary-density factor from `0.25×` through
`16×`; its effective target length is `Body spacing / factor`. The factor also
scales adaptive curve tolerances, so values below `1×` coarsen a boundary and
values above `1×` refine it. Boundary adjustments never
select a separate method or Curve Detail value. Schema-28 Even Spacing recipes
and absolute boundary overrides normalize to the adaptive recipe and factors.

Circle and Ellipse Primitives remain canonical as center plus axis diameters.
Sampling evaluates their analytic curve directly, including an ordinary Child
or Reference transform into Body-local space, so their sample count follows
Target Edge Length and Curve Detail rather than the fixed render-contour segment
count.

Before a Preview becomes a mesh-pipeline input, Sampling arranges its
constraints into a planar straight-line graph (PSLG). Every Cut intersection
with Outer, Hole, or another Cut becomes an exact shared geometric junction on
both affected segments. Cut spans outside Outer or inside a Hole are removed;
the remaining spans are persisted as ordered fragments, so no downstream stage
can accidentally reconnect a Cut across a Hole. These junctions are derived
samples and never modify authored Bézier topology.

## Preserve Point

Every Bézier edge endpoint participates in sampling. A Point with
`preserve_point: true` additionally carries an explicit preserved guarantee:
it remains at its exact authored position and may not be removed or merged by
later simplification. Coincident preserved Points are a validation concern,
not permission to erase authored intent.

## Generate and Bake

Changing a parameter schedules one debounced Generate and updates the temporary
point preview; the generated preview does not participate in document history.
The states are `Ready to Preview`, `Calculating`, `Preview Ready`, `Invalid`,
and `Baked`. `Bake Preview` only accepts and copies a valid preview matching the
current recipe and source fingerprint; it does not generate again. Recipe or
topology changes retain the previous Bake as stale and invalidate downstream
Seeding and Meshing through their existing fingerprint dependencies.

## Constraint-aware Seeding

`Mesh → Seeding` consumes only an accepted current Sampling Bake. It derives
one constraint domain: the Outer bounds the valid interior, closed Holes remove
interior regions, and open Cuts act as internal barriers without excluding
either side. Sampled Outer, Hole, and Cut points remain fixed downstream mesh
vertices and are never duplicated as interior Seeds.

Poisson Fill uses one minimum Seed Spacing and an automatic constraint
clearance equal to `Spacing × 0.5`. Candidates must remain inside Outer,
outside every Hole, and outside the clearance band of Outer, Holes, and Cuts.
The exact Sampling fingerprint includes sampled Cuts, so any accepted
constraint change makes Seeding and Meshing stale.

Spine Flow uses the same domain and clips its normal rows at the nearest Outer,
Hole, or Cut. A recipe may enable multiple Sampler Spines. Their candidates are
combined deterministically, resolve conflicts through stable Guide order, and
share one global minimum-distance pass. Optional Gap Fill runs once after all
Flow candidates and respects both constraints and accepted Flow Seeds.

The primary Spine Flow Inspector is an Artistic control layer. `Seed Spacing`
defines Across Spacing and Gap Fill density, while `Flow Stretch` derives
`Along Spacing = Seed Spacing × Flow Stretch`. Boundary Margin defaults to
`Seed Spacing × 0.5`, and Stagger defaults to `0.1`. Boundary Margin and
Stagger may be refined explicitly; derived Along/Across values, Stagger, and
Random Seed live below the collapsed `Advanced Pattern` disclosure. Legacy
recipes with explicit Along, Across, Boundary Clearance, or Stagger retain the
same result by loading those technical values as Artistic overrides.

Seeding parameter changes schedule a debounced transient Preview. The states
are `Sampling Required`, `Ready to Preview`, `Calculating`, `Preview Ready`,
`Invalid`, `Baked`, and `Edited`. `Bake Preview` copies the exact current
Preview; replacing a manually edited Bake remains an explicit confirmed action.
Only accepted current Bakes may enter manual Seed editing, and manual additions
or moves must satisfy the active constraint clearance and Seed spacing.

Schema 30 migrates the former Spine Flow `guide_id` into an ordered
`spine_inputs` list. Older Seeding Bakes remain readable but are stale until
regenerated with the constraint-aware algorithm version.

## Automatic density calibration

`Update Meshes` automatic recipe version 3 retains the version-2 Barde geometry
calibration as its stable reference range. Up to perimeter `60`, Boundary
Spacing and Poisson Seed Spacing retain `0.55`, apart from the existing
8-to-512 boundary-sample guards for very small or extreme contours. Larger
boundaries scale sublinearly:

`boundary_spacing = 0.55 × sqrt(perimeter / 60)`

Interior density is modeled independently. Seed Spacing is never smaller than
Boundary Spacing and grows to `sqrt(area / 750)` when area would otherwise
create excessive interior Seeds. A feature-size cap retains at least three
interior spans across ordinary narrow geometry. This separation lets a large
simple trunk use a coarser interior without forcing the Crown boundary to use
the same value.

Automatic ownership is explicit build provenance, not an Asset-type switch. A
stored automatic recipe remains automatic only while its normalized pipeline
hash matches the successful build. Editing Sampling, Seeding, or Meshing makes
that recipe manual and prevents recalibration or fallback retries from changing
it. Legacy `0.55` automatic profiles migrate to version 2. Untouched legacy UI
defaults migrate only for clearly oversized Components (perimeter at least `75`
and area at least `250`); smaller Character and Symbol defaults remain exact.

Automatic complexity is bounded at 4096 total sampled Constraint points, 2500
interior Seeds, and 12000 final Triangles. When a Build exceeds the interior or
Triangle budget, the next attempt increases only Seed Spacing by `1.25ⁿ` and
reuses the exact Boundary recipe. Boundary Spacing and Curve Detail scale only
when Sampling itself exceeds its hard safety limit or the 4096-Sample automatic
Boundary budget. At most four automatic attempts are allowed. Complete final
Constraint coverage and zero degenerate Triangles remain mandatory; minimum
angle, mean quality, and worst aspect ratio are recorded with the attempt
history for diagnosis. Manually owned recipes receive one exact attempt and no
automatic density adjustment.

`Mesh → Meshing → Auto Build Diagnostics` presents this state without mutating
it. Before the first build it shows resolved ownership, model version,
Area/Perimeter/Feature metrics, current Boundary/Seed Spacing, and budgets.
After `Update Meshes`, it additionally shows
budget usage, each attempt's Initial/Seed/Boundary scope and retry reason, plus
the accepted quality readings. A recipe edit is immediately labeled Manual and
the automatic budgets are shown as not applied.

The automatic regression corpus is synthetic: tiny Symbol, Barde-scale body,
Tree-scale trunk, large concave Crown, and a Body combining a Hole with a Cut.
Assertions protect topology, complete Constraint coverage, density transitions,
and broad complexity ranges without pinning exact Triangle layouts or reading
mutable World documents.

## Constrained Meshing

`Mesh → Meshing` consumes the complete accepted Sampling and Seeding chain and
offers one closed-Body method: `Constrained Mesh`. Its primary Artistic control
is `Mesh Character`, from Structured to Organic. Structured uses the direct
constrained triangulation. Moving toward Organic derives increasing interior
relocation strength and one to four optimization/retriangulation passes.
`Optimize Mesh` provides the raw-CDT versus optimized A/B switch. Sampled
Outer, Hole, and Cut vertices stay fixed throughout. `Advanced Optimization`
can override strength or pass count independently when exact technical control
is needed.

The constrained mesh sends the validated PSLG to the pinned
`artem-ogre/CDT` 1.4.5 native adapter, excludes Hole interiors, and treats each
Cut as a two-sided seam. Cut vertices are duplicated
only after the final optimization and constrained retriangulation, preventing the
seam from being invalidated by a later topology pass. The result reports
constraint, seam, before/after quality, and degenerate-triangle diagnostics.

Recipe changes schedule one debounced transient Preview. The states are
`Seeding Required`, `Ready to Preview`, `Calculating`, `Preview Ready`,
`Invalid`, and `Baked`. `Bake Preview` copies the exact matching Preview without
regenerating it and automatically records that Bake as the Component Mesh.
There is no separate Component Mesh acceptance step. The Outliner mirrors the
pipeline as Sampling → Seeding → Constraints → Mesh; the Inspector keeps mesh
edges, Seed points, triangle fill, constraints, Optimization, and Quality as
view-only toggles.

Schema 31 migrates the former Constrained Delaunay and Organic Relaxed methods
to one Constrained Mesh recipe. The accepted Component Mesh is preferred when
choosing between legacy Bakes, and legacy Organic values become an Artistic
Character plus exact Advanced Relaxation overrides. Legacy results are retained
as stale data until regenerated by the current algorithm.

Schema 32 persists Cut fragments and their arranged junctions. Older flat Cut
sample lists remain readable as one compatibility fragment. Meshing algorithm
version 3 marks older mesh results stale and regenerates them with the native
CDT backend.

Schema 33 and Meshing algorithm version 4 persist the optimizer switch plus
compact movement and quality diagnostics. The optimizer moves only existing
Interior Seeds and accepts only measured quality improvements.

Meshing algorithm version 5 replaces centroid and edge-midpoint domain
filtering with topology-based face classification. Sampled Outer and Hole
constraints form closed flood barriers, while Cut constraints remain traversable
for domain membership and are retained as two-sided seams. After classification,
every Outer and Hole segment must bound exactly one retained Triangle and every
Cut segment must have two-sided Triangle coverage. A missing final constraint is
an invalid Mesh result rather than a successful Bake with an open boundary.

Junction-aware Sampling Bakes identify Sampling algorithm version 2. Older
flat Cut Bakes remain readable for inspection but become stale upstream, so the
UI requests Sampling and Seeding rebakes instead of passing an unsplit PSLG to
Meshing and reporting a misleading invalid Mesh.

## Deferred

Manual sample-point editing, per-boundary Curve Detail, background-threaded
generation, per-Spine spacing overrides, blended vector fields at Spine
intersections, and export consumption remain deferred.
