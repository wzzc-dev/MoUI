# 0048: Render cache key excludes the animation clock

- **Date**: 2026-11-05
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-priority-execution` (W0.4/W1.1), ADR 0034, ADR 0036

## Context

The render cache's old hit predicate was a "default, static environment"
allowlist. It required a neutral `Environment`, empty `ViewStyle`, the fallback
`TextSystem`, unit scale factors, `en-US`, left-to-right layout, standard
contrast, medium content size, and `now_ms == 0.0`.

That predicate could not work in a host-driven application. `FrameTick` writes
the host clock into the runtime and does not reset it between frames, so after
the first tick every node failed the `now_ms == 0.0` clause. The performance
catalog independently showed `cacheHitRate` at 0 in four of five scenarios and
0.0417 in Showcase.

Including the clock in the key is not a fix: the key changes every frame and
the cache still never hits. Ignoring the clock without a per-node animation
contract is also unsafe: a mid-transition paint plan would be frozen at its
first sample.

## Decision

The render cache uses an explicit `RenderCacheKey` containing:

- placed frame and whether this node is the focused element;
- the content-interned environment identity;
- the resolved child style, font, foreground, and corner radius;
- the text-system identity;
- the control-state revision and text-control revision;
- the monotonic placement revision, because paint can read child frames.

The animation clock (`now_ms`) is not part of the key.

Nodes whose paint output is time-dependent must report
`ViewPaintPlan.animating = true` for every mid-animation sample. A plan with
`animating = true`, a rendered subtree with any animating descendant, and an
overlay enter fade bypass both render-cache reads and writes. A static plan may
still be cached when an animated descendant is present; the composed
`RenderNode` subtree is cached only when the whole subtree is static.

Text caret, selection, composition, undo/redo, goal-column, and reveal changes
bump `text_revision`, so a static plan cannot retain stale editing UI. A
transition recorded before the host clock starts is latched as animating at
`now_ms == 0.0`, allowing the first real tick to advance it.

The environment identity is content-derived and never reused. Child
environment passthrough classification is memoized only for one view node and
one parent environment identity; a presentation-declaration change forces
reclassification. A scope can equal its parent for one input and differ for
another, so the classification itself is not a permanent node-kind property.

## Options Considered

### Option A: keep `now_ms` in the cache key

- Pros: no animation-contract audit; time-dependent paints naturally miss.
- Cons: every frame is unique, so the render cache is effectively disabled
  after the clock starts.

### Option B: keep the default-static-environment allowlist

- Pros: simple and conservative.
- Cons: themes, high DPI, locale, direction, custom text systems, focus, and
  editing state all disable useful caching; this is the confirmed regression
  being fixed.

### Option C: explicit key plus animation bypass

- Pros: stable keys across frames and environment variations, with a local
  escape hatch for time-dependent paint.
- Cons: every control that reads the clock must report `animating` correctly;
  a control that hides time dependence can produce a stale sample.

## Rationale

The cache boundary must follow what paint actually reads. Most paint input is
structural or environment-derived and stable across ticks; animation is the
small time-dependent subset. Keeping the clock in the key conflates the two and
destroys the common case. The `animating` flag already exists for scheduling
redraws, so using the same signal to bypass caching keeps one animation
contract rather than adding a second clock-sensitivity API.

## Consequences

- Unchanged repaints after `FrameTick` hit the render cache in themed, scaled,
  localized, RTL, focused, and custom-text-system environments.
- Static siblings survive a parent message rebuild when their own cache keys,
  layout state, and paint-dirty state are unchanged.
- Custom controls must report `animating` for every mid-animation sample.
  Controls whose paint depends on hidden mutable state must also expose that
  dependence through their declaration or view-state revision.
- A view whose paint reads child frames must keep its layout declaration
  exact; the runtime observes the resulting placement revision even when the
  node's own paint flag is clean.
- The clock-zero transition path is explicit: paint the from-state, report
  animating, and let the first tick advance progress rather than caching a
  terminal sample.

## Agent Notes

- **Session context**: consolidating three 2026-11-05 MoUI architecture reviews
  into an execution plan, then landing the first cache-correctness slice.
- **Key prompt**: combine the three analyses into the next development plan.
- **Validation**: runtime FrameTick and text-control cache tests, a real
  message-driven parent/static-child cache test, button clock-zero paint tests,
  and the focused runtime/core/views test suites.

## References

- `docs/plans/done/architecture-priority-execution.md`
- `moui/runtime/paint_engine.mbt`
- `moui/runtime/render_environment.mbt`
- `moui/runtime/element_tree.mbt`
- `moui/views/button/button.mbt`
