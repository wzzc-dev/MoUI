name = "wzzc-dev/moui"

version = "0.1.10"

preferred_target = "native"

import {
  "wzzc-dev/window@0.5.4-0.1.5",
  "Milky2018/moon_accesskit@0.3.0",
  "Milky2018/moon_zeno@0.1.3",
  "mizchi/svg@0.2.1",
  "moonbitlang/async@0.20.2",
  "moonbitlang/x@0.5.1",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/MoUI.git"

license = "Apache-2.0"

keywords = [ "moui", "gui", "framework" ]

description = "MoUI is a multi-platform MoonBit GUI framework"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
