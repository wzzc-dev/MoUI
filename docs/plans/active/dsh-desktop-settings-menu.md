# Plan: DSH Desktop Settings Menu

- **Status**: active
- **Goal**: Add a standard macOS Settings command and a persisted MoUI request-URL dialog that composes above the full-surface WKWebView.
- **Non-goals**: Add a Web/Wasm entrypoint, change DSH HTTP caching, or claim general native-view interleaving beyond a full-surface WebView with a modal MoUI overlay.

**Before starting implementation:** Use the Skill tool to load the moonbit-c-binding skill, which provides comprehensive guidance on FFI declarations, ownership annotations, C stubs, and AddressSanitizer validation.

## Acceptance

- [ ] The default macOS application menu contains `Settings...` with `Cmd+,` and dispatches a typed app command.
- [ ] The DSH `Edit` menu routes Undo/Redo/Cut/Copy/Paste/Select All through the focused MoUI text control and native clipboard.
- [ ] The request URL loads from macOS settings before WKWebView placement and falls back to the loopback default when missing or invalid.
- [ ] The MoUI dialog validates and persists HTTP(S) URLs; a changed URL applies immediately and same-URL Save leaves the existing page intact.
- [ ] The modal scrim and dialog remain visible and interactive above WKWebView while the page remains visible behind them.
- [ ] Closing the dialog restores WKWebView drawing and input.
- [ ] Linux and Windows composition roots select the matching native WebView plugin and Skia provider route.
- [ ] Focused app, views, runtime, services, macOS backend, WebView, API, and guidance checks pass.
- [ ] Transparent-titlebar MoUI apps do not treat the full content surface as a window-drag region.

## Decision log

| Date | Decision |
|---|---|
| 2026-08-18 | Model application-menu placement explicitly instead of using a magic menu title. |
| 2026-08-18 | Inject macOS application-menu items from the MoUI backend so the published window dependency remains unchanged. |
| 2026-08-18 | Use Skia auto mode for DSH: prefer the GPU surface and fall back to CPU raster. For a full-surface WebView the active presenter stays above WKWebView, clears transparently without a modal, and changes only hit-test ownership across modal transitions. |
| 2026-08-18 | Keep WKWebView visually unmasked while a modal is active; input exclusion and presenter ordering are sufficient, and the host content view becomes first responder so MoUI text fields receive keyboard/IME input. |
| 2026-08-18 | Install standard DSH Edit commands as native key equivalents and dispatch focused-text commands through the macOS clipboard path; transparent titlebars no longer opt every drawn MoUI pixel into background window dragging. |
| 2026-08-18 | When a native platform view owns AppKit first-responder status, dispatch standard Edit commands through its responder chain before falling back to MoUI text handling. |
| 2026-08-18 | Intercept local Command key-down events after native menu installation, resolve exact menu-item key equivalents first, then fall back to `NSApp.mainMenu`; command shortcuts now take the same action path as clicked menu items even with the window event bridge installed. |
| 2026-08-18 | Add Linux WebKitGTK and Windows WebView2 composition roots that use the Skia auto provider route and share the DSH navigation patch. |

## Progress

| Date | Note |
|---|---|
| 2026-08-18 | Plan created after inspecting the existing DSH, menu service, runtime overlay-bounds, and macOS WebView paths. |
| 2026-08-18 | Fixed the real AppKit composition path: removed the WebView layer hole that hid the page, made GPU/raster presenter layers explicitly transparent, transferred first-responder ownership to the MoUI host, and added a native sibling-order/hit-test/focus regression test. |
| 2026-08-18 | Fixed modal interaction and close-transition flicker: transparent composition markers no longer outrank dialog hit targets, AppKit presenter/WebView hit tests route explicitly to the MoUI host, and full-surface presenters stay above the WebView instead of switching sibling order. |
| 2026-08-18 | Removed the same-URL reload hook after real-window testing showed that the explicit WKWebView reload was the remaining Save-time flash; unchanged saves now persist and close without navigating. |
| 2026-08-18 | Removed the remaining AppKit sibling transition from modal open/close. The full-surface presenter now stays above WKWebView with transparent ordinary frames and pass-through hit testing, avoiding WKWebView remote-layer reattachment when Save closes the dialog. |
| 2026-08-18 | Routed DSH Edit-menu shortcuts to the focused native responder when no MoUI text control is active, and restored WKWebView focus after the settings overlay closes. |
| 2026-08-18 | Added an AppKit synthetic-event regression covering `Cmd+A/C/X/V/Z` and `Shift+Cmd+Z` through the local key-equivalent monitor into the current first responder. |
