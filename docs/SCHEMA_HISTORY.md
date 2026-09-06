# PolyTools Schema History

`ARCHITECTURE.md` describes the documents as they are now. This file records
how they got there: every World schema step since 31, the Runtime Manifest
and Sampling algorithm versions beside it, and for each step how a document
written before it is brought to the current schema on load.

## Migration kinds

Loading never rewrites a file; it normalizes what it reads into the current
in-memory model. Three kinds of step exist.

- **Explicit** — a value that already existed was given a new meaning, so the
  migration is gated on the document's `schema_version` and applies only
  below the step. A document at or above the step gets no fallback: the value
  loads as it is or the load fails.
- **Shape** — the old form is recognized by its own type or content, not by
  the version: a scalar where a vector is expected, a retired method name.
- **Additive** — a new field with a default for documents that lack it, or a
  field that is simply no longer read. Nothing to migrate.

A step marked **derived** touches only Bakes or exported data; source
documents are unchanged and older Bakes become stale through their
fingerprints.

## Steps

| Schema | Change | Kind | Code | Fixture |
|---|---|---|---|---|
| 31 | `constrained_delaunay` and `organic_relaxed` consolidated into `constrained_mesh` | shape, derived | `WorldDocumentService.normalize_meshing_bake`, `normalize_geometry_document` | `_test_geometry_meshing_service_and_ui` |
| 32 | Arranged Cut fragments stored; triangulation delegated to CDT | derived | `GeometrySamplingService`, `GeometryMeshingService` | `_test_geometry_sampling_service` |
| 33 | Optimization switch, baseline triangles, Seed movements, quality metrics stored | derived | `normalize_meshing_bake` | `_test_geometry_meshing_service_and_ui` |
| 34 | Editor-only open-curve mode removed; converted to Ribbons | explicit (one-time, done) | — | — |
| 35 | Build provenance; `Update Meshes (N)`; automatic recipe version 3 | derived | `GeometryAutoBuildService` | `_test_geometry_auto_build_service`, `_test_geometry_auto_build_regression_corpus` |
| 36 | Accepted Mesh as sole UV input, UV Padding | derived, Legacy | `normalize_uv_mapping_bake` | `_test_geometry_uv_mapping_service_and_legacy_records` |
| 37 | Derived SDF stage | derived, Legacy | `normalize_sdf_bake` | `_test_geometry_sdf_service_and_legacy_records` |
| Manifest 4 | UV/SDF retired from the build and package path | derived | `RuntimeExportService` | `_test_runtime_export_service` |
| 38 | `semantic_role`; Godot-scene Export retired for `Export Runtime (N)` | additive | — | — |
| 40 | `ribbon` draw mode replaced by fill-less `contour` | **explicit** (< 40) | `normalize_component_draw_mode` | `_test_asset_deserialization_migrations`, `_test_contour_stroke_mesh` (legacy `ribbon_strip` Bakes) |
| 41 | Typed `world_settings` with the shared Contour width | **explicit** (< 41) | `WorldSettingsService.decode` | `_test_world_contour_settings` |
| 42 | Component Scale Rebase; analytic Ellipses | additive | `ComponentScaleRebaseService` | `_test_component_scale_rebase` |
| 43 | Free-form Component names; Semantic Keys migrated | **explicit** (< 43) | `migrated_component_name` | `_test_asset_deserialization_migrations` |
| 45 | Optional Component `contour_stroke_width_px` | additive | `serialized_contour_stroke_width_is_valid` | `_test_asset_deserialization_migrations` |
| 48 | Group `z_index` removed | additive (dropped on load) | `ComponentHierarchy.normalize_asset` | `_test_asset_deserialization_migrations` |
| 49 | Closed Contours; `closed_region_mesh` | additive, derived | `ClosedRegionMeshService` | `_test_closed_contour_region_mesh` |
| 52 | Weapon Guides; Regions as `type: "region"` Components | additive | `AssetGuide.normalize`, `deserialize_component` | `_test_asset_guides` (Weapon frames and Regions), `_test_runtime_export_service` |
| 53 | Asset-root `root_scale` (scalar) | additive | `deserialize_asset_root_scale` | `_test_asset_scale_rebase` |
| 54 | Weapon Guide role `reach_limit_primary`; Manifest 10 | additive | `AssetGuide` | — (no fixture names the role) |
| 55 | Weapon Guide role `grip_secondary`; Manifest 11 | additive | `AssetGuide` | — (no fixture names the role) |
| 56 | Component `projection_depth_cm`; Manifest 15 | additive | `deserialize_projection_depth_cm` | `_test_runtime_export_service`, `_test_inspector_field_wiring` |
| 58 | Asset-root `root_position` | additive | `deserialize_asset` | `_test_asset_scale_rebase` |
| 59 | `root_scale` as a two-axis vector | shape (scalar reads as equal axes) | `deserialize_asset_root_scale` | `_test_asset_deserialization_migrations` |
| 60 | Semantic Regions restored | additive | `deserialize_component` | `_test_runtime_export_service`, `_test_asset_guides` |
| 61 | Regions Component-scoped; `region_geometry_source` | additive (missing reads `authored`) | `normalize_region_geometry_source` | `_test_asset_deserialization_migrations` |
| 62 | `items` Asset type | additive | `normalize_asset_type` | `_test_asset_deserialization_migrations` |
| 63 | Seven Create views merged into `Single`; `editor_state.active_create_submodule` holds a module name | shape (every old view name reads as `Single`) | `main.gd._normalized_create_submodule` | `_test_create_outliner_expansion_scope` |
| 63 | The Outliner Asset filter gates Create as well | **explicit** (< 63) | `main.gd._restore_editor_state` | `_test_create_outliner_expansion_scope` |
| 64 | `set` Asset type; optional `role` on Reference Components | additive (missing role reads unauthored) | `normalize_asset_type`, `deserialize_component` | `_test_set_composition`, `_test_asset_deserialization_migrations` |
| 65 | `palette` Asset type; `palette_variants` and `variant_asset_type` | additive (missing list reads empty, missing category reads `character`) | `normalize_asset_type`, `normalized_palette_variants`, `normalize_variant_asset_type` | `_test_palette_composition`, `_test_asset_deserialization_migrations` |
| Manifest 16 | `contour_stroke_mesh`, `closed_region_mesh`, Attachment Frames, `projection_depth_corners`, `regions` | derived | `RuntimeExportService` | `_test_runtime_export_service` |
| Manifest 17 | required `role` on every `asset_reference`; Palette Manifests with `variants` and `variant_asset_type` | derived | `RuntimeExportService` | `_test_runtime_export_service` |
| 66 | `asset_category` beside `asset_type`; `variant_asset_type` retired | **explicit** (< 66) | `deserialize_asset_category` | `_test_asset_deserialization_migrations` |
| Manifest 18, Catalog 2 | `asset_category` on every Manifest and Catalog entry; `variant_asset_type` gone | derived | `RuntimeExportService`, `AssetCatalogService` | `_test_runtime_export_service`, `_test_asset_catalog_service` |
| 67 | `role` on Reference Components retired: a member's place in its Set is the Reference `name` | shape (a stored role is dropped on load) | `deserialize_component` | `_test_asset_deserialization_migrations` |
| Manifest 19 | `role` gone from `asset_reference`; a member Reference must sit at the Set's root | derived | `RuntimeExportService` | `_test_runtime_export_service` |
| Sampling 6 | Junction-aware Cuts, boundary-namespaced analytic Samples, corner balancing | derived | `GeometrySamplingService` | `_test_geometry_sampling_corner_balancing` |
| Motion 1–18 | Blink `anticipation_share` default 0.18 read as 0.5 | **explicit** (≤ 18) | `normalize_motion_act` | `_test_asset_deserialization_migrations` |

Only six steps are explicit. Every other legacy form is recognized by its
shape or simply defaulted, which is why load-time normalization is one pass
per document rather than a ladder of per-version functions. A row without a
fixture is either a one-time conversion applied to the World data at the
time, with nothing left to read, or — for the two Weapon Guide roles — a gap:
`_test_asset_guides` exercises Weapon frames but names neither role.

## Details

Schema 31 consolidates legacy `constrained_delaunay` and `organic_relaxed`
recipes/bakes into `constrained_mesh`. If both legacy Bakes exist, the accepted
Component Mesh wins, then the active recipe, then a deterministic fallback.
Legacy Organic parameters load as Artistic Character plus exact Advanced
Relaxation overrides. Old mesh results remain readable but stale until rebuilt
with the current constrained-mesh algorithm version.

Schema 32 stores arranged Cut fragments. Sampling owns PSLG junction creation
and clipping against Outer/Holes; Seeding consumes the resulting fragments as
independent barriers. Meshing validates the PSLG and delegates only constrained
triangulation to the pinned `artem-ogre/CDT` GDExtension. PolyTools
continues to own document data, stable IDs, domain filtering, diagnostics,
relaxation, and Cut-seam duplication.

Schema 33 stores the optimization recipe switch plus compact baseline
triangles, accepted Seed movements, and before/after quality metrics. These are
derived diagnostics for the Optimization and Quality views and never become
Component topology.

Schema 34 removes the editor-only open-curve Component mode. Existing World
assets were converted to Ribbons; Ribbon widths normalize to a practical minimum
of 1 px.

Schema 35 stores semantic Component Mesh build provenance in the derived
Geometry document and introduces the persistent `Update Meshes (N)` action.
Automatic recipe version 3 retains version 2's Barde-derived Boundary and Seed
Spacing at `0.55` through the measured normal Character/Symbol range. Beyond
perimeter `60`, Boundary Spacing scales by `sqrt(perimeter / 60)`; Seed Spacing
is independent and is at least `sqrt(area / 750)`, subject to a narrow-feature
cap. The existing 8-to-512 boundary-sample guards still protect very small and
very large contours. This reduces avoidable interior density on Tree-scale
geometry without coarsening smaller Assets. Legacy calibrated profiles migrate
automatically; untouched legacy UI defaults migrate only when both perimeter
and area place a Component clearly beyond the normal Asset range, leaving
small defaults intact. The current behaviour of the automatic build — budgets,
retries, provenance, diagnostics — is described in `ARCHITECTURE.md`.

Schema 36 makes the accepted Component Mesh the sole UV Mapping input. It adds
deterministic UV Padding, exact Vertex-ID mapping validation, Ribbon Strip UV
support, and the persistent `Update UVs (N)` batch. Existing manual recipes are
preserved, pre-schema-36 unpadded Bakes retain Padding `0` and therefore become
stale against the new padded default, and a failed batch attempt never replaces
an older valid UV Bake.

Schema 37 adds a derived single-channel SDF stage after accepted UV Mapping.
`Update SDFs (N)` rasterizes the accepted Mesh triangles in their exact UV space,
derives signed distance from the resulting silhouette boundary, and stores a
linear L8 PNG beside the Component Geometry document. The JSON Bake contains
only compact interpretation metadata, source fingerprints, pixel hash, and the
relative `contour_sdf.png` reference. Missing files and changed Mesh, UV, recipe,
or algorithm inputs make the Bake stale; no image data becomes Component topology.
SDF validation measures UV collapse relative to each Triangle's own longest-edge
scale. It rejects truly collinear mappings without misclassifying small,
well-shaped normalized UV Triangles as degenerate. Its failure-retry signature
is versioned independently from the pixel algorithm, allowing repaired
validation failures to retry without invalidating every accepted SDF image.

Runtime Manifest schema 4 later retires UV/SDF from the active build and
package path, and the UV Mapping Workspace, Inspector, and the `Update UVs (N)`
and `Update SDFs (N)` batches have since been removed. What remains is the
Legacy data path: `GeometryUVMappingService` and `GeometrySDFService` plus the
document normalization and serialization for their records. Existing UV and SDF
Bakes and their `contour_sdf.png` files load, round-trip, and save unchanged;
nothing generates new ones and nothing deletes or reinterprets the old ones.

Schema 38 adds the Component-level `semantic_role` field. It retires the
standalone Godot-scene Export workspace in favor of the persistent
`Export Runtime (N)` batch, which automatically considers every visible Asset,
and introduces the shared `Pending` / `Needs attention` batch summary and the
`BatchStatusButton` attention point described in `ARCHITECTURE.md`.

Schema 40 replaces the authored `ribbon` draw mode with the fill-less open
`contour` mode. Loading schema 39 or older converts Ribbon centerline topology
explicitly; current-schema Ribbon values are invalid and receive no fallback.
Component-local Ribbon widths are discarded. Legacy `ribbon_strip` Bakes remain
readable records but are never current for a Contour and must be rebuilt as
`contour_stroke`. Schema 40 retains the schema-39 free-form Component names.

Schema 41 renames the toolbar surface to `World Settings` and introduces one
typed authored default Contour width shared by every Asset. The required
`world_settings` record fixes reference density at `192 px/m` and stores a
finite positive `contour_stroke_width_px`, defaulting to `4 px` for new Worlds.
Schema 40 and older Worlds migrate explicitly to that default; schema-41 data
never receives a silent missing/invalid-value fallback. World-width changes
invalidate only inheriting Contour Meshes.

Schema 42 adds atomic Asset-level Component Scale Rebase and analytic Ellipses.
The service bakes finite, non-zero signed Scale into owned Bézier geometry,
resolved handles, Component-scoped Guides, or primitive axes around the
unchanged Pivot before setting local Scale to `(1, 1)`. Negative axes preserve
Mirror reflections in source geometry; analytic primitive diameters remain
positive. A parent Rebase compensates direct Child local transforms to preserve
the Child subtree's visible world transform. Zero/non-finite Scale blocks the
whole operation. See [`SCALE_REBASE.md`](SCALE_REBASE.md).

Schema 43 restores free-form Component names. New and renamed names use
`lower_snake_case`; the vocabulary remains unrestricted. Existing names are
preserved; the older Semantic Key fields (`semantic_key`,
`missing_semantic_source`, `semantic_role`) are used only as a deterministic
one-time migration fallback for documents below schema 43, and
case-insensitive name collisions receive numbered suffixes in document order.
From schema 43 on a Component without a name loads as `Component` and is not
renamed from a leftover key. Asset References retain their internal
`source_asset_id`; runtime export resolves that link to `source_asset_key`.

Schema 45 permits an optional finite positive `contour_stroke_width_px` on
each Component. An ordinary Component inherits the World default when the
field is absent or equal; a differing value is its implicit local override.
A non-finite or non-positive persisted value is ignored on load. The
effective width participates in Contour Mesh fingerprints and build
signatures, so downstream Bakes become stale without changing Component
topology.

Schema 48 removes `z_index` from editor-only Group records. Each Component is
the sole owner of its integer `z_index`; legacy Group layer values are ignored
on load and are not written again.

Schema 49 permits a fill-less `contour` Component to own either one open Chain
or one closed Chain. Closed Contours retain only their centered Stroke as the
visible Component Mesh and never request or export a Fill Mesh. Their accepted
Contour build also carries a separate derived Boundary triangulation for
Runtime `closed_region_mesh`; hidden Stroke runs do not remove any part of that
complete region.

World schema 52 distinguishes visual Components, curve-based spine Guides,
transform-based Weapon Guides, and optional semantic Regions. A Weapon Guide
stores a stable role, Component-or-Group scope, and a local position/rotation
frame; non-uniform scale is inherited from its scope and is never authored on
the frame. The shared add menu contains `Guide → Weapon → weapon_socket_primary
| grip_primary | grip_secondary | attack_point_primary | reach_limit_primary`.
A Region is stored as a nonvisual `type: "region"` Component backed by
canonical `points`, `edges`, and `chains`; it is excluded from visual Mesh
processing and exported in the separate Runtime `regions` array.

World schema 53 adds an authoring-only, positive Asset-root Scale, at first as
one scalar, exposed in the Asset root's `Asset Transform` Inspector. Canvas
presentation prefixes every Asset-space transform with that scale around the
unchanged Asset Pivot, while inspector fields continue to expose canonical
source coordinates. The atomic Root Scale Rebase multiplies each local
translation, owned Bézier coordinate/handle, primitive axis, Guide coordinate,
and Weapon-frame translation exactly once per axis. Root placements are scaled
around the Asset Pivot; nested placements are scaled around their local origin.
Reference geometry uses its instance scale, so its transform Pivot remains
unchanged during the bake. Component Scale is not modified, keeping schema
42's independent Component Scale Rebase valid before or after this operation.
Non-default Motion is an explicit blocker. Accepted derived data is not
rewritten and becomes stale through its existing source fingerprints. Runtime
Export blocks while the scale is not `1`; it never applies the scale silently.

World schema 54 extends transform-based Weapon Guides with
`reach_limit_primary`. It shares the existing frame data, scope inheritance,
Canvas gizmo, Inspector, history, Scale Rebase, and persistence paths; it does
not infer its position from a visual Component, and marks an Asset-local
maximum reach endpoint independently from visual Component names or pivots.
Runtime Manifest schema 10 exports this fourth optional Attachment Frame role
and rejects schema 9.

World schema 55 extends transform-based Weapon Guides with `grip_secondary`.
It is a second weapon-local hand-contact frame for an attack regrip and stays
semantically distinct from the character-owned `weapon_socket_primary`, the
carried `grip_primary`, and the maximum endpoint `reach_limit_primary`.
Runtime Manifest schema 11 exports this fifth optional Attachment Frame role
and rejects schema 10.

Schema 56 adds a visible-Component-only `projection_depth_cm` authoring field.
It defaults to `10 cm`, is persisted and exported independently of Component
and Asset Scale, and is not owned by Groups or the Asset root. Runtime Manifest
schema 15 carries the metric `projection_depth_meters` value and ordered
local-meter `projection_depth_corners` for authored Bézier points in `corner`
handle mode.

World schema 58 adds an authoring-only Asset-root Position. Canvas presentation
prefixes Asset-space transforms with translation followed by the existing
independent X/Y scale around the Asset Pivot. The shared atomic Asset Transform
Rebase adds translation exactly once to root-scoped Components, Groups, Asset
Guides, and Weapon frames while preserving nested local placement, resets Root
Position to zero, and also normalizes Root Scale as described above. The Asset
Pivot is not moved by the bake. Runtime Export rejects either pending root
transform instead of applying it silently.

World schema 59 persists Asset-root `root_scale` as a two-axis vector and
exposes separate `Scale X` and `Scale Y` Inspector controls. Legacy scalar
root scales load as equal axes; Runtime Export requires both axes to be `1`.

World schema 60 restores optional semantic gameplay Region records. They reuse
the canonical `points`/`edges`/`chains` Bézier topology, remain outside visual
Mesh processing, and are exported separately from ordinary Components.
Existing documents without Regions remain valid and consumers retain their
existing Component-based fallback behavior.

World schema 61 makes every Region Component-scoped, restricts Region creation
to a Component's `+` menu, and adds the normalized `region_geometry_source`
discriminator. `authored` reads the Region's own canonical topology;
`component` resolves `parent_component_id` as the live geometry owner while
leaving the authored topology dormant and intact, so switching back is
lossless. Newly created Regions default to `component`; missing legacy values
normalize to `authored`. The Canvas receives only the resolved view copy,
authoring commands are guarded in `main.gd`, drawing and Bézier editing are
disabled while the Component source is active, and Runtime export emits a
binding rather than copied geometry.

World schema 62 adds the `items` Asset type and its `Items` Create view. Items
use the same document, authoring, derived Mesh, Style, and Runtime Export paths
as every other Asset type, without introducing a second geometry model.

World schema 63 merges the seven Create views into the one `Single` view. No
Asset document changes: `asset_type` keeps its seven values, stays persisted
and stays exported; what it no longer does is open a view of its own. The type
is chosen in the New Asset dialog and corrected on the Asset root in the
Inspector, and the Outliner search plus the shared multi-select Asset filter
select among the types.

Two things in `editor_state` follow. `active_create_submodule` now holds a
Create module name; each of the seven old view names, and any unknown value,
reads as `Single` by its own shape, without a version gate. The Asset filter
is the explicit step: below 63 it gated Mesh and Style only, so a World could
be saved with every type switched off — `worlds/world01` was — and that state
would read as an empty Create module. Loading a World below 63 therefore
restores all seven filter entries exactly once. From 63 on the saved filter is
authoritative in Create as well and receives no fallback.

World schema 64 adds the `set` Asset type and the optional `role` on Reference
Components. A Set is an Asset whose visible Components are References to its
members: the assembly needs no new document, because the Reference already
carries which member, where it sits and in what order. The role is the one
thing it did not carry — `source_asset_key` says which member, not what it
stands for — and a Set may fill one role twice while a Component name is unique
per Asset, so the two cannot be the same field. It is free `lower_snake_case`
and normalizes on load; empty means unauthored, and Runtime Export then reads
the member's own Asset Key.

Both are additive. No existing document changes: every Asset keeps one of the
seven types, and a Reference without a role loads without one. `ASSET_TYPES`
gains `set` while the new `SINGLE_ASSET_TYPES` keeps the seven that the Asset
filter and the New Asset dialog offer, so a Set never appears in Mesh, Style or
the Single view.

World schema 65 adds the `palette` Asset type with `palette_variants` and
`variant_asset_type`. A Palette is the smallest form that says what it is: a
list of interchangeable Assets and the one ordinary category they share. It has
no Components, no geometry and no arrangement, which is why its variants are
plain Asset IDs rather than References — a Reference carries a transform, a
pivot, a z-index and a depth, and a Palette would have to define every one of
them away. The list drops blanks and repeats on load, because order and
multiplicity mean nothing among things that stand in for each other.

Additive as well. No existing document changes: an Asset that is not a Palette
loads with an empty variant list, and a category that is missing or names a
composition reads `character`, the same fallback `asset_type` uses.

World schema 66 separates what an Asset is from how it is composed. Schemas 64
and 65 had put `set` and `palette` into `asset_type`, which left both without a
category of their own: a Bridge could not also be props, and a Palette needed
`variant_asset_type` to say what its variants were. From 66 the two are
independent fields — `asset_type` is the seven again, `asset_category` is
`single`, `set` or `palette` — a Bridge is props and a Set, and a composition's
own type is the type of everything it owns, so `variant_asset_type` is gone and
a Set's members share its type the same way a Palette's variants do.

This is the explicit step of the series. Below 66 an `asset_type` of `set` or
`palette` is read as the category; the type it displaced cannot be recovered
and falls back to `character` the way a missing type always has, so a Set or
Palette authored under 64 or 65 loads as a Character and is corrected in the
Inspector. From 66 on neither field substitutes for the other. Every Asset that
never was a composition is untouched: it keeps its type and reads `single`.

Runtime Manifest schema 18 and Asset Catalog schema 2 carry the pair across the
boundary. Every Manifest and every Catalog entry has both `asset_type` and
`asset_category`, so a consumer can tell a Palette from a placeable Asset
without opening its package, and `bridge` and `grass` keep the types world01
already expects. `variant_asset_type` is gone from the Manifest with the field
itself.

Schema 67 retires the `role` field on Reference Components. What a member is
called in its Set is the Reference's own `name`: derived from the member's name
when the member is made, unique inside the Set, editable, and unchanged by a
later rename of the member Asset — which is exactly what an authored role was
for. A stored `role` is dropped on load rather than migrated; no World authored
one. Runtime Manifest schema 19 drops `role` from every `asset_reference` to
match, so an assembly is read from `name` and `source_asset_key` instead of from
three strings that said the same thing, and it additionally rejects a member
Reference that does not sit at the Set's root: a Set is a flat assembly, not a
tree of members.

Runtime Manifest schema 17 carries what the two compositions must say across
the boundary, and nothing more. An `asset_reference` gains a required
`lower_snake_case` `role`; where none was authored it is the member's own
`source_asset_key`, so a consumer reads the assembly instead of guessing it. A
Palette exports the one Manifest without geometry: `variants`, the sorted,
unique Asset Keys that may stand in for one another, and `variant_asset_type`,
the ordinary category they share, with `components`, `attachment_frames` and
`regions` present and empty.

Export is where a Palette variant is checked, not load. A variant that carries
gameplay Regions or Attachment Frames, is hidden, is missing, or is not of the
declared category invalidates the Palette — never the variant, which stays a
valid package of its own. `Surface`, placement rank and every other
consumer-side gameplay property live outside PolyTools and are explicitly not
checked; `RUNTIME_EXPORT_CONTRACT.md` says so, so that no consumer assumes a
guarantee that was never made.

Runtime Manifest schema 16 exports `contour_stroke_mesh` independently from
the unchanged Fill Mesh and adds geometry-only `closed_region_mesh` to closed
Contours. It also exports Asset-local Weapon Attachment Frames, the ordered
local-meter positions of authored `corner` points as
`projection_depth_corners`, and an optional `regions` array. It contains no
UV, SDF, mask, or Carrier compatibility fields; older consumers must reject it.

Sampling results carry their own algorithm version independently of the
World schema. Version 6 retains junction-aware Cut arrangement and namespaces
analytic Samples by resolved boundary, preventing collisions when one Hole
Reference contains multiple Primitives. It additionally balances abrupt
derived segment-length transitions at authored Bézier corners, resolves
source-to-source and closing intervals from explicit Chain topology, and
rejects spatially degenerate midpoint insertions without changing canonical
topology. Older Sampling Bakes become stale before Seeding or Meshing can
consume incompatible constraint identities.

Motion Act documents at schema 1 through 18 wrote a Blink `anticipation_share`
default of `0.18`; that exact value is read as the later default `0.5`, while
any other authored value is kept.
