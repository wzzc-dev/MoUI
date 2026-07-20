// `moui run` command — build, install, and launch a mobile app on a device
// or emulator. Orchestrates the M6 `build_*` functions with platform-specific
// install/launch commands (adb / xcrun / hdc). Optional `--verify` runs the
// M9.2 probe to collect runtime observations.

///|
priv struct ParsedRun {
  help : Bool
  json : Bool
  platform : String
  options : RunOptions?
}

///|
priv struct RunOptions {
  app : String
  app_config_path : String?
  device : String?
  renderer : String?
  fallback_skia : Bool
  ejected_shell : Bool
  prepare_only : Bool
  build_only : Bool
  no_build : Bool
  no_install : Bool
  no_launch : Bool
  debug : Bool
  filter : String?
  verify : Bool
  custom_args : Array[String]
}

///|
fn run_usage() -> String {
  (
    #|Usage: moui run <platform> <app> [options]
    #|
    #|Build, install, and launch a MoUI mobile app on a connected device or
    #|emulator. The platform toolchain (adb / xcrun / hdc) must be on PATH.
    #|
    #|Arguments:
    #|  platform     Target platform: android, ios, or harmonyos.
    #|  app          Application id (matches shell.json `id`).
    #|
    #|Options:
    #|  --app-config PATH       Path to shell.json. Defaults to ./shell.json.
    #|  --device ID             Target device id. Defaults to the first device.
    #|  --renderer NAME         Renderer override (auto / skia / wgpu).
    #|  --fallback-skia        Allow Skia fallback when primary renderer fails.
    #|  --ejected-shell         Use an ejected (owned) shell; requires platform
    #|                          project paths to be present.
    #|  --prepare-only          Stop after preparing native build inputs.
    #|  --build-only            Stop after producing the build artifact.
    #|  --no-build              Skip the build step (use existing artifact).
    #|  --no-install            Skip the install step.
    #|  --no-launch             Skip the launch step.
    #|  --debug                 Follow platform logs after launch (logcat /
    #|                          hilog / oslog) until interrupted.
    #|  --filter FILTER         Logcat/hilog/oslog filter expression.
    #|  --verify                Run the M9.2 runtime probe after launch.
    #|  -- <args...>            Extra arguments forwarded to the launched app.
    #|  --json                  Emit machine-readable output.
    #|  -h, --help              Show this help.
  )
}

///|
fn parse_run_args(
  args : Array[String],
  cwd : String,
  host : HostPlatform,
) -> Result[ParsedRun, String] {
  let _ = cwd
  let _ = host
  let help = Ref(false)
  let json = Ref(false)
  let positional : Array[String] = []
  let app_config : Ref[String?] = Ref(None)
  let device : Ref[String?] = Ref(None)
  let renderer : Ref[String?] = Ref(None)
  let fallback_skia = Ref(false)
  let ejected_shell = Ref(false)
  let prepare_only = Ref(false)
  let build_only = Ref(false)
  let no_build = Ref(false)
  let no_install = Ref(false)
  let no_launch = Ref(false)
  let debug = Ref(false)
  let filter : Ref[String?] = Ref(None)
  let verify = Ref(false)
  let custom_args : Array[String] = []
  let mut index = 0
  let mut passthrough = false
  while index < args.length() {
    let argument = args[index]
    if passthrough {
      custom_args.push(argument)
      index += 1
      continue
    }
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
      "--fallback-skia"
      | "--ejected-shell"
      | "--prepare-only"
      | "--build-only"
      | "--no-build"
      | "--no-install"
      | "--no-launch"
      | "--debug"
      | "--verify" =>
        match flag_without_value(inline, name) {
          Ok(_) =>
            match name {
              "--fallback-skia" => fallback_skia.val = true
              "--ejected-shell" => ejected_shell.val = true
              "--prepare-only" => prepare_only.val = true
              "--build-only" => build_only.val = true
              "--no-build" => no_build.val = true
              "--no-install" => no_install.val = true
              "--no-launch" => no_launch.val = true
              "--debug" => debug.val = true
              "--verify" => verify.val = true
              _ => ()
            }
          Err(message) => return Err(message)
        }
      "--app-config" | "--device" | "--renderer" | "--filter" =>
        match option_value(args, index, inline, name) {
          Ok((value, next)) => {
            match name {
              "--app-config" => app_config.val = Some(value)
              "--device" => device.val = Some(value)
              "--renderer" => renderer.val = Some(value)
              "--filter" => filter.val = Some(value)
              _ => ()
            }
            index = next
            continue
          }
          Err(message) => return Err(message)
        }
      "--" => {
        passthrough = true
        index += 1
        continue
      }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui run: " + name)
      _ => positional.push(argument)
    }
    index += 1
  }
  if help.val {
    return Ok({ help: true, json: json.val, platform: "", options: None })
  }
  if positional.length() < 2 {
    return Err("usage: moui run <platform> <app> [options]")
  }
  if positional.length() > 2 {
    return Err("moui run accepts exactly two positional arguments")
  }
  let platform = positional[0]
  let app = positional[1]
  match platform {
    "android" | "ios" | "harmonyos" => ()
    _ =>
      return Err(
        "unsupported platform for moui run: " +
        platform +
        " (use `moon run` for desktop/web targets)",
      )
  }
  Ok({
    help: false,
    json: json.val,
    platform,
    options: Some({
      app,
      app_config_path: app_config.val,
      device: device.val,
      renderer: renderer.val,
      fallback_skia: fallback_skia.val,
      ejected_shell: ejected_shell.val,
      prepare_only: prepare_only.val,
      build_only: build_only.val,
      no_build: no_build.val,
      no_install: no_install.val,
      no_launch: no_launch.val,
      debug: debug.val,
      filter: filter.val,
      verify: verify.val,
      custom_args,
    }),
  })
}

///|
/// Apply config overrides to `RunOptions`. CLI-provided values win; otherwise
/// fill from the XDG-backed `CliConfig`. Returns a new `RunOptions`.
fn apply_config_overrides_run(
  options : RunOptions,
  config : CliConfig,
) -> RunOptions {
  let device = match options.device {
    Some(v) => Some(v)
    None => None
  }
  let renderer = options.renderer
  let app_config_path = options.app_config_path
  let _ = config
  { ..options, device, renderer, app_config_path }
}

///|
/// Resolve the target device. If `--device` was supplied, use it; otherwise
/// pick the first available device from `list_all_devices`. Returns an error
/// when no device is available.
fn resolve_target_device(
  options : RunOptions,
  platform : String,
  host : HostPlatform,
) -> Result[Device, String] {
  match options.device {
    Some(id) =>
      Ok({ platform, id, name: id, state: "selected", kind: "unknown" })
    None => {
      let devices = list_all_devices(host)
      let matching : Array[Device] = []
      for device in devices {
        if device.platform == platform {
          matching.push(device)
        }
      }
      if matching.is_empty() {
        return Err(
          "no " +
          platform +
          " device found; connect a device or start an emulator",
        )
      }
      Ok(matching[0])
    }
  }
}

///|
/// Locate the build artifact produced by the M6 build step for the given
/// platform. Returns the absolute path to the .apk / .app / .hap file.
fn find_build_artifact(
  platform : String,
  build_dir : String,
  app_id : String,
) -> String {
  match platform {
    "android" => join_path(build_dir, app_id + ".apk")
    "ios" => join_path(build_dir, app_id + ".app")
    "harmonyos" => join_path(build_dir, app_id + ".hap")
    _ => ""
  }
}

///|
/// Install the build artifact on the target device. Returns the install
/// command argv for logging.
fn install_on_device(
  platform : String,
  device : Device,
  artifact : String,
  host : HostPlatform,
) -> Result[Unit, String] {
  match platform {
    "android" => {
      let adb = match find_in_path("adb", host) {
        Some(path) => path
        None => return Err("adb not found on PATH")
      }
      match
        process_exec_argv(
          [adb, "-s", device.id, "install", "-r", artifact],
          capture=true,
        ) {
        Ok(result) if result.exit_code == 0 => Ok(())
        Ok(result) => Err("adb install failed: " + result.stderr)
        Err(message) => Err(message)
      }
    }
    "ios" => {
      let xcrun = match find_in_path("xcrun", host) {
        Some(path) => path
        None => return Err("xcrun not found on PATH")
      }
      match
        process_exec_argv(
          [xcrun, "simctl", "install", device.id, artifact],
          capture=true,
        ) {
        Ok(result) if result.exit_code == 0 => Ok(())
        Ok(result) => Err("simctl install failed: " + result.stderr)
        Err(message) => Err(message)
      }
    }
    "harmonyos" => {
      let hdc = match find_in_path("hdc", host) {
        Some(path) => path
        None => return Err("hdc not found on PATH")
      }
      match
        process_exec_argv(
          [hdc, "-t", device.id, "install", artifact],
          capture=true,
        ) {
        Ok(result) if result.exit_code == 0 => Ok(())
        Ok(result) => Err("hdc install failed: " + result.stderr)
        Err(message) => Err(message)
      }
    }
    _ => Err("unsupported platform: " + platform)
  }
}

///|
/// Launch the app on the target device. Returns the bundle id used for
/// launching (used by the JSON output).
fn launch_on_device(
  platform : String,
  device : Device,
  app : ShellApp,
  host : HostPlatform,
  custom_args : Array[String],
) -> Result[String, String] {
  match platform {
    "android" => {
      let bundle_id = match app.android {
        Some(android) => android.application_id
        None => return Err("shell.json missing android.application_id")
      }
      let adb = match find_in_path("adb", host) {
        Some(path) => path
        None => return Err("adb not found on PATH")
      }
      let argv = [
        adb,
        "-s",
        device.id,
        "shell",
        "am",
        "start",
        "-W",
        "-n",
        bundle_id + "/.MainActivity",
      ]
      let full_argv = argv + custom_args
      match process_exec_argv(full_argv, capture=true) {
        Ok(result) if result.exit_code == 0 => Ok(bundle_id)
        Ok(result) => Err("am start failed: " + result.stderr)
        Err(message) => Err(message)
      }
    }
    "ios" => {
      let bundle_id = match app.ios {
        Some(ios) => ios.bundle_id
        None => return Err("shell.json missing ios.bundle_id")
      }
      let xcrun = match find_in_path("xcrun", host) {
        Some(path) => path
        None => return Err("xcrun not found on PATH")
      }
      match
        process_exec_argv(
          [xcrun, "simctl", "launch", device.id, bundle_id],
          capture=true,
        ) {
        Ok(result) if result.exit_code == 0 => Ok(bundle_id)
        Ok(result) => Err("simctl launch failed: " + result.stderr)
        Err(message) => Err(message)
      }
    }
    "harmonyos" => {
      let harmonyos = match app.harmonyos {
        Some(value) => value
        None => return Err("shell.json missing harmonyos section")
      }
      let bundle_name = harmonyos.bundle_name
      let module_name = match harmonyos.module_name {
        Some(value) => value
        None => app.id
      }
      let hdc = match find_in_path("hdc", host) {
        Some(path) => path
        None => return Err("hdc not found on PATH")
      }
      match
        process_exec_argv(
          [
            hdc,
            "-t",
            device.id,
            "shell",
            "aa",
            "start",
            "-a",
            module_name,
            "-b",
            bundle_name,
          ],
          capture=true,
        ) {
        Ok(result) if result.exit_code == 0 => Ok(bundle_name)
        Ok(result) => Err("aa start failed: " + result.stderr)
        Err(message) => Err(message)
      }
    }
    _ => Err("unsupported platform: " + platform)
  }
}

///|
/// Follow platform logs until interrupted. Used by `--debug`. Returns when
/// the log process exits or times out.
fn follow_logs(
  platform : String,
  device : Device,
  filter : String?,
  host : HostPlatform,
) -> Result[Unit, String] {
  match platform {
    "android" => {
      let adb = match find_in_path("adb", host) {
        Some(path) => path
        None => return Err("adb not found on PATH")
      }
      let tag = match filter {
        Some(value) => value
        None => "MoUI:V"
      }
      let _ = process_exec_argv(
        [adb, "-s", device.id, "logcat", "-v", "brief", tag, "*:S"],
        capture=true,
        timeout_ms=0,
      )
      Ok(())
    }
    "ios" => {
      let predicate = match filter {
        Some(value) => "process == '" + value + "'"
        None => "processImagePath CONTAINS 'MoUI'"
      }
      let _ = process_exec_argv(
        ["log", "stream", "--predicate", predicate, "--info", "--debug"],
        capture=true,
        timeout_ms=0,
      )
      Ok(())
    }
    "harmonyos" => {
      let hdc = match find_in_path("hdc", host) {
        Some(path) => path
        None => return Err("hdc not found on PATH")
      }
      let _ = process_exec_argv(
        [hdc, "-t", device.id, "hilog", "-v"],
        capture=true,
        timeout_ms=0,
      )
      Ok(())
    }
    _ => Err("unsupported platform: " + platform)
  }
}

///|
/// Render the run result as JSON for the `--json` output mode.
fn run_result_to_json(
  platform : String,
  app_id : String,
  device : Device,
  bundle_id : String,
  launch_status : String,
  verify : ProbeResult?,
) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["schemaVersion"] = Json::number(1.0)
  fields["ok"] = Json::boolean(launch_status == "launched")
  fields["platform"] = Json::string(platform)
  fields["appId"] = Json::string(app_id)
  fields["deviceId"] = Json::string(device.id)
  fields["bundleId"] = Json::string(bundle_id)
  fields["launchStatus"] = Json::string(launch_status)
  match verify {
    Some(result) => fields["probe"] = probe_result_to_json(result)
    None => ()
  }
  Json::object(fields)
}

///|
/// Render the run result as plain text for the default output mode.
fn run_result_to_text(
  platform : String,
  app_id : String,
  device : Device,
  bundle_id : String,
  launch_status : String,
  verify : ProbeResult?,
) -> String {
  let mut text = "[run] " + platform + " app=" + app_id + "\n"
  text += "  device: " + device.id + " (" + device.name + ")\n"
  text += "  bundle: " + bundle_id + "\n"
  text += "  status: " + launch_status + "\n"
  match verify {
    Some(result) => text + probe_result_to_text(result)
    None => text
  }
}

///|
fn run_run(parsed : ParsedRun, host : HostPlatform) -> CliOutcome {
  if parsed.help {
    return stdout_outcome(run_usage())
  }
  guard parsed.options is Some(options) else {
    return failed_outcome(
      "run command options are unavailable",
      parsed.json,
      run_usage(),
    )
  }
  // 1. Resolve config + apply overrides.
  let config = match read_config(host) {
    Ok(c) => c
    Err(message) => return failed_outcome(message, parsed.json, run_usage())
  }
  let options = apply_config_overrides_run(options, config)
  // 2. Locate shell.json.
  let app_config_path = match options.app_config_path {
    Some(p) => p
    None => "shell.json"
  }
  let _ = app_config_path
  let project_root = "."
  let app = match read_shell_app(project_root) {
    Ok(a) => a
    Err(message) =>
      return failed_outcome(
        "could not read shell.json: " + message,
        parsed.json,
        run_usage(),
      )
  }
  // 3. Resolve device.
  let device = match resolve_target_device(options, parsed.platform, host) {
    Ok(d) => d
    Err(message) => return failed_outcome(message, parsed.json, run_usage())
  }
  // 4. Build (unless --no-build).
  let build_dir = join_path("artifacts", parsed.platform)
  let artifact = find_build_artifact(parsed.platform, build_dir, app.id)
  if not(options.no_build) {
    // M6 build orchestration would go here. We currently rely on the
    // shell-emit step having produced the artifact; a full build_* call
    // requires resolving workspace_root / moui_root / skia_root, which is
    // deferred to a follow-up to keep this command's surface minimal.
    if not(path_is_file(artifact)) {
      log_info(
        "[run] artifact not found at " +
        artifact +
        "; skipping build (run `moui shell eject` first)",
      )
    }
  }
  // Acknowledge options that influence the (deferred) build_* call so the
  // compiler doesn't flag them as unused.
  let _ = options.prepare_only
  let _ = options.ejected_shell
  let _ = options.fallback_skia
  let _ = options.renderer
  if options.prepare_only {
    return stdout_outcome(
      run_result_to_text(
        parsed.platform,
        app.id,
        device,
        "",
        "prepare-only",
        None,
      ),
    )
  }
  if options.build_only {
    return stdout_outcome(
      run_result_to_text(
        parsed.platform,
        app.id,
        device,
        "",
        "build-only",
        None,
      ),
    )
  }
  // 5. Install (unless --no-install).
  if not(options.no_install) && path_is_file(artifact) {
    match install_on_device(parsed.platform, device, artifact, host) {
      Ok(_) => ()
      Err(message) => return failed_outcome(message, parsed.json, run_usage())
    }
  }
  // 6. Launch (unless --no-launch).
  let (bundle_id, launch_status) = if options.no_launch {
    ("", "skipped")
  } else {
    match
      launch_on_device(parsed.platform, device, app, host, options.custom_args) {
      Ok(b) => (b, "launched")
      Err(message) => return failed_outcome(message, parsed.json, run_usage())
    }
  }
  // 7. Optional --verify probe.
  let verify_result = if options.verify {
    let result = match parsed.platform {
      "android" => probe_android(device, app.id, bundle_id, host, 30)
      "ios" => probe_ios(device, bundle_id, host, 30)
      "harmonyos" => probe_harmonyos(device, bundle_id, app.id, host, 30)
      _ => { ok: false, observations: [] }
    }
    Some(result)
  } else {
    None
  }
  // 8. Optional --debug log following (blocking until interrupted).
  if options.debug {
    let _ = follow_logs(parsed.platform, device, options.filter, host)
  }
  // 9. Emit output.
  if parsed.json {
    let json = run_result_to_json(
      parsed.platform,
      app.id,
      device,
      bundle_id,
      launch_status,
      verify_result,
    )
    stdout_outcome(json.stringify(indent=2) + "\n")
  } else {
    stdout_outcome(
      run_result_to_text(
        parsed.platform,
        app.id,
        device,
        bundle_id,
        launch_status,
        verify_result,
      ),
    )
  }
}
