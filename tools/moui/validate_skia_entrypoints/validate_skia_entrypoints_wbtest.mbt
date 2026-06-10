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
    env_var: "MOUI_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
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
  #|  let exit_after_first_present = @env.get("MOUI_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT") ==
  #|    Some("1")
  #|  let font_resolution = if exit_after_first_present {
  #|    @skia_renderer.SkiaFontResolution::EmptyTypeface
  #|  } else {
  #|    @skia_renderer.SkiaFontResolution::SystemFontMgr
  #|  }
  #|  @macos_skia_backend.run_app_with_options(
  #|    runtime,
  #|    @macos_skia_backend.MacosSkiaAppOptions::new(
  #|      title="MoUI Showcase",
  #|      font_resolution~,
  #|      exit_after_first_present~,
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
