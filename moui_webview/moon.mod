name = "wzzc-dev/moui_webview"

version = "0.1.0"

description = "WebView platform view addon for MoUI: wraps platform-native WebView backends (WKWebView, WebKitGTK, WebView2) into MoUI's declarative view tree."

repository = "https://github.com/wzzc-dev/moui"

import {
  "wzzc-dev/moui@0.1.4",
  "wzzc-dev/window@0.5.1-0.1.6",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
