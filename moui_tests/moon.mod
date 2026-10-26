name = "wzzc-dev/moui_tests"

preferred_target = "native"

import {
  "wzzc-dev/moui@0.2.5",
  "wzzc-dev/moui_tui_renderer@0.2.1",
  "wzzc-dev/moui_tui@0.1.1",
  "wzzc-dev/moui_skia_renderer@0.2.2",
  "wzzc-dev/moui_web_renderer@0.2.3",
  "wzzc-dev/moui_wgpu_renderer@0.2.2",
  "wzzc-dev/moui_skia@0.2.2",
  "Milky2018/wgpu_mbt@0.16.2",
  "mizchi/pixelmatch@0.6.2",
  "moonbitlang/async@0.22.5",
  "moonbitlang/quickcheck@0.15.0",
  "moonbitlang/x@0.5.6",
  "examples/counter@0.1.0",
  "examples/showcase@0.1.0",
  "examples/terminal@0.1.0",
  "examples/tui_layers@0.1.0",
}

description = "Unpublished MoUI test harnesses, integration tests, benchmarks, and renderer smokes"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
