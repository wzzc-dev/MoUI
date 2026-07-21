// Internal `moui build-ios-core` command — env-var-driven entrypoint used by
// the thin `moui_shell/scripts/build-ios-app-core.sh` launcher that Xcode Run
// Script Phases invoke. Reads build settings from `MOUI_EMBEDDING_*` env
// vars (set by `build_ios.mbt`), constructs `BuildIosCoreOptions`, and
// delegates to `build_ios_core`. Not surfaced in `moui --help`; prefer the
// user-facing `moui build ios` for ad-hoc builds.

///|
priv struct ParsedBuildIosCore {
  help : Bool
  app_id : String?
}

///|
fn build_ios_core_usage() -> String {
  (
    #|Usage: moui build-ios-core --app <id> [options]
    #|
    #|Internal builder used by Xcode Run Script Phases. Reads build settings
    #|from MOUI_EMBEDDING_* env vars; only `--app` is a CLI flag. Prefer the
    #|user-facing `moui build ios` for ad-hoc builds.
    #|
    #|Arguments:
    #|  --app <id>     Shell app id (matches shell.json `id`).
    #|                 Falls back to $MOUI_EMBEDDING_APP.
    #|
    #|Options:
    #|  -h, --help     Show this help.
  )
}

///|
fn parse_build_ios_core_args(
  args : Array[String],
) -> Result[ParsedBuildIosCore, String] {
  let help = Ref(false)
  let app_id : Ref[String?] = Ref(None)
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (name, inline) = option_parts(argument)
    match name {
      "-h" | "--help" =>
        match flag_without_value(inline, name) {
          Ok(_) => help.val = true
          Err(message) => return Err(message)
        }
      "--app" =>
        match option_value(args, index, inline, name) {
          Ok((value, next)) => {
            app_id.val = Some(value)
            index = next
            continue
          }
          Err(message) => return Err(message)
        }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui build-ios-core: " + name)
      _ => return Err("unexpected positional argument: " + argument)
    }
    index += 1
  }
  Ok({ help: help.val, app_id: app_id.val })
}

///|
/// Return the value of `key` from the environment, or `default` when unset.
fn env_or(key : String, default : String) -> String {
  match @env.get_env_var(key) {
    Some(value) => value
    None => default
  }
}

///|
/// Read `MOUI_EMBEDDING_*` env vars + the `--app` flag, construct
/// `BuildIosCoreOptions`, and invoke `build_ios_core`. Used by Xcode Run
/// Script Phases via the thin `moui_shell/scripts/build-ios-app-core.sh`
/// launcher.
fn run_build_ios_core(
  parsed : ParsedBuildIosCore,
  host : HostPlatform,
) -> CliOutcome {
  if parsed.help {
    return stdout_outcome(build_ios_core_usage())
  }
  let app_id = match parsed.app_id {
    Some(value) => value
    None =>
      match @env.get_env_var("MOUI_EMBEDDING_APP") {
        Some(value) => value
        None =>
          return failed_outcome(
            "build-ios-core requires --app or $MOUI_EMBEDDING_APP",
            false,
            build_ios_core_usage(),
          )
      }
  }
  let workspace_root = env_or("MOUI_EMBEDDING_WORKSPACE_ROOT", ".")
  let moui_root = env_or("MOUI_PACKAGE_ROOT", join_path(workspace_root, "moui"))
  let skia_root = env_or(
    "MOUI_SKIA_ROOT",
    join_path(workspace_root, "moui_skia"),
  )
  let app_config = env_or("MOUI_EMBEDDING_APP_CONFIG", "")
  let project_root = match @env.get_env_var("MOUI_EMBEDDING_PROJECT_ROOT") {
    Some(value) => value
    None => if app_config != "" { parent_dir(app_config) } else { "." }
  }
  // Load shell.json to construct the full `ShellApp` (needed by
  // `prepare_native_build` which reads `app.android` / `app.ios` / etc.).
  let app = match read_shell_app(project_root) {
    Ok(value) => value
    Err(message) =>
      return failed_outcome(
        "could not read shell.json: " + message,
        false,
        build_ios_core_usage(),
      )
  }
  if app.id != app_id {
    return failed_outcome(
      "shell.json id (" + app.id + ") does not match --app (" + app_id + ")",
      false,
      build_ios_core_usage(),
    )
  }
  let sdk = env_or("MOUI_EMBEDDING_SDK", "iphonesimulator")
  let arch = env_or("MOUI_EMBEDDING_ARCH", "arm64")
  let deployment_target = env_or("MOUI_EMBEDDING_DEPLOYMENT_TARGET", "15.0")
  let renderer = env_or("MOUI_EMBEDDING_RENDERER", "auto")
  let fallback_skia = env_or("MOUI_EMBEDDING_FALLBACK_SKIA", "0") != "0"
  let shell_mode = env_or("MOUI_EMBEDDING_IOS_SHELL", "managed")
  let build_dir = env_or(
    "MOUI_EMBEDDING_BUILD_DIR",
    join_path(join_path(workspace_root, "artifacts"), "ios"),
  )
  let env_map = @env.get_env_vars()
  let env : Array[(String, String)] = []
  for key, value in env_map {
    env.push((key, value))
  }
  let options : BuildIosCoreOptions = {
    app,
    app_config,
    workspace_root,
    project_root,
    moui_root,
    skia_root,
    sdk,
    arch,
    deployment_target,
    renderer,
    fallback_skia,
    shell_mode,
    build_dir,
    target_build_dir: None,
    full_product_name: None,
    resolved_swift: None,
    resolved_manifest: None,
    env,
  }
  match build_ios_core(options, host) {
    Ok(result) =>
      stdout_outcome("[moui-shell-ios] Wrote " + result.output_artifact + "\n")
    Err(message) => failed_outcome(message, false, build_ios_core_usage())
  }
}
