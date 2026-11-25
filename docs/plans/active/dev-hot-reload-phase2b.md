# Plan: Dev hot reload platform state (IME, accessibility, platform views)

- **Status**: active
- **ADR**: [0076](../../decisions/0076-dev-hot-reload-platform-state.md)
- **Goal**: In native hot mode, plugin text-input focus/caret/composition,
  committed semantics and platform-view placements reach host adapters, and a
  swap cleans the previous generation's native state.
- **Non-goals**: breaking ABI v1, a second diagnostics bus, reimplementing
  `PlatformViewPlugin`, duplicating Phase 2A coverage, or raising readiness
  without matching-host evidence.

## Delivery

1. Additive frame codecs (`semantics`, `platform_views`, `overlay_bounds`,
   `clear_color`, `text_input`) plus `TextInputEvent`/`PlatformViewEvent`;
   reject malformed present fields.
2. Add `SemanticsSnapshot::from_frame_payload`, `HostDriverHooks`, and the
   optional `dev_semantics_action` ABI trio; reuse AX/AT-SPI adapters.
3. Wire the generated host: forward events, publish semantics/text input, pass
   placements/overlay bounds, dispose native views on a generation change.
4. Run package loops, validators and `check.sh --profile pr`; rebase on Phase 2A.

## Acceptance

- [x] Every `TextInputEvent` reaches the plugin; focus/caret/selection survive a
  swap; CJK composition commits into the model.
- [x] Semantics round-trip and clear stale generation-N nodes; actions cross the
  optional ABI.
- [x] Placements round-trip; the wrapper disposes native views and forwards
  `PlatformViewEvent` (fake-plugin test; native presentation unverified).
- [x] `overlay_bounds`/transparent clear survive; ABI v1 stays load-compatible;
  malformed payloads apply no partial state.
- [x] Docs and `memories/repo/` state fields, cleanup and unverified evidence;
  validators and `check.sh --profile pr` pass.

## Log

| Date | Decision / progress |
|------|---------------------|
| 2026-11-25 | Keep ABI v1 additive; reuse `PlatformViewPlugin` and accessibility adapters; explicit disposal plus full semantics read on swap. |
| 2026-11-25 | Protocol, hooks, session bridge, generated host and cleanup landed; Linux Xvfb smoke passes; rebased on Phase 2A. |
