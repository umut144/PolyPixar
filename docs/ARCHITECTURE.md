# PolyTools Architecture

## Product shell

`scripts/main.gd` composes the editor shell and routes user intent between the
Outliner, canvas/workspaces, Inspector, persistence, and export. The left rail
contains always-expanded Create, Mesh, and Style categories. A single
`active_module` plus its category-specific submodule identifies the one active
workspace.

Create has three modules. `Single` is one database view over the Asset
implementation; `Set` and `Palette` are compositions above it.

What an Asset is and how it is composed are two questions, so they are two
persisted fields. `asset_type` — `character`, `props`, `weapons`, `terrain`,
`items`, `icon`, `symbols`, normalizing to `character` — says what kind of
thing it is, and is authored in the New Asset dialog and corrected on the Asset
root. `asset_category` — `single`, `set`, `palette`, normalizing to `single` —
says how it is put together, and it alone picks the Create module. A Bridge is
therefore `props` **and** a Set, and a Grass Palette is `terrain` **and** a
Palette, which is also the type of every one of its variants. The composition
is fixed when the Asset is created and is not switched afterwards: changing it
would leave members or variants in an Asset with no place for them.

A **Set** is an Asset with `asset_category: "set"` whose visible Components are
Asset References to its members. Nothing new is persisted for the assembly: the
Reference already carries which member (`source_asset_id`, exported as
`source_asset_key`), where it sits in the Set's own space (its own transform,
canonicalized at export) and in what order (`z_index`). That space is authoring
space: `RUNTIME_EXPORT_CONTRACT.md` states that a Set's transforms say nothing
about placement in a world, because members are authored centered on their own
pivot so that a placing consumer sets them itself. Nothing is added for the role either: the
Reference's own `name` is its identity inside the Set: derived from the member's
name when the member is made, unique there, and editable. A Reference whose name
is still the source Asset's own Key follows a rename of that Asset
(`_follow_reference_rename`), because two names disagreeing about the same thing
help nobody and the Key moved anyway.

What a member stands for is a separate field, `role`, precisely because the name
follows. It is authored — suggested from the name while the member is made,
never substituted afterwards — `lower_snake_case`, may repeat where one role is
filled twice, and Runtime Export rejects a Set whose member carries none. The
Inspector shows it under `Role in the Set` and says so when it is missing.

A role names the part, the Asset names the execution: `post` rather than
`rope_post`, so a stone post can fill the same role later without the role
having to lie about it. The suggestion drawn from the Asset name pulls the
other way, which is why the field says what it wants rather than only showing
an example. A member always
sits at the Set's root, so its Inspector offers no Parent, and Runtime Export
rejects a member hung under anything. A Set is
authored from the `Set` module, top down: its Asset root offers
`New Member Asset`, and one dialog makes the member Asset plus the Reference
that carries it into the assembly, named after the member by the same
derivation the Asset Key uses. A Set therefore owns the Assets it is made of
rather than collecting Assets that already exist. Its Outliner entry has one
`Members` section.

A composition and everything it owns are one kind of thing: a Bridge is `props`
and so are its posts and planks. The type is declared once, where the
composition is named, and a member or variant is never asked again; changing it
on the composition moves it to everything the composition owns, so the two
cannot come to disagree. Export checks it rather than assuming it — a Set whose
member is of another type, or which holds anything but member References, is
rejected.
A member row names the member Asset, exactly as a Palette row names a variant.
The Reference that carries it is machinery: its name is derived from the
member's name by the Asset Key derivation, made unique inside the Set, and read
in the row's tooltip and in the Inspector rather than in the tree; the Canvas
names the member as well. A member Asset is drawn underneath its Reference with
everything an Asset has — Components, References, Guides and Regions — and the
`Add` button on that row belongs to the member, so a member is authored where
it belongs instead of in a second view. `OutlinerView._render_asset_contents`
is that shared body, drawn once for an Asset entry and once per member. Selecting a member's Component
therefore leaves `selected_asset_id` pointing at the member while the module
stays `Set`: `_create_submodule_for_asset` keeps the module, and
`_outliner_expansion_anchor_asset_id` redirects every expansion to the
composition that owns the member, so the module's one expanded row stays the
composition. The Canvas follows the selection and shows the member alone, the
same way Single would.

What a module lists and what it may keep selected are therefore two different
questions, and `_create_submodule_can_select` is the second one. The listing
rule skips a member on purpose, so anything that re-establishes the module
context — `_set_create_submodule_context`, reached from Undo, from a session
restore and from selecting an Asset — has to consult the owner as well.
Consulting only the listing rule re-anchored the selection to the composition
root and dropped the user out of the member they were drawing in.

A member Asset is ordinary in every other way, References included — but a
Reference under a Component and a Set are two different tools, and they are kept
apart. `_reference_source_candidates` in `main.gd` is what a Component's
`+ → Reference` offers: Symbols, and only Symbols. Such a Reference places a
Symbol inside a Component's frame and follows whatever that Component does,
which is what Barde's two eyes need and what a member Reference cannot do,
having no parent Component. Assembling ordinary Assets is the Set's job;
offering it here as well would be two ways to the same result, one of them
without a Set's guarantees. A Palette variant stays out even when it is a
Symbol, because a variant is presentation the client chooses on its own and
therefore must not carry an authoritative placement; a composition stays out
because it is assembled rather than placed. `_reference_cycle_issue` completes
it — a cycle is a consumer's infinite recursion, so it is rejected where it
would be authored rather than exported and left for the consumer to notice.

A Single offers the same entry on its own Asset row, for a Symbol that belongs
to the Asset rather than to one of its Components: the same Symbols-only
candidates, the same cycle check, and no Parent. A parentless Reference was
always part of the document — the Inspector's Parent picker offers `Root`, and
Detach from Parent reaches it — so the Asset row only closes the detour of
authoring it under some Component first and reparenting it afterwards. What a
Parent buys is what a Parent is for: the Reference follows that Component's
transform and visibility, and only a Reference with a direct outer Body as
Parent can act as its Sampling Hole. A Set keeps its own rule, that every
member sits at the Set's root, and Runtime Export still checks it.

A member is an ordinary Asset, so it keeps its own type, its own Components
and its own place in Mesh and Style. What it does not keep is a second entry in
`Single`: that view lists what is placed on its own, and an Asset some
composition already owns is reached through that composition instead.
`_composition_owner_by_member_id` in `main.gd` resolves that map once per render
and hands it to the Outliner, and `_asset_matches_create_submodule` applies the
same rule to the module's expansion scope and its active Asset, so the three
never disagree.

A **Palette** is an Asset with `asset_category: "palette"` and needs less than
an Asset, not more: `palette_variants`, a list of stable Asset IDs that export
resolves to Asset Keys. Every variant is an Asset of the Palette's own
`asset_type`, so nothing else has to say what they are. It owns no Components, no geometry and no arrangement,
because the presentation chooses among the variants freely — order in the list
means nothing and duplicates are dropped on load. That is why a variant is not
a Reference: a Reference carries a transform, a pivot, a z-index and a depth,
and a Palette would have to define all of them away. Its type is chosen where the Palette is
named, so `Add → New Variant Asset` only asks for a name, the same way
`New Member Asset` does. Removing a variant drops it from the list and leaves the Asset alone, and a
variant whose Asset is gone stays visible as missing rather than vanishing.

Single, Mesh and Style share one multi-select Outliner Asset filter. Its seven
checkbox states are persisted in `editor_state`; the filter is applied together
with the Outliner search and does not alter the selected Asset or document
data. In Single it is what selects among the seven types, so a World saved
below schema 63 — where the filter gated Mesh and Style only and could be
stored with every type switched off — has it restored once on load. The
`Set` module has no checkbox row of its own and is handed the one type it
lists, so the Outliner keeps applying exactly one rule; `set` is absent from
the seven, which is why Sets never appear in Mesh or Style.

The row's one button says what pressing it does rather than what it is called:
with a type switched off it reads `All` and shows every type, and with all seven
shown it reads `None` and clears them, so picking a single type is two presses
instead of six unticks. An empty Create list then names its own cause — hidden
by the filter, hidden by the search, or nothing of this kind authored yet —
because hidden and absent look the same when the list is simply empty.

Mesh is the user-facing name of the derived geometry pipeline. Existing
internal `geometry_*` identifiers remain technical names, while UI copy uses
Mesh. Style currently contains only Weighting. Motion code is retained but its
category is disabled. Transform and Effects categories do not exist.

Two Canvas shortcuts are routed in `_input`, ahead of the GUI: the Pivot key,
which a focused SpinBox would otherwise swallow as text, and the caret keys the
Outliner and a selected Point own. Reaching past the GUI means a text field
cannot defend itself by consuming the key, so `_canvas_shortcuts_are_blocked`
stands them down while a `LineEdit` or `TextEdit` holds the keyboard — a
SpinBox through the `LineEdit` it holds. Without it, typing a name with the
pointer resting over the Canvas places a Pivot and takes the focus away
mid-word.

The Create toolbar's optional `Frame` guide is editor-only canvas state. It
stores `visible`, `half_extent`, and `offset` under `editor_state`, authored in
centimetres and hidden by default with a `10 cm` half extent, draws around the
canvas origin, and never enters Asset topology, derived geometry, or Runtime
export data.

## Ownership boundaries

- `BezierTopology` owns changes to points, edges, chains, IDs, ordering, and
  topology validation.
- `BezierGeometry` owns cubic Bézier evaluation, flattening, and handle
  resolution.
- `PrimitiveGeometryService` owns typed primitive validation and deterministic
  derived contours. It does not create or own Bézier topology.
- `ClosedRegionMeshService` owns validation and deterministic triangulation of
  the complete adaptively sampled Boundary of a closed Contour. Its result is
  derived Runtime geometry without rendering or Fill semantics.
- `ComponentHierarchy` owns parent/child normalization and world/local
  transform conversion.
- `ComponentCanvas` renders immutable copies and emits user intent.
- `main.gd` applies intent to the selected World document and records
  history.
- `OutlinerView` renders the Outliner list from a context `main.gd` pushes in
  and emits what the user did. Like `ComponentCanvas` it holds no editor state
  and mutates no document: a drop reports intent and `main.gd` applies it.
  Derived row state, such as Weighting status, is resolved by `main.gd` and
  handed over, so the view never reaches into the geometry documents. The Mesh
  tree follows the same rule as data: `main.gd` resolves the derived geometry
  state across Sampling, Seeding and Meshing into a flat list of typed rows —
  `asset`, `component`, `hole`, `guide`, `input`, `dependency`, `pipeline`
  plus labels — and the view draws them without deciding what a row says. A
  `pipeline` row carries an `action_id` rather than a callback, so the view
  stays free of editor behaviour.
- `CreateInspectorView` draws the Create module's Inspector under the same
  contract as `OutlinerView`: `main.gd` pushes a snapshot in through `set_document`,
  `set_selection`, `set_resolved_selection` and `set_mode`, `rebuild()` draws from
  that snapshot alone, and every user action leaves as one of 46 intent signals.
  The two lists that need the document to resolve — the Components of a multi
  selection and the Point ids that still exist — are computed in `main.gd` and
  handed over, so the view never resolves a stale id itself. The controls the
  editor updates without a full rebuild (`transform_fields`, the name editors,
  the two rebase buttons) belong to the view and are read from it.
  The intent signals still carry the argument lists of the handlers they replaced,
  `OptionButton` references included; giving them plain values is a separate step.
- `GeometryInspectorView` does the same for the Mesh module, with one difference
  that follows from what it draws: nearly everything on screen is derived from
  the Geometry documents and the preview caches, so `main.gd` resolves each
  submodule into one context Dictionary — `_geometry_sampling_inspector_context`,
  `_geometry_seeding_inspector_context`, `_geometry_meshing_inspector_context` —
  and the view renders that. Boundary rows and Sampler Spine rows arrive as row
  models with their labels already resolved, the same way the Outliner gets its
  Mesh tree.
- `StyleInspectorView` is the same thing at a much smaller scale: one context
  Dictionary holding the selected Component, its Weighting Style, the Mesh and
  Style status, the preview or baked result, and whether Bake is available.
- `MotionInspectorView` completes the set, with one difference stated plainly:
  it holds references to the Motion session models rather than only data.
  `motion_workspace`, `motion_player` and `motion_selection` are queried in about
  thirty places for the selected preview, display names, summaries, primitive
  options and Transition order, and they are handed in through `set_models`.
  Turning those queries into a row model, as the Mesh tree already has, is the
  step that is still open. Everything that is a document lookup does go through
  a context Dictionary, and the syncing that used to run halfway through the
  Animation render — selecting the Asset, setting the Workspace Asset, syncing
  the player document, refreshing the preview — now runs in `main.gd` around
  `rebuild()`, in the same order.

`main.gd` no longer draws an Inspector. It routes: it clears, decides which of
the four views is visible, resolves that view's context and calls `rebuild()`.
- `EditorWidgets` builds the shared widget vocabulary — panels, labels, section
  headers, buttons and their styling. It is static and purely constructive: it
  reads no editor state and knows nothing about Worlds, Assets or Components.
  A control that needs a handler receives it as a `Callable`.
  `build_number_grid` takes a grid, an array of field descriptors (`caption`,
  `property`, `value`, optionally `min`, `max`, `step`, `arrow_step`, `tooltip`
  and `silent`) and one handler bound per property, and *returns* the built
  fields keyed by property. Callers that need live updates keep that map —
  `transform_fields`, `asset_pivot_fields`, `asset_root_position_fields`,
  `asset_root_scale_fields` — instead of the builder writing into editor state
  behind their back. Read-only blocks such as the Global Transform simply drop
  the return value. `add_stacked_number_field` is the same idea for the
  Inspector's other numeric shape — a caption line above a full-width field —
  and `create_toggle_field` for its boolean rows. `create_option_field` takes a
  dropdown as a list of `{label, metadata}` entries plus the metadata to
  preselect; twelve of the editor's thirty-two dropdowns go through it, and the
  rest — Motion, Export, the world settings bar — still build their items by
  hand because no render comparison covers those states yet.
- `WorldDocumentService` owns the on-disk document format: normalization on
  load, serialization on save, and the atomic file replacement both sides use.
  It is static and holds no editor state. `deserialize_asset` turns one Asset
  document at any supported schema into the in-memory record and carries every
  load-time migration — Ribbon to Contour below schema 40, Semantic Keys to
  names, Guides once stored among the Components — so
  `_test_asset_deserialization_migrations` can exercise them on a fixture
  without a World on disk. It also owns the discriminator vocabularies that
  every reader compares against by name rather than by literal string, so a
  misspelling is a parse error rather than a silent fall into the default
  branch: the Component's `DRAW_MODE_CLOSED_LOOP`, `DRAW_MODE_CONTOUR`,
  `DRAW_MODE_PRIMITIVE`, `ROLE_OUTER`, `ROLE_HOLE`, `ROLE_CUT` and the
  predicates that read them — `component_draw_mode`, `is_closed_loop`,
  `is_contour`, `is_primitive`, `topology_role`, `is_outer_body` — and the
  the seven `ASSET_TYPE_*` constants behind `asset_type` and
  `normalize_asset_type`, the three `ASSET_CATEGORY_*` constants behind
  `asset_category` and `normalize_asset_category`, plus `is_set_asset`,
  `is_palette_asset`, `is_composition_asset` and the `palette_variants`
  reader; `main.gd`'s
  `CREATE_SUBMODULE_BY_ASSET_CATEGORY` maps a category to its Create module and
  `ASSET_CATEGORY_BY_CREATE_SUBMODULE` back again, while
  `_normalized_create_submodule` reads any unknown module name, including the
  seven Asset-type names Worlds below schema 63 stored, as `Single`. `AssetGuide` owns the Guide types the same way, plus the Guide scope
  vocabulary — `SCOPE_COMPONENT`, `SCOPE_GROUP`, `is_group_scoped`,
  `scope_component_id`, `scope_group_id`, `scope_target_id` — read by
  `ComponentHierarchy.guide_world_transform`, the one place a Guide's scope
  resolves to a world Transform. `main.gd` keeps the orchestration — which records
  exist, when they are read and written, and what the editor does with them —
  including `_serialize_editor_state` and `_serialize_world_settings`, which
  read editor state by definition, and the Asset serialization in `_save_world`,
  which decides a Contour width override against the World default.
- `RuntimeExportView` is the Runtime Export module's work surface under the same
  contract as the Inspector views: `main.gd` resolves the Preflight into one
  context Dictionary — summary line, Consumer Sync hint, the two stages with
  their candidate counts and their pending and attention lines, and the state of
  the three action Buttons — and `rebuild()` draws that snapshot alone. It reads
  no Assets or Geometry documents, counts no candidates, checks no files, and
  runs no Export, Mesh build, Save or Consumer Sync. The three Buttons stay
  children of the shared toolbar, because re-parenting them under the view would
  nest a container inside that flat toolbar and shift the spacing of unrelated
  neighbours; `main.gd` hands them over once and from then on the view owns what
  they say and what a press means, reporting it as `build_all_requested`,
  `export_all_valid_requested` or `sync_consumers_requested`. The batch runs stay
  in `main.gd` and write their progress through the view rather than into its
  controls.
- `RuntimeExportFileService` owns the file-system mechanics behind Runtime
  Export: the Catalog and package paths below a given World root, whether what
  is on disk still matches what was built, the staged replacement of one
  package, and the removal of package directories. It is static, holds no
  editor state, and resolves nothing from the World document: the World root,
  the Asset Key, the already built Catalog or Manifest, and the set of package
  names that may stay are all passed in. Its removal is bounded strictly below
  the export root it is given, so neither that root nor anything beside it can
  be reached. `main.gd` keeps every decision that needs the document —
  `_asset_catalog_build`, `_runtime_export_build`, `_asset_key`, and which
  visible Assets keep their last valid package — plus the batch, the toolbar
  and the Consumer Sync.

Rendering is invalidation-driven. A mutation calls `_invalidate_render` with the
targets that became stale — `RENDER_OUTLINER`, `RENDER_INSPECTOR`,
`RENDER_CANVAS_CONTEXT`, `RENDER_CONTEXT_BAR`, `RENDER_INFO_BAR`, or the
`RENDER_DOCUMENT` combination of the first three — rather than naming the render
functions to call. `_flush_pending_renders` then runs the accumulated set once,
in a fixed order, before `_invalidate_render` returns.

The flush is synchronous on purpose. Several call sites consume render output in
the statements that follow: the Weighting shortcut opens a Context Bar menu that
the same render rebuilds, `_select_geometry_component` focuses a Workspace that
the Canvas render makes visible, and a handful of handlers write `canvas_view`
properties that the Canvas render also writes. Deferring the flush to the end of
the frame inverts that ordering, so it is not done. Requesting the Canvas covers
the Context Bar and Info Bar, which it renders before it can return; the reverse
does not hold, because `_render_context_bar` has exit paths that leave the Info
Bar alone.

Pointer-based `P` Pivot placement is intercepted by `main.gd` during the early
input phase because focused Inspector controls may consume printable keys
before unhandled input. Routing requires the pointer inside the visible Canvas
and a selected Asset, Group, or Component. `ComponentCanvas` converts the
pointer to the appropriate snapped coordinate and emits intent; Draw state and
Guide selection reject the command. Reference-point snapping also lets a
Parent's newly drawn or moved authored Point align to a visible Child point
after converting the Child's composed world transform into Parent-local space.
Whole Parent transforms exclude descendant snapping because those targets
inherit and move with the Parent.

The Create Context Bar's `Measure` menu holds view-only tools. Its `Ruler` is a
toggle rather than a command, and the menu entry carries its on/off state while
the Measure button stays highlighted for as long as a tool inside it is on. The
Ruler owns two independent halves. The guides are the persistent half: they are
drawn for as long as the toggle is on, survive every other context command, and
are cleared only by switching the Ruler off or by moving to another Component,
whose local space they would otherwise describe wrongly. Placing is the
transient half: `_set_active_context_command` hands it to the Canvas exactly
while `asset.measure` is the active command, so Edit Point keeps its clicks
while the guides above it keep updating. Picking `Ruler` from another command
resumes placing with the guides intact; picking it while Measure already owns
the Canvas switches the toggle off.

A Ruler Point placed inside the pick radius of an authored Point stores that
Point's id instead of its coordinates and resolves its position on every draw,
which is what makes a measurement follow the Point as Edit Point moves it. Every
other Point stores the snapped raster position. `set_bezier_geometry` drops a
guide whose anchored Point no longer exists rather than freezing it at a
coordinate nothing occupies. A faint cross leads the cursor at the resolved snap
target while placing, so the Point a click would place is visible before it is
placed. A guide is drawn as three dashed lines: the measured span in orange
labelled with the world distance in centimetres, plus the two legs that close
the right triangle over it — the horizontal one in red carrying the x distance
and the vertical one in green carrying the y distance. Both legs are World axis
aligned rather than Component local so they stay horizontal and vertical on
screen for a rotated Component, and a leg that collapses to a few pixels is left
out rather than labelled with a zero.

Escape steps back over the placed Points instead of ending the Ruler: it drops a
pending first Point, and on a finished guide it takes the second Point back and
reopens the first one as the live anchor, which is how several distances are
measured from one Point without stacking a guide for each. The Canvas consumes
that Escape, because an unconsumed one reaches the editor's global Escape reset;
`_unhandled_key_input` therefore also leaves a placing Ruler alone rather than
resetting around it. Nothing about a measurement reaches the World document, so
Measure stays available for every Component, including one whose geometry is
locked by a Region.

A geometry document must be able to read back what it wrote. Godot's JSON
parser returns zero for a number written far below the format's resolution, so
a bake that emitted one — the `1e-17` numerical zeros a rotation leaves behind —
came back changed from its own file. Nothing looked edited, but the Manifest
rebuilt after the next load no longer matched the exported one, and
`RuntimeExportFileService.package_is_stale` compares that text byte for byte, so
the package reported itself stale on every open. `WorldDocumentService.document_safe`
turns anything under `DOCUMENT_ZERO_EPSILON` into an exact zero and is applied to
every bake as it enters a document, which keeps memory, file and Manifest on the
same numbers. The threshold is the resolution the fingerprints already declare by
formatting coordinates with `%.9f`.

What the document cannot preserve, a fingerprint must not distinguish, and the
sign of a zero is the trap there: `%.9f` prints `-1e-17` as `-0.000000000`
against a plain zero's `0.000000000`. A bake flattened on the way in therefore
hashed differently from the one its stored `mesh_fingerprint` was taken over,
`_component_mesh_status` read Stale for a Mesh nothing was wrong with, and the
Runtime Export refused it with "a current accepted Fill Mesh is required" while
the Mesh step kept reporting the same Component as freshly built. Every
fingerprint over coordinates therefore passes them through
`WorldDocumentService.document_coordinate` first, which is the same threshold
`document_safe` stores by.

Each Component declares a geometry source. Bézier sources contain only
`points`, `edges`, and `chains`; primitive sources contain one typed primitive
definition: authored `circle` with `center` and `diameter_cm`, an `ellipse`
with `center`, `diameter_x_cm`, and `diameter_y_cm` produced by Scale Rebase,
an authored `rectangle` with `center`, `width_cm`, and `length_cm`, or an
authored isosceles `triangle` with `center`, `width_cm`, and `height_cm`. Generated
primitive contours, samples, fill, and hit-test polygons are derived and are
never persisted. A Primitive's center handle moves its `primitive.center`; its
Component pivot remains an independent transform handle. Do not add `outer_shape`, Component-level `closed`, the old
Line tool, or synchronization from a display polygon back into source geometry.

Closed-loop and Primitive Components also carry a persisted `topology_role`:
`outer` by default or `hole` when authored as a hole. A Primitive retains its
analytic source and does not create a Chain when its role changes. An Asset
Reference owns its role independently from the Asset it instances, so the
reference may be `hole` while the source stays `outer`.


## Documents

This section describes the documents as they are at the current World schema.
How they got here — every schema step, what it changed and how a document
below it is migrated — is in [`SCHEMA_HISTORY.md`](SCHEMA_HISTORY.md).

### World

`worlds/<world_name>/<world_name>.json` indexes Assets by stable ID plus the
retained motion and derived resources. Its canonical technical `name` owns the
directory and filename, while the separate persisted `world_name` is the
human-facing World title and need not be shown by the current UI.

The required `world_settings` record fixes reference density at `192 px/m` and
stores one finite positive `contour_stroke_width_px`, the authored default
Contour width shared by every Asset; new Worlds get `4 px`. The World Settings
summary expresses the shared `1 m` game Tile as `100 cm`, or twenty default
`5 cm` Grid Boxes; Tile size does not alter Component geometry or the
persisted World scale contract. A missing or invalid record is a load error,
not a default.

`editor_state` persists the active Create/Mesh/Style module and valid
selection, the Outliner Asset-type filters, per-Asset cameras and the `Frame`
guide; it does not restore disabled Motion as the active category. Its
`active_create_submodule` holds a Create module name; below schema 63 it held
one of the seven Asset-type names, and every such value reads as `Single`.

### Asset

An Asset contains:

- stable ID, name, visibility, `asset_type` — `character`, `props`, `weapons`,
  `terrain`, `items`, `icon`, `symbols`, normalizing to `character` — and
  `asset_category` — `single`, `set`, `palette`, normalizing to `single`. A
  Palette additionally carries `palette_variants`;
- typed Asset-level `authored_facing` presentation metadata (`left`, `right`,
  `neutral`, `top`, or `down`). It is edited only on the Asset root in the
  Inspector's `Initial Pose` group, uses the `AssetPresentation.AuthoredFacing`
  enum in memory and its stable lower-case value in JSON, and describes only
  the direction the artwork was drawn in: it has no geometry, Canvas, or
  transform behavior;
- Asset pivot and reference-image settings. The Reference Image carries a
  `rotation` in degrees that turns it around the Asset Pivot as the Canvas
  shows that point, so the authored artwork can be lined up at an angle. It
  is an authoring aid on the Canvas only: no geometry, Bake, or Runtime
  Export reads it;
- an authoring-only root transform: `root_position` and a positive,
  independently two-axis `root_scale` (a legacy scalar reads as equal axes).
  Canvas presentation prefixes every Asset-space transform with the
  translation and then the scale around the unchanged Asset Pivot, while
  Inspector fields keep exposing canonical source coordinates. Runtime Export
  requires Position `(0, 0)` and both Scale axes `1`; it never applies a
  pending root transform silently;
- Components, Groups, and Guides;
- retained asset-local animation data.

### Component

A Component contains its geometry source, hierarchy reference, local
transform, visibility/layer settings, draw mode, optional Contour stroke-width
override, catch-parent reference, `projection_depth_cm`, and point number
display setting. It has no Material assignment.

Its `type` is `component`, `reference`, or `region`. A Reference carries
`source_asset_id` as the editor's internal link to another Asset, a signed
`reference_instance_scale`, and an optional `role` naming what it stands for in
a Set; runtime export resolves the link to `source_asset_key` and never copies
the referenced geometry.

The free-form `name` is unique within its Asset, case-insensitively, and is
the authored identity used by runtime animation bindings: runtime animation
configs bind generic targets such as `target01` to these names per Asset, and
a Reference classifies borrowed geometry locally — Barde may use the Orb
Asset through `source_asset_id` under the local name `belly`, which export
resolves to `source_asset_key = "orb"`. New and renamed
names use `lower_snake_case`; the vocabulary is unrestricted, and the
Component dialog and Inspector reject invalid names before committing. Weapon
Components use the namespaced keys `weapon_body`, `weapon_collar`,
`weapon_grip`, `weapon_head`, `weapon_head_left`, `weapon_rear`,
`weapon_shaft`, and `weapon_string`. Duplicate maps the known pairs
`eye_left` / `eye_right` and `eyebrow_left` / `eyebrow_right` automatically;
every other copied Component requires an explicit picker choice before the
duplicate is committed.

`draw_mode` is `closed_loop`, `contour`, or `primitive`. A Contour is
fill-less and owns either one open Chain or one closed Chain. A closed Contour
retains only its centered Stroke as the visible Component Mesh and never
requests or exports a Fill Mesh; its accepted Contour build also carries a
separate derived triangulation of the complete authored Boundary for the
Runtime `closed_region_mesh`, and hidden Stroke runs do not remove any part of
that region. That region is engine-neutral geometry without material, color,
transparency, UV, rendering, or Fill semantics; it is not displayed by the
Canvas, Preview, or Component Mesh and never becomes Component source data.

`contour_stroke_width_px` is optional and, when present, finite and positive.
An ordinary Component inherits the World default when the field is absent or
equal to it; a differing value is its implicit local override. On an Asset
Reference the same field applies uniformly to every Contour part of its source
Asset without changing the source. The Inspector always shows the width
field, without a separate Override toggle. A World-width change affects only
inheriting Components, an override change only that Component; the effective
width participates in Contour Mesh fingerprints and build signatures, so
downstream Bakes become stale without changing Component topology.

`projection_depth_cm` exists on visible Components only, defaults to `10 cm`,
is shown in the Component Inspector beside Contour Stroke Width and Z Order,
and is independent of Component and Asset Scale, Rebase, Z Order, and Contour
Stroke Width. Groups and the Asset root do not own it.

`z_index` is an integer each Component owns exclusively; Groups carry none.
It is authoritative only as an asset-local semantic order across the complete
Component set. Runtime Manifest `z_order.scope = "global"` means global within
that Asset, not global across a consuming game scene. Consumers may use any
strictly monotonic local depth spacing and position the complete Asset range
contextually relative to other Assets without rewriting its internal order.

### Group

A Group is an Asset-local authoring container with a stable ID, a unique
lower-snake-case name, visibility, one shared transform/pivot, and an optional
`parent_component_id`. Components retain their own transforms and `group_id`
membership; they are not children of the Group. Descendants inherit their
ancestor's effective Group membership unless explicitly assigned otherwise.
When parented, a Group transform is local to its Component Parent and is applied
exactly once in every Part's world transform: after that parent for a Part whose
own Component chain runs through it, and as the frame the chain starts in for a
Part that does not name the parent itself. Both shapes occur in authored data,
because a Component added to a parented Group is not required to repeat that
parent, and both place the Part identically. A Group cannot be placed beneath
one of its own Parts. Group visibility is effective while each Component's individual Z
Index remains authoritative. Outliner drag-and-drop preserves each affected
Component's world transform when changing Group membership, Component
parentage, or Group parentage. Dropping a Group across Component branches
reparents its direct Parts atomically. Deleting the selected Group deletes the
Group: the container, its Group-scoped Guides, every Part and each Part's
Children, behind the same confirmation a Component deletion asks for. Releasing
the Parts instead is the separate Remove from Group action, which keeps each one
exactly where it is. Duplicate, with and without a mirror, reads the same
Outliner selection as Group, Copy Components and Remove from Group: every
selected Component is copied with its own subtree in one undo step, and a
selected Child inside a selected Parent is not copied twice because its
Parent's subtree already carries it. The new copies are what stays selected. Groups are
editor-only containers: runtime export emits ordinary Components and resolves
the Group transform into their canonical exported transforms.

### Guides

Guides are independent topology records scoped to an Asset or Component; they
are not Component Semantic Keys. Curve-based Guides — Flow, Sampler Spine,
Animation Spine and Cut — carry `points`, `edges` and `chains` like a
Component. Transform-based Weapon Guides store a stable role, a
Component-or-Group scope, and a local position/rotation frame; non-uniform
scale is inherited from the scope and is never authored on the frame. The
roles are `weapon_socket_primary`, `grip_primary`, `grip_secondary`,
`attack_point_primary` and `reach_limit_primary`. `grip_secondary` is a second
weapon-local hand contact for an attack regrip, semantically distinct from the
character-owned `weapon_socket_primary`, the carried `grip_primary` and the
maximum endpoint `reach_limit_primary`; none of them infers its position from
a visual Component. Weapon Guides are authored through the Component and
Group `+` and context-menu paths and share the frame data, scope inheritance,
Canvas gizmo, Inspector, history, Scale Rebase and persistence paths. The
shared gizmo turns its X and Y axes with an authored frame rotation and
constrains an axis drag to the turned axis, because a Weapon Guide carries
no geometry and the gizmo is the only thing that can show its orientation. A
Component or Group keeps world-parallel gizmo axes; its rotation is already
visible in the geometry it moves.

Ordinary outer Component and Group Outliner rows expose `+`; constraint-only
Hole rows do not, because Holes cannot own children, Guides, or Regions.

### Regions

A Region is a nonvisual `type: "region"` Component attached to a Component,
with a `region_type` of `attack`, `hurt`, `collision` or `destructible`, backed by canonical
`points`, `edges` and `chains`. It is excluded from visual Mesh processing and
exported in the separate Runtime `regions` array. Its `region_geometry_source`
is `authored` or `component`: `authored` reads the Region's own retained,
editable topology; `component` resolves `parent_component_id` as the live
geometry owner while leaving the authored topology dormant and intact, so
switching back is lossless. Newly created Regions default to `component`, a
missing value normalizes to `authored`. The Canvas receives only the resolved
view copy, drawing and Bézier editing are disabled while the Component source
is active, and Runtime export emits a binding rather than copied geometry.
A hidden Region blocks Runtime export instead of dropping out of it, because
a Region is nonvisual and its visibility says nothing about the Asset.
Regions are created from a Component's `+` menu and from an outer
Reference's, which offers the Region entry alone: a Reference draws another
Asset and owns no Child, Guide or nested Reference, but it occupies a
Component's place in the hierarchy and can be hit, hurt or collided with as
one. Documents without
Regions remain valid and consumers retain their Component-based fallback.

### Scale Rebase

Two atomic rebases exist and are independent of each other; see
[`SCALE_REBASE.md`](SCALE_REBASE.md).

The Asset Inspector's Component Scale Rebase bakes finite, non-zero signed
Component and Group Scale into owned Bézier geometry, resolved handles,
Component-scoped Guides, or analytic primitive axes around the unchanged Pivot
before setting local Scale to `(1, 1)`. Group Rebase first compensates member
transforms. Negative axes preserve Mirror reflections in source geometry;
analytic primitive diameters remain positive, and a non-uniform Circle becomes
an analytic Ellipse, while the straight-edged shapes keep their type and bake
Scale directly into their own two independent extents. A parent Rebase compensates direct Child local transforms
to preserve the Child subtree's visible world transform, so Child Position,
Rotation, or Scale may change; hierarchy and animation data remain untouched.
Zero or non-finite Scale blocks the whole operation with no partial fallback.
Asset References are excluded because their signed Scale is an instance
placement transform rather than owned geometry Scale.

The Asset root's `Rebase Asset Transform` bakes Root Position and Root Scale
together: it adds the translation exactly once to root-scoped Components,
Groups, Asset Guides and Weapon frames while preserving nested local
placement, multiplies each local translation, owned Bézier coordinate and
handle, primitive axis, Guide coordinate and Weapon-frame translation exactly
once per axis — root placements around the Asset Pivot, nested placements
around their local origin — and resets Position to `(0, 0)` and Scale to
`(1, 1)`. Reference geometry uses its instance scale, so its transform Pivot is
unchanged. The Asset Pivot is not moved, Component Scale is not modified, and
authored non-default Motion is an explicit blocker until a dedicated scale
conversion exists. Accepted derived data is not rewritten and becomes stale
through its existing source fingerprints.

### Derived documents

Derived mesh documents are keyed by Asset and Component IDs and stored below
`geometry/<asset>/<component>/geometry.json`. Sampling feeds Seeding, Seeding
feeds Meshing, and accepted Bakes remain separate from source Component
geometry. Weighting styles reference accepted mesh data without becoming
Component topology. Each document also carries the Contour Stroke build,
semantic build provenance, and the optimization diagnostics — baseline
triangles, accepted Seed movements and before/after quality metrics — for the
Optimization and Quality views; none of that ever becomes Component topology.

Sampling results carry their own algorithm version independently of the World
schema, currently 6, and Bakes from an older version are stale before Seeding
or Meshing can consume incompatible constraint identities. Meshing knows one
Fill method, `constrained_mesh`; a `contour_stroke` build exists for every
ordinary Component. UV Mapping and SDF records are Legacy data: they load,
round-trip and save unchanged through `GeometryUVMappingService` and
`GeometrySDFService`, nothing generates new ones, nothing deletes or
reinterprets old ones, and they have no Workspace, Inspector, batch, Canvas
presentation or Runtime dependency.

## Derived pipeline

Mesh is the user-facing name of this pipeline. Sampling, Seeding and Meshing
share one Preview contract: a debounced transient Preview is generated once
per settled recipe, and an explicit Bake copies that exact Preview without
regenerating it.

Sampling owns one adaptive Body recipe. Its Outer boundary, direct Hole Child
Components, and scoped Cut Guides inherit the Body target edge length and Curve
Detail. A Hole Child may be an ordinary Closed Loop or Primitive, or an Asset
Reference; its exclusion applies only to its direct outer Parent and only while
the Hole is effectively visible. Ordinary Hole Components are constraint-only:
they receive no independent Mesh pipeline and are omitted from Runtime export.
They cannot be rooted, own Component children, or receive Weighting Styles; a
visible invalid Hole is surfaced as a Mesh/Runtime validation issue, and its
Inspector keeps the invalid current Parent visible as an explicit warning
entry until it is repaired. A Hole Reference continues to export its source Asset instance, while owning no
Fill or Contour Stroke Mesh itself. Hole and Cut inputs
may apply a boundary-density factor from `0.25×` through `16×`. Values below
`1×` coarsen all adaptive criteria, while values above `1×` refine them. Primitive Circles, Ellipses, Rectangles, and Triangles
remain analytic through sampling, including their transform into Body-local
space; they are evaluated at the Body's adaptive target edge length and
scale-aware Curve Detail and have no fixed or user-editable sample count. The
sides of a Rectangle and a Triangle are straight, so only Target Edge Length
subdivides them; there is no curvature to refine. On Bézier boundaries, a deterministic best-effort post-pass splits only
the longer derived curve segment beside an authored corner toward a maximum
adjacent-length ratio of `3×`; it never adds authored Points or changes the
curve. At most 64 derived samples are added per Chain. Untreatable intervals
and exhausted limits remain non-blocking and are exposed in diagnostics.
Sampling also owns PSLG junction creation and the clipping of Cuts against
Outer and Holes, and stores the arranged Cut fragments; Seeding consumes those
fragments as independent barriers.

Seeding derives a shared constraint domain from that accepted Sampling Bake.
Outer and Hole contours bound valid Seed positions, while open Cuts are
two-sided internal barriers. Poisson Fill applies automatic constraint
clearance; Spine Flow clips rows against the same constraints and combines all
enabled Sampler Spines into one deterministic globally spaced result. Seeding
also uses debounced Preview plus explicit exact Preview Bake. Its Artistic
recipe derives Across from Seed Spacing and Along from Spacing times Flow
Stretch while retaining explicit technical overrides for compatibility: the
exact lattice values and the optional Boundary and Stagger refinements stay
available under Advanced Pattern. Manual editing is available only on a
current accepted Bake.

Meshing exposes one constrained recipe for closed Body Components. `Mesh
Character` derives the relaxation strength and pass count along a Structured to
Organic continuum. `Optimize Mesh` gates existing-point relocation as an exact
raw-CDT A/B comparison, and the Optimization and Quality views expose the
accepted movement and a triangle heatmap; optional Advanced Optimization
overrides preserve exact legacy or technical control. The service triangulates Sampling boundaries plus
Seeding vertices, recovers Outer/Hole/Cut constraints, classifies retained faces
by flooding from the oriented Outer interior without crossing closed Outer/Hole
barriers, and accepts a relocation pass only when measured quality improves
without a material minimum-angle
regression. It retriangulates after each candidate and only then duplicates the
Cut seam. Final validation requires one retained Triangle on every Outer/Hole
constraint and two retained Triangles on every Cut constraint before seam
duplication. Boundary vertices never move and this phase neither adds nor
removes vertices. Meshing uses the same debounced transient Preview and exact Preview
Bake contract as Sampling and Seeding. Accepting the Preview atomically replaces
the single Constrained Mesh Bake and records it as the Component Mesh, so no
separate `Use as Component Mesh` action exists.
The Meshing root-Asset view derives a transient display-only aggregate by
transforming each current visible Component Mesh into Asset space. It never
persists a merged Mesh, and missing or stale Component Meshes are omitted.
Meshing validates the PSLG and delegates only the constrained triangulation to
the pinned `artem-ogre/CDT` GDExtension; PolyTools owns document data, stable
IDs, domain filtering, diagnostics, relaxation, and Cut-seam duplication.

New Constrained Mesh recipes default to `Mesh Character = 0.64`, which derives
Strength `0.402` and three quality-checked passes. Existing persisted recipes
retain their exact Character and override values.

The persistent `Update Meshes (N)` action rebuilds only
effectively visible meshable Components across all Create Asset types whose effective geometry,
constraints, or recipes differ meaningfully from their last successful build.
Automatic recipe version 3 retains version 2's Barde-derived Boundary and Seed
Spacing at `0.55` through the measured normal Character/Symbol range. Beyond
perimeter `60`, Boundary Spacing scales by `sqrt(perimeter / 60)`; Seed Spacing
is independent and is at least `sqrt(area / 750)`, subject to a narrow-feature
cap. The existing 8-to-512 boundary-sample guards still protect very small and
very large contours. This reduces avoidable interior density on Tree-scale
geometry without coarsening smaller Assets.

Automatic acceptance budgets at most 4096 total boundary/constraint Samples,
2500 interior Seeds, and 12000 Triangles. A rejected attempt first increases
only Seed Spacing. Boundary Spacing and Curve Detail may increase only after
Sampling exceeds its hard safety limit or automatic Boundary budget. Complete
final Constraint coverage and zero degenerate Triangles remain hard quality
gates; minimum angle, mean quality, and worst aspect ratio are recorded for
diagnostics rather than imposing a shape-dependent global threshold. Minimum
angles below `5°` and worst aspect ratios above `25` are surfaced as non-blocking
quality warnings. Every
attempt and effective recipe is retained in automatic build provenance. Manual
recipes are evaluated exactly once and never use these fallback adjustments.

The Meshing Inspector derives `Auto Build Diagnostics` directly from the current
recipe resolution and stored provenance. It shows automatic/manual ownership,
pending model migration, Area/Perimeter/Feature metrics, current effective
spacings, fixed limits and last
usage, per-attempt scope/outcome/reason, and accepted quality metrics. This is a
read-only projection and introduces no second source of pipeline state.
Regression coverage uses canonical synthetic Components — including a narrow
concave Item at two proportional scales — and broad invariant or range checks
rather than exact mesh snapshots or documents below `worlds/`.

Build provenance records `recipe_mode`, automatic recipe version, and a hash of
the normalized Sampling/Seeding/Meshing recipes. Matching automatic recipes can
be recalibrated; any later recipe edit breaks that hash and transfers ownership
to exact manual settings. Successful results commit atomically per
Component. Legacy calibrated profiles migrate automatically.
Untouched legacy UI defaults migrate only when both perimeter and area place a
Component clearly beyond the normal Asset range, leaving small defaults intact.
Numeric geometry is compared
with a scale-aware tolerance against that accepted snapshot; topology,
constraints, recipes, and algorithm versions remain exact. The actionable
count therefore comes from build provenance rather than a mutable dirty flag,
so selection and sub-tolerance pointer jitter never trigger the batch. Failed Components
are isolated and retain their previous valid Component Mesh. Components with
invalid source topology remain outside the actionable count and surface the
specific validation issue in the Meshing Inspector.

The Mesh and Runtime Export batch tooltips share compact `Pending` and
`Needs attention` sections so blocked records remain discoverable without being
treated as executable derived-build candidates. `BatchStatusButton` consumes
the same summary and draws a per-Button attention point independently of the
Button's enabled state; it never maintains a separate warning flag.
Both Buttons consume one UI-only Batch-status snapshot. Selection and
render-only changes reuse it; document mutations invalidate it and coalesced
edits refresh it after a short debounce. Batch execution never trusts the UI
cache and recomputes authoritative candidates before mutating derived data.

## Persistence

Each Asset is stored below a sanitized visible-name directory with a matching
JSON filename, for example `assets/Wizard/Wizard.json`. The stable ID remains
inside the JSON and in the World index. Older ID-based paths such as
`assets/asset_1/asset.json` remain readable as a migration fallback. Motion
Paths, Acts and Sequences live below `paths/`, `acts/` and `sequences/`.

An Asset is published under two names: `asset_key`, derived from the display
name and moving with it, and `asset_id`, which does not move at all. Consumers
store the ID and read the Key; `previous_keys` on the Catalog entry carries the
Keys an Asset left behind, for the files people write by hand and keep in Keys
on purpose. `_confirm_asset_rename` appends to that list, which is the only
place it grows.

An Asset ID is handed out once. The counters live in the World document rather
than being derived from what exists, and a deleted Asset's ID is kept in
`retired_assets` with the Key it carried last; both only ever raise the derived
counter on load. Without that, deleting the highest Asset handed its ID back to
the next one created, and every Reference still pointing at it followed along
without a word. The retired Key is also what lets a consumer tell an Asset that
was deleted from one whose package is merely missing.

Because an Asset is found by its ID rather than by its directory, a document
that exists twice is ambiguous, and the first directory read wins — alphabetical
order deciding which version of an Asset a World loads. Renames used to leave
such copies behind. `_asset_storage_scan` reports every ID it finds more than
once when the World loads, naming the copy that was taken; it resolves nothing
on its own, because which copy is the real one is not the editor's to guess.

Because the directory is derived from the visible name, renaming an Asset moves
files. Three things live under that directory — the document, the Reference
Image beside it, and the Asset's Geometry documents under `geometry/<name>/` —
and all three are addressed through the derived name, so a rename that changed
only the label would strand them and leave a second document of the same ID
behind for the next load to find. `_confirm_asset_rename` therefore moves the
directories first and applies the name only when the move succeeded, and it
refuses rather than merges when a target directory already exists. For the same
reason the name is not edited in place: the Inspector offers `Rename…`, and the
dialog shows the Asset Key the new name derives, because that Key is what the
Catalog publishes and a consumer resolves.

Every record is written through `WorldDocumentService.write_text_atomically`:
a staging file is completed and then swapped in, so a failed write leaves the
previous content rather than a truncated file, and a `.staging` or `.backup`
residue only ever means an interrupted swap. There is no autosave; every
save is an explicit user action. Renaming an Asset is the one action that also
writes the World, because it has already moved that Asset's directories: a
document left behind would say the old name while its directories say the new
one, and the next load would look for Geometry where the name points rather
than where it lies.

Loading normalizes every document to the current schema.
`WorldDocumentService.deserialize_asset` and the `normalize_*` functions
beside it perform the migrations, and `WorldSettingsService.decode` the World
Settings. Two kinds exist. A change that gave an existing value a new meaning
is gated on the source schema version — Ribbon to Contour below 40, the
World Settings default below 41, the Semantic Key name fallback below 43, the
Blink `anticipation_share` default through 18 — and never applies to a
document at or above that schema, which instead loads the value as it is or
fails. Everything else is discriminated by the shape of the value itself: a
scalar `root_scale` is two equal axes, a legacy Meshing method name maps to
`constrained_mesh`, a Group `z_index` is dropped, a missing `asset_type` is
`character`. `SCHEMA_HISTORY.md` lists every step with its kind, its code and
its fixture. Persistence must never add display polygons or reverse
synchronization into Component topology.

The World-root `catalog.json` is an independently versioned derived index, not
an authored identity store, and it is not tracked by Git: together with
`PolyToolsRuntimeExports/` it forms one generated publication unit that the
consumers read from the working directory. A fresh clone has neither until
`Export Runtime` has run once. It lists currently runtime-exportable visible
Assets by the `asset_key` mechanically derived from each complete display
name. A visible Asset blocked by Runtime validation is omitted, so it cannot
prevent valid siblings from publishing; its retained package remains
unadvertised until the Asset validates again. The derivation cannot be
overridden, and creation or rename rejects collisions across visible and
hidden Assets. Internal stable Asset IDs remain in editor persistence only;
neither the Catalog nor runtime manifests expose them, so consumers do not
discover packages by directory listing.

Undo/Redo snapshots copy canonical documents and stable selections; the
Geometry documents are shared copy-on-write, everything else is a deep copy.
Derived previews are transient and are recomputed after restoration. The
whole-document snapshots are also what provides Dirty-state invalidation.

## Export contract

The normative serialized package and consumer contract is
[`RUNTIME_EXPORT_CONTRACT.md`](RUNTIME_EXPORT_CONTRACT.md); other documents
must not redefine its fields. The summary below describes how the editor
produces that contract.

`RuntimeExportService` builds Manifest schema 21 exclusively from current
accepted Fill and Contour Stroke Mesh Bakes. Ordinary Hole Components are
authoring-only Sampling constraints and do not enter the Manifest. A visible
ordinary Hole with no valid direct outer Parent Body blocks export, as does a
Runtime Component loaded beneath such a Hole. For a closed Contour, the current
Stroke Bake must also contain its current complete-Boundary region
triangulation. It rejects missing or stale inputs,
invalid or duplicate Component Names, non-rebased Scale, unresolved
Asset References, and incomplete or cyclic visible hierarchies. Ordinary
Components never derive replacement geometry during export. References emit an
`asset_reference` record containing the local `name`, signed placement
transform, and actual `source_asset_key`, without copying geometry into the owner.

Every Manifest carries both `asset_type` and `asset_category`. A Set exports as
an ordinary Manifest whose Components are all `asset_reference` records, each
with its `role`; a Palette exports the one Manifest without geometry, carrying
`variants` and no Components. Its variants are validated at export — a Palette whose variant is
missing, hidden, of another category, or carrying gameplay Regions or
Attachment Frames is rejected, while the variant itself stays a valid package.
`main.gd` resolves those variant facts, because they are questions about other
Assets, and the Catalog prunes a Palette whose variant is not publishable the
same way it prunes a dependant of an unpublishable Reference.

Every schema-18 Manifest also exports the Asset-level presentation metadata as
`presentation.authored_facing`, oriented Asset-local Weapon Attachment Frames,
and geometry-only closed Contour boundaries. Free semantic Regions are exported
as triangulated Asset-local meter geometry. Component-geometry Regions instead
export `source_component_id` without vertices, preserving the canonical
Component geometry and its Runtime deformation path.

The contract is engine-neutral: X points right, Y points up, lengths are meters,
positive rotations are counter-clockwise radians, and one Tool unit equals
0.1 m. Component local transforms mean
`T(position) * R(rotation) * S(scale)` applied to pivot-relative vertices:
every exported vertex already has the authored pivot subtracted, and a
consumer subtracts `asset_pivot` afterwards
(`docs/RUNTIME_EXPORT_CONTRACT.md`, Placing a Component). Components are listed in
Asset-global ascending `(z_index, component_id)` order from back to front. This
is an asset-local semantic order rather than an absolute consumer Z coordinate.
Group membership does not override a Component's individual `z_index`; the
Group Transform and visibility still apply to its members. Accepted
Mesh Vertex order is retained and Triangle Vertex IDs become compact indices.
Every ordinary Component exports a separate centered `contour_stroke_mesh`;
closed and Primitive Components additionally export their unchanged Fill Mesh,
while fill-less Contours do not invent one. A closed Contour additionally
exports `closed_region_mesh` as local-meter vertices and triangle indices. That
field is engine-neutral geometry only and has no material, color, alpha, UV,
rendering, or Fill semantics. Open Contours and Asset References omit it.
Schema 18 contains no UV/SDF/Carrier fields and carries an optional semantic
gameplay Region array.

Each visible Asset is exported to the active World-local
`res://worlds/<world_key>/PolyToolsRuntimeExports/<asset_key>/` directory as
`manifest.json`. The batch verifies a staging package
before atomically replacing the prior package; validation or I/O failure leaves
the prior package intact. Once all required packages are current, the same batch
atomically updates World-root Asset Catalog schema 3. The Catalog is the closed
consumer set; generated directories absent from it are ignored and pruned only
after every listed package is current and the new Catalog has been committed. Package freshness is derived by comparing the expected
Manifest bytes, not by persisting export diagnostics in the Asset.

The separate `Sync Consumers` action beside `Export All Valid` runs two
PolyTools-owned orchestrators against the currently published Catalog, one
after the other and each as its own process: `scripts/sync_world01_consumers.sh`
for world01 and SceneMaker, and `scripts/sync_game04_consumers.sh` for game04.
Neither calls or reads the other, so a broken or absent world01 or SceneMaker
never keeps game04 from syncing and the reverse; a missing script or one that
stops before its summary still shows as one red line under its group. The
game04 orchestrator has one step, game04's own
`scripts/sync_polytools_assets.sh` (`GAME04_PROJECT_DIR`, default `../game04`),
which copies every single Asset of the shared world01 World into game04's Godot
client (game04 `docs/TASKS.md`, SYNC-02). A step missing its tool fails only
that step, and a failed step's reason is the consumer's last `ERROR:` line.

The world01 orchestrator runs by dependency rather than by consumer: world01's
runtime content and SceneMaker's own Catalog copy depend on nothing but the
published Catalog and go first, then SceneMaker re-exports its current
`world01` scene, and last world01 imports that map. The script also prints one
machine-readable `STEP|index|total|status|title|reason` line per step —
reason is only filled in for a blocked or failed step, its own last output
line or which step it is waiting on. The Export workspace parses these into
one line per step and nothing else: green `<title>: Success`, red `<title>:
FAILED — <reason>`, orange `<title>: WARNING — <reason>` for a step skipped
because something it needed failed. No counts, no raw command output — the
colour alone says which step needs attention. Export and synchronization are
deliberately separate actions: a downstream failure does not alter the already
published PolyTools Runtime packages, and each consumer script remains
responsible for its own atomic target update.

The run itself is not atomic — each step writes as it goes — so a failure names
what reached whom: which steps were applied, which failed, which never ran, and
what that leaves each consumer on. A log that simply stops says none of that,
and the reader cannot tell an untouched consumer from an updated one.

Every step declares what it cannot run without, and a step is skipped only when
its own input is missing — naming the step it was waiting for. The first two are
siblings rather than a sequence: both need nothing but the published Catalog, so
a failure pushing content to world01 no longer costs SceneMaker its Catalog copy
and the scene export that follows from it. Only the map sync waits on both.
Because the steps no longer fall over in one line, the report names each
consumer on its own: world01 can hold new content while SceneMaker is still on
its previous state, and the other way round.

The order is world01's answer, not our convenience. The dangerous direction is
a new map against old content, and keeping the map sync last locks that out —
a map naming an Asset they do not have is refused at their gate. The reverse,
new content against an old map, is a state they can see: their build fails
loudly on a renamed file, and the next map sync refuses the stale map with a
reason. So the independent pushes run first, and neither a failure downstream
nor a failure beside them can starve the other.

## Testing

`tools/verify.sh` is the verification path; `AGENTS.md` describes what it
runs and what counts as a failure. The suite is `tests/run_tests.gd` over the
five suites that extend `tests/test_case.gd`: topology, geometry, editor,
persistence and motion. It covers topology, derived geometry, navigation
state, persistence and the UI contracts of the extracted views; the Inspector
render probe in `tools/` covers what the suite cannot. Geometry regression
coverage uses canonical synthetic Components — tiny Symbol, a narrow concave
Item at two scales, Barde-scale, Tree-scale, concave, Hole and Cut fixtures —
with invariant or range checks rather than exact mesh snapshots. World data is
never used as a mutable test fixture.
