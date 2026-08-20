# Plan: WebView Controller And Bridge

- **Status**: active
- **Goal**: Replace the mutable command queue and ad-hoc event fields with one
  controller-owned navigation, JSON bridge, security, and host-patch contract
  across macOS, Windows, and Linux.
- **Non-goals**: Add mobile WebView backends, alter page theme content, or move
  WebView-specific state into the base `wzzc-dev/moui` module.

## Acceptance

- [ ] `WebViewHost` uniquely owns controller registration, command IDs,
      navigation generations, pending requests, and disposal.
- [ ] `web_view` declares only controller identity, layout, semantics, and
      native appearance; URL changes never navigate through placement sync.
- [ ] macOS WKWebView, Windows WebView2, and Linux WebKitGTK implement the same
      controller command/event wire contract and JSON message envelope.
- [ ] Page messages are limited to the main frame and checked against exact
      origin and channel policies derived by the native host.
- [ ] Versioned HostPatch bundles replace public arbitrary JavaScript
      evaluation and are installed before their target navigation.
- [ ] DSH Desktop and WebView Demo use controller tasks through TEA effects;
      business models contain no host/controller handles.
- [ ] The old queue, old event variants, placement URL navigation, and public
      `EvaluateJavaScript` API are removed in the same release.
- [ ] Focused native/wasm checks, generated interfaces, static validators, and
      matching-host WebView smokes pass.

## Decision Log

| Date | Decision |
|------|----------|
| 2026-08-20 | Keep the complete feature in the independent `moui_webview` addon; `moui/core` retains only generic platform-view transport. |
| 2026-08-20 | Use a breaking 0.2 controller contract with no deprecated compatibility layer. |
| 2026-08-20 | Controller work enters applications as cancellable `WebViewTask` effects; controllers are captured by Program closures and never stored in business models. |
| 2026-08-20 | Exact native-derived origins and channel direction policies guard schema-v1 JSON messages; page-supplied origin data is never trusted. |
| 2026-08-20 | Raw JavaScript evaluation is removed; DSH uses a configuration-time, origin-scoped HostPatch bundle. |

## Progress

| Date | Note |
|------|------|
| 2026-08-20 | Plan and ADR created after auditing the addon host/views packages, all three native bridges, WebView Demo, and DSH Desktop. |
| 2026-08-20 | Host/controller/codec/view migration, three desktop plugin adapters, DSH, and WebView Demo compile under the 0.2 contract; native callbacks retain the existing FFI envelope while bridge handling is upgraded inside each platform adapter. |
| 2026-08-20 | Focused native tests cover FIFO IDs, stale generations, request timeout, HostPatch origin validation, placement appearance-only semantics, and DSH/WebView Demo TEA behavior. |
