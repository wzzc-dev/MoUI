name = "examples/pdf_workbench"

version = "0.1.0"

import {
  "wzzc-dev/moui@0.1.0",
  "bobzhang/pdflite@0.1.38",
  "moonbitlang/async@0.17.0",
  "moonbitlang/x@0.4.43",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
