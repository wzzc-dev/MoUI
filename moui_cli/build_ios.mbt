// iOS build glue. Migrates `moui_shell/scripts/build-ios-app.sh` (274 lines)
// into MoonBit.
//
// `build_ios` enforces the Xcode 15.4 floor, prepares native inputs (M5),
// stages the canonical iOS Xcode project (managed) or validates the ejected
// shell lock (M9.1), and invokes `xcodebuild` with the
// `MOUI_EMBEDDING_*` env vars consumed by `build-ios-app-core.sh`.

///|
priv struct BuildIosOptions {
  app : ShellApp
  xcode_project : String?
  scheme : String?
  product_name : String?
  app_config : String
  workspace_root : String
  project_root : String
  moui_root : String
  skia_root : String
  sdk : String
  arch : String
  deployment_target : String?
  renderer : String
  build_dir : String
  output_app : String
  fallback_skia : Bool
  ejected_shell : Bool
  prepare_only : Bool
}

///|
/// Locate the Xcode version via `xcodebuild -version`. Returns the first
/// numeric version token (e.g. `"15.4"`). Empty string when `xcodebuild` is
/// unavailable.
fn xcode_version_string() -> String {
  match process_exec_argv(["xcodebuild", "-version"], capture=true) {
    Ok(result) if result.exit_code == 0 => {
      let line = result.stdout.split("\n").to_array()[0].to_string()
      // "Xcode 15.4\n..." -> take the second whitespace-delimited token.
      let parts = line.split(" ").to_array()
      if parts.length() >= 2 {
        parts[1].to_string()
      } else {
        ""
      }
    }
    _ => ""
  }
}

///|
/// Parse a dotted numeric version into an array of integers. Trailing
/// non-numeric parts are dropped. Empty array when parsing fails.
fn parse_dotted_version(value : String) -> Array[Int] {
  let parts = value.split(".").to_array()
  let result : Array[Int] = []
  for part in parts {
    let trimmed = part.trim()
    if trimmed == "" {
      return []
    }
    let mut num = 0
    let mut ok = true
    for ch in trimmed {
      if ch >= '0' && ch <= '9' {
        num = num * 10 + (ch.to_int() - '0'.to_int())
      } else {
        ok = false
        break
      }
    }
    if !ok {
      return []
    }
    result.push(num)
  }
  result
}

///|
/// Returns `true` when `actual >= floor` using dotted numeric comparison.
fn version_at_least(actual : String, floor : String) -> Bool {
  let left = parse_dotted_version(actual)
  let right = parse_dotted_version(floor)
  if left.is_empty() || right.is_empty() {
    return false
  }
  let length = if left.length() > right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<length {
    let l = if i < left.length() { left[i] } else { 0 }
    let r = if i < right.length() { right[i] } else { 0 }
    if l > r {
      return true
    }
    if l < r {
      return false
    }
  }
  true
}

///|
/// Build the iOS app bundle. Mirrors `build-ios-app.sh`. On macOS only.
fn build_ios(
  options : BuildIosOptions,
  host : HostPlatform,
) -> Result[BuildResult, String] {
  match host {
    Macos => ()
    _ => return Err("iOS builds require macOS with Xcode installed")
  }
  // 1. Xcode version floor.
  let found = xcode_version_string()
  if !version_at_least(found, "15.4") {
    return Err(
      "MoUI iOS shell requires Xcode 15.4 or newer; found " +
      (if found == "" { "unknown" } else { found }),
    )
  }
  // 2. Determine xcode_project + scheme + product_name.
  let xcode_project = match options.xcode_project {
    Some(value) =>
      if path_is_absolute(value) {
        value
      } else {
        join_path(options.workspace_root, value)
      }
    None =>
      if options.ejected_shell {
        return Err("--ejected-shell requires --xcode-project")
      } else {
        join_path(options.build_dir, "ios-project/MoUIShellApp.xcodeproj")
      }
  }
  let scheme = match options.scheme {
    Some(value) => value
    None =>
      if options.ejected_shell {
        // basename($xcode_project) without .xcodeproj
        let base = basename(xcode_project)
        if base.has_suffix(".xcodeproj") {
          base.substring(end=base.length() - ".xcodeproj".length()).to_string()
        } else {
          base
        }
      } else {
        "MoUIShellApp"
      }
  }
  let product_name = options.product_name.unwrap_or(scheme)
  // 3. Validate ejected lock if applicable.
  if options.ejected_shell {
    let lock_path = join_path(
      join_path(xcode_project, ".."),
      ".moui-shell.json",
    )
    match
      validate_ejected_lock(
        lock_path,
        "ios",
        options.moui_root,
        join_path(options.moui_root, "../moui_shell"),
        options.project_root,
        options.app_config,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  } else {
    // Stage the canonical iOS Xcode project template.
    let staged_root = join_path(xcode_project, "..")
    let stage_marker = join_path(staged_root, ".moui-managed-ios-stage")
    let template_root = join_path(
      join_path(options.moui_root, "../moui_shell"),
      "ios/runner/template",
    )
    if !path_is_file(
        join_path(template_root, "MoUIShellApp.xcodeproj/project.pbxproj"),
      ) ||
      !path_is_file(join_path(template_root, "Info.plist")) {
      return Err("MoUI iOS template is incomplete: " + template_root)
    }
    if path_is_dir(staged_root) && !path_is_file(stage_marker) {
      return Err("refusing to replace an unowned iOS project: " + staged_root)
    }
    remove_tree(staged_root)
    match mkdir_p(staged_root) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    match write_file_bytes_result(stage_marker, b"") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    match copy_tree(template_root, staged_root) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    log_info("[moui-shell-ios] Staged canonical iOS shell in " + staged_root)
  }
  // 4. Prepare native build inputs.
  let contract = match
    managed_platform_contract(
      options.app,
      "ios",
      options.workspace_root,
      join_path(options.moui_root, "../moui_shell"),
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let deployment_target = options.deployment_target.unwrap_or("15.0")
  let prepare_options : PrepareOptions = {
    app: options.app,
    app_config_path: options.app_config,
    workspace_root: options.workspace_root,
    moui_root: options.moui_root,
    skia_root: options.skia_root,
    build_dir: options.build_dir,
    abi: "",
    android_shell: "",
    sdk: options.sdk,
    arch: options.arch,
    renderer: options.renderer,
    fallback_skia: options.fallback_skia,
    shell_root: join_path(options.moui_root, "../moui_shell"),
    contract,
  }
  let prepare_result = match prepare_native_build(prepare_options) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if options.prepare_only {
    log_info(
      "[moui-shell-ios] Prepared iOS build inputs in " + options.build_dir,
    )
    return Ok({
      platform: "ios",
      build_dir: options.build_dir,
      output_artifact: "",
      prepare_result,
    })
  }
  // 5. Invoke xcodebuild with the MOUI_EMBEDDING_* env block.
  let shell_mode = if options.ejected_shell { "ejected" } else { "managed" }
  let env = moon_build_env()
  env.push(("MOUI_EMBEDDING_APP", options.app.id))
  env.push(("MOUI_EMBEDDING_WORKSPACE_ROOT", options.workspace_root))
  env.push(("MOUI_EMBEDDING_PROJECT_ROOT", options.project_root))
  env.push(("MOUI_PACKAGE_ROOT", options.moui_root))
  env.push(
    ("MOUI_SHELL_PACKAGE_ROOT", join_path(options.moui_root, "../moui_shell")),
  )
  env.push(("MOUI_SKIA_ROOT", options.skia_root))
  env.push(("MOUI_EMBEDDING_APP_CONFIG", options.app_config))
  env.push(("MOUI_EMBEDDING_BUILD_DIR", options.build_dir))
  env.push(("MOUI_EMBEDDING_OUTPUT_APP", options.output_app))
  env.push(("MOUI_EMBEDDING_ARCH", options.arch))
  env.push(("MOUI_EMBEDDING_DEPLOYMENT_TARGET", deployment_target))
  env.push(("MOUI_EMBEDDING_SDK", options.sdk))
  env.push(("MOUI_EMBEDDING_RENDERER", options.renderer))
  env.push(
    (
      "MOUI_EMBEDDING_FALLBACK_SKIA",
      if options.fallback_skia {
        "1"
      } else {
        "0"
      },
    ),
  )
  env.push(("MOUI_EMBEDDING_IOS_SHELL", shell_mode))
  let argv = [
    "xcodebuild",
    "-project",
    xcode_project,
    "-scheme",
    scheme,
    "-configuration",
    "Debug",
    "-sdk",
    options.sdk,
    "ARCHS=" + options.arch,
    "IPHONEOS_DEPLOYMENT_TARGET=" + deployment_target,
    "MOUI_EMBEDDING_IOS_SHELL=" + shell_mode,
    "build",
  ]
  log_command("xcodebuild", argv)
  match process_exec_argv(argv, env~, capture=false) {
    Ok(result) if result.exit_code == 0 => ()
    Ok(result) =>
      return Err(
        "xcodebuild failed with exit code " + result.exit_code.to_string(),
      )
    Err(message) => return Err(message)
  }
  // 6. Resolve output_app.
  let output_app = if options.output_app == "" {
    join_path(options.build_dir, product_name + ".app")
  } else {
    options.output_app
  }
  if !path_is_dir(output_app) {
    return Err("iOS app bundle was not produced: " + output_app)
  }
  log_info("[moui-shell-ios] Wrote " + output_app)
  Ok({
    platform: "ios",
    build_dir: options.build_dir,
    output_artifact: output_app,
    prepare_result,
  })
}
