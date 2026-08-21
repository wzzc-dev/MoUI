name = "wzzc-dev/moui_wgpu_renderer"

version = "0.1.9"

preferred_target = "native"

supported_targets = "native"

import {
  "wzzc-dev/moui@0.1.9",
  "Milky2018/moon_cosmic@0.3.3",
  "Milky2018/moon_swash@0.1.10",
  "Milky2018/wgpu_mbt@0.14.8",
  "mizchi/image@0.4.3",
  "moonbitlang/x@0.5.1",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/MoUI.git"

license = "Apache-2.0"

keywords = [ "moui", "renderer", "wgpu", "diagnostic" ]

description = "Experimental native WGPU renderer and text providers for MoUI"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
