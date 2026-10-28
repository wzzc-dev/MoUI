name = "wzzc-dev/moui_metal_renderer"

version = "0.2.2"

preferred_target = "native"

supported_targets = "native"

import {
  "wzzc-dev/moui@0.2.5",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/MoUI.git"

license = "Apache-2.0"

keywords = [ "moui", "renderer", "metal", "experimental" ]

description = "Experimental direct Metal renderer for MoUI: no Skia, no wgpu"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
