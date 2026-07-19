# Plan: Web first-click DPR synchronization

- **Status**: done
- **Goal**: Make a Website control activate on its first physical pointer
  click, while keeping browser DPR conversion correct.
- **Non-goals**: Changing Website navigation behavior, adding a second pointer
  bridge, or changing the public `wzzc-dev/window` API.

## Acceptance

- [x] Browser resize updates the Web window's stored scale factor before later
  pointer input is converted to logical coordinates.
- [x] A focused `window/web` regression test covers the DPR update.
- [x] The Website's first physical click activates Tutorial and other header
  controls without a priming click.
- [x] The browser input router treats canvas, hidden text input, and semantic
  overlay elements as one focus host, so an internal focus transition cannot
  turn a `Down` into a `Cancel`.
- [x] Local-window dev mode is disabled before handoff.

## Decision log

| Date | Decision |
|------|----------|
| 2026-07-19 | Fix the Web host's persisted DPR state in `window/web`; do not add per-button website workarounds. |
| 2026-07-20 | Keep focus transitions within the canvas host (including the semantic overlay) out of the window-blur cancellation path. |

## Progress

| Date | Note |
|------|------|
| 2026-07-19 | Reproduced with a real pointer click: the first click only focuses the canvas, the second activates Tutorial. The browser sends a DPR-2 resize, but `window/web` queues the scale-change event without updating the stored factor used by pointer conversion. |
| 2026-07-20 | Tested `wzzc-dev/window@0.5.1-0.1.7` (commit `33a9134`): it has the same first-click failure, so `edf6ac…` did not introduce it. That commit did expose a separate DPR bridge requirement. |
| 2026-07-20 | Browser trace identified `focus → Down → blur → Up` on the first semantic click. The blur became a pointer cancel and removed capture. Tutorial and Showcases now navigate on their first click in the in-app browser. |
