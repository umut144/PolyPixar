# AssetFlow2D – Motion Sampler

**Status:** Phase 9 visible Outer Bob in the Inspector Animation Preview.

## Sampling boundary

`MotionSampler` consumes runtime State, phase, and blend information from
`MotionPlayer`. It returns temporary per-Component transform deltas and never
mutates Asset, Component, or Bézier topology data.

The common Outer sample contains `position`, rotation in degrees, and `scale`.
Phase 9 produces only position through Bob. This is an asset-local Animation
sample; Path travel is composed outside the Sampler.

## Bob

Bob applies an asset-local Y translation:

```text
y = sin(TAU * (phase * cycles + phase_offset)) * distance
```

Enabled Bob Motions in one State combine additively. An Outer Motion may target
`Entire Asset` or one Component. Inner Motion remains Component-only and is not
sampled until mesh and Animation Guides exist.

During a Transition the Sampler evaluates source and target States at the
phases owned by `MotionPlayer`, then interpolates their transform samples using
the Player's target blend weight.

## Stable Preview framing

`MotionAssetPreview` calculates its fitted camera from immutable rest geometry.
Samples are applied only after this fit is known. Therefore an Entire Asset Bob
moves visibly instead of being cancelled by per-frame auto-centering.

The Preview converts AssetFlow's Y-up world coordinates to Godot Control's
Y-down screen coordinates after sampling. Component transforms and authored
Bézier Points/Edges/Chains remain unchanged.
