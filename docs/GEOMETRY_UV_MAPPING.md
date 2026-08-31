# PolyTools – Geometry UV Mapping

**Status:** Legacy derived-data contract. Runtime Manifest schema 4 and active
Build All do not consume UV or SDF data, and the authoring surface described
below no longer exists: the `Geometry → UV Mapping` Workspace, its Inspector,
and the `Update UVs (N)` and `Update SDFs (N)` batches have been removed.

What remains is `GeometryUVMappingService`, `GeometrySDFService`, and the
document normalization and serialization for their records. Existing Bakes and
`contour_sdf.png` files stay readable and survive a load/save round trip
unchanged; nothing generates new ones. The sections below therefore describe
the recorded data and the service contracts, not a reachable workflow.

## Observable result

In `Geometry → UV Mapping`, the user selects one Component, chooses
`CMD/Ctrl + 1 · Method → 1 · Bounds / Planar`, adjusts a compact mapping recipe,
previews the accepted Component Mesh beside normalized UV space, and explicitly
bakes the accepted UV result.

## Ownership and dependency

UV Mapping is a separate derived stage after Meshing:

```text
canonical Bézier topology → Sampling → Seeding → Mesh Bake → UV Bake
```

A UV Bake never changes Mesh vertices, Triangles, or Component
`points`/`edges`/`chains`. It references one exact Mesh Bake ID and fingerprint
and stores one UV coordinate for each stable Mesh Vertex ID. A changed or stale
Mesh makes the UV Bake stale without reverse synchronization.

The accepted Component Mesh is the only UV input. There is no independent Mesh
source selection: closed Bodies contribute their accepted Constrained Mesh and
Contour Components contribute their accepted Contour Stroke. UV Bakes are retained
by the combination of Component Mesh method and UV method.

## Bounds / Planar

Bounds / Planar maps Component-local Mesh positions into normalized UV space.
It exposes the accepted `Component Mesh` plus `Scale`, `Rotation`, `Offset U`,
`Offset V`, `Padding`, and `Preserve Aspect`.

Preserve Aspect uses one uniform Component bound and centres unused space.
Disabling it fills U and V independently. New recipes inset the mapped bounds by
`0.0625` on every UV edge. This deterministic Padding reserves exterior texels
for later contour-mask derivation. Scale and rotation operate around the centre
of UV space; offsets are applied afterward. Identical Mesh and recipe inputs
produce identical UV coordinates.

## Legacy Update UVs

The retained legacy update implementation accepts deterministic Bounds / Planar UVs
for every visible Component whose accepted Component Mesh is current and whose
UV Bake is missing or stale. Existing recipes are preserved; Components without
an authored recipe use the calibrated padded default. Each Component is committed
atomically, one failure cannot replace an older valid UV Bake, and a repeated
failure is not actionable again until its Mesh or recipe changes.

Every accepted result is validated as an exact one-to-one mapping from stable
Component Mesh Vertex IDs to finite UV coordinates. Hidden Components and
Components without a current accepted Component Mesh are not batch candidates.

## Generate, Bake, and Outliner

Input or parameter changes automatically Generate a temporary preview. Manual
Bake remains explicit and participates in Undo/Redo and World persistence;
the global batch provides the deterministic default acceptance path. The UV
Outliner nests accepted results beneath their source Mesh method so the exact
dependency remains visible and directly selectable.

The UV Space always uses a neutral 8×8 checker background. The Source Mesh
shows the same checker through its derived UV coordinates by default, making
stretching, rotation, density changes, and out-of-range UVs visible. `UV
Checker Overlay` is an editor-only Preview toggle; it does not affect recipes
or Bakes.

## Deferred

`CMD/Ctrl + 2 · Edit UV`, manual UV overrides, Seams, texture assignment,
Sampler-Spine or Shader-Flow mapping, packing, atlases, distortion analysis,
manual SDF editing, and export consumption are outside this Slice.

## Legacy Contour SDF

Runtime schema 4 exports neither UV nor SDF. This section documents the retained
legacy derivation only.

The downstream contour stage consumes the exact accepted Component Mesh and UV
Bake. The retained legacy SDF implementation creates one deterministic
`256×256` single-channel PNG
per visible Component. The channel is interpreted linearly: `0.5` is the contour,
greater values are inside, lower values are outside, and the signed-distance
spread is `16 px`.

Mesh triangles define the filled silhouette, including Contour Strokes and holes;
Bézier control polygons are not consulted. UV uses `u` right and `v` up, while
PNG rows use a top-left image origin, so rasterization applies `y = (1-v) ×
height`. Bake metadata records the channel, color-space interpretation,
resolution, spread, origins, source Bake IDs and fingerprints, algorithm version,
and pixel hash. The relative resource name is `contour_sdf.png` beside
`geometry.json`.

Changing Mesh, UV coordinates, SDF recipe, or algorithm makes the SDF stale.
A missing PNG is also actionable. Batch commits are atomic per Component and a
failure cannot replace an older valid Bake or image.
