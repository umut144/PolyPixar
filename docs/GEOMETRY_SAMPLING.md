# PolyTools – Geometry Sampling

**Status:** Sampling MVP contract.

## Observable result

In `Mesh → Sampling`, the user selects one Body Component, adjusts one adaptive
boundary recipe, inspects an automatically generated point preview, and
explicitly bakes the accepted result. Outer, referenced Hole, and scoped Cut
boundaries participate in one shared Bake.

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

Outer, Hole, and Cut boundaries inherit the Body recipe. A Hole Reference or
Cut Guide may optionally store a boundary-density factor from `0.25×` through
`16×`; its effective target length is `Body spacing / factor`. The factor also
scales adaptive curve tolerances, so values below `1×` coarsen a boundary and
values above `1×` refine it. Boundary adjustments never
select a separate method or Curve Detail value. Schema-28 Even Spacing recipes
and absolute boundary overrides normalize to the adaptive recipe and factors.

Circle Primitives remain canonical as center plus diameter. Sampling evaluates
their analytic curve directly, including a Reference transform into Body-local
space, so their sample count follows Target Edge Length and Curve Detail rather
than the fixed render-contour segment count.

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

## Deferred

Manual sample-point editing, per-boundary Curve Detail, background-threaded
generation, per-Spine spacing overrides, blended vector fields at Spine
intersections, and export consumption remain deferred.
