///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
struct SkiaEntry {
  package_path : String
  app_import : String
  app_constructor : String
  backend_import : String
  backend_alias : String
  host_summary_call : String
  app_title : String
  async_pump : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_skia_entrypoints [root]
    #|
    #|Checks that native Skia applications explicitly compose the renderer and
    #|platform backend, while environment selection stays in render/skia.
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
      app_import: "\"examples/showcase/app\"",
      app_constructor: "@app.ShowcaseApp::new()",
      backend_import: "\"wzzc-dev/moui/backend/macos\" @macos_backend",
      backend_alias: "@macos_backend",
      host_summary_call: "@macos_backend.macos_capability_summary()",
      app_title: "\"MoUI Showcase\"",
      async_pump: false,
    },
    {
      package_path: "examples/showcase/windows_skia",
      app_import: "\"examples/showcase/app\" @showcase_app",
      app_constructor: "@showcase_app.ShowcaseApp::new()",
      backend_import: "\"wzzc-dev/moui/backend/windows\" @windows_backend",
      backend_alias: "@windows_backend",
      host_summary_call: "@windows_backend.windows_capability_summary()",
      app_title: "\"MoUI Showcase\"",
      async_pump: false,
    },
    {
      package_path: "examples/showcase/linux_skia",
      app_import: "\"examples/showcase/app\" @showcase_app",
      app_constructor: "@showcase_app.ShowcaseApp::new()",
      backend_import: "\"wzzc-dev/moui/backend/linux\" @linux_backend",
      backend_alias: "@linux_backend",
      host_summary_call: "@linux_backend.linux_capability_summary()",
      app_title: "\"MoUI Showcase\"",
      async_pump: false,
    },
    {
      package_path: "examples/markdown_editor/macos_skia",
      app_import: "\"examples/markdown_editor/app\"",
      app_constructor: "@app.MarkdownEditorApp::new_with_services(services)",
      backend_import: "\"wzzc-dev/moui/backend/macos\" @macos_host",
      backend_alias: "@macos_host",
      host_summary_call: "",
      app_title: "\"MoUI Markdown Editor\"",
      async_pump: false,
    },
    {
      package_path: "examples/markdown_editor/windows_skia",
      app_import: "\"examples/markdown_editor/app\" @markdown_app",
      app_constructor: "@markdown_app.MarkdownEditorApp::new_with_services(services)",
      backend_import: "\"wzzc-dev/moui/backend/windows\" @windows_host",
      backend_alias: "@windows_host",
      host_summary_call: "",
      app_title: "\"MoUI Markdown Editor\"",
      async_pump: false,
    },
    {
      package_path: "examples/markdown_editor/linux_skia",
      app_import: "\"examples/markdown_editor/app\" @markdown_app",
      app_constructor: "@markdown_app.MarkdownEditorApp::new_with_services(services)",
      backend_import: "\"wzzc-dev/moui/backend/linux\" @linux_host",
      backend_alias: "@linux_host",
      host_summary_call: "",
      app_title: "\"MoUI Markdown Editor\"",
      async_pump: false,
    },
    {
      package_path: "examples/mo_workbench/macos_skia",
      app_import: "\"examples/mo_workbench/app\"",
      app_constructor: "@app.AgentBackendRuntime::stub()",
      backend_import: "\"wzzc-dev/moui/backend/macos\" @macos_host",
      backend_alias: "@macos_host",
      host_summary_call: "",
      app_title: "\"Mo Workbench\"",
      async_pump: true,
    },
  ]
}

///|
fn require_token(
  text : String,
  token : String,
  path : String,
  failures : Array[String],
) -> Unit {
  if token != "" && !text.contains(token) {
    failures.push(path + ": missing '" + token + "'")
  }
}

///|
fn reject_token(
  text : String,
  token : String,
  path : String,
  failures : Array[String],
) -> Unit {
  if token != "" && text.contains(token) {
    failures.push(path + ": must not contain '" + token + "'")
  }
}

///|
fn validate_entry(repo_root : String, entry : SkiaEntry) -> Array[String] {
  let pkg_path = entry.package_path + "/moon.pkg"
  let main_path = entry.package_path + "/main.mbt"
  let pkg = match
    @tools.read_required_text(
      @tools.resolve_path(repo_root, pkg_path),
      "Skia composition package",
    ) {
    Ok(value) => value
    Err(message) => return [message]
  }
  let main = match
    @tools.read_required_text(
      @tools.resolve_path(repo_root, main_path),
      "Skia composition entry",
    ) {
    Ok(value) => value
    Err(message) => return [message]
  }
  let failures : Array[String] = []
  for
    token in [
      "\"wzzc-dev/moui\"",
      "\"wzzc-dev/moui/runtime\"",
      "\"wzzc-dev/moui/render/skia\" @render_skia",
      entry.backend_import,
      entry.app_import,
      "supported_targets = \"native\"",
      "pkgtype(kind: \"executable\")",
      "targets: { \"main.mbt\": [ \"native\" ] }",
    ] {
    require_token(pkg, token, pkg_path, failures)
  }
  for
    token in [
      "fn main",
      entry.app_constructor,
      "@runtime.new_program_with_dimensions",
      "@moui.run_app(" + entry.app_title,
      ".render_all(@render_skia.from_env())",
      ".backend(",
      entry.backend_alias + ".entry(",
    ] {
    require_token(main, token, main_path, failures)
  }
  if entry.host_summary_call != "" {
    require_token(main, entry.host_summary_call, main_path, failures)
  }
  require_token(
    main,
    if entry.async_pump {
      ".run_async_pump()"
    } else {
      ".run()"
    },
    main_path,
    failures,
  )
  reject_token(main, "run_app_" + "with_options", main_path, failures)
  failures
}

///|
fn validate_renderer_policy(repo_root : String) -> Array[String] {
  let path = "moui/render/skia/binding_factory.mbt"
  let source = match
    @tools.read_required_text(
      @tools.resolve_path(repo_root, path),
      "Skia renderer factory",
    ) {
    Ok(value) => value
    Err(message) => return [message]
  }
  let failures : Array[String] = []
  for
    token in [
      "pub fn raster(", "pub fn gpu(", "pub fn from_env()", "MOUI_SKIA_RENDERER",
      "NativeRendererMode::parse", "[gpu(), raster()]",
    ] {
    require_token(source, token, path, failures)
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
      let failures = validate_renderer_policy(options.repo_root)
      for entry in skia_entries() {
        failures.append(validate_entry(options.repo_root, entry))
      }
      if failures.is_empty() {
        println("native Skia explicit composition validation: ok")
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
