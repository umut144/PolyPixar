# AssetFlow2D – Asset Guides

**Status:** Guide Foundation and component-child authoring contract.

## Ownership

Guides are persistent authored children of an Asset. They are neither
Components nor derived Geometry data. A Guide owns only its own `points`,
`edges`, and `chains`; it never changes Component topology and no consumer may
reverse-synchronize a Guide into a Component.

Every Guide has a stable ID, editable name, visibility, semantic `guide_type`,
and Component scope. Guide points use the target Component's local coordinate
space. Changing the target is therefore disabled after topology has been
authored.

## Spine types

- `body_flow` is reserved for later Inner Animation consumption.
- `sampler_spine` is reserved for later Geometry Spine Flow consumption.

Both types share the same open cubic Bézier authoring model, but their semantic
types are never converted or interpreted interchangeably.

## Outliner and authoring

Asset `Add` continues to create Components. Each Component has its own `+`
action that creates a persistent Guide child with a name dialog. The Guide
inherits that Component scope at creation and is shown directly beneath its
parent in the Outliner, with its own visibility checkbox and yellow-tinted
entry. There is no separate Guides group.

The Guide Inspector exposes its type while it is empty. Once Points are
authored, its semantic type is fixed. Its parent Component is displayed as a
read-only relationship.

With a Guide selected, `CMD/Ctrl + 1 · Draw Guide Point` adds Points directly
to that persistent Guide. `CMD/Ctrl + 2 · Edit Guide Point` selects, moves,
and deletes authored Guide Points. New Points use automatic Smooth/Aligned
handles. Guides are presented as dashed yellow curves. The scoped Component
remains visually emphasized while drawing. Cursor and new Points are
constrained to its derived closed Bézier contour; hole regions are excluded.

Guides can be selected, renamed, hidden, inspected, deleted, and restored
through Undo/Redo and Save/Load. Component lookup explicitly excludes Guide
records.

## Deferred

Editing an existing Spine, Spine Flow Seeding, Animation deformation, weights,
falloff, multiple branches, and further Guide types remain separate future
slices.
