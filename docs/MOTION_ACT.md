# PolyTools – Motion Act

**Status:** Phase 15 bounded primitive catalog with Slide, Jump, and Blink.

## Ownership

An Act is a Workspace-level resource. It does not belong to an Animation State,
does not contain Path geometry, and is not implicitly part of a Sequence. The
selected Preview Asset is editor state only and is never persisted in the Act.

Act order in the workspace list is presentational. It has no runtime priority
or playback meaning. A later Act Group may own an explicit ordered list of Act
references, but grouping is outside this phase.

## Workspace contract

`Motion → Act` divides the centre workspace into a vertical Act list on the
left (one quarter) and a stable, centered Preview on the right (three quarters).
The plus menu is the creation boundary; the MVP offers `Slide`, `Jump`, and
`Blink` from one bounded primitive catalog. Selecting an Act exposes only its
common and primitive-specific parameters in the Inspector.

## Primitive documents

Each Act is stored at `acts/<act_id>/act.json` using schema 22. Common fields
are:

- stable `id`, editable `name`, `kind: primitive`, and a primitive ID;
- `enabled`;
- `parameters.direction` and non-negative `parameters.distance` in centimetres;
- positive `timing.duration` and `timing.easing` (`linear`, `ease_in`,
  `ease_out`, or `ease_in_out`).

`Slide` evaluates normalized Direction × Distance over the eased phase. `Jump`
adds positive Y Height through a zero-at-both-ends mathematical arc. Its
`arc` is `smooth`, `floaty`, or `snappy`; the options vary the arc exponent
without introducing authored Path geometry.

`Blink` first moves opposite Direction by `anticipation_distance` over
`anticipation_share` of its duration. It then travels forward to Distance.
Before the Asset crosses the authored Start its uniform scale remains one;
between Start and End, spatial progress drives a symmetric contraction to
`minimum_scale` at the exact midpoint and expansion back to one at End. Blink
does not use visibility changes. The remaining time after anticipation is split
80/20 around the midpoint. With the default `anticipation_share: 0.5`, this is
50% anticipation, 40% ingress, and a fast Ease-Out during the final 10%.

The evaluator is geometry-independent. `MotionActPreview` derives immutable
contour copies from the selected Asset, fits the complete sampled trajectory,
and applies the current transform offset only while drawing.

## Deferred

Cast, Act Groups, Sequence integration, runtime export contracts,
and scene-level target binding are intentionally deferred.
