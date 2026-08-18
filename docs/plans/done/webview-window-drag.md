# Plan: WKWebView Drag And No-Drag Regions

- **Status**: done
- **Goal**: Let the macOS WKWebView surface retain clickable top-bar controls while blank top-bar space moves the native window.
- **Non-goals**: Add `web_wasm`, change Web/Windows/Linux WebView behavior, or rebuild the DSH UI in MoUI.

## Acceptance

- [x] macOS WKWebView exposes a fixed top drag region.
- [x] Interactive DOM controls in that region remain clickable through no-drag rectangles.
- [x] The actual macOS plugin sync path configures both overlay masking and drag behavior.
- [x] Native build and focused tests pass.
- [x] Host and dsh-desktop docs describe the drag/no-drag contract.

## Decision log

| Date | Decision |
|---|---|
| 2026-08-17 | Use a fixed 32-point top drag region and injected DOM geometry for interactive no-drag controls; blank space starts native `performWindowDragWithEvent:`. |

## Progress

| Date | Note |
|---|---|
| 2026-08-17 | Existing WKWebView overlay hit-test exclusion is retained; inspected the plugin composition path and native AppKit drag API. |
| 2026-08-17 | Added the fixed drag strip, injected DOM no-drag geometry, real plugin overlay synchronization, focused validation, and host/example documentation. |
