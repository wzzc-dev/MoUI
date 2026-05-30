name = "wzzc-dev/skia_mbt"

version = "0.1.2"

import {
  "wzzc-dev/window@0.5.1",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/skia_mbt"

license = "Apache-2.0"

keywords = [ "skia", "graphics", "bindings" ]

description = "MoonBit bindings for the Skia Graphics Library"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
