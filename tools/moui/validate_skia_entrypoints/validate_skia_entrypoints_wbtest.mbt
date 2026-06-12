///|
fn sample_entry() -> SkiaEntry {
  {
    package_path: "examples/showcase/macos_skia",
    platform: "macos",
    app_import: "\"examples/showcase/app\"",
    app_constructor: "@app.ShowcaseApp::new()",
    backend_alias: "@macos_skia_backend",
    host_backend_import: "\"wzzc-dev/moui/backend/macos\" @macos_backend",
    host_summary_call: "@macos_backend.macos_capability_summary()",
    options_type: "MacosSkiaAppOptions",
    run_function: "run_app_with_options",
    surface_route_env: "MOUI_MACOS_SKIA_SURFACE_ROUTE",
    app_title: "\"MoUI Showcase\"",
    expected_link_token: "-framework AppKit",
    allow_async_pump: false,
  }
}

///|
let valid_pkg =
  #|import {
  #|  "moonbitlang/core/env",
  #|  "wzzc-dev/moui/backend/macos" @macos_backend,
  #|  "wzzc-dev/moui/backend/macos/skia" @macos_skia_backend,
  #|  "wzzc-dev/moui/render/skia" @skia_renderer,
  #|  "examples/showcase/app",
  #|}
  #|
  #|supported_targets = "native"
  #|
  #|options(
  #|  "is-main": true,
  #|  targets: { "main.mbt": [ "native" ] },
  #|  link: { "native": { "cc-link-flags": "-framework AppKit" } },
  #|)

///|
let valid_main =
  #|///|
  #|fn main {
  #|  let app = @app.ShowcaseApp::new()
  #|  let runtime = app.runtime_with_host_summary(@macos_backend.macos_capability_summary())
  #|  let surface_route = if @env.get_env_var("MOUI_MACOS_SKIA_SURFACE_ROUTE") ==
  #|    Some("metal-gpu") {
  #|    @skia_renderer.SkiaSurfaceRoute::MetalGpuSurfaceRoute
  #|  } else {
  #|    @skia_renderer.SkiaSurfaceRoute::RasterSurfaceRoute
  #|  }
  #|  @macos_skia_backend.run_app_with_options(
  #|    "MoUI Showcase",
  #|    runtime,
  #|    @macos_skia_backend.MacosSkiaAppOptions::new(
  #|      surface_route~,
  #|    ),
  #|  )
  #|}

///|
test "accepts valid Skia entrypoint text" {
  inspect(
    validate_entry_texts(sample_entry(), valid_pkg, valid_main).is_empty(),
    content="true",
  )
}

///|
test "reports missing renderer import" {
  let failures = validate_entry_texts(
    sample_entry(),
    valid_pkg.replace(
      old="\"wzzc-dev/moui/render/skia\" @skia_renderer",
      new="\"wzzc-dev/moui/render/wgpu\" @skia_renderer",
    ),
    valid_main,
  )
  inspect(
    failures.contains(
      "examples/showcase/macos_skia/moon.pkg: missing '\"wzzc-dev/moui/render/skia\" @skia_renderer'",
    ),
    content="true",
  )
}

///|
test "reports missing host summary" {
  let failures = validate_entry_texts(
    sample_entry(),
    valid_pkg,
    valid_main.replace(
      old="app.runtime_with_host_summary(@macos_backend.macos_capability_summary())",
      new="app.runtime()",
    ),
  )
  inspect(
    failures.contains(
      "examples/showcase/macos_skia/main.mbt: missing 'runtime_with_host_summary'",
    ),
    content="true",
  )
}
