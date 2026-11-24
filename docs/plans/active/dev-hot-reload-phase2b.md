# Plan: Dev hot reload platform state (IME, accessibility, platform views)

- **Status**: active
- **ADR**: [0076](../../decisions/0076-dev-hot-reload-platform-state.md)
- **Goal**: Remove the Phase 2 gap left by ADR 0072/0073: in native hot mode,
  the plugin's text-input focus/caret/composition, committed semantics tree and
  platform-view placements reach the host adapters, and a generation swap
  cleans the previous generation's native state instead of leaking it.
- **Non-goals**: changing ABI v1 or production platform paths, a second
  diagnostics bus, reimplementing the addon `PlatformViewPlugin` contract,
  duplicating the parallel Phase 2A frame/event coverage, or raising any
  platform readiness claim without matching-host evidence.

## Delivery sequence

1. Record ADR 0076, this plan, and the doc/memory updates before production
   changes.
2. Add additive frame codecs for `semantics`, `platform_views`,
   `overlay_bounds`, `clear_color` and `text_input`, plus event codecs for every
   `TextInputEvent` variant and `PlatformViewEvent`; keep `dev_abi_version == 1`
   and reject malformed required payloads.
3. Add the host bridges: `SemanticsSnapshot::from_frame_payload`,
   `HostSemanticsBridge`, `HostRuntimeDriver` semantics/text-input overrides,
   and the optional `dev_semantics_action` ABI symbol. Reuse the macOS
   NSAccessibility and Linux AT-SPI adapters unchanged.
4. Wire the generated host: forward every host event (including IME-mapped
   text input) to the plugin, publish plugin semantics and text-input state to
   the driver, pass platform-view placements and overlay bounds to the backend,
   and dispose native platform views on a generation change.
5. Extend the Linux Xvfb hot-reload smoke to drive a composition sequence and a
   semantics/platform-view assertion; record what a given host cannot verify.
6. Run the smallest package loops, the pre-push validators, and `check.sh
   --profile pr`; rebase onto the Phase 2A branch if it is ahead; open the PR
   and own it until green.

## Acceptance

- [ ] Every `TextInputEvent` variant round-trips through the bridge and reaches
  the plugin's `AppRuntime`; a focused text field keeps focus, caret and
  selection across a generation swap.
- [ ] A composition/preedit sequence through the bridge commits CJK text into the
  app model, with caret/selection reflected in the frame's `text_input` state.
- [ ] `DrawFrame.semantics` round-trips; the host serves `read_semantics` from
  the plugin payload and forwards actions over the optional ABI symbol; a node
  exposed in generation N is absent after the N+1 full replacement while a new
  node is exposed.
- [ ] `platform_views` placements/properties round-trip; the host creates,
  positions and z-orders native views through the existing plugin contract,
  forwards `PlatformViewEvent` into the plugin, and disposes them on a swap
  without stale z-order or leaks.
- [ ] `overlay_bounds` and transparent clear survive the bridge so the host
  paints behind/around native views.
- [ ] ABI v1 remains load-compatible in both directions; malformed payloads are
  rejected without dispatching partial state.
- [ ] Docs (`development.md`, `testing.md`, ADR index, plan index) and
  `memories/repo/` describe the new fields, the swap cleanup rule, and exactly
  which native evidence is unverified.
- [ ] `sh scripts/check.sh --profile pr`, the pre-push validators, and targeted
  `moon test` loops pass.

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-25 | Keep ABI v1 and make every new frame/event field additive; add `dev_semantics_action` as an optional symbol. |
| 2026-11-25 | Reuse the existing `PlatformViewPlugin` contract and accessibility adapters; no second diagnostics path. |
| 2026-11-25 | Swap cleanup is explicit generation-scoped disposal plus a full semantics read, not "absence means gone". |

## Progress

| Date | Note |
|------|------|
| 2026-11-25 | ADR 0076 and plan written; protocol/host work in progress. |
