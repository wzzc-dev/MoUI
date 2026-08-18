# Plan: MoUI Overlay Over Native WebView

- **Status**: done
- **Goal**: Let MoUI view-level overlays (dialogs, sheets, popovers) remain visible and interactive when a native macOS WKWebView occupies the base surface.
- **Non-goals**: Rebuild DSH UI in MoUI, add `web_wasm`, change Windows/Linux WebView behavior, or introduce a second renderer provider.

**Before starting implementation:** Use the Skill tool to load the moonbit-c-binding skill, which provides comprehensive guidance on FFI declarations, ownership annotations, C stubs, and AddressSanitizer validation.

## Acceptance

- [x] Runtime frames carry the bounds needed to expose MoUI overlay pixels above native platform views.
- [x] macOS keeps WKWebView visible under a transparent reordered presenter and excludes the overlay region from WebView hit testing.
- [x] Pointer hit testing passes through the masked region to MoUI.
- [x] No-overlay frames restore an unmasked, full-surface WebView.
- [x] Focused runtime, WebView, and DSH checks pass; public interfaces are regenerated.
- [x] Docs record the macOS-only capability and current non-support on Web/other native hosts.

## Decision log

| Date | Decision |
|---|---|
| 2026-08-17 | Use a native WebView mask exposing the existing Skia pixels instead of a second renderer surface. This gives a sibling-layer result without duplicating renderer state. |

## Progress

| Date | Note |
|---|---|
| 2026-08-17 | Plan created; runtime frame, macOS WebView bridge, and platform-view ordering inspected. |
| 2026-08-17 | Added overlay bounds to `DrawFrame`, implemented macOS presenter reordering and WebView hit-test pass-through, added focused tests, and documented the macOS-only capability. |
