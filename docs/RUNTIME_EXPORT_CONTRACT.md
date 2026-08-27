# PolyTools Runtime Export Contract

**Status:** Normative consumer contract for Asset Catalog schema `1` and
runtime Manifest schema `8`.

This document is the sole field-level contract for PolyTools Runtime packages.
Manifest schema 8 replaces schema 7. Consumers must reject older schemas; there is
no SDF/Carrier/UV compatibility fallback.

## Package boundary

`Export Runtime` writes one atomic package per currently valid visible Asset:

```text
res://worlds/<world_key>/
├── catalog.json
└── PolyToolsRuntimeExports/
    └── <asset_key>/
        └── manifest.json
```

`asset_key` is the deterministic lower-snake-case derivation of the complete
Asset display name. Internal editor Asset IDs never enter the contract.
`catalog.json` schema 1 is the closed authoritative Asset set; consumers must
not discover packages by enumerating directories. An invalid visible Asset is
excluded from the newly published Catalog so it cannot block valid siblings;
its previous complete package is retained on disk but is not advertised until
it validates again. A failed write keeps the previous complete package. All
numbers must be finite.

## Compatibility policy

Catalog `schema_version` must equal `1`; Manifest `schema_version` must equal
`8`. Missing, non-integer, older, or newer versions are rejected as complete
packages. Missing required geometry is an error. Consumers must not synthesize
Fill Meshes, strokes, closed Contour regions, Semantic Keys, hierarchy links,
or referenced Assets.

Schema 8 contains no UV, SDF, mask, contour-domain, padding, or Carrier field.
Those schema-3 concepts are not optional aliases and must not be inferred.

## Catalog

The Catalog requires `world_key`, `world_name`, and `assets`, sorted by
`asset_key`. Every Asset entry requires `asset_key`, `display_name`,
`asset_type`, and the exact World-relative path
`PolyToolsRuntimeExports/<asset_key>/manifest.json` in `runtime_package`.

## Top-level Manifest

Schema 8 requires:

| Field | Type | Meaning |
| --- | --- | --- |
| `schema_version` | integer | Exactly `8`. |
| `asset_key` | non-empty lower-snake-case string | Runtime identity. |
| `display_name` | string | Informational authored name. |
| `asset_type` | string | `character`, `props`, `weapons`, `terrain`, `icon`, or `symbols`. |
| `coordinate_system` | object | Exact convention below. |
| `z_order` | object | Exact convention below. |
| `asset_pivot` | two floats | Asset anchor in meters. |
| `components` | array | Sorted ordinary Components and References. |

```json
{
  "coordinate_system": {
    "dimensions": 2,
    "x_axis": "right",
    "y_axis": "up",
    "unit": "meter",
    "tool_unit_in_meters": 0.1,
    "rotation_unit": "radian",
    "positive_rotation": "counter_clockwise",
    "component_transform": "T(position) * R(rotation) * S(scale) * T(-pivot)"
  },
  "z_order": {
    "scope": "global",
    "back_to_front": "ascending",
    "tie_breaker": "component_id_lexicographic"
  }
}
```

Components are already sorted by ascending `(z_index, component_id)`. Drawing
in that order is the normative overlap rule. Components keep independent
Boundaries; no cross-Component shared-edge merge or epsilon deduplication is
part of the contract.

## Common Component fields

Every Component requires `component_id`, unique `name` in `lower_snake_case`, nullable
`parent_component_id`, integer `z_index`, two-float `component_pivot`, and
`local_transform`:

```json
{
  "position": [0.0, 0.0],
  "rotation_radians": 0.0,
  "scale": [1.0, 1.0]
}
```

Exported authored Component Scale is always `[1,1]`; PolyTools rejects a
non-rebased Asset. Runtime animation may subsequently apply translate, rotate,
or scale to the Component hierarchy. Fill, stroke, and closed region receive
the same complete transform and require no geometry regeneration.

## Indexed Mesh

An indexed Mesh contains `vertices`, an array of local-meter `[x,y]` pairs, and
`indices`, a flat triangle list. Indices are in range, each triangle uses three
distinct vertices, and a non-empty Mesh has a positive multiple of three
indices. Schema 8 carries no UVs, normals, tangents, colors, or materials.

Closed-loop and Primitive Components require `mesh` as their unchanged Fill
Mesh. An open `contour` Component must not contain `mesh`.

## Contour Stroke Mesh

Every ordinary Component requires `contour_stroke_mesh`. It is independent of
the Fill Mesh and requires:

| Field | Type / exact value |
| --- | --- |
| `role` | `"centered_boundary_stroke"` |
| `has_outline` | boolean |
| `vertices`, `indices` | indexed Mesh arrays |
| `reference_pixels_per_meter` | `192.0` |
| `stroke_width_px` | finite positive effective authored value (Component override or World default) |
| `stroke_width_meters` | `stroke_width_px / 192` |
| `centerline` | `"original_authored_boundary"` |
| `inner_offset_meters` | `stroke_width_meters / 2` |
| `outer_offset_meters` | `stroke_width_meters / 2` |
| `join` | `{ "type":"miter", "miter_limit":4.0, "fallback":"bevel" }` |
| `cap` | `"butt"` |
| `topology_role` | `"outer"` or `"hole"` |
| `runs` | ordered visible Boundary runs |

The original PolyTools Boundary is the geometric centerline. The stroke is not
a scaled polygon and is never clipped by `mesh`. Each run requires `run_id`,
ordered `edge_ids`, `closed`, `start_cap`, `end_cap`, and non-negative
`vertex_offset`, `vertex_count`, `index_offset`, and `index_count` ranges into
the combined stroke arrays. Closed uninterrupted runs use `none` caps; every
visible interruption uses butt caps.

`render_outline = false` is permanent authored absence. Hidden Edges split
visible runs and export no triangles for their Boundary interval. If every
Edge is hidden, `has_outline` is `false`, `runs`, `vertices`, and `indices` are
empty, and the Component remains valid. A consumer must draw no outline and
must not generate a fallback.

Primitive Circles and Ellipses are sampled deterministically within the same
certified deviation bound before stroke tessellation. Their exported stroke is
otherwise consumed identically.

## Closed Contour Region Mesh

An ordinary Component with `draw_mode == "contour"` and one closed authored
Chain requires `closed_region_mesh` in addition to its independent
`contour_stroke_mesh`:

```json
{
  "role": "closed_contour_region",
  "vertices": [[0.0, 0.0], [1.0, 0.0], [0.5, 1.0]],
  "indices": [0, 1, 2]
}
```

These are engine-neutral geometric data only. The object contains exactly
`role`, `vertices`, and `indices`; it has no material, color, alpha,
transparency, normal, tangent, UV, stroke, rendering, or Fill property. Runtime
consumers decide independently whether to use it for clipping, collision,
masking, or another geometric purpose. Its presence never means that PolyTools
or a consumer should render a Fill.

Vertices use the same Component-local meters and authored-Pivot subtraction as
the other Runtime Meshes. Indices form a non-empty flat list of finite,
in-range, non-degenerate triangles. The triangulation covers the complete
ordered, simple, closed authored Boundary. PolyTools derives that Boundary with
the same adaptive Bezier centerline sampling used by the Contour Stroke before
Stroke width, offsets, miter/bevel joins, caps, or visible-run subdivision are
applied. It never reconstructs the region from thick Stroke triangles.

`render_outline = false`, including a fully hidden Stroke, does not remove any
Boundary interval from this region. Fewer than three unique Boundary points,
non-finite coordinates, a practically area-less Boundary, self-intersection,
failed or incomplete triangulation, or invalid/degenerate triangle indices are
package-blocking errors. PolyTools retains the prior atomic package on such a
failure rather than omitting the field.

Open Contours must not contain `closed_region_mesh`. Closed-loop and Primitive
Components retain their existing `mesh` and do not receive this additional
field. Asset References also omit it.

## Asset References

An Asset Reference adds `kind: "asset_reference"` and required
`source_asset_key`. It contains neither `mesh`, `contour_stroke_mesh`, nor
`closed_region_mesh`. An
optional finite positive `contour_stroke_width_override_px` is local to the
Reference and applies uniformly to every Contour part in its source Asset; it
never modifies that source Asset.
`name` is its authored identity in the owner Asset and must use
`lower_snake_case`; `source_asset_key`
identifies the instanced source package. Consumers resolve References through
the Catalog, retain the referenced Asset pivot/hierarchy, apply the complete
signed Reference transform as placement, and reject missing packages or
cross-Asset cycles.

## Minimal ordinary examples

Closed Component:

```json
{
  "component_id": "component_6",
  "name": "body",
  "parent_component_id": null,
  "z_index": 0,
  "component_pivot": [0.0, 0.0],
  "local_transform": {"position":[0,0], "rotation_radians":0, "scale":[1,1]},
  "mesh": {"vertices":[[0,0],[1,0],[0,1]], "indices":[0,1,2]},
  "contour_stroke_mesh": {
    "role": "centered_boundary_stroke",
    "has_outline": true,
    "vertices": [[-0.0104167,0],[0.0104167,0],[1,0.0104167]],
    "indices": [0,1,2],
    "reference_pixels_per_meter": 192.0,
    "stroke_width_px": 4.0,
    "stroke_width_meters": 0.0208333,
    "centerline": "original_authored_boundary",
    "inner_offset_meters": 0.0104167,
    "outer_offset_meters": 0.0104167,
    "join": {"type":"miter", "miter_limit":4.0, "fallback":"bevel"},
    "cap": "butt",
    "topology_role": "outer",
    "runs": []
  }
}
```

Open Contour uses the same common and `contour_stroke_mesh` fields but omits
both `mesh` and `closed_region_mesh`. A closed Contour likewise omits `mesh`
but requires the geometry-only `closed_region_mesh` defined above. The example
IDs are illustrative and not reserved constants.
