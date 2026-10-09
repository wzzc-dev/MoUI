name = "wzzc-dev/moui_skia_renderer"

version = "0.2.1"

preferred_target = "native"

supported_targets = "native"

import {
  "wzzc-dev/moui@0.2.2",
  "wzzc-dev/moui_skia@0.2.1",
  "moonbitlang/x@0.5.5",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/MoUI.git"

license = "Apache-2.0"

keywords = [ "moui", "renderer", "skia", "gui" ]

description = "Native Skia renderer provider for MoUI"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
