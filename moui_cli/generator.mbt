///|
let platform_order : ReadOnlyArray[String] = [
  "web", "macos", "windows", "linux", "android", "ios", "harmonyos",
]

///|
fn is_platform(value : String) -> Bool {
  platform_order.contains(value)
}

///|
fn is_mobile_platform(value : String) -> Bool {
  value == "android" || value == "ios" || value == "harmonyos"
}

///|
fn detect_host_platform() -> HostPlatform {
  if @env.get_env_var("OS") == Some("Windows_NT") ||
    @env.get_env_var("SystemRoot") is Some(_) {
    Windows
  } else if @fs.path_exists("/System/Library/CoreServices") {
    Macos
  } else if @fs.path_exists("/proc/sys/kernel/ostype") ||
    @fs.path_exists("/etc/os-release") {
    Linux
  } else {
    Unknown
  }
}

///|
fn default_platforms(host : HostPlatform) -> Array[String] {
  let result = ["web"]
  match host {
    Macos => result.push("macos")
    Windows => result.push("windows")
    Linux => result.push("linux")
    Unknown => ()
  }
  result
}

///|
fn normalize_platforms(
  host : HostPlatform,
  requested : Array[String],
) -> Result[Array[String], String] {
  let selected : Map[String, Bool] = Map([])
  for platform in default_platforms(host) {
    selected[platform] = true
  }
  for requested_platform in requested {
    let platform = requested_platform.to_lower()
    if platform == "all" {
      for value in platform_order {
        selected[value] = true
      }
    } else if is_platform(platform) {
      selected[platform] = true
    } else {
      return Err(
        "unsupported platform: " +
        requested_platform +
        " (expected web|macos|windows|linux|android|ios|harmonyos|all)",
      )
    }
  }
  let result : Array[String] = []
  for platform in platform_order {
    if selected.contains(platform) {
      result.push(platform)
    }
  }
  Ok(result)
}

///|
fn validate_project_options(options : ProjectOptions) -> Result[Unit, String] {
  if options.target == "" {
    return Err("project target path must not be empty")
  }
  if !valid_project_id(options.id) {
    return Err(
      "project id must start with a letter and contain only letters, digits, and underscores",
    )
  }
  if !valid_module_name(options.module_name) {
    return Err(
      "module name must use owner/name form and contain only letters, digits, '.', '-', '_', and '/'",
    )
  }
  if options.title.trim() == "" {
    return Err("project title must not be empty")
  }
  if !valid_version(options.moui_version) {
    return Err("MoUI version contains unsupported characters")
  }
  for platform in options.platforms {
    if !is_platform(platform) {
      return Err("unsupported normalized platform: " + platform)
    }
  }
  let requires_bundle = options.platforms.any(is_mobile_platform)
  match (requires_bundle, options.bundle_id) {
    (true, None) =>
      return Err("--bundle-id is required when generating a mobile platform")
    (_, Some(value)) if !valid_bundle_id(value) =>
      return Err("bundle id is invalid: " + value)
    _ => ()
  }
  Ok(())
}

///|
fn moon_mod_text(options : ProjectOptions) -> String {
  let template =
    #|name = "__MODULE__"
    #|
    #|version = "0.1.0"
    #|
    #|import {
    #|  "wzzc-dev/moui@__MOUI_VERSION__",
    #|}
  template
  .replace_all(old="__MODULE__", new=options.module_name)
  .replace_all(old="__MOUI_VERSION__", new=options.moui_version)
}

///|
fn app_pkg_text() -> String {
  let template =
    #|import {
    #|  "wzzc-dev/moui/views",
    #|  "wzzc-dev/moui",
    #|}
    #|
    #|supported_targets = "+native+wasm-gc"
    #|
    #|options(
    #|  targets: { },
    #|)
  template
}

///|
fn app_text(title : String) -> String {
  let title = moon_string(title)
  let template =
    #|///|
    #|using @views {button, card, center, column, row, text}
    #|
    #|///|
    #|pub struct Model {
    #|  count : Int
    #|}
    #|
    #|///|
    #|pub(all) enum Msg {
    #|  Increment
    #|  Decrement
    #|  Reset
    #|}
    #|
    #|///|
    #|pub fn Model::new() -> Model {
    #|  { count: 0 }
    #|}
    #|
    #|///|
    #|pub fn update(model : Model, msg : Msg) -> Model {
    #|  match msg {
    #|    Increment => { count: model.count + 1 }
    #|    Decrement => { count: model.count - 1 }
    #|    Reset => { count: 0 }
    #|  }
    #|}
    #|
    #|///|
    #|pub fn view(model : Model) -> @moui.View[Msg] {
    #|  center(
    #|    card(
    #|      column([
    #|        text("__TITLE__").title(),
    #|        text("Count: \{model.count}").title(),
    #|        row([
    #|          button("-", on_click=Decrement),
    #|          button("Reset", on_click=Reset),
    #|          button("+", on_click=Increment),
    #|        ]),
    #|      ]),
    #|    ),
    #|  )
    #|}
    #|
    #|///|
    #|pub fn program() -> @moui.Program[Model, Msg] {
    #|  @moui.Program::simple(init=Model::new(), update~, view~)
    #|}
  template.replace_all(old="__TITLE__", new=title)
}

///|
fn app_test_text() -> String {
  let template =
    #|///|
    #|test "counter update is deterministic" {
    #|  let model = Model::new()
    #|  inspect(update(model, Increment).count, content="1")
    #|  inspect(update(model, Decrement).count, content="-1")
    #|  inspect(update(model, Reset).count, content="0")
    #|}
  template
}

///|
fn web_pkg_text(module_name : String) -> String {
  let template =
    #|import {
    #|  "wzzc-dev/moui/backend/web",
    #|  "wzzc-dev/moui/runtime",
    #|  "__MODULE__/app" @app,
    #|}
    #|
    #|supported_targets = "wasm-gc"
    #|
    #|pkgtype(kind: "executable")
    #|
    #|options(
    #|  link: {
    #|    "wasm-gc": {
    #|      "exports": [
    #|        "web_dispatch_event",
    #|        "web_dispatch_semantics_action",
    #|        "web_dispatch_route",
    #|        "web_complete_async_clipboard_read",
    #|        "web_complete_async_file_dialog",
    #|      ],
    #|    },
    #|  },
    #|  targets: { "main.mbt": [ "wasm-gc" ] },
    #|)
  template.replace_all(old="__MODULE__", new=module_name)
}

///|
fn web_main_text(title : String) -> String {
  let title = moon_string(title)
  let template =
    #|///|
    #|fn main {
    #|  @web.run_app(
    #|    "__TITLE__",
    #|    @runtime.new_program_with_dimensions(
    #|      program=@app.program(),
    #|      width=720.0,
    #|      height=480.0,
    #|    ),
    #|  )
    #|}
    #|
    #|///|
    #|pub fn web_dispatch_event(
    #|  kind : Int,
    #|  raw_id : Int,
    #|  arg0 : Int,
    #|  arg1 : Int,
    #|  argd : Double,
    #|  text_id : Int,
    #|) -> Unit {
    #|  @web.web_dispatch_event(kind, raw_id, arg0, arg1, argd, text_id)
    #|}
    #|
    #|///|
    #|pub fn web_dispatch_route(source_code : Int, text_id : Int) -> Unit {
    #|  @web.web_dispatch_route(source_code, text_id)
    #|}
    #|
    #|///|
    #|pub fn web_dispatch_semantics_action(
    #|  raw_id : Int,
    #|  element_id : Int,
    #|  action_code : Int,
    #|  value_id : Int,
    #|) -> Unit {
    #|  @web.web_dispatch_semantics_action(raw_id, element_id, action_code, value_id)
    #|}
    #|
    #|///|
    #|pub fn web_complete_async_clipboard_read(
    #|  id : Int,
    #|  ok : Bool,
    #|  text_id : Int,
    #|) -> Unit {
    #|  @web.web_complete_async_clipboard_read(id, ok, text_id)
    #|}
    #|
    #|///|
    #|pub fn web_complete_async_file_dialog(
    #|  id : Int,
    #|  ok : Bool,
    #|  text_id : Int,
    #|) -> Unit {
    #|  @web.web_complete_async_file_dialog(id, ok, text_id)
    #|}
  template.replace_all(old="__TITLE__", new=title)
}

///|
fn web_html_text(title : String) -> String {
  let title = html_text(title)
  let template =
    #|<!doctype html>
    #|<html lang="en">
    #|  <head>
    #|    <meta charset="utf-8" />
    #|    <meta name="viewport" content="width=device-width, initial-scale=1" />
    #|    <title>__TITLE__</title>
    #|    <style>
    #|      * { box-sizing: border-box; }
    #|      html, body, #canvas-host { width: 100%; height: 100%; margin: 0; }
    #|      body { overflow: hidden; background: #f6f7f9; }
    #|      canvas { display: block; width: 100%; height: 100%; outline: none; touch-action: none; }
    #|    </style>
    #|  </head>
    #|  <body>
    #|    <div id="canvas-host" aria-label="MoUI canvas host"></div>
    #|    <script type="module">
    #|      import { bootMouiWasmGcApp } from "../.mooncakes/wzzc-dev/moui/backend/web/runtime.js";
    #|      bootMouiWasmGcApp({
    #|        wasmUrl: new URL("../_build/wasm-gc/debug/build/web_wasm/web_wasm.wasm", import.meta.url),
    #|        canvasHost: "#canvas-host",
    #|      }).catch(error => console.error(error));
    #|    </script>
    #|  </body>
    #|</html>
  template.replace_all(old="__TITLE__", new=title)
}

///|
fn desktop_pkg_text(module_name : String, platform : String) -> String {
  let template =
    #|import {
    #|  "wzzc-dev/moui/backend/__PLATFORM__/skia" @platform_skia,
    #|  "wzzc-dev/moui/runtime",
    #|  "__MODULE__/app" @app,
    #|}
    #|
    #|supported_targets = "native"
    #|
    #|pkgtype(kind: "executable")
    #|
    #|options(
    #|  link: { "native": { "cc-link-flags": "" } },
    #|  targets: { "main.mbt": [ "native" ] },
    #|)
  template
  .replace_all(old="__MODULE__", new=module_name)
  .replace_all(old="__PLATFORM__", new=platform)
}

///|
fn desktop_main_text(title : String) -> String {
  let title = moon_string(title)
  let template =
    #|///|
    #|fn main {
    #|  @platform_skia.run_app(
    #|    "__TITLE__",
    #|    @runtime.new_program_with_dimensions(
    #|      program=@app.program(),
    #|      width=720.0,
    #|      height=480.0,
    #|    ),
    #|  )
    #|}
  template.replace_all(old="__TITLE__", new=title)
}

///|
fn gitignore_text() -> String {
  let template =
    #|/.mooncakes/
    #|/_build/
    #|/target/
    #|/artifacts/
    #|/.skia-cache/
    #|*.log
    #|*.tmp
    #|.DS_Store
  template
}

///|
fn moon_work_text() -> String {
  // Single-module workspace root. Local path deps later go through moon.work
  // members (or moon.mod.json deps.path); moon.mod import stays registry-only.
  (
    #|members = [
    #|  ".",
    #|]
    #|
  )
}

///|
fn readme_text(options : ProjectOptions) -> String {
  let builder = StringBuilder::new()
  builder.write_string("# " + options.title + "\n\n")
  builder.write_string(
    "Generated by `moui` CLI " +
    version +
    " for module `" +
    options.module_name +
    "`.\n\n",
  )
  builder.write_string("## Versions\n\n")
  builder.write_string("- CLI: `" + version + "`\n")
  builder.write_string(
    "- Default/framework dependency: `wzzc-dev/moui@" +
    options.moui_version +
    "`\n",
  )
  builder.write_string(
    "- These versions are independent: upgrading the CLI does not change the project dependency until you edit `moon.mod` / regenerate.\n\n",
  )
  builder.write_string("## Platforms\n\n")
  for platform in options.platforms {
    builder.write_string("- `" + platform + "`\n")
  }
  builder.write_string("\n## Next steps\n\n")
  builder.write_string("```sh\n")
  builder.write_string("moon update\n")
  builder.write_string("moui doctor\n")
  if options.platforms.contains("web") {
    builder.write_string("moon check web_wasm --target wasm-gc\n")
    builder.write_string(
      "# serve web_wasm/index.html after building web_wasm\n",
    )
  }
  if options.platforms.contains("macos") {
    builder.write_string("moon run macos_skia --target native\n")
  }
  if options.platforms.contains("windows") {
    builder.write_string("moon run windows_skia --target native\n")
  }
  if options.platforms.contains("linux") {
    builder.write_string("moon run linux_skia --target native\n")
  }
  if options.platforms.any(is_mobile_platform) {
    builder.write_string(
      "# managed mobile shells are staged by the MoUI package; eject only when you need app ownership:\n",
    )
    if options.platforms.contains("android") {
      builder.write_string("moui mobile eject android --output android_app\n")
    }
    if options.platforms.contains("ios") {
      builder.write_string("moui mobile eject ios --output ios_app\n")
    }
    if options.platforms.contains("harmonyos") {
      builder.write_string(
        "moui mobile eject harmonyos --output harmonyos_app\n",
      )
    }
  }
  builder.write_string("```\n\n")
  builder.write_string("## Project maintenance\n\n")
  builder.write_string(
    "- Add a platform later: `moui add platform <name> [--bundle-id ID]`\n",
  )
  builder.write_string(
    "- Scaffold a managed plugin: `moui plugin new <id> --platform android`\n",
  )
  builder.write_string(
    "- Package inventory: `moui package` / `moui package --json`\n",
  )
  builder.write_string("- Safe doctor remediations: `moui doctor --fix`\n")
  builder.to_string()
}

///|
fn managed_platform_json(fields : Array[(String, Json)]) -> Json {
  let values : Map[String, Json] = Map([("shellMode", "managed".to_json())])
  for field in fields {
    let (key, value) = field
    values[key] = value
  }
  Json::object(values)
}

///|
fn mobile_config_text(options : ProjectOptions) -> String {
  let empty_strings : Array[String] = []
  let mobile : Json = {
    "renderer": "auto",
    "systemUi": { "fullscreen": false, "statusBar": "auto" },
    "orientation": "any",
    "resources": empty_strings,
    "permissions": empty_strings,
    "plugins": empty_strings,
  }
  let root : Map[String, Json] = Map([
    ("schemaVersion", (2 : Int).to_json()),
    ("id", options.id.to_json()),
    ("displayName", options.title.to_json()),
    ("artifactName", options.id.to_json()),
    ("appPackage", "app".to_json()),
    ("shellApiVersion", (1 : Int).to_json()),
    ("runtimeAbiVersion", (1 : Int).to_json()),
    ("mobile", mobile),
  ])
  let bundle_id = options.bundle_id.unwrap_or("")
  if options.platforms.contains("android") {
    root["android"] = managed_platform_json([
      ("applicationId", bundle_id.to_json()),
      ("minSdk", (23 : Int).to_json()),
    ])
  }
  if options.platforms.contains("ios") {
    root["ios"] = managed_platform_json([
      ("bundleId", bundle_id.to_json()),
      ("productName", product_name(options.id).to_json()),
      ("deploymentTarget", "15.0".to_json()),
    ])
  }
  if options.platforms.contains("harmonyos") {
    root["harmonyos"] = managed_platform_json([
      ("bundleName", bundle_id.to_json()),
      ("productName", product_name(options.id).to_json()),
      ("appName", options.title.to_json()),
      ("moduleName", "entry".to_json()),
      ("moduleDescription", (options.title + " HarmonyOS app").to_json()),
      ("entryDescription", (options.title + " entry ability").to_json()),
      ("compatibleSdkVersion", (20 : Int).to_json()),
    ])
  }
  Json::object(root).stringify(indent=2) + "\n"
}

///|
fn build_project_file_plan(
  options : ProjectOptions,
) -> Result[Array[PlannedFile], String] {
  match validate_project_options(options) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let manifest : ProjectManifest = {
    schema_version: 1,
    id: options.id,
    title: options.title,
    module_name: options.module_name,
    moui_version: options.moui_version,
    platforms: options.platforms.copy(),
    bundle_id: options.bundle_id,
  }
  let files = [
    text_file(".gitignore", gitignore_text()),
    text_file("README.md", readme_text(options)),
    text_file("moon.mod", moon_mod_text(options)),
    text_file("moon.work", moon_work_text()),
    text_file("moui.project.json", manifest.to_json_text()),
    text_file("app/moon.pkg", app_pkg_text()),
    text_file("app/app.mbt", app_text(options.title)),
    text_file("app/app_test.mbt", app_test_text()),
  ]
  if options.platforms.contains("web") {
    files.push(
      text_file("web_wasm/moon.pkg", web_pkg_text(options.module_name)),
    )
    files.push(text_file("web_wasm/main.mbt", web_main_text(options.title)))
    files.push(text_file("web_wasm/index.html", web_html_text(options.title)))
  }
  for platform in ["macos", "windows", "linux"] {
    if options.platforms.contains(platform) {
      let directory = platform + "_skia"
      files.push(
        text_file(
          directory + "/moon.pkg",
          desktop_pkg_text(options.module_name, platform),
        ),
      )
      files.push(
        text_file(directory + "/main.mbt", desktop_main_text(options.title)),
      )
    }
  }
  if options.platforms.any(is_mobile_platform) {
    files.push(text_file("mobile.json", mobile_config_text(options)))
    for platform in ["android", "ios", "harmonyos"] {
      if options.platforms.contains(platform) {
        let directory = platform + "_skia"
        files.push(
          text_file(
            directory + "/moon.pkg",
            mobile_entrypoint_pkg_text(options.module_name, platform),
          ),
        )
        files.push(
          text_file(
            directory + "/main.mbt",
            mobile_entrypoint_main_text(platform),
          ),
        )
      }
    }
  }
  let sorted = files.copy()
  sorted.sort_by((left, right) => left.path.lexical_compare(right.path))
  Ok(sorted)
}

///|
fn generate_project_with_validator(
  options : ProjectOptions,
  validate : (String) -> Result[Unit, String],
) -> Result[Array[String], String] {
  let files = match build_project_file_plan(options) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  write_validated_project_file_plan(options.target, files, validate)
}

///|
fn generate_project(options : ProjectOptions) -> Result[Array[String], String] {
  match generate_project_with_validator(options, validate_generated_project) {
    Ok(files) => Ok(files)
    Err(message) if options.platforms.any(is_mobile_platform) &&
      (
        message.contains("drain_host_update_envelope_json") ||
        message.contains("dispatch_host_response_envelope_json") ||
        message.contains("session_generation") ||
        message.contains("attach_surface")
      ) =>
      Err(
        "the resolved wzzc-dev/moui@" +
        options.moui_version +
        " package is incompatible with managed mobile shell API 1/runtime ABI 1. " +
        "Registry 0.1.7 predates this contract; validate against a current `moon package` artifact " +
        "or set MOUI_PACKAGE_ROOT to a current package root. The target directory was rolled back.\n" +
        message,
      )
    Err(message) => Err(message)
  }
}
