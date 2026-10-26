name = "examples/pdf_workbench"

version = "0.1.0"

preferred_target = "native"

import {
  "wzzc-dev/moui@0.2.5",
  "moonbitlang/pdflite@0.4.0",
  "moonbitlang/async@0.22.5",
  "moonbitlang/x@0.5.6",
  "wzzc-dev/moui_skia_renderer@0.2.5",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
