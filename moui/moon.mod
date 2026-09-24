name = "wzzc-dev/moui"

version = "0.1.12"

preferred_target = "native"

import {
  "wzzc-dev/window@0.5.4-0.1.7",
  "Milky2018/moon_accesskit@0.3.0",
  "Milky2018/moon_zeno@0.1.3",
  "Milky2018/svg@0.5.3",
  "moonbitlang/async@0.22.1",
  "moonbitlang/x@0.5.5",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/MoUI.git"

license = "Apache-2.0"

keywords = [ "moui", "gui", "framework" ]

description = "MoUI is a multi-platform MoonBit GUI framework"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
