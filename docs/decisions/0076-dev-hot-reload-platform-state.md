# 0076: Dev hot reload carries platform-owned state across the bridge

- **Date**: 2026-11-25
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted)
- **Related**: ADR 0072, ADR 0073, ADR 0068, ADR 0029; plan
  `dev-hot-reload-phase2b`

## Context

ADR 0072/0073 swap only the app plugin over UTF-8 JSON at ABI v1, leaving three
host-invisible surfaces: text-input focus/IME (the host runtime has no app tree),
accessibility (AX/AT-SPI read host semantics, not plugin-owned semantics), and
platform views (placements and `PlatformViewEvent` never left the plugin). Native
AX nodes, IME state and views live in the long-lived host, so generation N must
be invalidated or replaced in N+1 without rebuilding the host.

## Decision

Carry platform state over the existing bridge; no second diagnostics bus or
production-path replacement. ABI stays v1 (additive).

1. **Frame.** `dev_frame` gains optional `semantics`
   (generation/root/focused/nodes), `platform_views` (ordered
   id/kind/frame/clip/properties), `overlay_bounds`, `clear_color`, and
   `text_input` (focus/frame/caret/selection/composition/caret rect). Missing
   means not provided; malformed present fields are rejected.
2. **Events.** The codec covers every `TextInputEvent` and
   `PlatformViewEvent::Named`; the plugin dispatches them and the host does not
   reinterpret them.
3. **IME/focus.** The plugin publishes `focused_text_input` every frame and the
   host installs `HostDriverHooks::focused_text_input`, so native IME/context
   menu follow plugin focus, caret, selection and composition. ADR 0068 restores
   these into the next generation; no IME state is retained host-side.
4. **Accessibility.** `SemanticsSnapshot::from_frame_payload` feeds
   `HostDriverHooks::read_semantics`/`perform_semantics_action`; existing
   macOS/AT-SPI adapters consume that driver unchanged. Actions use optional
   `dev_semantics_action`/`_len`/`_release` resolved all-or-nothing; absence means
   unavailable while reads still work. A swap bumps a synthetic generation and
   serves an empty `Full` snapshot until the new plugin publishes, so old nodes
   cannot survive; stale actions are rejected.
5. **Platform views.** `HostDriverHooks::augment_frame` layers placements,
   overlay bounds and clear color onto the host frame after plugin commands and
   forces full damage. Existing `PlatformViewPlugin`s create/position/z-order
   views around the bridge; native events reach plugin and host runtime; a
   generation change calls `dispose_platform_views` before syncing. macOS only
   hides unseen views, so absence from a frame is not disposal.

## Options considered

- ABI v2 — explicit schema, but lockstep rebuilds and no failure retention.
- Reconstruct from paint commands — no roles/actions/editing or view identity.
- Separate AX/diagnostics bus — violates one committed semantics stream.
- Host platform-view proxy — duplicates addon factories and native code.

## Consequences

- Dev frames are larger; semantics serialize only when the plugin opts in.
- The host owns swap cleanup: dispose views and reset the semantics cursor, or
  stale AX nodes/views leak.
- Live macOS AX/AT-SPI and native view presentation need matching-host evidence;
  portable codecs, bridge and cleanup are tested.
- General `DrawCommand`/`AppEvent` coverage is Phase 2A; this ADR covers only the
  platform-owned subset. `moui_devhost` stays outside the release closure.

## References

- ADR 0072, ADR 0073, ADR 0068, ADR 0029; plan
  `docs/plans/active/dev-hot-reload-phase2b.md`
- Code: `moui_devhost/{protocol,host,plugin}/`,
  `moui/apphost/host_driver_hooks.mbt`,
  `moui/backend/macos/macos_accessibility_bridge.mbt`,
  `moui/backend/linux/linux_atspi_host.mbt`
