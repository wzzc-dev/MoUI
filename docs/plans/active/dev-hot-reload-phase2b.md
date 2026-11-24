# Plan: Dev hot reload platform state (IME, accessibility, platform views)

- **Status**: active
- **ADR**: [0076](../../decisions/0076-dev-hot-reload-platform-state.md)
- **Goal**: In native hot mode, the plugin's text-input focus/caret/composition,
  committed semantics and platform-view placements reach the host adapters, and
  a generation swap cleans the previous generation's native state.
- **Non-goals**: breaking ABI v1, a second diagnostics bus, reimplementing
  `PlatformViewPlugin`, duplicating Phase 2A's frame/event coverage, or raising
  readiness without matching-host evidence.

## Delivery sequence

1. Record ADR 0076, this plan and doc/memory updates.
2. Add additive frame codecs (`semantics`, `platform_views`, `overlay_bounds`,
   `clear_color`, `text_input`) and all `TextInputEvent`/`PlatformViewEvent`
   codecs; reject malformed present fields.
3. Add `SemanticsSnapshot::from_frame_payload`, `HostDriverHooks`, and the
   optional `dev_semantics_action` ABI trio; reuse existing AX/AT-SPI adapters.
4. Wire the generated host: forward host events, publish plugin semantics and
   text input, pass placements/overlay bounds to the backend, and dispose native
   views on a generation change.
5. Run package loops, pre-push validators and `check.sh --profile pr`; rebase on
   Phase 2A if needed and own the PR until green.

## Acceptance

- [x] Every `TextInputEvent` variant round-trips and reaches the plugin runtime;
  focus, caret and selection survive a simulated generation swap.
- [x] A CJK composition/preedit sequence commits into the app model, with
  caret/selection reflected in `text_input`.
- [x] Semantics round-trip; a generation N node is gone after the N+1 full
  replacement while a new node is exposed; actions cross the optional ABI.
- [x] Placements/properties round-trip; the wrapper disposes native views on a
  swap, and `PlatformViewEvent` reaches the plugin (fake-plugin host test;
  native presentation unverified).
- [x] `overlay_bounds` and transparent clear survive the bridge.
- [x] ABI v1 stays load-compatible both ways; malformed payloads do not apply
  partial state.
- [x] Docs and `memories/repo/` describe the fields, cleanup rule and unverified
  native evidence.
- [ ] Pre-push validators and `check.sh --profile pr` pass.

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-25 | Keep ABI v1; all new fields additive; `dev_semantics_action` optional. |
| 2026-11-25 | Reuse `PlatformViewPlugin` and existing accessibility adapters. |
| 2026-11-25 | Swap cleanup is explicit disposal plus a full semantics read. |

## Progress

| Date | Note |
|------|------|
| 2026-11-25 | ADR/plan written; protocol/host work in progress. |
| 2026-11-25 | Protocol, hooks, session bridge, generated host and cleanup landed; Linux Xvfb smoke passes after fixing watcher content-edit detection. |
