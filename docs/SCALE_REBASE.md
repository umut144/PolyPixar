# Scale Rebase

## Asset Root Transform

World schema 53 adds `Scale X` and `Scale Y` to the root Asset Inspector.
World schema 58 adds `Position X/Y`. Position translates the complete Asset,
while the two positive Scale axes preview independent horizontal and vertical
size changes around the unchanged Asset Pivot. Both fields affect Components,
Groups, References, Guides, and Weapon frames. Legacy scalar Scale values are
read as equal X/Y values.

`Rebase Asset Transform` atomically bakes the preview into canonical authoring
data and resets Root Position to `(0, 0)` and Root Scale to exactly `(1, 1)`. Root
translation is applied exactly once to root-scoped placements. Local positions, Bézier Points and
handles, primitive centers and diameters, Guide positions, and Weapon-frame
positions are multiplied exactly once. Root placements are scaled around the
Asset Pivot; nested placements use their local origin. References multiply
their instance scale while preserving their transform Pivot. Component Scale
is deliberately unchanged, so the Component workflow below can be used before
or after Root Rebase.

Default Motion documents are safe. Any authored non-default Motion blocks the
whole Root Rebase because its spatial values do not yet have an exact root
transform conversion. Runtime Export likewise rejects a Root Position other
than `(0, 0)` or either Root Scale axis other than `1`.
Automatic handles stay automatic and are re-derived from the positions the bake
wrote, rather than carried through the affine beside their anchors: the two
agree in real arithmetic but not in 32-bit floats, and a handle the loader would
recompute makes every Bake on that Component report itself stale one reload
later. Component Scale Rebase has no such step because it turns automatic
handles into manual ones.
Accepted derived geometry is not rewritten; existing fingerprints make it
stale for an explicit rebuild.

## Component Scale

World schema 42 adds an explicit Asset-level Scale Rebase workflow. Component
and Group Scale are authoring conveniences; Rebase normalizes both local Scale
axes to `1`. A Group Rebase first compensates member transforms, then bakes the
resulting Component Scale into owned source geometry.

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

The Asset Inspector lists every Component and Group candidate and blocker. Its Rebase button is
enabled only when at least one candidate exists and the complete operation is
safe. Finite, non-zero signed Scale is accepted for owned Components and Groups.
Negative axes are a transient Mirror/authoring representation: their reflection
is baked into the owned geometry before Scale becomes `(1, 1)`. Primitive
centers receive the signed affine transform while their analytic axis diameters
use the absolute axis factors. Zero or non-finite Scale is blocked. Asset
References are source-Asset instances and are excluded from Rebase; their
finite, non-zero signed Scale remains an instance placement transform. Scaled
Components with Children are supported: Child local transforms are compensated
so the visible Child subtree stays in place. There is no partial or silent
fallback. Group-scoped Bézier Guides and Weapon frames are compensated with
their Group so their visible world transform is retained.

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
