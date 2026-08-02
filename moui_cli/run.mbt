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
  app_config_path : String?
  device : String?
  renderer : String?
  fallback_skia : Bool
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
    #|  app          Application id (matches moui.mobile.json `id`).
    #|
    #|Options:
    #|  --mobile-config PATH    Path to moui.mobile.json. Defaults to ./moui.mobile.json.
    #|  --device ID             Target device id. Defaults to the first device.
    #|  --renderer NAME         Renderer override (auto / skia / wgpu).
    #|  --fallback-skia        Allow Skia fallback when primary renderer fails.
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
      "--mobile-config" | "--device" | "--renderer" | "--filter" =>
        match option_value(args, index, inline, name) {
          Ok((value, next)) => {
            match name {
              "--mobile-config" => app_config.val = Some(value)
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
      app_config_path: app_config.val,
      device: device.val,
      renderer: renderer.val,
      fallback_skia: fallback_skia.val,
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
/// Convert `RunOptions` (from `moui run`) into `BuildCommandOptions` so
/// `moui run`'s build step shares the same pipeline as `moui build`. Most
/// platform-specific overrides stay `None` — they default inside
/// `build_*_options_from_command` from `CliConfig`. `workspace_root` mirrors
/// `parse_build_args`'s `cwd` default — it MUST be the actual cwd (absolute),
/// not `"."`, because `mobile_entrypoint_package` calls `path_relative_to`
/// which only succeeds when `workspace_root` is the absolute prefix of the
/// resolved entrypoint path. With `"."` the relative resolution fails and
/// `entrypoint_package` falls back to an absolute path, which then causes
/// `moonbit_c_path` to drop the `build_dir` prefix and look for the
/// generated C at `<workspace_root>/<entrypoint_package>/<generated_c>`.
///
/// `sdk_override` lets `moui run` inject the iOS SDK (`iphonesimulator` vs
/// `iphoneos`) based on the resolved target device. Without this, the
/// `build_command.mbt` default (`iphoneos`) is used even when targeting the
/// simulator, which causes `build_ios_core` to skip ad-hoc signing and the
/// bundle fails to launch on the simulator with `SBMainWorkspace` denial.
fn build_options_from_run_options(
  options : RunOptions,
  cwd : String,
  sdk_override : String?,
) -> BuildCommandOptions {
  {
    app_config_path: options.app_config_path,
    workspace_root: cwd,
    moui_root: "",
    skia_root: "",
    build_dir: "",
    output: None,
    renderer: options.renderer,
    fallback_skia: options.fallback_skia,
    prepare_only: options.prepare_only,
    product_name: None,
    abi: None,
    compile_sdk: None,
    target_sdk: None,
    sdk: sdk_override,
    arch: None,
    deployment_target: None,
    sdk_home: None,
    hvigorw: None,
    ohpm: None,
    signing_config_file: None,
  }
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
/// Detect whether an iOS device id corresponds to a simulator. iOS simulator
/// UDIDs are UUIDs in the `8-4-4-4-12` hex format (e.g.
/// `33E45CC1-A8C6-4245-B820-CAFBC9AB6E5C`); physical device UDIDs are 25 or
/// 40 hex chars without dashes. Used by `moui run` to auto-select
/// `iphonesimulator` vs `iphoneos` when the user did not pass `--sdk` or set
/// `moui config ios.sdk`. Returns `true` iff the id contains at least one
/// `-`, contains at least one hex char, and matches the UUID character class.
fn is_ios_simulator_udid(id : String) -> Bool {
  if !id.contains("-") {
    return false
  }
  let mut has_hex = false
  for ch in id {
    if is_hex_char(ch) {
      has_hex = true
    } else if ch != '-' {
      return false
    }
  }
  has_hex
}

///|
/// Returns `true` iff `ch` is `[0-9a-fA-F]`. MoonBit's `Char` does not expose
/// `is_hex_digit`, so this is the inline equivalent.
fn is_hex_char(ch : Char) -> Bool {
  (ch >= '0' && ch <= '9') ||
  (ch >= 'a' && ch <= 'f') ||
  (ch >= 'A' && ch <= 'F')
}

///|
/// Resolve the iOS SDK to use for `moui run`. When the target device is a
/// simulator (UUID-format UDID), return `iphonesimulator`. Otherwise return
/// `None` so `build_command.mbt` falls back to its default (`iphoneos`) or
/// the user's `moui config ios.sdk` setting. Returns `None` for non-iOS
/// platforms so `build_options_from_run_options` doesn't override anything.
fn resolve_ios_sdk_override(platform : String, device : Device) -> String? {
  if platform == "ios" && is_ios_simulator_udid(device.id) {
    Some("iphonesimulator")
  } else {
    None
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
        Ok(result) if result.exit_code == 0 &&
          !result.stdout.to_lower().contains("error") &&
          !result.stderr.to_lower().contains("error") &&
          !result.stdout.to_lower().contains("failed") &&
          !result.stderr.to_lower().contains("failed") => Ok(())
        Ok(result) => {
          let detail = if result.stderr != "" {
            result.stderr
          } else {
            result.stdout
          }
          Err("hdc install failed: " + detail)
        }
        Err(message) => Err(message)
      }
    }
    _ => Err("unsupported platform: " + platform)
  }
}

///|

///|
/// Launch an installed iOS app on a simulator via `xcrun simctl launch`.
fn ios_simctl_launch(
  xcrun : String,
  device_id : String,
  bundle_id : String,
  custom_args : Array[String],
) -> Result[Unit, String] {
  let argv = [xcrun, "simctl", "launch", device_id, bundle_id] + custom_args
  match process_exec_argv(argv, capture=true) {
    Ok(result) if result.exit_code == 0 => Ok(())
    Ok(result) => {
      let detail = if result.stderr != "" {
        result.stderr
      } else {
        result.stdout
      }
      Err("simctl launch failed: " + detail)
    }
    Err(message) => Err(message)
  }
}

///|
let android_window_hosted_activity = "dev.wzzc.window.template.HostedActivity"

///|
/// Launch the app on the target device. Returns the bundle id used for
/// launching (used by the JSON output).
fn launch_on_device(
  platform : String,
  device : Device,
  app : MobileApp,
  host : HostPlatform,
  custom_args : Array[String],
) -> Result[String, String] {
  match platform {
    "android" => {
      let bundle_id = match app.android {
        Some(android) => android.application_id
        None => return Err("moui.mobile.json missing android.applicationId")
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
        bundle_id + "/" + android_window_hosted_activity,
      ]
      let full_argv = argv + custom_args
      match process_exec_argv(full_argv, capture=true) {
        Ok(result) if result.exit_code == 0 &&
          !result.stdout.to_lower().contains("error") &&
          !result.stderr.to_lower().contains("error") => Ok(bundle_id)
        Ok(result) => {
          let detail = if result.stderr != "" {
            result.stderr
          } else {
            result.stdout
          }
          Err("am start failed: " + detail)
        }
        Err(message) => Err(message)
      }
    }
    "ios" => {
      let bundle_id = match app.ios {
        Some(ios) => ios.bundle_id
        None => return Err("moui.mobile.json missing ios.bundleId")
      }
      let xcrun = match find_in_path("xcrun", host) {
        Some(path) => path
        None => return Err("xcrun not found on PATH")
      }
      // Best-effort: stop a previous instance so install/launch is not racing
      // an already-running process after reinstall.
      let _ = process_exec_argv(
        [xcrun, "simctl", "terminate", device.id, bundle_id],
        capture=true,
      )
      match ios_simctl_launch(xcrun, device.id, bundle_id, custom_args) {
        Ok(_) => Ok(bundle_id)
        Err(_) => {
          // SpringBoard sometimes needs a beat after `simctl install` before
          // the new bundle is registered. Retry once.
          let _ = process_exec_argv(["/bin/sleep", "1"], capture=true)
          match ios_simctl_launch(xcrun, device.id, bundle_id, custom_args) {
            Ok(_) => Ok(bundle_id)
            Err(second) => Err(second)
          }
        }
      }
    }
    "harmonyos" => {
      let harmonyos = match app.harmonyos {
        Some(value) => value
        None => return Err("moui.mobile.json missing harmonyos section")
      }
      let bundle_name = harmonyos.bundle_name
      // Module name is the HAP module id (default "entry"); ability name is
      // always EntryAbility in the managed template's mainElement.
      let module_name = match harmonyos.module_name {
        Some(value) => value
        None => "entry"
      }
      let ability_name = "EntryAbility"
      let hdc = match find_in_path("hdc", host) {
        Some(path) => path
        None => return Err("hdc not found on PATH")
      }
      // Best-effort stop any previous instance so reinstall/launch is clean.
      let _ = process_exec_argv(
        [hdc, "-t", device.id, "shell", "aa", "force-stop", bundle_name],
        capture=true,
      )
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
            ability_name,
            "-b",
            bundle_name,
            "-m",
            module_name,
          ],
          capture=true,
        ) {
        Ok(result) if result.exit_code == 0 &&
          !result.stdout.to_lower().contains("error") &&
          !result.stderr.to_lower().contains("error") => Ok(bundle_name)
        Ok(result) => {
          let detail = if result.stderr != "" {
            result.stderr
          } else {
            result.stdout
          }
          Err("aa start failed: " + detail)
        }
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
fn run_run(parsed : ParsedRun, cwd : String, host : HostPlatform) -> CliOutcome {
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
  // 2. Locate the mobile configuration from the supplied path or cwd.
  let app_result = match options.app_config_path {
    Some(path) => read_mobile_app_at(path)
    None => read_mobile_app(cwd)
  }
  let app = match app_result {
    Ok(a) => a
    Err(message) =>
      return failed_outcome(
        "could not read moui.mobile.json: " + message,
        parsed.json,
        run_usage(),
      )
  }
  // 3. Resolve device.
  let device = match resolve_target_device(options, parsed.platform, host) {
    Ok(d) => d
    Err(message) => return failed_outcome(message, parsed.json, run_usage())
  }
  // 4. Build (unless --no-build). Shares the same `build_*` pipeline as
  // `moui build` so defaults stay in sync.
  let predicted_artifact = find_build_artifact(
    parsed.platform,
    default_build_dir(parsed.platform, cwd),
    app.id,
  )
  let artifact = if options.no_build {
    predicted_artifact
  } else {
    let sdk_override = resolve_ios_sdk_override(parsed.platform, device)
    let build_options = build_options_from_run_options(
      options, cwd, sdk_override,
    )
    match
      run_build_internal(build_options, parsed.platform, host, app, config) {
      Ok(result) => {
        log_info("[run] build succeeded: " + result.output_artifact)
        if result.output_artifact != "" {
          result.output_artifact
        } else {
          predicted_artifact
        }
      }
      Err(message) =>
        return failed_outcome(
          "build failed: " + message,
          parsed.json,
          run_usage(),
        )
    }
  }
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
  // iOS bundles are directories (`*.app`); Android APKs / HarmonyOS HAPs are
  // files. Using only `path_is_file` silently skips iOS install and then
  // `simctl launch` fails with FBSOpenApplicationServiceErrorDomain code=4.
  if !options.no_install && (path_is_file(artifact) || path_is_dir(artifact)) {
    match install_on_device(parsed.platform, device, artifact, host) {
      Ok(_) => ()
      Err(message) => return failed_outcome(message, parsed.json, run_usage())
    }
  } else if !options.no_install {
    return failed_outcome(
      "build artifact not found for install: " + artifact,
      parsed.json,
      run_usage(),
    )
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
      "harmonyos" => {
        let module_name = match app.harmonyos {
          Some(h) =>
            match h.module_name {
              Some(value) => value
              None => "entry"
            }
          None => "entry"
        }
        probe_harmonyos(device, bundle_id, module_name, host, 30)
      }
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
