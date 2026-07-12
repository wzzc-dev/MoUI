name = "examples/pdf_workbench"

version = "0.1.0"

import {
  "wzzc-dev/moui@0.1.7",
  "bobzhang/pdflite@0.1.38",
  "moonbitlang/async@0.18.1",
  "moonbitlang/x@0.4.45",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
