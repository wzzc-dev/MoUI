name = "wzzc-dev/moui_skia_renderer"

version = "0.2.0"

preferred_target = "native"

supported_targets = "native"

import {
  "wzzc-dev/moui@0.2.0",
  "wzzc-dev/moui_skia@0.2.0",
  "moonbitlang/x@0.4.46",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/MoUI.git"

license = "Apache-2.0"

keywords = [ "moui", "renderer", "skia", "gui" ]

description = "Native Skia renderer provider for MoUI"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
