name = "wzzc-dev/moui"

version = "0.1.4"

import {
  "Milky2018/moon_accesskit@0.3.0",
  "Milky2018/moon_cosmic@0.3.3",
  "Milky2018/moon_swash@0.1.10",
  "Milky2018/moon_taffy@0.5.2",
  "Milky2018/moon_zeno@0.1.3",
  "Milky2018/wgpu_mbt@0.14.3",
  "wzzc-dev/window@0.5.1-0.1.5",
  "mizchi/image@0.4.2",
  "mizchi/pixelmatch@0.6.1",
  "mizchi/svg@0.2.1",
  "moonbitlang/async@0.19.4",
  "moonbitlang/quickcheck@0.14.0",
  "moonbitlang/x@0.4.45",
  "wzzc-dev/moui_skia@0.1.4",
  "wzzc-dev/moui_webview@0.1.0",
}

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/MoUI.git"

license = "Apache-2.0"

keywords = [ "moui", "gui", "framework" ]

description = "MoUI is a multi-platform MoonBit GUI framework"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
