# 0076: Dev hot reload carries platform-owned state across the bridge

- **Date**: 2026-11-25
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted)
- **Related**: ADR 0072, ADR 0073, ADR 0068, ADR 0029, plan
  `dev-hot-reload-phase2b`

## Context

ADR 0072 and ADR 0073 made native `moui dev --hot` keep one host process and
swap only the app plugin image. The generated bridge host owns the window,
renderer, input and platform services; the generated `foreign_library` owns the
app `Program` and its `AppRuntime`. Only UTF-8 JSON crosses `dev_event` /
`dev_frame`, and ABI v1 is fixed.

Phase 1 deliberately carried the smallest useful payload: a paint-command
subset, basic pointer/keyboard/insert-text events, and resize/redraw/close. That
left three platform-owned surfaces invisible in hot mode:

- **Text input focus.** Native IME sync reads the host runtime's focused
  element, and the host runtime has no app tree. The plugin's focused control,
  caret, selection and composition never reach the host, so preedit, commit and
  caret placement are absent or wrong.
- **Accessibility.** The macOS NSAccessibility and Linux AT-SPI adapters read
  the host runtime's committed semantics stream. A plugin-owned app tree
  publishes nothing to them.
- **Platform views.** `DrawFrame.platform_views` is produced by the plugin
  runtime, so native web/video/map views hosted by the backend never see
  placements, and `AppEvent::PlatformView` events never reach the app.

A second constraint follows from the swap: the host outlives the plugin image
while native objects (AX nodes, IME state, native views) live in the host
process. Anything derived from generation N must be invalidated or replaced in
generation N+1. Rebuilding the host on every edit would defeat the feature, so
the protocol has to be additive and stay at ABI v1.

## Decision

Carry the platform-owned state across the existing bridge, without a second
diagnostics bus and without changing production platform paths.

1. **Frame payload (additive, schema version 1).** `dev_frame` JSON gains
   optional fields, all derived from the plugin's `DrawFrame`:
   - `semantics` — the committed semantics payload (`generation`, `root`,
     `focused`, nodes) when the plugin enables semantics frames;
   - `platform_views` — ordered placements (`id`, `kind`, `frame`, `clip`,
     properties);
   - `overlay_bounds` — the overlay paint union, when present;
   - `clear_color` — the frame clear color, so a transparent platform frame
     survives the bridge;
   - `text_input` — the focused `TextInputState` (focus flag, frame, caret,
     selection, composition, composition cursor, caret rect).
   Missing fields mean "not provided"; decode never invents platform state.
   Unknown fields are ignored, so old and new images can interleave.

2. **Events.** The bridge event codec covers every `TextInputEvent` variant
   (`CompositionStart`, `CompositionUpdate`, `CompositionEnd`, `InsertText`,
   `ReplaceText`, `SetSelection`, `DeleteRange`, `DeleteSurrounding`) and
   `PlatformViewEvent::Named`, in addition to the general event coverage owned
   by the parallel Phase 2A slice. The plugin dispatches them into its own
   `AppRuntime`; the host never re-interprets them.

3. **Text input and focus survival.** The generated host driver gains a
   text-input override fed from the latest frame. While the bridge is attached,
   `HostRuntimeDriver::focused_text_input()` — and therefore the native IME
   session and the host context menu — reports the plugin's `TextInputState`.
   Focus, caret, selection and composition already ride the ADR 0068 transient
   transport, so a swap restores them into the new generation; the first frame
   from that generation re-syncs the host IME session. No IME state is stored
   host-side across generations.

4. **Accessibility.** The plugin enables semantics frames, so each frame
   carries the committed tree. A new additive
   `SemanticsSnapshot::from_frame_payload` lets the host build a
   `HostSemanticsBridge`; the driver serves `read_semantics` and
   `perform_semantics_action` from it. Semantics actions are forwarded to the
   plugin over a new **optional** `dev_semantics_action` ABI symbol carrying a
   JSON `PerformSemanticsActionRequest` and returning a JSON receipt or
   `SemanticsActionDispatchError`; the symbol is resolved with `dlsym`, and its
   absence means actions are unavailable while reads still work. The macOS
   NSAccessibility and Linux AT-SPI adapters are reused unchanged. Reads are
   generation-scoped: the host cursor resets on a swap and the first read of a
   new generation is `Full`, so native nodes from generation N cannot survive
   into N+1. The plugin's runtime rejects actions whose precondition generation
   is stale.

5. **Platform views.** `DevBridgeView` publishes the frame's placements and
   overlay bounds, so the backend's existing `PlatformViewPlugin` implementations
   create/position/z-order native views around the bridge surface. Native
   events route through the host event source into the plugin. On a generation
   change the host calls `dispose_platform_views` for the window before syncing
   the first frame of the new generation; because some plugins only hide unseen
   views (macOS), disposal is explicit rather than "absence from the new frame".
   The bridge clear/overlay metadata keeps host paint behind and around native
   views.

6. **Compatibility.** `dev_abi_version` stays 1. The new symbol is optional for
   both directions, and every new frame/event field is additive JSON. A new
   host can load an old plugin (no platform state), and an old host can load a
   new plugin (unknown fields ignored; no semantics/platform views).

7. **Scope boundary.** Production packages gain only additive dev-facing seams
   (the snapshot adapter and driver bridge setters, plus a bridge-backdrop
   `ViewNode` hook if the runtime union needs one). `moui_devhost` remains a
   dev-only module outside the release closure. No new readiness claim follows
   from hot-mode support.

## Options Considered

### Option A: bump the bridge ABI to v2

- Pros: one explicit schema version.
- Cons: breaks the property that a failed build leaves the previous generation
  interactive, forces lockstep host/plugin rebuilds for every field addition,
  and invalidates images produced before the upgrade. Rejected; additive v1
  fields are cheaper and match how the transient transport already evolves.

### Option B: host-side reimplementation from paint commands

- Pros: no protocol growth.
- Cons: paint commands carry no roles, actions, text-editing state or native
  view identity. Reconstructing them in the host would duplicate the render
  tree and drift from the plugin. Rejected.

### Option C: separate diagnostics/AX bus

- Pros: decouples accessibility from frame cadence.
- Cons: violates the "one committed semantics stream" rule, creates a second
  source of truth, and would not reuse the existing macOS/AT-SPI adapters.
  Rejected.

### Option D: host-owned platform-view proxy

- Pros: the host could own native views directly.
- Cons: duplicates the addon `PlatformViewPlugin` factories and their
  per-platform native code. Reusing the backend contract is smaller and keeps
  the plugin contract as the only platform-view owner. Rejected.

## Rationale

The plugin is the only owner of the app tree, so every piece of platform state
must travel from the plugin to the host, not the reverse. The frame is already
the periodic, generation-tagged carrier, and the host's platform adapters
already consume `DrawFrame`, `TextInputState`, semantics reads and platform
view placements — so extending the frame payload reuses the entire adapter
stack instead of adding a parallel one. Generation-scoped full snapshots give
the stale-cleanup property for free: replacing the tree wholesale is the
simplest correct answer to "node N must be gone in N+1".

The ABI stays additive because the hot-reload contract explicitly promises that
a build failure leaves the previous generation live. A lockstep version bump
would make that promise conditional on rebuilding the host, which is exactly
the restart this feature exists to avoid.

## Consequences

- Dev-mode frames are larger, and semantics serialization runs once per painted
  frame only when the plugin opted in. The cost is confined to `moui dev`.
- The host owns lifecycle duties that were implicit before: disposing native
  platform views and resetting the semantics cursor on every swap. Tests must
  cover both, or a swap leaves stale AX nodes or leaked native views.
- Any host-side cache keyed on a frame must be invalidated when the plugin
  generation changes; caches keyed by revision already do this.
- Readiness is unchanged. macOS AX query/action from a live display, a live
  Linux AT-SPI client, and a native platform-view presentation need
  matching-host evidence; the portable codecs, bridge and disposal rules are
  covered by tests without them. Docs must say exactly which parts are
  unverified rather than implying hot-mode parity.
- General `DrawCommand`/`AppEvent` coverage is delivered by the parallel Phase
  2A slice; this ADR covers the platform-owned subset (IME state, semantics,
  accessibility, platform views) and expects that slice before release.

## Agent Notes

- **Session context**: Phase 2B of native dev hot reload — carrying IME/text
  editing, semantics/accessibility and platform views across the bridge.
- **Agent model**: DeepSeek-V4.1-Flash (Orca worker).
- **Key prompt**: complete the platform-owned state ADR 0072/0073 left as Phase
  2; keep ABI v1 additive, reuse existing accessibility adapters, and prove
  stale-node/native-view cleanup on a generation swap.
- **Validation**: protocol round-trip tests for every new field and event
  variant, host disposal tests with fake platform-view plugins, and the Linux
  Xvfb hot-reload smoke; native AX/AT-SPI and web-view evidence recorded under
  `artifacts/` and reported as verified or unverified per host.

## References

- ADR 0072: native dev hot reload bridge host + plugin dylib
- ADR 0073: Linux native dev hot reload
- ADR 0068: dev transient handoff
- ADR 0029: native accessibility adapters and evidence
- Plan: `docs/plans/active/dev-hot-reload-phase2b.md`
- Code: `moui_devhost/protocol/`, `moui_devhost/host/`,
  `moui_devhost/plugin/`, `moui/apphost/host_runtime_driver.mbt`,
  `moui/backend/macos/macos_accessibility_bridge.mbt`,
  `moui/backend/linux/linux_atspi_host.mbt`,
  `moui/backend/platform_view_plugin.mbt`
