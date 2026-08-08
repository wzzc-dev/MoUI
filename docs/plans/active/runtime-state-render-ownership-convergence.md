# Plan: Runtime neutrality, state ownership, and render-resource convergence

- **Status**: active
- **RFC**: [0006](../../rfcs/0006-runtime-state-render-ownership-convergence.md)
- **ADR**: [0028](../../decisions/0028-runtime-state-render-ownership-convergence.md)
- **Baseline**: [backend-renderer-lifecycle-convergence](backend-renderer-lifecycle-convergence.md)
- **Goal**: Make runtime platform-neutral, leave one application state/effect
  model, keep control transients runtime-owned, and make each renderer session
  the sole owner of render resources and retained-layer residency.
- **Non-goals**: publishing 0.2, compatibility wrappers, provider/session
  redesign, renderer reclassification, registry changes, or platform-readiness
  promotion.

## Delivery sequence

1. Record RFC 0006, ADR 0028, this plan, and ownership invariants before code.
2. Move AccessKit conversion and bridge state from runtime to
   `moui/backend/accesskit`; leave only neutral semantics requests and results
   in runtime/core contracts.
3. Add immutable `ControlledValue`, migrate controls and repository apps to
   typed messages plus runtime-owned view slots, then remove the generic
   mutable state/component APIs and mutable navigation/focus holders.
4. Add `FrameToken`, `RenderFrameSubmission`, `RendererEvent`, and tokenized
   image request/completion; migrate backend frame/task owners and all four
   renderer sessions.
5. Emit complete retained-layer declarations every frame and remove runtime
   cache residency/admission, backend image resource mirrors, command-cache
   fallback, and revision fields from presentation completion.
6. Add MoonBit-backed ownership validation, regenerate interfaces, and update
   architecture, state, rendering, backend, app, and skill guidance.
7. Run focused package tests, static gates, profiles, host simulation, and
   path-triggered presentation checks that are available on the current host.

## Acceptance

- [x] `moui/runtime` has no AccessKit dependency, bridge, conversion, or
  AppKit/UIAutomation/AT-SPI platform token.
- [x] Platform accessibility adapters consume neutral semantics and own native
  bridge availability, conversion, diagnostics, and cleanup.
- [x] `Program`/`Effect`/`Subscription` is the only application state/effect
  loop; app-facing generic mutable state and component lifecycle APIs are gone.
- [x] Element-owned transient state uses typed runtime slots and cannot retain
  services, runtimes, renderers, task handles, or cleanup closures.
- [x] Controlled controls emit typed messages and have no setter path into an
  application model.
- [x] Frame completion is accepted only for the current surface generation and
  frame sequence; duplicate, stale, disposed, and cross-window events are
  rejected.
- [x] Backend image ownership contains cancellable I/O tasks only; renderer
  sessions own decode/resource/cache state and apply tokenized completions.
- [x] Every retained layer includes its complete payload each frame; runtime
  and backend do not mirror renderer residency, admission, or eviction.
- [x] Provider/session remains the only renderer lifecycle topology and the
  regression validator rejects the removed five-layer contracts.
- [x] Focused checks, interfaces, ownership gates, and feasible profiles/smoke
  pass without publishing or readiness changes.

## Decision log

| Date | Decision |
|------|----------|
| 2026-08-07 | Use one application state model plus runtime-owned control transient slots; do not force caret, IME, hover, or uncontrolled scroll into `Model`. |
| 2026-08-07 | Treat backend image state as cancellable I/O ownership only; renderer sessions uniquely own image/resource/cache state. |
| 2026-08-07 | Retained layers carry full payloads every frame so eviction never requires a host command-cache fallback. |
| 2026-08-07 | Keep the completed `RendererProvider -> RendererSession` topology from ADR 0027 and add regression gates only. |

## Progress

| Date | Note |
|------|------|
| 2026-08-07 | Plan, RFC, ADR, and initial ownership invariants established before production edits. |
| 2026-08-08 | Runtime AccessKit code moved behind `backend/accesskit`; generic mutable/component state APIs removed; controls/apps migrated to Program messages plus runtime slots. |
| 2026-08-08 | Frame/image flow migrated to `FrameToken`, renderer events, tokenized completion, and backend-owned cancellable I/O tasks only; retained layers now carry complete payloads with renderer-local residency. |
| 2026-08-08 | Markdown Editor immutable-model runtime tests repaired (420/420); maintenance, API, backend boundary, ownership, doc-reference, and renderer-capability gates pass. `pr` reaches the pre-existing Crater active-plan guidance inconsistency and stops there. |
