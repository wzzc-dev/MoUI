name = "wzzc-dev/moui_webview"

version = "0.1.13"

description = "WebView platform view addon for MoUI: wraps platform-native WebView backends (WKWebView, WebKitGTK, WebView2) into MoUI's declarative view tree."

repository = "https://github.com/wzzc-dev/moui"

license = "Apache-2.0"

preferred_target = "native"

import {
  "wzzc-dev/moui@0.1.11",
  "wzzc-dev/window@0.5.4-0.1.5",
}

readme = "README.mbt.md"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
