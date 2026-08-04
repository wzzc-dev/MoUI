# WebView Demo

A focused WebView embedding demo built with MoUI. The retained composition
roots are macOS and Web; Windows/Linux WebView capability remains covered by
backend tests and matching-host probes.

## Supported Platforms

| Platform | Entry Point | WebView Backend | Status |
|----------|-------------|-----------------|--------|
| macOS    | `macos_skia` | WKWebView (via WebKit framework) | Native |
| Web      | `web_wasm` | Unavailable | Fallback (shows "unavailable" message) |

## Features

- URL address bar with Open button
- Back / Forward navigation (with dynamic enabled/disabled state)
- Reload, Stop buttons
- JavaScript evaluation (Eval button evaluates `window.location.href`)
- Navigation event tracking: request → start → commit → finish / failed
- Title display updated via DocumentTitleChanged event
- Status panel showing: native capability, state, back/forward availability, JS results, event log

## Preview

Default URL: `https://wzzc-dev.github.io/MoUI/`

Window size: 1120 × 760

When the native WebView is unavailable, the demo gracefully degrades to an
"unavailable" panel with the capability description.

## Run

### macOS

```sh
moon run examples/webview_demo/macos_skia --target native
```

The macOS entrypoint links against the system WebKit framework; no additional
setup is needed.

### Web (wasm-gc)

```sh
moon build examples/webview_demo/web_wasm --target wasm-gc
```

Then open the generated `index.html` in a browser.  The Web entrypoint
reports the native WebView as unavailable and shows the fallback UI.
