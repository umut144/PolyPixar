# Scale Rebase

## Asset Root Scale

World schema 53 adds `Scale` to the root Asset Inspector. It is one positive
uniform factor (for example, `3.6` means 3.6 times the current size), previewed
around the unchanged Asset Pivot across the complete Asset: Components,
Groups, References, Guides, Weapon frames, and semantic Regions.

`Rebase Asset Scale` atomically bakes the preview into canonical authoring
data and resets Root Scale to exactly `1`. Local positions, Bézier Points and
handles, primitive centers and diameters, Guide positions, and Weapon-frame
positions are multiplied exactly once. Root placements are scaled around the
Asset Pivot; nested placements use their local origin. References multiply
their instance scale while preserving their transform Pivot. Component Scale
is deliberately unchanged, so the Component workflow below can be used before
or after Root Rebase.

Default Motion documents are safe. Any authored non-default Motion blocks the
whole Root Rebase because its spatial values do not yet have an exact scale
conversion. Runtime Export likewise rejects a Root Scale other than `1`.
Accepted derived geometry is not rewritten; existing fingerprints make it
stale for an explicit rebuild.

## Component Scale

World schema 42 adds an explicit Asset-level Scale Rebase workflow. Component
Scale is an authoring convenience; Rebase bakes it into owned source geometry
and sets both local Scale axes exactly to `1`.

The operation is atomic across the selected Asset and preserves each affected
Component's Pivot, hierarchy, visibility, animation document, and visible world
transform. Rebasing a parent compensates its direct Child transforms as needed
to preserve the Child subtree in world space; this can change a Child's local
Position, Rotation, or Scale. For Bézier Components, Points and resolved cubic handles are
transformed around the unchanged Pivot. Automatic handles become manual during
the bake so anisotropic Scale cannot regenerate a different curve later.
Component-scoped Guide Points and handles receive the same affine bake.

A uniformly scaled Circle remains a Circle. A non-uniformly scaled Circle
becomes the analytic primitive:

```json
{
  "type": "ellipse",
  "center": [0.0, 0.0],
  "diameter_x_cm": 12.0,
  "diameter_y_cm": 6.0
}
```

Ellipse contours, sampling, automatic metrics, hit geometry, and mesh inputs
remain derived; Rebase never polygonizes the primitive into stored Bézier
topology.

The Asset Inspector lists every candidate and blocker. Its Rebase button is
enabled only when at least one candidate exists and the complete operation is
safe. Finite, non-zero signed Scale is accepted for owned Components.
Negative axes are a transient Mirror/authoring representation: their reflection
is baked into the owned geometry before Scale becomes `(1, 1)`. Primitive
centers receive the signed affine transform while their analytic axis diameters
use the absolute axis factors. Zero or non-finite Scale is blocked. Asset
References are source-Asset instances and are excluded from Rebase; their
finite, non-zero signed Scale remains an instance placement transform. Scaled
Components with Children are supported: Child local transforms are compensated
so the visible Child subtree stays in place. There is no partial or silent
fallback.

Duplicate & Mirror with Flip Orientation uses a targeted atomic Rebase for the
newly duplicated Component subtree. It preserves the subtree's world transforms
while baking the mirrored negative Scale into the duplicated geometry, so the
new Components finish with Scale `(1, 1)` without changing unrelated Asset
Components. The same rule applies to a duplicated Group: its mirrored Group
Scale is normalized and the duplicated member transforms are compensated
before the subtree Rebase.

Runtime Export rejects every visible Component whose authored Scale is not
`(1, 1)` and directs the author to Rebase. It never bakes Scale implicitly and
never exports a negative Mirror scale. It does not silently preserve the old
scaled export behavior. Later simulation
Scale remains relative to the normalized reference drawing and transforms the
complete drawing, including its eventual contour stroke geometry.

Accepted derived geometry is not rewritten. Source fingerprints and build
signatures make affected Mesh, UV, SDF, and export inputs stale for an explicit
rebuild.
