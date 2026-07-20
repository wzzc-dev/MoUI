name = "wzzc-dev/moui_skia"

version = "0.1.7"

import {
  "wzzc-dev/window@0.5.1-0.1.7-3",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/moui_skia"

license = "Apache-2.0"

keywords = [ "skia", "graphics", "bindings" ]

description = "MoonBit bindings for the Skia Graphics Library"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
