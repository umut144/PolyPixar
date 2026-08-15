# PolyTools – Motion Composition Contract

**Status:** Phase 12 ownership, persistence, Path runtime, and first Sequence
composition contract.

## Ownership

`Animation`, `Path`, and `Sequence` are separate Motion modules because they
answer different questions:

- **Animation:** How does one Asset move locally? It is persisted inside the
  Asset and owns States, primitive Motions, Transitions, and Markers.
- **Path:** Where does something travel? It is an independent Workspace
  resource and owns path topology plus playback defaults. It has no Asset ID.
- **Sequence:** What is combined and when? It is an independent Workspace
  resource and owns stable references to an Asset, one Animation State, and an
  optional Path.

Renaming any resource cannot invalidate a composition because references use
stable IDs. A Sequence must not embed or mutate referenced documents.

## Persistent resources

Paths are persisted below `paths/<path_id>/path.json`:

```json
{
  "id": "path_1",
  "name": "Arc",
  "topology": { "points": [], "segments": [] },
  "playback": { "duration": 2.0, "loop": true, "orient_along_path": false }
}
```

Sequences are persisted below `sequences/<sequence_id>/sequence.json` and own
an ordered `entries` array. The Phase 12 MVP entry contract is:

```json
{
  "id": "entry_1",
  "name": "Composition Entry",
  "enabled": true,
  "asset_id": "asset_1",
  "animation_state_id": "state_idle",
  "path_id": "path_1"
}
```

Path Duration and Orient Along Path are inherited from the referenced Path.
The Player's `Preview Loop` is editor state, not composition data. Phase 12
authors and evaluates one Entry; the array shape preserves the deliberate route
to future parallel participants without implementing them yet.

## Runtime outputs and composition

Animation evaluation returns temporary asset-local Component deltas. Path
evaluation returns position, tangent rotation, normalized progress, and path
length; finished state and marker crossings remain future additions. Sequence chooses the referenced
inputs and combines them in this conceptual order:

```text
Sequence placement × Path travel × Asset Animation × Component transform × geometry
```

The exact matrix implementation remains a Phase 12 decision, but the ownership
order is fixed so Animation cannot reacquire Path data indirectly. See
`MOTION_SEQUENCE.md` for the two-view workflow and MVP boundary.

## Migration

Older Animation documents may contain the primitive string `path_follow`.
Normalization removes those entries from State Motions and retains their
original dictionaries under `legacy_path_follow_motions`, together with the
source State ID. They no longer evaluate. The archive is persisted and shown
in the Asset Inspector until a future explicit conversion workflow is added.
