# PolyTools Runtime Export Contract

**Status:** Normative consumer contract for runtime manifest schema `1`.

This document is the single source of truth for consuming PolyTools Runtime
packages. `AI_CONTEXT.md`, `ARCHITECTURE.md`, and the geometry documents explain
editor ownership and derivation, but they defer to this contract when describing
the exported package.

## Package boundary

`Export Runtime (N)` writes one independently replaceable package per visible
Asset:

```text
res://worlds/<world_name>/PolyToolsRuntimeExports/<asset_id>/
├── manifest.json
└── masks/
    └── <component_id>.sdf.png
```

`<asset_id>` is the stable authored Asset identity. `display_name` is
presentation metadata and must not be used as an identity or path key. All paths
inside a Manifest use `/`, are relative to the package directory, and must remain
inside that directory after normalization.

The exporter stages and verifies a complete package before replacing the prior
package directory. A validation or I/O failure preserves the prior package. The
root is a generated cache and may contain editor-owned sidecar files such as
`.import`; only `manifest.json` and resources referenced by that Manifest belong
to this contract.

There is no schema-1 root catalog. Removing or hiding an Asset does not assert
that an older package directory has been removed. A consumer that needs a closed
Asset set must maintain an explicit allow-list; directory discovery alone may
also discover older independently valid packages.

## Compatibility and failure policy

Every Manifest has an integer `schema_version`. A schema-1 consumer must reject
an absent, non-integer, or unsupported version. It must not guess the meaning of
unknown fields in place of missing required fields.

A package is rejected as a unit when any required Manifest field, referenced
mask, Component relationship, index, or numeric value is invalid. Consumers
must not silently create fallback Meshes, UVs, masks, Semantic Keys, or source
Assets. Unknown additional fields may be ignored to permit additive evolution
within a supported schema.

JSON integer fields are semantically integers even when a generic JSON parser
stores all numbers in one numeric representation. All floating-point values
must be finite.

## Top-level Manifest

Schema 1 requires:

| Field | Type | Meaning |
| --- | --- | --- |
| `schema_version` | integer | Exactly `1` for this contract. |
| `asset_id` | non-empty string | Stable Asset identity and package directory name. |
| `display_name` | string | Informational authored name. |
| `asset_type` | string | `character`, `props`, `terrain`, `icon`, or `symbols`. |
| `coordinate_system` | object | Self-describing coordinate and transform convention. |
| `z_order` | object | Global draw-order convention. |
| `asset_pivot` | two floats | Authored Asset anchor in meters. |
| `components` | array | Ordinary Components and Asset References. |

The required coordinate values are:

```json
{
  "dimensions": 2,
  "x_axis": "right",
  "y_axis": "up",
  "unit": "meter",
  "tool_unit_in_meters": 0.1,
  "rotation_unit": "radian",
  "positive_rotation": "counter_clockwise",
  "component_transform": "T(position) * R(rotation) * S(scale) * T(-pivot)"
}
```

All exported geometry and translation values are already converted to meters.
`tool_unit_in_meters` documents the authoring conversion and must not be applied
a second time.

`asset_pivot` does not rewrite exported Component geometry. It identifies an
anchor in Asset space. To place that anchor at an instance origin, apply
`T(-asset_pivot)` between the consumer's instance transform and the Component
hierarchy.

The required Z-order values are:

```json
{
  "scope": "global",
  "back_to_front": "ascending",
  "tie_breaker": "component_id_lexicographic"
}
```

The `components` array is already sorted by ascending
`(z_index, component_id)`. `z_index` remains global across the Asset and is not
made relative by hierarchy nesting.

## Common Component fields

Every entry in `components` requires:

| Field | Type | Meaning |
| --- | --- | --- |
| `component_id` | non-empty string | Stable identity, unique inside the Asset. |
| `semantic_key` | non-empty string | Runtime role, unique inside the Asset. |
| `parent_component_id` | string or `null` | Parent in the same Manifest, or `null` for a root. |
| `z_index` | integer | Global back-to-front draw order. |
| `local_pivot` | two floats | Pivot in the Component's authored local coordinate space. |
| `local_transform` | object | Position, rotation, and scale relative to the parent. |

`local_transform` requires:

```json
{
  "position": [0.0, 0.0],
  "rotation_radians": 0.0,
  "scale": [1.0, 1.0]
}
```

For a point `p`, one Component transform is:

```text
T(position) * R(rotation_radians) * S(scale) * T(-local_pivot) * p
```

Parent transforms are applied from the Asset root toward the Component. Parent
IDs must resolve inside the same Manifest, and the parent graph must be acyclic.

`semantic_key` is the sole authored runtime designation. Consumers use it for
gameplay, motion, and simulation lookup. They must not derive a role from
`display_name`, `component_id`, array position, or `source_asset_id`.
Keys are registered lower-snake-case strings, but schema 1 does not embed the
Semantic Registry or its version. Consumers should retain the key as a string
and coordinate any stricter engine-side registry update explicitly.

## Ordinary Mesh Components

An ordinary Component has no `kind: "asset_reference"`. It requires both
`mesh` and `contour_mask` and must not be interpreted as a Reference.

`mesh` requires:

| Field | Type | Meaning |
| --- | --- | --- |
| `vertices` | array of `[x, y]` | Component-local positions in meters. |
| `indices` | flat integer array | Triangle-list indices into `vertices`. |
| `uvs` | array of `[u, v]` | Normalized UVs aligned one-to-one with `vertices`. |

For every index `i`, `vertices[i]` and `uvs[i]` describe the same stable Mesh
Vertex. The index count is a positive multiple of three. Every index is in
range, and the three indices of one Triangle are distinct.

Schema 1 does not guarantee one Triangle winding across every Mesh method.
Transforms with a negative determinant may also reverse the final winding. A
consumer using face culling must calculate and normalize winding explicitly; a
2D consumer may instead use a non-culling material.

The runtime format carries 2D positions and no normals, tangents, vertex colors,
or material assignment. A 3D Mesh API may extend each position to `[x, y, 0]`
without changing the contract.

## UV convention

Exported UVs use normalized coordinates with `u` increasing right and `v`
increasing up. Their origin is bottom-left. The SDF PNG has a top-left row
origin. The exact mapping is:

```text
pixel_x = u * width
pixel_y = (1 - v) * height
```

A consumer whose texture UV origin is top-left converts exactly once:

```text
consumer_uv = [u, 1 - v]
```

The conversion may occur during import or sampling, but not both. UVs are
already padded and normalized to `[0, 1]`; consumers must not renormalize them
from Mesh bounds.

## Contour SDF

`contour_mask` requires:

| Field | Schema-1 value or type |
| --- | --- |
| `path` | Relative package path to the PNG. |
| `type` | `signed_distance_field` |
| `channel` | `r` |
| `color_space` | `linear` |
| `resolution` | `[256, 256]` for current exports. |
| `spread_px` | `16.0` for current exports. |
| `boundary_value` | `0.5` |
| `inside_is_greater` | `true` |
| `uv_origin` | `bottom_left` |
| `image_origin` | `top_left` |
| `uv_to_pixel` | `x=u*width, y=(1-v)*height` |
| `pixel_hash` | Lowercase SHA-256 of the decoded L8 pixel bytes. |

The resource is a deterministic single-channel L8 PNG. It is data, not color:
the texture must be sampled without sRGB decoding, and the red channel is the
normative channel even if an image loader expands L8 to RGB or RGBA.

For a normalized sample `s`, schema 1 encodes signed distance as:

```text
signed_distance_px = (s - boundary_value) * 2 * spread_px
```

Positive values are inside and negative values are outside. Values clamp at the
positive and negative Spread boundary. Filtering and edge antialiasing are
consumer presentation choices; they do not change the stored threshold or sign.

`pixel_hash` covers decoded pixel values, not compressed PNG file bytes. It can
be used to validate or cache the logical mask independent of PNG encoding.

## Asset References

An Asset Reference is identified by:

```json
{
  "kind": "asset_reference",
  "semantic_key": "belly",
  "source_asset_id": "asset_7"
}
```

In addition to the common Component fields, `source_asset_id` is required and
identifies the actual borrowed Asset package. A Reference contains no `mesh` or
`contour_mask`; geometry is not duplicated into its owner package.

The Reference's `semantic_key` is its local classification in the owner Asset.
It does not rename the referenced Asset and must not replace
`source_asset_id`. For example, Barde may classify an Orb Reference as `belly`
while the referenced geometry retains the Orb Asset's stable ID.

Consumers resolve References after registering packages by `asset_id`. Import
order is not significant. A missing source package rejects that Reference at
runtime. Consumers must also guard against transitive cross-Asset Reference
cycles. Instantiating referenced geometry uses the Reference's Component
transform as the placement transform; the referenced package retains its own
Asset pivot and Component hierarchy.

## Minimal examples

An ordinary Component record is structurally equivalent to:

```json
{
  "component_id": "component_6",
  "semantic_key": "body",
  "parent_component_id": null,
  "z_index": 0,
  "local_pivot": [0.0, 0.0],
  "local_transform": {
    "position": [0.0, 0.0],
    "rotation_radians": 0.0,
    "scale": [1.0, 1.0]
  },
  "mesh": {
    "vertices": [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]],
    "indices": [0, 1, 2],
    "uvs": [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]]
  },
  "contour_mask": {
    "path": "masks/component_6.sdf.png",
    "type": "signed_distance_field",
    "channel": "r",
    "color_space": "linear",
    "resolution": [256, 256],
    "spread_px": 16.0,
    "boundary_value": 0.5,
    "inside_is_greater": true,
    "uv_origin": "bottom_left",
    "image_origin": "top_left",
    "uv_to_pixel": "x=u*width, y=(1-v)*height",
    "pixel_hash": "<sha256-of-decoded-l8-pixels>"
  }
}
```

A Reference uses the common transform fields plus:

```json
{
  "component_id": "component_58",
  "semantic_key": "belly",
  "kind": "asset_reference",
  "source_asset_id": "asset_7",
  "parent_component_id": null,
  "z_index": 2,
  "local_pivot": [0.0, 0.0],
  "local_transform": {
    "position": [0.0, 0.0],
    "rotation_radians": 0.0,
    "scale": [1.0, 1.0]
  }
}
```

The example IDs illustrate the current World and are not reserved schema
constants.

## Consumer implementation notes

The following are recommended integration choices, not additional serialized
fields:

- Keep the Runtime root configurable instead of hard-coding an absolute
  development path.
- Parse and validate every package before publishing it to a live Asset
  registry.
- Register manifests by `asset_id`, then resolve References in a second pass.
- Convert UV origin in one centralized layer.
- Disable face culling for 2D, or normalize Triangle winding explicitly.
- Load SDF masks as linear data textures and sample the red channel.
- Keep both `semantic_key` and `source_asset_id` on a resolved Reference.
- Use `pixel_hash` and Manifest bytes for cache invalidation rather than file
  modification times.
- Ignore unreferenced files and editor sidecars inside the generated root.
