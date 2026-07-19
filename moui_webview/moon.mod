name = "wzzc-dev/moui_webview"

version = "0.1.7"

description = "WebView platform view addon for MoUI: wraps platform-native WebView backends (WKWebView, WebKitGTK, WebView2) into MoUI's declarative view tree."

repository = "https://github.com/wzzc-dev/moui"

license = "Apache-2.0"

import {
  "wzzc-dev/moui@0.1.7",
  "wzzc-dev/window@0.5.1-0.1.7-2",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
