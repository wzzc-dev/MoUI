# ADR 0029: WebView Controller, Bridge, And HostPatch

- **Date**: 2026-08-20
- **Status**: Accepted
- **Deciders**: Repository maintainer, agent-assisted
- **Related**: [implementation plan](../plans/active/webview-controller-bridge.md)

## Context

The WebView addon currently mixes immutable placement declarations with URL
navigation, exposes a mutable host command queue directly to applications, and
encodes lifecycle events as unrelated `name/value/detail/flag` fields. The
three native implementations do not agree on whether placement URL changes or
commands own navigation. DSH also executes an arbitrary script after a finish
callback, so the patch is neither configuration-scoped nor generation-safe.

## Decision

1. `moui_webview/host` owns `WebViewHost`, `WebViewController`, command and
   navigation IDs, request completion, schema-v1 JSON codecs, origin/channel
   policy, and HostPatch configuration. The base MoUI module remains unaware
   of WebView-specific types.
2. Composition roots create the host and controllers. Programs capture a
   controller in effect-producing closures; application models remain plain
   data. `web_view` stores only a stable controller identity and declarative
   appearance.
3. Controller commands are the sole navigation source. Placement sync happens
   before command drain so the native startup background and color scheme are
   applied before loading a page.
4. Native adapters derive the main-frame origin, attach the current navigation
   generation, and forward raw page JSON to the MoonBit owner. The owner rejects
   stale generations, disallowed origins/channels, invalid envelopes, and
   over-limit traffic.
5. HostPatch bundles are immutable, versioned, exact-origin configuration.
   They may provide CSS plus document-start/document-end scripts but no native
   capability. Public arbitrary JavaScript evaluation is removed.
6. The old queue, command enum, placement URL, and old event variants are
   removed together. The addon version advances to 0.2.0 and repository
   consumers migrate in the same change.

## Consequences

- Navigation, request cancellation, and stale-event handling have one owner.
- Authored pages can use a capability-checked event/RPC bridge while unmodified
  pages such as DSH can receive narrowly scoped host patches.
- Platform bindings grow a versioned command/event ABI and require matching-
  host smoke evidence, but application code no longer depends on native queues
  or JavaScript execution.

## Validation

- Pure MoonBit protocol, policy, controller, request, generation, and view
  declaration tests.
- Native adapter tests and a local HTTP fixture on macOS, Windows, and Linux.
- DSH rapid-switch, settings failure, HostPatch, and native background
  regression smokes.
- `moon info`, API/release/guidance validators, and PR/platform profiles.
