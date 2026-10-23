# 2026-10-23 — Pointer/input parity, S0–S6 + S8 + S9

- Workspace: MoUI, `main` working tree (nothing committed during the session).
- Plan: [pointer-input-parity](../plans/active/pointer-input-parity.md) — §0–§6,
  §8 and §9 landed; §7 (pinch/rotation, approved in full) and the fling half of
  §3 remain.

## Why the first plan was rejected

The first draft answered "what is MoUI missing versus a mature GUI toolkit" as a
list of *infrastructure* gaps. The owner rejected it and required six concrete
items folded in verbatim, with no RFC in front of any of them: timed wake so a
held long-press fires at its own duration, the `PointerEvent` multi-touch
contract (upstream `FingerId`/`Force`/`PinchGesture`/`RotationGesture` were
dropped by a `_ => None` arm in `window_event_decode.mbt`), the touch-era input
minimum set, scroll inertia/rebound, RTL layout mirroring, and fixing stale docs.
The lesson is about scope authoring, not about those features: a parity plan that
omits the user-visible behaviour it is supposed to unlock reads as plumbing work
and gets sent back.

## Judgments made during the work

- §3 was **split** rather than shipped whole. Rubber-band clamping, animated
  rebound and the derived scrollbar geometry all close inside `moui/views`;
  exponential velocity decay needs the runtime to pump frames while a subtree
  holds the paint latch. Shipping a decay function that nothing drives would have
  been another declared-but-inert API, so it is tracked as the remaining half of
  §3 behind an explicit owner approval for the `moui/runtime` pump.
- §4 kept the **published Web ABI** where it was. The workspace pointer ABI grew
  to 10 parameters (`id`, `pressure`), but the `moui_cli` scaffold template stays
  on the published 8-parameter line on purpose — the Studio export compiles the
  template against the released package, and widening it broke that build with
  "requires 8 arguments, but is given 10".
- §5 chose the **hard line** for triple-click (up to the next `\n`) and a bounded
  word-boundary subset for double-click, instead of claiming UAX #29. The
  honest-subset decision is the same one that shaped §6's semantics work.
- §9 reversed its own design note while implementing. The plan put the canonical
  mirror helper in `moui/views/common`; that missed that `moui/core` needs the
  identical formula for alignment and guides and can import nothing, so a
  views-side home guarantees a second copy. The formula moved to
  `Rect::mirrored_x`/`Insets::mirrored` in core, `layout_mirror_x` and the
  drafted `view_mirror_*` helpers were deleted, and
  `CustomPlacementContext::mirror_x` became the delegate-facing spelling that the
  framework's own two custom-layout delegates now use. Net public effect: +2 core
  methods, −1 views method.
- §9 also corrected its own "wheel is unchanged by design" row. Because
  `offset.x` is a leading-edge distance, a physical delta cannot be added to it
  directly; the conversion is isolated in `scroll_leading_x_delta`, applied only
  at the wheel branch and the container-drag path, with events staying physical
  and `scroll_clamp_offset` direction-free. Auto-reveal needed no change, which
  is the payoff of that boundary: it dispatches a physical delta and inherits the
  flip.
- RTL overlay placement was structurally unreachable (the overlay context had no
  direction). Fixed by one `OverlayPlacementContext.layout_direction` field and
  one runtime fill, and `PresentationPlacement::resolve` gained a **required**
  `direction~` instead of a silent `LeftToRight` default, because a defaulted
  label compiles and still lands the popup on the wrong side.

## Pitfalls hit

- MoonBit syntax: `-.x` does not parse (repo idiom is `0.0 - x`); tuple
  destructuring needs parentheses, `let (a, b) = ...`; a labeled parameter is
  referenced bare in the body but must be *passed* as `direction~` or
  `direction=`; a bare cross-package enum constructor works in argument and
  pattern position but not in an unannotated array literal, so
  `let ds : Array[@core.LayoutDirection] = [LeftToRight, RightToLeft]` is the
  form that compiles; `import { ... } for "test"` is required for a package whose
  test bucket needs a sibling package.
- `moon check <pkg>` can answer "Finished. moon: no work to do" after real edits,
  so verification went through `moon test` and workspace-wide `moon check`.
- The `pr` profile compiles native only. Four workspace Web forwarders shipped
  calling the 10-parameter export with 8 arguments and were caught afterwards by
  `moon check <pkg> --target wasm-gc`; that command is now recorded in
  `memories/repo/pointer-stream-identity.md` instead of a new gate.
- Local toolchain: `nvm` Node v18 breaks the Skia prebuild, so scripts run with
  `PATH=/opt/homebrew/opt/node/bin:$PATH`. Concurrent `moon` subprocesses produced
  `compile_native` flakes in the Studio evidence run; the smokes were rerun
  sequentially.
- `moui/views` is a facade and every subpackage owns its own
  `pkg.generated.mbti`, so test runs must name each subpackage explicitly and
  shared private helpers cannot cross subpackages — the reason
  `moui/views/layout`, `moui/views/controls` and `moui/views/presentation` each
  got a local test-context builder instead of importing one.

## Evidence at handoff

- 341/341 green across `moui/core`, the touched `moui/views` subpackages and
  `moui/runtime`; 159/159 runtime tests green with the inert
  `layout_direction~` parameter deleted, which is what proves it carried nothing.
- New mirroring cases are all LTR/RTL pairs (5 in core, 4 in `views/common`, 4 in
  `views/layout` — that directory had zero test files before, 5 in
  `views/controls`, 4 in `views/presentation`).
- `moui/core` measured 2518 lines / 1113 pub; the cap comment carries the reason,
  `checks/api-surface-report.json` and `docs/repository-facts.md` regenerated, and
  `checks/source-file-policy.json` moved one ratchet (1704 → 1710) because the §9
  note text itself counts against the logic-line budget of the file that holds it.
  `sh scripts/check.sh --profile pr` is green end to end.
- Owner-side manual checks still open: `moon run examples/showcase/macos_skia
  --target native` and real two-touch Web verification.
