# AssetFlow2D – Geometry UV Mapping

**Status:** UV Mapping MVP contract.

## Observable result

In `Geometry → UV Mapping`, the user selects one Component, chooses
`CMD/Ctrl + 1 · Method → 1 · Bounds / Planar`, selects one current Mesh Bake,
adjusts a compact mapping recipe, previews the source Mesh beside normalized UV
space, and explicitly bakes the accepted UV result.

## Ownership and dependency

UV Mapping is a separate derived stage after Meshing:

```text
canonical Bézier topology → Sampling → Seeding → Mesh Bake → UV Bake
```

A UV Bake never changes Mesh vertices, Triangles, or Component
`points`/`edges`/`chains`. It references one exact Mesh Bake ID and fingerprint
and stores one UV coordinate for each stable Mesh Vertex ID. A changed or stale
Mesh makes the UV Bake stale without reverse synchronization.

UV Bakes are retained by the combination of Mesh method and UV method. This
allows CDT and Organic Relaxed Meshes to keep independent Bounds / Planar UV
results beneath the same Component.

## Bounds / Planar

Bounds / Planar maps Component-local Mesh positions into normalized UV space.
It exposes only `Mesh Source`, `Scale`, `Rotation`, `Offset U`, `Offset V`, and
`Preserve Aspect`.

Preserve Aspect uses one uniform Component bound and centres unused space.
Disabling it fills U and V independently. Scale and rotation operate around the
centre of UV space; offsets are applied afterward. Identical Mesh and recipe
inputs produce identical UV coordinates.

## Generate, Bake, and Outliner

Input or parameter changes automatically Generate a temporary preview. Bake is
explicit and participates in Undo/Redo and Workspace persistence. The UV
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
and export consumption are outside this MVP.
