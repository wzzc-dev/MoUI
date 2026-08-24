name = "wzzc-dev/moui_skia_renderer"

version = "0.1.11"

preferred_target = "native"

supported_targets = "native"

import {
  "wzzc-dev/moui@0.1.12",
  "wzzc-dev/moui_skia@0.1.10",
  "moonbitlang/x@0.5.1",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/MoUI.git"

license = "Apache-2.0"

keywords = [ "moui", "renderer", "skia", "gui" ]

description = "Native Skia renderer provider for MoUI"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
