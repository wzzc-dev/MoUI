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
   `clear_color`, `text_input`) plus `TextInputEvent`/`PlatformViewEvent`
   codecs; reject malformed present fields.
3. Add `SemanticsSnapshot::from_frame_payload`, `HostDriverHooks`, and the
   optional `dev_semantics_action` ABI trio; reuse existing AX/AT-SPI adapters.
4. Wire the generated host: forward events, publish plugin semantics/text input,
   pass placements/overlay bounds to the backend, and dispose native views on a
   generation change.
5. Run package loops, pre-push validators and `check.sh --profile pr`; rebase on
   Phase 2A and own the PR until green.

## Acceptance

- [x] Every `TextInputEvent` round-trips to the plugin runtime; focus, caret and
  selection survive a simulated swap; a CJK composition/preedit sequence commits
  into the app model.
- [x] Semantics round-trip; a generation N node is gone while a new one is
  exposed after the N+1 full replacement; actions cross the optional ABI.
- [x] Placements/properties round-trip; the wrapper disposes native views on a
  swap and `PlatformViewEvent` reaches the plugin (fake-plugin test; native
  presentation unverified).
- [x] `overlay_bounds` and transparent clear survive the bridge; ABI v1 stays
  load-compatible both ways and malformed payloads apply no partial state.
- [x] Docs and `memories/repo/` state the fields, cleanup rule and unverified
  native evidence; pre-push validators and `check.sh --profile pr` pass.

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-25 | Keep ABI v1; new fields additive; `dev_semantics_action` optional. |
| 2026-11-25 | Reuse `PlatformViewPlugin` and existing accessibility adapters. |
| 2026-11-25 | Swap cleanup is explicit disposal plus a full semantics read. |

## Progress

| Date | Note |
|------|------|
| 2026-11-25 | Protocol, hooks, session bridge, generated host and cleanup landed; Linux Xvfb smoke passes; rebased on Phase 2A. |
