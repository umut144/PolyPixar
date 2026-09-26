# PolyTools Runtime Export Contract

**Status:** Normative consumer contract for Asset Catalog schema `3` and
runtime Manifest schema `23`.

This document is the sole field-level contract for PolyTools Runtime packages.
Manifest schema 23 replaces schema 22 and Catalog schema 3 replaces schema 2.
Consumers must reject older schemas; there is no SDF/Carrier/UV compatibility
fallback.

## Package boundary

`Export Runtime` writes one atomic package per currently valid visible Asset:

```text
res://worlds/<world_key>/
├── catalog.json
└── PolyToolsRuntimeExports/
    └── <asset_key>/
        └── manifest.json
```

Both `catalog.json` and `PolyToolsRuntimeExports/` are generated, and both are
outside the source history: consumers read them from the working directory
through `POLYTOOLS_WORLD_DIR`, not from Git. **A fresh clone therefore has
neither. Run `Export Runtime` once before the first Consumer Sync**, otherwise
the sync finds no Catalog and no packages. The Export preflight names what is
missing — a fresh clone lists every Asset plus `World Catalog — catalog.json
missing or stale` as pending.

An Asset is published under two names, because readable and stable are two
different jobs and one field cannot do both.

`asset_key` is the deterministic lower-snake-case derivation of the complete
Asset display name. It names the package directory, reads well in a log and in
a hand-written file, and **follows a rename**: rename the Asset and the Key,
the directory and the Catalog entry all move with it.

`asset_id` is the identity. It is stable across every rename, it is opaque —
the current `asset_N` shape is not a promise and must not be parsed — and it is
unique within its World and never handed out twice, not even after the Asset it
belonged to was deleted. Anything a consumer stores and expects to resolve
later belongs on the ID; the Key belongs where a person reads it.

This replaces the earlier rule that internal editor IDs never cross the
boundary. That rule protected readability, and readability is still protected —
by the Key, which is unchanged. What it also did, unintentionally, was make
identity a function of a label, so every rename broke every consumer that had
written a Key down. The ID is published to end that, not to replace the Key.
`catalog.json` is the closed authoritative Asset set; consumers must
not discover packages by enumerating directories. An invalid visible Asset is
excluded from the newly published Catalog so it cannot block valid siblings;
its previous complete package is retained on disk but is not advertised until
it validates again. A failed write keeps the previous complete package. All
numbers must be finite.

The editor's schema-53 `root_scale` (two axes; legacy scalar values are
normalized to equal axes) and schema-58 `root_position` are authoring state
only and are never part of a Runtime Manifest. They must be rebased to
exactly `1` and `(0, 0)` before export; Runtime Export rejects either pending
Root Transform instead of silently changing package placement or dimensions.

## Compatibility policy

Catalog `schema_version` must equal `3`; Manifest `schema_version` must equal
`23`. Missing, non-integer, older, or newer versions are rejected as complete
packages. Missing required geometry is an error. Consumers must not synthesize
Fill Meshes, strokes, closed Contour regions, Semantic Keys, hierarchy links,
or referenced Assets.

Schema 21 contains no UV, SDF, mask, contour-domain, padding, or Carrier field.
Its optional `regions` array contains authored or Component-bound Attack, Hurt,
Collision and Destructible geometry; consumers may use it and must retain their Component
fallback when it is empty.

## Catalog

The Catalog requires `world_key`, `world_name`, `assets` sorted by `asset_key`,
and `retired_assets`. Every Asset entry requires `asset_key`, `asset_id`,
`previous_keys`, `display_name`, `asset_type`, `asset_category`, and the exact
World-relative path `PolyToolsRuntimeExports/<asset_key>/manifest.json` in
`runtime_package`. `asset_category` lets a consumer tell a Palette from a
placeable Asset without opening its package.

`previous_keys` holds the Keys an Asset carried before its current one, oldest
first. It exists for consumers whose own files name Assets by Key on purpose —
hand-written design data, where an opaque ID would age into a lie no tool
refreshes. A consumer that finds a Key it does not recognize may look here and
learn which Asset now answers to another name. **A live `asset_key` always wins
over any `previous_keys` entry**: a Key that has been taken over by another
Asset names that Asset, not the one that used to hold it.

A Key is not handed out twice either. The Key a deleted Asset carried last, and
every Key still published under some Asset's `previous_keys`, are refused for a
new or renamed Asset — an author may release one of those `previous_keys`
entries in PolyTools, which stops publishing it and frees the Key again — a Key that once meant something must not quietly come to
mean something else, and a consumer that wrote a Key down without an ID beside
it cannot tell the difference. Keys that never existed in this Catalog are
outside that guarantee: a consumer whose own vocabulary overlaps with a Key
PolyTools may coin later has to keep them apart itself.

`retired_assets` holds `{asset_id, last_asset_key}` for every ID the World has
withdrawn. It is what separates "this Asset was deleted" from "this package is
missing and the sync is broken" — without it the two are the same absence. A
retired ID is never issued again.

## Top-level Manifest

Every Manifest except a Palette requires:

| Field | Type | Meaning |
| --- | --- | --- |
| `schema_version` | integer | Exactly `23`. |
| `asset_key` | non-empty lower-snake-case string | Readable handle; follows the display name. |
| `asset_id` | non-empty opaque string | Stable identity; never reused, not even after deletion. |
| `display_name` | string | Informational authored name. |
| `asset_type` | string | What the Asset is: `character`, `props`, `weapons`, `terrain`, `items`, `icon`, or `symbols`. |
| `asset_category` | string | How it is composed: `single`, `set`, or `palette`. |
| `presentation` | object | Required Asset-level presentation metadata. |
| `coordinate_system` | object | Exact convention below. |
| `z_order` | object | Exact convention below. |
| `asset_pivot` | two floats | Asset anchor in meters. |
| `components` | array | Sorted outer Components, outer References, and Hole Components; a Hole Reference is omitted. |
| `attachment_frames` | array | Oriented Asset-local Weapon attachment frames. |
| `regions` | array | Optional authored or Component-bound gameplay Regions. |

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
    "component_transform": "T(position) * R(rotation) * S(scale); vertices are pivot-relative"
  },
  "z_order": {
    "scope": "global",
    "back_to_front": "ascending",
    "tie_breaker": "component_id_lexicographic"
  }
}
```

`presentation` contains exactly one field:

```json
{
  "presentation": {
    "authored_facing": "left"
  }
}
```

`authored_facing` is always one of `left`, `right`, `neutral`, `top`, or
`down`. It records the direction in which the source artwork was originally
drawn. PolyTools exports it explicitly, including `neutral`; consumers must not
infer geometry mirroring, transform changes, or Canvas behavior from it.

Components are already sorted by ascending `(z_index, component_id)`. Drawing
in that order is the normative overlap rule within this Asset. `z_index` is an
asset-local semantic ordinal, not an absolute engine or game-world depth. The
`z_order.scope = "global"` value means that the order spans all Components in
this one Manifest rather than resetting per hierarchy branch. A consumer may
map adjacent values into a contextual local range, such as `1.00`, `1.01`, and
`1.02`, and place that complete range before or behind another Asset as long as
the authored internal order is preserved. Components keep independent
Boundaries; no cross-Component shared-edge merge or epsilon deduplication is
part of the contract.

## Attachment Frames

`attachment_frames` contains transform Guides authored through
`Guide → Weapon`. Each record contains exactly `frame_id`, `role`, and
`asset_transform`. `role` is one of `weapon_socket_primary`, `grip_primary`,
`grip_secondary`, `attack_point_primary`, or `reach_limit_primary` and may occur
at most once per Asset. `grip_secondary` marks a second weapon-local hand
contact for an attack regrip; it remains distinct from the character-owned
socket and carried primary grip. `reach_limit_primary` marks an authored maximum reach endpoint;
consumers must not infer it from visual Component names or pivots.
`asset_transform`
contains a two-float meter `position` and counter-clockwise
`rotation_radians`. Component- and Group-scoped editor transforms are resolved
to Asset space during export; scale is inherited while authoring but is not an
independent Frame property.

## Gameplay Regions

`regions` is always present in schema 23 and may be empty. Every record contains
`region_id`, `name`, `role`, `geometry_source`, and `source_component_id`;
`role` is one of `attack`, `hurt`, `collision`, or `destructible`.

`destructible` (since schema 23) marks the surface through which a placed,
stationary Asset — a Totem, for example — can be hit and destroyed. It is
separate from `hurt`, which belongs to Characters. PolyTools publishes only the
surface; health, damage and what destruction means are decided by the
consumer. An Asset without a `destructible` Region is not destructible.

Region visibility is an Outliner convenience and never selects what is
exported. A Region is nonvisual in every consumer, so a hidden one would
leave a gameplay surface out of the package while looking authored in the
editor, and no consumer can tell that apart from a Region that never
existed. A hidden Region is therefore an export error, not a silent
omission, unlike a hidden Component, which is simply not part of the Asset.

With `geometry_source: "authored"`, the record additionally contains
`vertices` and `indices`. Vertices are triangulated Asset-local meter
coordinates from the Region's own Bézier topology.

With `geometry_source: "component"`, the record contains no vertices or
indices. `source_component_id` identifies a Component in the same Manifest,
which may be an outer Asset Reference: a Reference stands in the hierarchy
where a Component would, so it carries Regions like one. A Reference owns no
Mesh itself, so a consumer resolves its geometry through `source_asset_key`
and the Components of the Asset it instances, placed by the Reference's own
transform. A Reference authored as a Hole carries nothing, because it is not
published at all. The consumer uses that Component's `mesh`, or its
`closed_region_mesh` when it is a closed Contour, after applying the same
current animation and deformation evaluation used for presentation. This is a
live binding rather than an exported geometry snapshot; collision and gameplay
systems must therefore consume the CPU-visible deformed result when visual
deformation is implemented in a shader.

A consumer should use Regions when the relevant role is present and retain its
existing Component-based geometry fallback otherwise.

## Common Component fields

Every ordinary Component requires `component_id`, unique `name` in `lower_snake_case`, nullable
`parent_component_id`, integer `z_index`, finite non-negative
`projection_depth_meters`, `projection_depth_corners`, two-float
`component_pivot`, and `local_transform`:

```json
{
  "position": [0.0, 0.0],
  "rotation_radians": 0.0,
  "scale": [1.0, 1.0]
}
```

### Placing a Component

The `component_transform` string above is the transform a consumer applies.
Every exported vertex array - `mesh`, `closed_region_mesh`,
`contour_stroke_mesh` and `projection_depth_corners` - is relative to the
Component's authored pivot: PolyTools has already subtracted it, so there is no
`T(-pivot)` left to apply. Until the Manifest 23 packages exported on
2026-09-15 the string still read `... * T(-pivot)`, describing the authored
Component before that subtraction; the numbers were the same. A consumer
places an exported vertex `v` with

```text
asset_local(v) = Parent(...) * T(position) * R(rotation) * S(scale) * v - asset_pivot
```

where `Parent(...)` is the same product for each ancestor along
`parent_component_id`, and `position`, `rotation_radians` and `scale` come from
`local_transform`. `component_pivot` is not a term of this formula: it is a
derived, read-only value, the Component's origin (its authored pivot) in
Asset-local meters after `- asset_pivot`, i.e. `asset_local([0, 0])`. A
consumer may use it as an anchor, for example to rotate a body about its pivot,
but subtracting it from the vertices moves the Component a second time.

Worked example, `card` / `mana_glyph03`, child of `body` whose
`local_transform` is the identity: `local_transform.position`
`(-0.275, 0.425)`, vertices within `±0.025` of `(0, 0)`, `asset_pivot`
`(0, -0.45)`. The glyph lands around `(-0.275, 0.425) - (0, -0.45) =
(-0.275, 0.875)`, the top-left of the card, which is also its
`component_pivot`. Applying `T(-component_pivot)` as well would move it to
`(0, 0)`, the bottom centre.

Since 2026-09-26 the editor treats the Pivot as a fixed anchor: moving a
Component moves its shape against that anchor, and moving an Asset moves it
against `asset_pivot`, neither of which drags the anchor along. Nothing about
the schema or these formulas changes — `position` was always the Pivot's
position and the vertices were always pivot-relative — but the offset between a
Component's drawing and its `component_pivot` is now authored deliberately
rather than incidentally, so a consumer that anchors on `component_pivot` sees
what the artist placed there.

Exported authored Component Scale is always `[1,1]`; PolyTools rejects a
non-rebased Asset. Runtime animation may subsequently apply translate, rotate,
or scale to the Component hierarchy. Fill, stroke, and closed region receive
the same complete transform and require no geometry regeneration.

## Projection Depth Corners

`projection_depth_corners` is an ordered array of authored Bézier Points whose
handle mode is `corner`:

```json
"projection_depth_corners": [
  {"point_id":"point_123", "position":[0.25,-0.10]}
]
```

Each item contains exactly a non-empty stable `point_id` and a finite local-meter
`position`. Positions use the same authored-Pivot subtraction as Component Mesh
vertices. The array follows authored Chain order and may be empty. No point in
another handle mode (`linear`, `aligned`, `free`, or `mirrored`) appears in this
field. It expresses only where a consumer may draw a contour edge through a
Component's authored projection depth; it does not define a mesh, material,
rendering policy, or gameplay geometry. Asset References omit this field and
resolve any such data from their source package.

## Indexed Mesh

An indexed Mesh contains `vertices`, an array of local-meter `[x,y]` pairs, and
`indices`, a flat triangle list. Indices are in range, each triangle uses three
distinct vertices, and a non-empty Mesh has a positive multiple of three
indices. Schema 11 carries no UVs, normals, tangents, colors, or materials.

Closed-loop and Primitive Components require `mesh` as their unchanged Fill
Mesh. An open `contour` Component must not contain `mesh`.

## Contour Stroke Mesh

Every ordinary Component requires `contour_stroke_mesh`. It is independent of
the Fill Mesh and requires:

| Field | Type / exact value |
| --- | --- |
| `role` | `"boundary_stroke"` |
| `alignment` | `"centered"`, `"inside"`, or `"outside"` |
| `has_outline` | boolean |
| `vertices`, `indices` | indexed Mesh arrays |
| `reference_pixels_per_meter` | `192.0` |
| `stroke_width_px` | finite positive effective authored value (Component override or World default) |
| `stroke_width_meters` | `stroke_width_px / 192` |
| `centerline` | `"original_authored_boundary"` |
| `inner_offset_meters` | how far the Stroke reaches toward the material side |
| `outer_offset_meters` | how far it reaches away from it |
| `join` | `{ "type":"miter", "miter_limit":4.0, "fallback":"bevel" }` |
| `cap` | `"butt"` |
| `topology_role` | `"outer"` or `"hole"` |
| `runs` | ordered visible Boundary runs |

The original PolyTools Boundary is the geometric centerline of record whatever
the alignment does; the two offsets say where the width actually went. A
`centered` Stroke reports half the width on each side, `inside` the full width
as the inner offset and zero as the outer, and `outside` the reverse. Only a
closed Boundary encloses a side to point at, so an open Contour always exports
`centered`. The stroke is not a scaled polygon and is never clipped by `mesh`. Each run requires `run_id`,
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

## Compositions

`asset_category` says how an Asset is composed, independently of what
`asset_type` says it is. Neither composition requires a consumer to learn a new
package shape.

A **Set** — `asset_category: "set"` — is an ordinary Manifest whose Components
are all `asset_reference` records sitting at the Manifest root, and every member
is an Asset of the Set's own `asset_type`. A Set publishes which Assets belong
together and, through each Reference's required `role`, what every member
stands for in it. `source_asset_key` says which Asset fills that role, and
`name` is the Reference's identity inside the Set.

The role is the only one of the three a consumer cannot work out for itself.
`source_asset_key` and `name` both follow a rename of the member Asset — the Key
by derivation, the `name` because it is derived from the member and kept in step
— so neither says what a member is *for*. The role is authored, never derived
and never rewritten: rename `deck` to `plank` and the plank of the bridge is
still the plank of the bridge. It is `lower_snake_case`, it may repeat within a
Set where one role is filled twice, and Runtime Export rejects a Set whose
member carries none rather than inventing one. Its Component transforms are ordinary
exported transforms in the Set's own space and say **nothing about placement in
a world**. Where members lie centered on their own pivot, that is exactly what
it is: not an arrangement, but the precondition for a placing source to set
them itself. A consumer that already resolves Asset References needs nothing
further.

A **Palette** — `asset_category: "palette"` — is the one Manifest without
geometry. It publishes the Keys that may substitute for one another; every one
of them is an Asset of the Palette's own `asset_type`:

```json
{
  "schema_version": 23,
  "asset_key": "grass",
  "display_name": "Grass",
  "asset_type": "terrain",
  "asset_category": "palette",
  "variants": ["grass01", "grass02", "grass03", "grass04"],
  "presentation": {"authored_facing": "neutral"},
  "coordinate_system": { },
  "z_order": { },
  "asset_pivot": [0.0, 0.0],
  "components": [],
  "attachment_frames": [],
  "regions": []
}
```

`variants` is non-empty, sorted, and holds unique `lower_snake_case` Asset Keys
that the Catalog also lists as packages of their own; each variant Manifest is
an ordinary `asset_category: "single"` Manifest of the same `asset_type`.
`components`, `attachment_frames` and `regions` are present and empty. No other
Manifest carries `variants`.

A variant is chosen by the presentation, independently per client. Which
variant is shown is not an authoritative statement: nobody has to agree on it,
neither server and client nor two clients with each other. It may look the same
everywhere; it has to match nowhere. That is why a variant carries nothing
anyone would have to agree on. PolyTools enforces the
part it owns and rejects the Palette — not the variant — when a variant has
gameplay Regions or Attachment Frames, is hidden, is missing, or is not of the
Palette's `asset_type`. **`Surface`, placement rank and every other consumer-side
gameplay property are outside PolyTools and are not checked here.** A consumer
that owns such properties must assert their absence itself, against this same
`variants` list. The list is also the authority for which Keys are not placed
on their own: a variant is reached by choosing it for a Palette, never by
naming it in a map.

An invalid Palette is excluded from the newly published Catalog like any other
invalid Asset, and its variants remain valid packages of their own.

## Asset References

Only a Reference with the `outer` topology role is published. A Reference
authored as a Hole is a constraint and nothing else: its boundary has already
left the parent Component through Sampling and Meshing, so publishing it a
second time as an Asset Reference would draw the referenced Asset back over
the hole it cut.

An ordinary Hole Component is published, and only its Stroke is. Its boundary
has likewise already left the parent through Sampling and Meshing, so it
carries no `mesh` of its own — the same shape a Contour exports — but the edge
it cut is drawn, at its own authored width and alignment, with its own
`z_index` and visibility. Nothing may be parented beneath it: a Hole is a cut
in someone else's body and never a body of its own, and a Runtime Component
naming one as its Parent fails the export.

An Asset Reference adds `kind: "asset_reference"`, a required
`source_asset_key` and the required `source_asset_id` of the Asset it
instances — the Key for reading, the ID for pointing. Without the ID a Set's
`role` would be stable while what it points at still followed a rename, which
would leave the break standing in the one place the Role was meant to close. In
a Set Manifest the Reference also carries the required `lower_snake_case`
`role` described under **Compositions**; elsewhere a Reference is a member of
nothing and carries none. It contains neither `mesh`, `contour_stroke_mesh`, nor
`closed_region_mesh`, but retains its local `projection_depth_meters` value.
An
optional finite positive `contour_stroke_width_override_px` is local to the
Reference and applies uniformly to every Contour part in its source Asset; it
never modifies that source Asset.
`name` is its authored identity in the owner Asset and must use
`lower_snake_case`; `source_asset_key`
identifies the instanced source package. Consumers resolve References through
the Catalog, retain the referenced Asset pivot/hierarchy, apply the complete
signed Reference transform as placement, and reject missing packages or
cross-Asset cycles.

A Reference may act as a Sampling Hole for its direct Parent. It still exports
the same `asset_reference` instance and owns no duplicated Fill, Contour Stroke,
or closed-region geometry. In contrast, an ordinary Component with
`topology_role: "hole"` is an authoring-only constraint and is omitted from the
Runtime Component array.

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
