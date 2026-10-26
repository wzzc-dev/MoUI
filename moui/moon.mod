name = "wzzc-dev/moui"

version = "0.2.5"

preferred_target = "native"

import {
  "wzzc-dev/window@0.5.4-0.2.1",
  "Milky2018/moon_accesskit@0.4.2",
  "Milky2018/moon_zeno@0.1.5",
  "Milky2018/svg@0.6.0",
  "moonbitlang/async@0.22.5",
  "moonbitlang/x@0.5.6",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/MoUI.git"

license = "Apache-2.0"

keywords = [ "moui", "gui", "framework" ]

description = "MoUI is a multi-platform MoonBit GUI framework"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
