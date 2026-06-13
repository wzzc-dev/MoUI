# WebView Demo

A cross-platform native WebView embedding demo built with MoUI.

## Supported Platforms

| Platform | Entry Point | WebView Backend | Status |
|----------|-------------|-----------------|--------|
| macOS    | `macos_skia` | WKWebView (via WebKit framework) | Native |
| Windows  | `windows_skia` | Microsoft Edge WebView2 | Native (requires SDK + Evergreen Runtime) |
| Linux    | `linux_skia` | WebKitGTK | Native (requires WebKitGTK) |
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

### Windows

WebView2 requires the Microsoft Edge Evergreen Runtime on the target machine
(typically pre-installed with Edge on Windows 10/11).

**One-liner (from Git Bash or CMD):**

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; . .\scripts\windows\webview2_sdk.ps1; Enable-WebView2BuildEnvironment; moon run examples/webview_demo/windows_skia --target native }"
```

**Step by step (in an existing PowerShell session):**

```powershell
. .\scripts\windows\msvc_env.ps1
. .\scripts\windows\webview2_sdk.ps1
Enable-WebView2BuildEnvironment
moon run examples/webview_demo/windows_skia --target native
```

The WebView2 SDK (headers + static loader library) is downloaded from NuGet
on first use and cached under `.tools\webview2\`.  The SDK version is locked
in `scripts\windows\webview2-sdk-lock.json` with a SHA-256 integrity check.

Without WebView2 setup, the demo still compiles but reports
"unavailable" at runtime.

### Linux

```sh
moon run examples/webview_demo/linux_skia --target native
```

The Linux entrypoint requires WebKitGTK (`webkit2gtk-4.1` or `4.0`) with
`gtk+-3.0`.  Set `MOUI_LINUX_ENABLE_WEBKITGTK=1` or the explicit
`MOUI_LINUX_WEBKITGTK_STUB_CC_FLAGS` / `MOUI_LINUX_WEBKITGTK_CC_LINK_FLAGS`
environment variables to enable the native bridge.  Without WebKitGTK, the
demo compiles and reports "unavailable".

### Web (wasm-gc)

```sh
moon build examples/webview_demo/web_wasm --target wasm-gc
```

Then open the generated `index.html` in a browser.  The Web entrypoint
reports the native WebView as unavailable and shows the fallback UI.
