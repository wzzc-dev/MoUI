# 0076: Dev hot reload carries platform-owned state across the bridge

- **Date**: 2026-11-25
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted)
- **Related**: ADR 0072, ADR 0073, ADR 0068, ADR 0029, plan
  `dev-hot-reload-phase2b`

## Context

ADR 0072/0073 keep one native host process and swap only the app plugin image
over UTF-8 JSON at ABI v1. Phase 1 carried a paint-command subset, basic input,
resize/redraw/close and the dev transient snapshot. Three platform-owned
surfaces stayed host-invisible:

- **Text input focus.** Native IME sync reads the host runtime's focused
  element, which has no app tree, so preedit, commit and caret are absent.
- **Accessibility.** The macOS NSAccessibility and Linux AT-SPI adapters read
  the host runtime's committed semantics, which a plugin-owned tree never
  reaches.
- **Platform views.** `DrawFrame.platform_views` is produced by the plugin, so
  native web/video/map views see no placements and `PlatformViewEvent` never
  reaches the app.

Native AX nodes, IME state and views live in the long-lived host, so state from
generation N must be invalidated or replaced in N+1. Rebuilding the host would
defeat hot reload, so the protocol stays additive at ABI v1.

## Decision

Carry platform state over the existing bridge, with no second diagnostics bus
and no production path replacement.

1. **Frame payload (additive, schema v1).** `dev_frame` gains optional
   `semantics` (generation, root, focused, nodes), `platform_views` (ordered
   id/kind/frame/clip/properties), `overlay_bounds`, `clear_color` and
   `text_input` (focus, frame, caret, selection, composition, caret rect).
   Missing means "not provided"; decode never invents platform state, malformed
   present fields are rejected, and unknown fields are ignored.
2. **Events.** The bridge event codec covers every `TextInputEvent` variant and
   `PlatformViewEvent::Named` in addition to the parallel Phase 2A general
   coverage. The plugin dispatches them into its `AppRuntime`; the host does not
   re-interpret them.
3. **Text input and focus.** The plugin publishes `focused_text_input` every
   frame. The generated host installs
   `HostDriverHooks::focused_text_input`, so the native IME session and context
   menu read the plugin's focus, caret, selection and composition. ADR 0068's
   transient transport restores them into the next generation, and its first
   frame re-syncs the host IME session. No IME state is retained host-side
   across generations.
4. **Accessibility.** The plugin enables semantics frames. An additive
   `SemanticsSnapshot::from_frame_payload` lets the host feed
   `HostDriverHooks::read_semantics` and `perform_semantics_action`; existing
   macOS/AT-SPI adapters consume that driver stream unchanged. Actions use an
   optional ABI trio (`dev_semantics_action`, `_len`, `_release`) resolved
   together with `dlsym`; absence means actions are unavailable, reads still
   work. Reads are generation-scoped: a swap bumps a synthetic generation and
   forces an empty `Full` snapshot until the new plugin publishes, so old nodes
   cannot survive. The plugin rejects stale-precondition actions.
5. **Platform views.** `HostDriverHooks::augment_frame` layers placements,
   overlay bounds and clear color onto the host frame after the bridge view
   paints the plugin commands, and forces full damage so a transparent
   platform-view frame is not skipped. Existing `PlatformViewPlugin`
   implementations create/position/z-order views around the bridge surface.
   Native events are forwarded to the plugin in addition to the host runtime.
   On a generation change the host wrapper calls `dispose_platform_views`
   before syncing the first new frame; macOS only hides unseen views, so
   absence from a frame is not disposal.
6. **Compatibility.** `dev_abi_version` stays 1. The action symbols and every
   new JSON field are optional and additive, so old/new host and plugin images
   interoperate; old images simply expose no platform state.
7. **Scope.** Production packages gain only `SemanticsSnapshot::from_frame_payload`
   and the opt-in `HostDriverHooks` seam. `moui_devhost` remains outside the
   release closure, and hot-mode support raises no readiness claim.

## Options Considered

- **Bump the ABI to v2.** Explicit schema version, but it breaks failure
  retention (an old generation must stay live after a failed build) and forces
  lockstep rebuilds. Rejected; additive v1 fields match the transient
  transport's evolution.
- **Reconstruct state from paint commands.** No protocol growth, but commands
  carry no roles, actions, editing state or native view identity; rebuilding
  would duplicate and drift from the plugin tree. Rejected.
- **Separate diagnostics/AX bus.** Decouples from frame cadence, but violates
  the single committed semantics stream and would not reuse the existing
  adapters. Rejected.
- **Host-owned platform-view proxy.** Duplicates the addon
  `PlatformViewPlugin` factories and their native code. Rejected.

## Rationale

The plugin owns the app tree, so its state must travel plugin → host. Frames are
already periodic and generation-tagged, and host adapters already consume
`DrawFrame`, `TextInputState`, semantics and placements; extending the frame
reuses that stack. Replacing the semantics tree wholesale gives stale cleanup
directly, and additive ABI fields keep a failed build's generation interactive
without a host restart.

## Consequences

- Dev frames are larger; semantics serialize once per painted frame only when
  the plugin opted in. Cost is confined to `moui dev`.
- The host owns swap cleanup: native platform views must be disposed and the
  semantics cursor reset, or stale AX nodes/views leak across generations.
- Host caches derived from a frame must be invalidated on a plugin swap.
- Readiness is unchanged. Live macOS AX query/action, a live Linux AT-SPI
  client and native platform-view presentation need matching-host evidence;
  portable codecs, bridge and cleanup rules are covered by tests. Docs state
  this rather than implying hot-mode parity.
- General `DrawCommand`/`AppEvent` coverage belongs to the parallel Phase 2A
  slice; this ADR covers only the platform-owned subset.

## Agent Notes

Phase 2B of native dev hot reload (IME/text editing, semantics/accessibility,
platform views) on an Orca worker (DeepSeek-V4.1-Flash). The prompt required
additive ABI v1, adapter reuse and swap cleanup proof. Validation: protocol
round-trips, fake-plugin disposal, a Session bridge CJK/action test and the
Linux Xvfb smoke; live macOS AX/AT-SPI and native view presentation remain
unverified.

## References

- ADR 0072 (macOS hot reload), ADR 0073 (Linux hot reload), ADR 0068 (dev
  transient handoff), ADR 0029 (native accessibility adapters)
- Plan: `docs/plans/active/dev-hot-reload-phase2b.md`
- Code: `moui_devhost/protocol/`, `moui_devhost/host/`,
  `moui_devhost/plugin/`, `moui/apphost/host_runtime_driver.mbt`,
  `moui/apphost/host_driver_hooks.mbt`,
  `moui/backend/macos/macos_accessibility_bridge.mbt`,
  `moui/backend/linux/linux_atspi_host.mbt`,
  `moui/backend/platform_view_plugin.mbt`
