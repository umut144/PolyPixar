# Component Scale Rebase

World schema 42 adds an explicit Asset-level Scale Rebase workflow. Component
Scale is an authoring convenience; Rebase bakes it into owned source geometry
and sets both local Scale axes exactly to `1`.

The operation is atomic across the selected Asset and preserves each affected
Component's Position, Rotation, Pivot, hierarchy, visibility, and animation
document. For Bézier Components, Points and resolved cubic handles are
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
safe. Finite, non-zero signed Scale is accepted for owned leaf Components.
Negative axes are a transient Mirror/authoring representation: their reflection
is baked into the owned geometry before Scale becomes `(1, 1)`. Primitive
centers receive the signed affine transform while their analytic axis diameters
use the absolute axis factors. Zero or non-finite Scale is blocked. Scaled Asset
References are blocked because they do not own their source geometry. A scaled
Component with Child Components is also blocked: preserving those Children
while forbidding Position/Rotation compensation is not generally possible,
especially under anisotropic Scale. There is no partial or silent fallback.

Runtime Export rejects every visible Component whose authored Scale is not
`(1, 1)` and directs the author to Rebase. It never bakes Scale implicitly and
never exports a negative Mirror scale. It does not silently preserve the old
scaled export behavior. Later simulation
Scale remains relative to the normalized reference drawing and transforms the
complete drawing, including its eventual contour stroke geometry.

Accepted derived geometry is not rewritten. Source fingerprints and build
signatures make affected Mesh, UV, SDF, and export inputs stale for an explicit
rebuild.
