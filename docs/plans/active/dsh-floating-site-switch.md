# DeepSeek Floating Site Switch

- **Status**: active

## Product behavior

`deepseek_harness_desktop` starts on the configured Harness URL and can switch
between that root and `https://chat.deepseek.com/` through a small native MoUI
`D` button. A primary click switches sites, a secondary click opens Settings,
and a drag keeps the button at the released in-session position. Releasing
near either window edge docks it and leaves a small clickable tab visible;
dragging or clicking that tab expands it again. The View menu bar exposes the
same actions: "Switch Chat/DSH Site" toggles the root and "Toggle Floating
Button" shows or hides the floating control. The last position, the visible
state of the floating button, and the active site are intentionally not
persisted.

## State and settings

The existing `dsh-desktop/request-url` key remains the Harness URL. The new
`dsh-desktop/chat-url` key stores the Chat URL. Both values are read before the
WebView is placed, validated as HTTP(S), and independently written on Save.
The app closes Settings only after both writes succeed; the visible site
navigates immediately when its corresponding value changes.

The Settings dialog also persists `dsh-desktop/theme-mode` with `system`,
`dark`, or `light`. The resolved theme background is serialized into the
WebView platform placement and applied by the native WebView before a URL
navigation starts, so the WebView surface itself has the selected color during
startup. The webpage is not modified by injected theme JavaScript.
On macOS the same value selects the WKWebView's native Aqua or Dark Aqua
appearance, so WebKit's own loading surface follows the explicit mode even when
the desktop system appearance differs.

## Overlay ownership

The button is an app-local ViewNode. Its transparent overlay marker contributes
only the button bounds to `DrawFrame.overlay_bounds`; the marker is ignored by
pointer hit testing. Linux keeps its existing offscreen WebKitGTK composition.
macOS uses the bounds to make only that rectangle available to the MoUI
presenter while the rest of WKWebView continues to receive input. Windows
applies a temporary WebView2 child-window region exclusion for the same bounds
and restores the full region when no overlay is present.

## Validation and host evidence

Focused package tests cover URL fallback, dual-write Settings behavior, site
switching, secondary tap, and overlay bounds. Native package checks cover all
three Skia composition roots. Matching macOS, Windows, and Linux hosts are
required to confirm visible button compositing and input routing; Windows
region behavior in particular cannot be proven by the non-Windows compiler.
