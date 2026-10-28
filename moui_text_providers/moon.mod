name = "wzzc-dev/moui_text_providers"

version = "0.2.2"

preferred_target = "native"

supported_targets = "native"

import {
  "wzzc-dev/moui@0.2.5",
  "Milky2018/moon_cosmic@0.3.8",
  "Milky2018/moon_swash@0.1.14",
  "moonbitlang/x@0.5.6",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/MoUI.git"

license = "Apache-2.0"

keywords = [ "moui", "text", "coretext", "directwrite", "fontconfig" ]

description = "Platform text providers for MoUI renderers"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
