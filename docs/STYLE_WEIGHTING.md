# PolyTools – Style Weighting

**Status:** Uniform and Axis Gradient MVP.

## Observable result

`Style → Weighting` lists Assets and Components, reports `Missing Mesh` until a
current Component Mesh is selected in Geometry, and lets the user create
multiple named Weighting Styles per Component. Each Style generates a temporary
Mesh heatmap and owns one explicit persistent Bake.

## Ownership and dependency

Weighting Styles are Component-local authored recipes stored in the Component's
Geometry document. A Style has a stable ID, method, parameters, and one derived
Bake. Multiple Styles may use the same method so Motion can later choose among
different artistic profiles.

```text
Component Mesh → Weighting Style → Weighting Bake → future Inner Motion
```

Every Bake references the exact Component Mesh Bake ID and fingerprint and
stores one scalar weight per stable Mesh Vertex ID. A missing, replaced, or
stale Component Mesh makes the result stale without deleting either Style or
Bake.

## Methods

- **Uniform** assigns one Strength to every Mesh Vertex.
- **Axis Gradient** maps the Component-local Mesh bounds along Bottom → Top,
  Top → Bottom, Left → Right, or Right → Left. Linear, Ease In, Ease Out, and
  Smooth curves, Invert, and Strength shape the result.

`CMD/Ctrl + 1 · Method` selects the current method. Parameter changes generate
an immutable preview automatically; Bake is explicit and participates in
Undo/Redo and World persistence.

## Preview

The centre workspace draws the exact Component Mesh with a per-Vertex heatmap:
blue represents zero, violet the middle range, and pale yellow one. Mesh edges,
status, Vertex count, and a compact 0–1 legend remain visible.

## Deferred

Spine Field, along/across curves, Animation Spine binding, manual Edit/Paint
Weights (`CMD/Ctrl + 2`), Motion references, deformation evaluation, and export
consumption are deferred.
