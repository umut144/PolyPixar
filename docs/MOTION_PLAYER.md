# PolyTools – Motion Player

**Status:** Phase 9 evaluator and editor playback controls feeding visible
Outer Bob samples.

## Runtime state

`MotionPlayer` consumes a persisted Asset Animation document without mutating
it. Its runtime-only state consists of:

- current State ID and normalized phase;
- play/pause and loop flags;
- typed Simulation Contract values;
- an optional source/target blend interval;
- emitted State-change and Marker events.

Every State has a positive `cycle_duration` in seconds. Advancing by `delta`
adds `delta / cycle_duration` to normalized phase.

## Evaluation order

For each playing update the Player:

1. advances current State phase;
2. emits Markers crossed by that phase interval, including loop wrap;
3. advances any active blend interval;
4. visits Transitions in persisted list-priority order;
5. checks Exit Policy and every typed `Rules · ALL` entry;
6. takes at most the first eligible Transition.

`Any Phase`, `After Phase`, and `At Loop End` are supported. `Restart` enters
the target at phase zero; `Preserve Phase` carries the source phase forward.
An empty Rule list matches. Missing targets, parameters, or incompatible
operators never match.

## Blend contract

Taking a Transition records source State/phase, target State, elapsed time, and
blend duration. The normalized target weight is available to a sampler as
`elapsed / duration`. The source phase continues during the blend. Phase 9's
`MotionSampler` uses this to blend non-destructive Outer transform samples
without changing the Player or document model.

## Editor preview controls

The Motion Context Bar now provides Play/Pause, current runtime State, phase
scrubbing, Marker ticks, and Loop. Selecting a State while paused makes it the
preview State. Selecting the Asset exposes runtime-only Number/Bool values for
driving Transition Rules. Marker crossings appear in the status and Info bars.
