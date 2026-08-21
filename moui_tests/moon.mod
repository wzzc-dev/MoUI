name = "wzzc-dev/moui_tests"

preferred_target = "native"

import {
  "wzzc-dev/moui@0.1.9",
  "wzzc-dev/moui_skia_renderer@0.1.9",
  "wzzc-dev/moui_web_renderer@0.1.9",
  "wzzc-dev/moui_wgpu_renderer@0.1.9",
  "wzzc-dev/moui_skia@0.1.9",
  "Milky2018/wgpu_mbt@0.14.8",
  "mizchi/pixelmatch@0.6.1",
  "moonbitlang/quickcheck@0.14.0",
  "moonbitlang/x@0.5.1",
}

description = "Unpublished MoUI test harnesses, integration tests, benchmarks, and renderer smokes"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
