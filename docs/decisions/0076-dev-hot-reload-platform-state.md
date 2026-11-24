# 0076: Dev hot reload carries platform-owned state across the bridge

- **Date**: 2026-11-25
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted)
- **Related**: ADR 0072, ADR 0073, ADR 0068, ADR 0029; plan
  `dev-hot-reload-phase2b`

## Context

ADR 0072/0073 swap only the app plugin over UTF-8 JSON at ABI v1. Three
platform-owned surfaces stayed host-invisible: text-input focus/IME (the host
runtime has no app tree), accessibility (AX/AT-SPI read host semantics, not
plugin-owned semantics), and platform views (placements and
`PlatformViewEvent` never left the plugin). Native AX nodes, IME state and views
live in the long-lived host, so generation N must be invalidated or replaced in
N+1 without rebuilding the host.

## Decision

Carry platform state over the existing bridge; no second diagnostics bus or
production-path replacement. ABI stays v1 (additive).

1. **Frame.** `dev_frame` gains optional `semantics`
   (generation/root/focused/nodes), `platform_views` (ordered
   id/kind/frame/clip/properties), `overlay_bounds`, `clear_color`, and
   `text_input` (focus/frame/caret/selection/composition/caret rect). Missing
   means not provided; malformed present fields are rejected; unknown fields are
   ignored.
2. **Events.** The codec covers every `TextInputEvent` and
   `PlatformViewEvent::Named`; the plugin dispatches them and the host does not
   reinterpret them.
3. **IME/focus.** The plugin publishes `focused_text_input` every frame and the
   host installs `HostDriverHooks::focused_text_input`, so native IME and the
   context menu follow plugin focus, caret, selection and composition. ADR 0068
   restores these into the next generation; no IME state is retained host-side.
4. **Accessibility.** The plugin enables semantics.
   `SemanticsSnapshot::from_frame_payload` feeds
   `HostDriverHooks::read_semantics`/`perform_semantics_action`, and existing
   macOS/AT-SPI adapters consume that driver unchanged. Actions use the optional
   `dev_semantics_action`/`_len`/`_release` trio resolved all-or-nothing;
   absence means unavailable while reads still work. A swap bumps a synthetic
   generation and serves an empty `Full` snapshot until the new plugin
   publishes, so old nodes cannot survive; stale actions are rejected.
5. **Platform views.** `HostDriverHooks::augment_frame` layers placements,
   overlay bounds and clear color onto the host frame after plugin commands and
   forces full damage. Existing `PlatformViewPlugin`s create/position/z-order
   views around the bridge; native events reach the plugin and host runtime; a
   generation change calls `dispose_platform_views` before syncing. macOS only
   hides unseen views, so absence from a frame is not disposal.
6. **Compatibility/scope.** Only `SemanticsSnapshot::from_frame_payload` and the
   opt-in `HostDriverHooks` enter production packages; `moui_devhost` stays
   outside the release closure and hot mode raises no readiness claim.

## Options considered

- ABI v2 — explicit schema, but lockstep rebuilds and breaks failure retention.
- Reconstruct from paint commands — commands carry no roles/actions/editing or
  native-view identity.
- Separate AX/diagnostics bus — violates one committed semantics stream and
  duplicates adapters.
- Host platform-view proxy — duplicates addon factories and native code.

## Rationale

The plugin owns the app tree, so state must travel plugin → host. Frames are
already periodic and generation-tagged, and adapters already consume frames,
text input, semantics and placements; extending that stack reuses the adapters.
Wholesale semantics replacement makes stale cleanup direct; additive fields keep
a failed build's UI interactive without restart.

## Consequences

- Dev frames are larger; semantics serialize once per painted frame only when
  opted in.
- The host owns swap cleanup: dispose views and reset the semantics cursor, or
  stale AX nodes/views leak across generations.
- Host caches derived from a frame must be invalidated on a plugin swap.
- Readiness is unchanged: live macOS AX/AT-SPI query/action and native
  platform-view presentation need matching-host evidence; portable
  codecs/bridge/cleanup are tested.
- General `DrawCommand`/`AppEvent` coverage is Phase 2A; this ADR covers only
  the platform-owned subset.

## Evidence

Phase 2B on an Orca worker (DeepSeek-V4.1-Flash): protocol round-trips,
fake-plugin disposal, Session CJK/action tests and Linux Xvfb smoke passed; live
macOS AX/AT-SPI and native views remain unverified.

## References

- ADR 0072, ADR 0073, ADR 0068, ADR 0029
- Plan: `docs/plans/active/dev-hot-reload-phase2b.md`
- Code: `moui_devhost/{protocol,host,plugin}/`,
  `moui/apphost/host_driver_hooks.mbt`,
  `moui/backend/macos/macos_accessibility_bridge.mbt`,
  `moui/backend/linux/linux_atspi_host.mbt`
