name = "examples/pdf_workbench"

version = "0.1.0"

preferred_target = "native"

import {
  "wzzc-dev/moui@0.1.12",
  "bobzhang/pdflite@0.1.38",
  "moonbitlang/async@0.20.2",
  "moonbitlang/x@0.5.1",
  "wzzc-dev/moui_skia_renderer@0.1.11",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
