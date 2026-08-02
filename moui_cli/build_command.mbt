// `moui build` command — build a mobile app artifact (APK / .app / .hap)
// without installing or launching. Shares the same `build_android` /
// `build_ios` / `build_harmonyos` implementations as `moui run`'s build
// step; `moui run --build-only` is equivalent to `moui build` followed by
// skipping install/launch.

///|
priv struct ParsedBuild {
  help : Bool
  json : Bool
  platform : String
  options : BuildCommandOptions?
}

///|
priv struct BuildCommandOptions {
  // `app` (positional arg) is not stored here because the platform
  // `Build*Options` carry the parsed mobile configuration directly.
  app_config_path : String?
  workspace_root : String
  moui_root : String
  skia_root : String
  build_dir : String
  output : String?
  renderer : String?
  fallback_skia : Bool
  prepare_only : Bool
  // Platform-specific product override.
  product_name : String?
  abi : String?
  compile_sdk : Int?
  target_sdk : Int?
  sdk : String?
  arch : String?
  deployment_target : String?
  sdk_home : String?
  hvigorw : String?
  ohpm : String?
  signing_config_file : String?
}

///|
fn build_usage() -> String {
  (
    #|Usage: moui build <platform> <app> [options]
    #|
    #|Build a MoUI mobile app artifact (APK / .app / .hap) without installing
    #|or launching. The platform toolchain (Gradle / Xcode / hvigor) must be
    #|on PATH. Configuration defaults come from `moui config`.
    #|
    #|Arguments:
    #|  platform     Target platform: android, ios, or harmonyos.
    #|  app          Application id (matches moui.mobile.json `id`).
    #|
    #|Options:
    #|  --mobile-config PATH        Path to moui.mobile.json. Defaults to ./moui.mobile.json.
    #|  --workspace-root PATH       Workspace root. Defaults to the current directory.
    #|  --moui-root PATH            MoUI package root. Defaults from `moui config`.
    #|  --skia-root PATH            Skia package root. Defaults from `moui config`.
    #|  --build-dir PATH            Build output directory. Defaults to ./artifacts/<platform>.
    #|  --output PATH                Output artifact path. Defaults to <build-dir>/<app-id>.<ext>.
    #|  --renderer NAME             Renderer override (auto / skia / wgpu).
    #|  --fallback-skia             Allow Skia fallback when primary renderer fails.
    #|  --prepare-only               Stop after preparing native build inputs.
    #|  --product-name NAME         iOS product name override.
    #|  --abi ABI                   Android ABI (e.g. arm64-v8a). Defaults from `moui config`.
    #|  --compile-sdk VERSION       Android compileSdk. Defaults from `moui config`.
    #|  --target-sdk VERSION        Android targetSdk. Defaults from `moui config`.
    #|  --sdk NAME                  iOS SDK name (e.g. iphoneos). Defaults from `moui config`.
    #|  --arch ARCH                 iOS arch (e.g. arm64). Defaults from `moui config`.
    #|  --deployment-target VER     iOS deployment target (e.g. 15.0). Defaults from `moui config`.
    #|  --sdk-home PATH             HarmonyOS SDK home. Defaults from `moui config`.
    #|  --hvigorw PATH               hvigorw executable. Defaults from `moui config`.
    #|  --ohpm PATH                  ohpm executable. Defaults from `moui config`.
    #|  --signing-config-file PATH  HarmonyOS signing config file.
    #|  --json                       Emit machine-readable output.
    #|  -h, --help                   Show this help.
  )
}

///|
fn parse_build_args(
  args : Array[String],
  cwd : String,
  host : HostPlatform,
) -> Result[ParsedBuild, String] {
  let _ = host
  let help = Ref(false)
  let json = Ref(false)
  let positional : Array[String] = []
  let app_config : Ref[String?] = Ref(None)
  let workspace_root : Ref[String?] = Ref(None)
  let moui_root : Ref[String?] = Ref(None)
  let skia_root : Ref[String?] = Ref(None)
  let build_dir : Ref[String?] = Ref(None)
  let output : Ref[String?] = Ref(None)
  let renderer : Ref[String?] = Ref(None)
  let fallback_skia = Ref(false)
  let prepare_only = Ref(false)
  let product_name : Ref[String?] = Ref(None)
  let abi : Ref[String?] = Ref(None)
  let compile_sdk : Ref[Int?] = Ref(None)
  let target_sdk : Ref[Int?] = Ref(None)
  let sdk : Ref[String?] = Ref(None)
  let arch : Ref[String?] = Ref(None)
  let deployment_target : Ref[String?] = Ref(None)
  let sdk_home : Ref[String?] = Ref(None)
  let hvigorw : Ref[String?] = Ref(None)
  let ohpm : Ref[String?] = Ref(None)
  let signing_config_file : Ref[String?] = Ref(None)
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (name, inline) = option_parts(argument)
    match name {
      "--json" =>
        match flag_without_value(inline, name) {
          Ok(_) => json.val = true
          Err(message) => return Err(message)
        }
      "-h" | "--help" =>
        match flag_without_value(inline, name) {
          Ok(_) => help.val = true
          Err(message) => return Err(message)
        }
      "--fallback-skia" | "--prepare-only" =>
        match flag_without_value(inline, name) {
          Ok(_) =>
            match name {
              "--fallback-skia" => fallback_skia.val = true
              "--prepare-only" => prepare_only.val = true
              _ => ()
            }
          Err(message) => return Err(message)
        }
      "--mobile-config"
      | "--workspace-root"
      | "--moui-root"
      | "--skia-root"
      | "--build-dir"
      | "--output"
      | "--renderer"
      | "--product-name"
      | "--abi"
      | "--sdk"
      | "--arch"
      | "--deployment-target"
      | "--sdk-home"
      | "--hvigorw"
      | "--ohpm"
      | "--signing-config-file" =>
        match option_value(args, index, inline, name) {
          Ok((value, next)) => {
            match name {
              "--mobile-config" => app_config.val = Some(value)
              "--workspace-root" => workspace_root.val = Some(value)
              "--moui-root" => moui_root.val = Some(value)
              "--skia-root" => skia_root.val = Some(value)
              "--build-dir" => build_dir.val = Some(value)
              "--output" => output.val = Some(value)
              "--renderer" => renderer.val = Some(value)
              "--product-name" => product_name.val = Some(value)
              "--abi" => abi.val = Some(value)
              "--sdk" => sdk.val = Some(value)
              "--arch" => arch.val = Some(value)
              "--deployment-target" => deployment_target.val = Some(value)
              "--sdk-home" => sdk_home.val = Some(value)
              "--hvigorw" => hvigorw.val = Some(value)
              "--ohpm" => ohpm.val = Some(value)
              "--signing-config-file" => signing_config_file.val = Some(value)
              _ => ()
            }
            index = next
            continue
          }
          Err(message) => return Err(message)
        }
      "--compile-sdk" | "--target-sdk" =>
        match option_value(args, index, inline, name) {
          Ok((value, next)) => {
            match parse_int(value) {
              Ok(num) =>
                match name {
                  "--compile-sdk" => compile_sdk.val = Some(num)
                  "--target-sdk" => target_sdk.val = Some(num)
                  _ => ()
                }
              Err(_) => return Err("invalid integer for " + name + ": " + value)
            }
            index = next
            continue
          }
          Err(message) => return Err(message)
        }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui build: " + name)
      _ => positional.push(argument)
    }
    index += 1
  }
  if help.val {
    return Ok({ help: true, json: json.val, platform: "", options: None })
  }
  if positional.length() < 2 {
    return Err("usage: moui build <platform> <app> [options]")
  }
  if positional.length() > 2 {
    return Err("moui build accepts exactly two positional arguments")
  }
  let platform = positional[0]
  let app = positional[1]
  match platform {
    "android" | "ios" | "harmonyos" => ()
    _ =>
      return Err(
        "unsupported platform for moui build: " +
        platform +
        " (use `moon run` for desktop/web targets)",
      )
  }
  // `app` positional arg is validated but not stored; the platform
  // build functions carry the parsed mobile configuration.
  let _ = app
  Ok({
    help: false,
    json: json.val,
    platform,
    options: Some({
      app_config_path: app_config.val,
      workspace_root: workspace_root.val.unwrap_or(cwd),
      moui_root: moui_root.val.unwrap_or(""),
      skia_root: skia_root.val.unwrap_or(""),
      build_dir: build_dir.val.unwrap_or(""),
      output: output.val,
      renderer: renderer.val,
      fallback_skia: fallback_skia.val,
      prepare_only: prepare_only.val,
      product_name: product_name.val,
      abi: abi.val,
      compile_sdk: compile_sdk.val,
      target_sdk: target_sdk.val,
      sdk: sdk.val,
      arch: arch.val,
      deployment_target: deployment_target.val,
      sdk_home: sdk_home.val,
      hvigorw: hvigorw.val,
      ohpm: ohpm.val,
      signing_config_file: signing_config_file.val,
    }),
  })
}

///|
/// Parse a decimal integer. Returns `Err` on empty input or non-digit characters.
fn parse_int(value : String) -> Result[Int, String] {
  if value == "" {
    return Err("empty integer")
  }
  let mut num = 0
  for ch in value {
    if ch >= '0' && ch <= '9' {
      num = num * 10 + (ch.to_int() - '0'.to_int())
    } else {
      return Err("invalid digit: " + value.to_string())
    }
  }
  Ok(num)
}

///|
/// Resolve default `moui_root` / `skia_root` from `CliConfig` when the user
/// did not pass `--moui-root` / `--skia-root` on the command line. The
/// `workspace_root` is the anchor for relative path resolution.
fn resolve_build_roots(
  options : BuildCommandOptions,
  config : CliConfig,
) -> (String, String) {
  let moui_root = if options.moui_root != "" {
    options.moui_root
  } else {
    match config.paths.moui_root {
      Some(p) => p
      None => join_path(options.workspace_root, "moui")
    }
  }
  let skia_root = if options.skia_root != "" {
    options.skia_root
  } else {
    match config.paths.skia_root {
      Some(p) => p
      None => join_path(options.workspace_root, "moui_skia")
    }
  }
  (moui_root, skia_root)
}

///|
/// Resolve the default build directory for the given platform.
fn default_build_dir(platform : String, workspace_root : String) -> String {
  join_path(join_path(workspace_root, "artifacts"), platform)
}

///|
/// Construct `BuildAndroidOptions` from the user-facing `BuildCommandOptions`
/// and `CliConfig`. Caller ensures `platform == "android"`.
fn build_android_options_from_command(
  options : BuildCommandOptions,
  app : MobileApp,
  config : CliConfig,
) -> BuildAndroidOptions {
  let (_, skia_root) = resolve_build_roots(options, config)
  let build_dir = if options.build_dir != "" {
    options.build_dir
  } else {
    default_build_dir("android", options.workspace_root)
  }
  let output_apk = match options.output {
    Some(p) => p
    None => join_path(build_dir, app.id + ".apk")
  }
  let abi = match options.abi {
    Some(a) => a
    None =>
      if config.android.abi.length() > 0 {
        config.android.abi[0]
      } else {
        "arm64-v8a"
      }
  }
  let compile_sdk = match options.compile_sdk {
    Some(v) => v
    None =>
      match config.android.compile_sdk {
        Some(v) => v
        None => 34
      }
  }
  let target_sdk = match options.target_sdk {
    Some(v) => v
    None =>
      match config.android.target_sdk {
        Some(v) => v
        None => 34
      }
  }
  let renderer = match options.renderer {
    Some(r) => r
    None => "auto"
  }
  {
    app,
    workspace_root: options.workspace_root,
    skia_root,
    abi,
    compile_sdk,
    target_sdk,
    renderer,
    build_dir,
    output_apk,
    fallback_skia: options.fallback_skia,
    prepare_only: options.prepare_only,
  }
}

///|
/// Construct `BuildIosOptions` from the user-facing `BuildCommandOptions`
/// and `CliConfig`. Caller ensures `platform == "ios"`.
fn build_ios_options_from_command(
  options : BuildCommandOptions,
  app : MobileApp,
  config : CliConfig,
) -> BuildIosOptions {
  let (_, _) = resolve_build_roots(options, config)
  let build_dir = if options.build_dir != "" {
    options.build_dir
  } else {
    default_build_dir("ios", options.workspace_root)
  }
  let output_app = match options.output {
    Some(p) => p
    None => join_path(build_dir, app.id + ".app")
  }
  let sdk = match options.sdk {
    Some(s) => s
    None =>
      match config.ios.sdk {
        Some(s) => s
        None => "iphoneos"
      }
  }
  let arch = match options.arch {
    Some(a) => a
    None =>
      match config.ios.arch {
        Some(a) => a
        None => "arm64"
      }
  }
  let deployment_target : String? = match options.deployment_target {
    Some(t) => Some(t)
    None =>
      match config.ios.deployment_target {
        Some(v) => Some(v.to_string())
        None => None
      }
  }
  let renderer = match options.renderer {
    Some(r) => r
    None => "auto"
  }
  {
    app,
    product_name: options.product_name,
    workspace_root: options.workspace_root,
    sdk,
    arch,
    deployment_target,
    renderer,
    build_dir,
    output_app,
    fallback_skia: options.fallback_skia,
    prepare_only: options.prepare_only,
  }
}

///|
/// Construct `BuildHarmonyosOptions` from the user-facing `BuildCommandOptions`
/// and `CliConfig`. Caller ensures `platform == "harmonyos"`.
fn build_harmonyos_options_from_command(
  options : BuildCommandOptions,
  app : MobileApp,
  config : CliConfig,
) -> BuildHarmonyosOptions {
  let (_, skia_root) = resolve_build_roots(options, config)
  let build_dir = if options.build_dir != "" {
    options.build_dir
  } else {
    default_build_dir("harmonyos", options.workspace_root)
  }
  let output_hap = match options.output {
    Some(p) => p
    None => join_path(build_dir, app.id + ".hap")
  }
  let arch = match options.arch {
    Some(a) => a
    None => "arm64"
  }
  let renderer = match options.renderer {
    Some(r) => r
    None => "auto"
  }
  let sdk_home = match options.sdk_home {
    Some(p) => Some(p)
    None => config.harmonyos.sdk_home
  }
  let hvigorw = match options.hvigorw {
    Some(p) => Some(p)
    None => config.harmonyos.hvigorw
  }
  let ohpm = match options.ohpm {
    Some(p) => Some(p)
    None => config.harmonyos.ohpm
  }
  let signing_config_file = match options.signing_config_file {
    Some(p) => Some(p)
    None => config.harmonyos.signing_config_file
  }
  {
    app,
    workspace_root: options.workspace_root,
    skia_root,
    arch,
    renderer,
    build_dir,
    output_hap,
    sdk_home,
    hvigorw,
    ohpm,
    fallback_skia: options.fallback_skia,
    prepare_only: options.prepare_only,
    signing_config_file,
  }
}

///|
/// Dispatch to the platform-specific `build_*` function. Shared by
/// `moui build` and `moui run`'s build step so they stay in sync.
fn run_build_internal(
  options : BuildCommandOptions,
  platform : String,
  host : HostPlatform,
  app : MobileApp,
  config : CliConfig,
) -> Result[BuildResult, String] {
  match platform {
    "android" =>
      build_android(
        build_android_options_from_command(options, app, config),
        host,
      )
    "ios" =>
      build_ios(build_ios_options_from_command(options, app, config), host)
    "harmonyos" =>
      build_harmonyos(
        build_harmonyos_options_from_command(options, app, config),
        host,
      )
    _ => Err("unsupported platform: " + platform)
  }
}

///|
/// Render the build result as JSON for the `--json` output mode.
fn build_result_to_json(
  platform : String,
  app_id : String,
  result : BuildResult,
) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["schemaVersion"] = Json::number(1.0)
  fields["ok"] = Json::boolean(true)
  fields["platform"] = Json::string(platform)
  fields["appId"] = Json::string(app_id)
  fields["buildDir"] = Json::string(result.build_dir)
  fields["artifact"] = Json::string(result.output_artifact)
  Json::object(fields)
}

///|
/// Render the build result as plain text for the default output mode.
fn build_result_to_text(
  platform : String,
  app_id : String,
  result : BuildResult,
) -> String {
  let mut text = "[build] " + platform + " app=" + app_id + "\n"
  text += "  build_dir: " + result.build_dir + "\n"
  text += "  artifact: " + result.output_artifact + "\n"
  match result.output_artifact {
    "" => text + "  status: prepared\n"
    _ => text + "  status: built\n"
  }
}

///|
fn run_build(parsed : ParsedBuild, host : HostPlatform) -> CliOutcome {
  if parsed.help {
    return stdout_outcome(build_usage())
  }
  guard parsed.options is Some(options) else {
    return failed_outcome(
      "build command options are unavailable",
      parsed.json,
      build_usage(),
    )
  }
  // 1. Read mobile metadata from the supplied path or workspace root.
  let app_result = match options.app_config_path {
    Some(path) => read_mobile_app_at(path)
    None => read_mobile_app(options.workspace_root)
  }
  let app = match app_result {
    Ok(a) => a
    Err(message) =>
      return failed_outcome(
        "could not read moui.mobile.json: " + message,
        parsed.json,
        build_usage(),
      )
  }
  // 2. Read CLI config for SDK / NDK / Xcode defaults.
  let config = match read_config(host) {
    Ok(c) => c
    Err(message) => return failed_outcome(message, parsed.json, build_usage())
  }
  // 3. Dispatch to platform build_*.
  let result = match
    run_build_internal(options, parsed.platform, host, app, config) {
    Ok(r) => r
    Err(message) => return failed_outcome(message, parsed.json, build_usage())
  }
  // 4. Emit output.
  if parsed.json {
    stdout_outcome(
      build_result_to_json(parsed.platform, app.id, result).stringify(indent=2) +
      "\n",
    )
  } else {
    stdout_outcome(build_result_to_text(parsed.platform, app.id, result))
  }
}
