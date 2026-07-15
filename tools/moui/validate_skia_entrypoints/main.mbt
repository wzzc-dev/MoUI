///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
struct SkiaEntry {
  package_path : String
  platform : String
  app_import : String
  app_constructor : String
  backend_alias : String
  host_backend_import : String
  host_summary_call : String
  options_type : String
  run_function : String
  app_title : String
  allow_async_pump : Bool
}

///|
struct SkiaProviderContract {
  platform : String
  package_path : String
  source_path : String
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_skia_entrypoints [root]
    #|
    #|Statically checks native Skia example entrypoints and provider ownership.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(".")
  let help = Ref(false)
  let seen_root = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      value => {
        if value.has_prefix("-") {
          return Err("unknown argument: " + value)
        }
        if seen_root.val {
          return Err("unexpected argument: " + value)
        }
        repo_root.val = value
        seen_root.val = true
        index += 1
      }
    }
  }
  Ok({ repo_root: repo_root.val, help: help.val })
}

///|
fn skia_entries() -> Array[SkiaEntry] {
  [
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
    },
    {
      package_path: "examples/showcase/windows_skia",
      platform: "windows",
      app_import: "\"examples/showcase/app\" @showcase_app",
      app_constructor: "@showcase_app.ShowcaseApp::new()",
      backend_alias: "@windows_skia_backend",
      host_backend_import: "\"wzzc-dev/moui/backend/windows\" @windows_backend",
      host_summary_call: "@windows_backend.windows_capability_summary()",
      options_type: "WindowsSkiaAppOptions",
      run_function: "run_app_with_options",
      app_title: "\"MoUI Showcase\"",
      allow_async_pump: false,
    },
    {
      package_path: "examples/showcase/linux_skia",
      platform: "linux",
      app_import: "\"examples/showcase/app\" @showcase_app",
      app_constructor: "@showcase_app.ShowcaseApp::new()",
      backend_alias: "@linux_skia_backend",
      host_backend_import: "\"wzzc-dev/moui/backend/linux\" @linux_backend",
      host_summary_call: "@linux_backend.linux_capability_summary()",
      options_type: "LinuxSkiaAppOptions",
      run_function: "run_app_with_options",
      app_title: "\"MoUI Showcase\"",
      allow_async_pump: false,
    },
    {
      package_path: "examples/markdown_editor/macos_skia",
      platform: "macos",
      app_import: "\"examples/markdown_editor/app\"",
      app_constructor: "@app.MarkdownEditorApp::new_with_services(services)",
      backend_alias: "@macos_skia_backend",
      host_backend_import: "",
      host_summary_call: "",
      options_type: "MacosSkiaAppOptions",
      run_function: "run_app_with_options",
      app_title: "\"MoUI Markdown Editor\"",
      allow_async_pump: false,
    },
    {
      package_path: "examples/markdown_editor/windows_skia",
      platform: "windows",
      app_import: "\"examples/markdown_editor/app\" @markdown_app",
      app_constructor: "@markdown_app.MarkdownEditorApp::new_with_services(services)",
      backend_alias: "@windows_skia_backend",
      host_backend_import: "",
      host_summary_call: "",
      options_type: "WindowsSkiaAppOptions",
      run_function: "run_app_with_options",
      app_title: "\"MoUI Markdown Editor\"",
      allow_async_pump: false,
    },
    {
      package_path: "examples/markdown_editor/linux_skia",
      platform: "linux",
      app_import: "\"examples/markdown_editor/app\" @markdown_app",
      app_constructor: "@markdown_app.MarkdownEditorApp::new_with_services(services)",
      backend_alias: "@linux_skia_backend",
      host_backend_import: "",
      host_summary_call: "",
      options_type: "LinuxSkiaAppOptions",
      run_function: "run_app_with_options",
      app_title: "\"MoUI Markdown Editor\"",
      allow_async_pump: false,
    },
    {
      package_path: "examples/mo_workbench/macos_skia",
      platform: "macos",
      app_import: "\"examples/mo_workbench/app\"",
      app_constructor: "@app.AgentBackendRuntime::stub()",
      backend_alias: "@macos_skia_backend",
      host_backend_import: "",
      host_summary_call: "",
      options_type: "MacosSkiaAppOptions",
      run_function: "run_app_with_options_async_pump",
      app_title: "\"Mo Workbench\"",
      allow_async_pump: true,
    },
  ]
}

///|
fn skia_provider_contracts() -> Array[SkiaProviderContract] {
  [
    {
      platform: "macos",
      package_path: "moui/backend/macos/skia/moon.pkg",
      source_path: "moui/backend/macos/skia/macos_skia_provider.mbt",
    },
    {
      platform: "windows",
      package_path: "moui/backend/windows/skia/moon.pkg",
      source_path: "",
    },
    {
      platform: "linux",
      package_path: "moui/backend/linux/skia/moon.pkg",
      source_path: "",
    },
  ]
}

///|
fn platform_backend_import(platform : String) -> String {
  match platform {
    "macos" => "\"wzzc-dev/moui/backend/macos/skia\" @macos_skia_backend"
    "windows" => "\"wzzc-dev/moui/backend/windows/skia\" @windows_skia_backend"
    "linux" => "\"wzzc-dev/moui/backend/linux/skia\" @linux_skia_backend"
    _ => ""
  }
}

///|
fn entrypoint_platform_link_token(platform : String) -> String {
  match platform {
    "macos" => "-framework AppKit"
    "linux" => "-lz"
    _ => ""
  }
}

///|
fn provider_owned_package_token(platform : String) -> String {
  match platform {
    "windows" =>
      "\"native-stub\": [ \"win32_skia_presenter.cpp\", \"windows_async_image.cpp\" ]"
    _ => entrypoint_platform_link_token(platform)
  }
}

///|
fn assert_contains(
  source : String,
  token : String,
  label : String,
  failures : Array[String],
) -> Unit {
  if token != "" && !source.contains(token) {
    failures.push(label + ": missing '" + token + "'")
  }
}

///|
fn assert_not_contains(
  source : String,
  token : String,
  label : String,
  failures : Array[String],
) -> Unit {
  if token != "" && source.contains(token) {
    failures.push(label + ": must not contain '" + token + "'")
  }
}

///|
fn legacy_first_frame_env_token() -> String {
  "EXIT" + "_AFTER" + "_FIRST" + "_PRESENT"
}

///|
fn validate_entry_texts(
  entry : SkiaEntry,
  pkg : String,
  main : String,
) -> Array[String] {
  let pkg_path = entry.package_path + "/moon.pkg"
  let main_path = entry.package_path + "/main.mbt"
  let failures : Array[String] = []

  assert_contains(
    pkg,
    platform_backend_import(entry.platform),
    pkg_path,
    failures,
  )
  assert_contains(pkg, entry.host_backend_import, pkg_path, failures)
  assert_contains(pkg, entry.app_import, pkg_path, failures)
  assert_contains(pkg, "supported_targets = \"native\"", pkg_path, failures)
  assert_contains(pkg, "pkgtype(kind: \"executable\")", pkg_path, failures)
  assert_not_contains(pkg, "\"is-main\": true", pkg_path, failures)
  assert_contains(pkg, "\"cc-link-flags\": \"\"", pkg_path, failures)
  assert_contains(
    pkg, "targets: { \"main.mbt\": [ \"native\" ] }", pkg_path, failures,
  )
  assert_not_contains(
    pkg,
    entrypoint_platform_link_token(entry.platform),
    pkg_path,
    failures,
  )
  assert_contains(pkg, "\"wzzc-dev/moui/runtime\"", pkg_path, failures)

  assert_not_contains(pkg, "\"wzzc-dev/moui/render/skia\"", pkg_path, failures)
  assert_not_contains(pkg, "\"wzzc-dev/moui/render/wgpu\"", pkg_path, failures)
  assert_not_contains(
    pkg, "\"wzzc-dev/moui/backend/macos/wgpu\"", pkg_path, failures,
  )
  assert_not_contains(
    pkg, "\"wzzc-dev/moui/backend/windows/wgpu\"", pkg_path, failures,
  )
  assert_not_contains(
    pkg, "\"wzzc-dev/moui/backend/linux/wgpu\"", pkg_path, failures,
  )

  assert_contains(main, "///|", main_path, failures)
  assert_contains(main, "fn main", main_path, failures)
  assert_contains(main, entry.app_constructor, main_path, failures)
  assert_contains(
    main, "@runtime.new_program_with_dimensions", main_path, failures,
  )
  if entry.host_summary_call != "" {
    assert_contains(main, "program_with_host_summary", main_path, failures)
    assert_contains(main, entry.host_summary_call, main_path, failures)
  }
  assert_not_contains(main, legacy_first_frame_env_token(), main_path, failures)
  assert_not_contains(main, "first_frame_smoke_auto_exit", main_path, failures)
  assert_not_contains(main, "MOUI_MACOS_NATIVE_IME_SMOKE", main_path, failures)
  assert_not_contains(
    main, "MOUI_MACOS_NATIVE_IME_EVIDENCE", main_path, failures,
  )
  assert_not_contains(main, "native_ime_runtime_smoke", main_path, failures)
  assert_not_contains(main, "EmptyTypeface", main_path, failures)
  assert_not_contains(main, "run_smoke_app_with_options", main_path, failures)
  if entry.platform == "macos" {
    assert_not_contains(
      main, "@env.get_env_var(\"MOUI_MACOS_SKIA_SURFACE_ROUTE\")", main_path, failures,
    )
    assert_not_contains(main, "@render.SkiaSurfaceRoute::", main_path, failures)
    assert_not_contains(main, "surface_route=", main_path, failures)
    assert_not_contains(main, "surface_route~", main_path, failures)
  } else {
    assert_not_contains(main, "@env.", main_path, failures)
    assert_not_contains(main, "@skia_renderer.", main_path, failures)
  }
  assert_contains(
    main,
    entry.backend_alias + "." + entry.run_function,
    main_path,
    failures,
  )
  assert_contains(main, entry.app_title, main_path, failures)
  assert_contains(
    main,
    entry.backend_alias + "." + entry.options_type + "::new",
    main_path,
    failures,
  )
  if !entry.allow_async_pump {
    assert_not_contains(
      main, "run_app_with_options_async_pump", main_path, failures,
    )
  }
  failures
}

///|
fn validate_provider_texts(
  contract : SkiaProviderContract,
  pkg : String,
  source : String,
) -> Array[String] {
  let failures : Array[String] = []
  assert_contains(
    pkg,
    provider_owned_package_token(contract.platform),
    contract.package_path,
    failures,
  )
  if contract.platform == "macos" {
    assert_contains(
      source,
      "surface_route? : @render.SkiaSurfaceRoute = macos_surface_route_from_environment()",
      contract.source_path,
      failures,
    )
    assert_contains(
      source,
      "fn macos_surface_route_from_environment()",
      contract.source_path,
      failures,
    )
    assert_contains(
      source,
      "@env.get_env_var(\"MOUI_MACOS_SKIA_SURFACE_ROUTE\")",
      contract.source_path,
      failures,
    )
    assert_contains(
      source,
      "@render.select_native_renderer(",
      contract.source_path,
      failures,
    )
  }
  failures
}

///|
fn validate_entry(repo_root : String, entry : SkiaEntry) -> Array[String] {
  let pkg_path = entry.package_path + "/moon.pkg"
  let main_path = entry.package_path + "/main.mbt"
  let resolved_pkg = @tools.resolve_path(repo_root, pkg_path)
  let resolved_main = @tools.resolve_path(repo_root, main_path)
  let pkg = match
    @tools.read_required_text(resolved_pkg, "Skia entrypoint package") {
    Ok(value) => value
    Err(message) => return [message]
  }
  let main = match
    @tools.read_required_text(resolved_main, "Skia entrypoint main") {
    Ok(value) => value
    Err(message) => return [message]
  }
  validate_entry_texts(entry, pkg, main)
}

///|
fn validate_provider(
  repo_root : String,
  contract : SkiaProviderContract,
) -> Array[String] {
  let resolved_pkg = @tools.resolve_path(repo_root, contract.package_path)
  let pkg = match
    @tools.read_required_text(resolved_pkg, "Skia provider package") {
    Ok(value) => value
    Err(message) => return [message]
  }
  let source = if contract.source_path == "" {
    ""
  } else {
    let resolved_source = @tools.resolve_path(repo_root, contract.source_path)
    match @tools.read_required_text(resolved_source, "Skia provider source") {
      Ok(value) => value
      Err(message) => return [message]
    }
  }
  validate_provider_texts(contract, pkg, source)
}

///|
fn validate_skia_entrypoints(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  for contract in skia_provider_contracts() {
    for failure in validate_provider(repo_root, contract) {
      failures.push(failure)
    }
  }
  for entry in skia_entries() {
    for failure in validate_entry(repo_root, entry) {
      failures.push(failure)
    }
  }
  failures
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let failures = validate_skia_entrypoints(options.repo_root)
      if failures.is_empty() {
        println("native Skia example entrypoint validation: ok")
        0
      } else {
        for failure in failures {
          println(failure)
        }
        1
      }
    }
    Err(message) => {
      println(message)
      println(usage())
      2
    }
  }
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
