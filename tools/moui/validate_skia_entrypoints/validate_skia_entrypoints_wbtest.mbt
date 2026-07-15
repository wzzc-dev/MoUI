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
    app_title: "\"MoUI Showcase\"",
    allow_async_pump: false,
  }
}

///|
fn sample_provider() -> SkiaProviderContract {
  {
    platform: "macos",
    package_path: "moui/backend/macos/skia/moon.pkg",
    source_path: "moui/backend/macos/skia/macos_skia_provider.mbt",
  }
}

///|
let valid_pkg =
  #|import {
  #|  "wzzc-dev/moui/runtime",
  #|  "wzzc-dev/moui/backend/macos" @macos_backend,
  #|  "wzzc-dev/moui/backend/macos/skia" @macos_skia_backend,
  #|  "examples/showcase/app",
  #|}
  #|
  #|supported_targets = "native"
  #|
  #|pkgtype(kind: "executable")
  #|
  #|options(
  #|  targets: { "main.mbt": [ "native" ] },
  #|  link: { "native": { "cc-link-flags": "" } },
  #|)

///|
let valid_main =
  #|///|
  #|fn main {
  #|  let app = @app.ShowcaseApp::new()
  #|  let runtime = @runtime.new_program_with_dimensions(
  #|    program=app.program_with_host_summary(
  #|      @macos_backend.macos_capability_summary(),
  #|    ),
  #|    width=960.0,
  #|    height=560.0,
  #|  )
  #|  @macos_skia_backend.run_app_with_options(
  #|    "MoUI Showcase",
  #|    runtime,
  #|    options=@macos_skia_backend.MacosSkiaAppOptions::new(),
  #|  )
  #|}

///|
let valid_provider_pkg =
  #|options(
  #|  link: {
  #|    "native": {
  #|      "cc-link-flags": "-framework AppKit -framework Metal -lz",
  #|    },
  #|  },
  #|)

///|
let valid_provider_source =
  #|pub fn MacosSkiaAppOptions::new(
  #|  surface_route? : @render.SkiaSurfaceRoute = macos_surface_route_from_environment(),
  #|) -> MacosSkiaAppOptions {
  #|  ...
  #|}
  #|
  #|fn macos_surface_route_from_environment() -> @render.SkiaSurfaceRoute {
  #|  match @env.get_env_var("MOUI_MACOS_SKIA_SURFACE_ROUTE") {
  #|    _ => @render.select_native_renderer(
  #|      @render.NativeGpuPlatform::Macos,
  #|      @render.NativeRendererMode::Auto,
  #|      gpu_available=true,
  #|      gpu_promoted=true,
  #|    ).surface_route
  #|  }
  #|}

///|
test "accepts valid Skia entrypoint text" {
  inspect(
    validate_entry_texts(sample_entry(), valid_pkg, valid_main).is_empty(),
    content="true",
  )
}

///|
test "rejects WGPU renderer import" {
  let failures = validate_entry_texts(
    sample_entry(),
    valid_pkg.replace(
      old="  \"wzzc-dev/moui/runtime\",\n",
      new="  \"wzzc-dev/moui/runtime\",\n  \"wzzc-dev/moui/render/wgpu\",\n",
    ),
    valid_main,
  )
  inspect(
    failures.contains(
      "examples/showcase/macos_skia/moon.pkg: must not contain '\"wzzc-dev/moui/render/wgpu\"'",
    ),
    content="true",
  )
}

///|
test "requires executable package kind" {
  let failures = validate_entry_texts(
    sample_entry(),
    valid_pkg.replace(
      old="pkgtype(kind: \"executable\")",
      new="options(\"is-main\": true)",
    ),
    valid_main,
  )
  assert_true(
    failures.contains(
      "examples/showcase/macos_skia/moon.pkg: missing 'pkgtype(kind: \"executable\")'",
    ),
  )
  assert_true(
    failures.contains(
      "examples/showcase/macos_skia/moon.pkg: must not contain '\"is-main\": true'",
    ),
  )
}

///|
test "rejects entrypoint-owned platform link flags" {
  let failures = validate_entry_texts(
    sample_entry(),
    valid_pkg.replace(
      old="\"cc-link-flags\": \"\"",
      new="\"cc-link-flags\": \"-framework AppKit\"",
    ),
    valid_main,
  )
  assert_true(
    failures.contains(
      "examples/showcase/macos_skia/moon.pkg: missing '\"cc-link-flags\": \"\"'",
    ),
  )
  inspect(
    failures.contains(
      "examples/showcase/macos_skia/moon.pkg: must not contain '-framework AppKit'",
    ),
    content="true",
  )
}

///|
test "rejects repo-only runtime evidence hooks" {
  let failures = validate_entry_texts(
    sample_entry(),
    valid_pkg,
    valid_main.replace(
      old="fn main {",
      new="fn main {\n  let _ = @env.get_env_var(\"MOUI_MACOS_NATIVE_IME_EVIDENCE\")",
    ),
  )
  inspect(
    failures.contains(
      "examples/showcase/macos_skia/main.mbt: must not contain 'MOUI_MACOS_NATIVE_IME_EVIDENCE'",
    ),
    content="true",
  )
}

///|
test "rejects entrypoint-owned macOS surface route" {
  let failures = validate_entry_texts(
    sample_entry(),
    valid_pkg,
    valid_main.replace(
      old="@macos_skia_backend.MacosSkiaAppOptions::new()",
      new="@macos_skia_backend.MacosSkiaAppOptions::new(surface_route=@render.SkiaSurfaceRoute::MetalGpuSurfaceRoute)",
    ),
  )
  inspect(
    failures.contains(
      "examples/showcase/macos_skia/main.mbt: must not contain '@render.SkiaSurfaceRoute::'",
    ),
    content="true",
  )
}

///|
test "accepts provider-owned link and route selection" {
  inspect(
    validate_provider_texts(
      sample_provider(),
      valid_provider_pkg,
      valid_provider_source,
    ).is_empty(),
    content="true",
  )
}

///|
test "reports missing provider link ownership" {
  let failures = validate_provider_texts(
    sample_provider(),
    valid_provider_pkg.replace(old="-framework AppKit", new=""),
    valid_provider_source,
  )
  inspect(
    failures.contains(
      "moui/backend/macos/skia/moon.pkg: missing '-framework AppKit'",
    ),
    content="true",
  )
}

///|
test "reports missing provider route default" {
  let failures = validate_provider_texts(
    sample_provider(),
    valid_provider_pkg,
    valid_provider_source.replace(
      old="surface_route? : @render.SkiaSurfaceRoute = macos_surface_route_from_environment()",
      new="surface_route? : @render.SkiaSurfaceRoute",
    ),
  )
  inspect(
    failures.contains(
      "moui/backend/macos/skia/macos_skia_provider.mbt: missing 'surface_route? : @render.SkiaSurfaceRoute = macos_surface_route_from_environment()'",
    ),
    content="true",
  )
}

///|
test "reports missing runtime import" {
  let failures = validate_entry_texts(
    sample_entry(),
    valid_pkg.replace(old="  \"wzzc-dev/moui/runtime\",\n", new=""),
    valid_main,
  )
  inspect(
    failures.contains(
      "examples/showcase/macos_skia/moon.pkg: missing '\"wzzc-dev/moui/runtime\"'",
    ),
    content="true",
  )
}

///|
test "reports missing runtime constructor" {
  let failures = validate_entry_texts(
    sample_entry(),
    valid_pkg,
    valid_main.replace(
      old="@runtime.new_program_with_dimensions",
      new="@runtime.new_view_with_dimensions",
    ),
  )
  inspect(
    failures.contains(
      "examples/showcase/macos_skia/main.mbt: missing '@runtime.new_program_with_dimensions'",
    ),
    content="true",
  )
}

///|
test "reports missing host summary" {
  let failures = validate_entry_texts(
    sample_entry(),
    valid_pkg,
    valid_main.replace(old="program_with_host_summary", new="program"),
  )
  inspect(
    failures.contains(
      "examples/showcase/macos_skia/main.mbt: missing 'program_with_host_summary'",
    ),
    content="true",
  )
}
