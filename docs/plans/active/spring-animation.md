# Plan: Spring physics for transitions and app-driven motion

- **Status**: active
- **Goal**: Give MoUI motion physical character and interruption continuity.
  The existing pipeline (`View::transition` / `View::presence` sampling a
  `TransitionSpec` into style modifiers, `ViewPaintPlan.animating` frame
  pumping) is time-eased only: four fixed `Easing` curves, no velocity, and an
  interruption restarts from zero. Apps need springs (underdamped bounce,
  critical settling) that survive target changes with velocity handoff.
- **Non-goals**: implicit per-property auto-tweening of arbitrary model fields
  (needs a runtime slot design + ADR), gesture-velocity wiring, timeline /
  keyframe system, renderer-side animation.

## Contract shape (`moui/core/animation.mbt`)

1. `SpringSpec` value type: `damping_ratio` (ζ; <1 underdamped, 1 critical,
   >1 overdamped) and `duration_ms` settle estimate, plus named presets
   (`gentle`, `snappy`, `bouncy`). Immutable, `Eq`/`Debug`/`ToJson` derived.
2. Closed-form curve: `spring_progress(spec, elapsed_ms) -> Double` —
   normalized unit-displacement spring solution; monotone for ζ ≥ 1, bounded
   overshoot for ζ < 1, exactly `1.0` at/after settle, respects reduced motion
   at the caller.
3. `TransitionSpec` gains an optional `spring : SpringSpec?` field with
   `TransitionSpec::with_spring(spring~)`; `sample_elapsed` and `presence`
   derive progress from the spring when present (falling back to duration +
   easing otherwise). `sample(progress)` keeps progress-based semantics.
4. Stateful interruptible solver for app-driven motion: `SpringState`
   (`value`, `velocity`) with `SpringState::new(value~)`,
   `advance(target~, frame~, spec~)` (semi-implicit Euler, velocity carries
   across target changes — the interruption handoff), and
   `settled(target~, spec~)`.
5. `moui/animation` facade re-exports `SpringSpec` / `SpringState`.

## Acceptance

- [ ] Physics tests: ζ ≥ 1 curves are monotone and settle to exactly 1;
      ζ < 1 overshoots past 1 then returns; `advance` integrates deterministically
      for fixed frames and preserves velocity across a target change; settled
      detection holds at the target; `sample_elapsed` with a spring reaches
      the destination style and respects reduced motion.
- [ ] `moui/animation` re-exports the new types.
- [ ] `docs/canvas-and-custom-paint.md` animation section and the
      `View::transition` row in `docs/view-catalog.md` mention springs.
- [ ] `moon info` + committed mbti diffs; api-surface budgets ratcheted with
      justification; static validators pass.
