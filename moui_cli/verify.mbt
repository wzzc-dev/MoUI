// `moui verify` command — verify window-hosted mobile app runtime evidence.
// It generates the canonical `verify-manifest.json`.

///|
priv struct ParsedVerify {
  help : Bool
  json : Bool
  platform : String
  options : VerifyOptions?
}

///|
priv struct VerifyOptions {
  app : String
  device : String?
  build_dir : String?
  output_path : String?
  require_passed : Bool
  observation_filter : String?
}

///|
/// Canonical producer of `verify-manifest.json`.
let verify_manifest_generated_by_canonical : String = "moui_cli"

///|
fn verify_usage() -> String {
  (
    #|Usage: moui verify <platform> <app> [options]
    #|
    #|Verify mobile app runtime evidence for the window-hosted path.
    #|Build artifacts must exist under artifacts/<platform>/<app>/ and the
    #|device must be connected. The command writes `verify-manifest.json`.
    #|
    #|Arguments:
    #|  platform     Target platform: android, ios, or harmonyos.
    #|  app          Application id (matches moui.mobile.json `id`).
    #|
    #|Options:
    #|  --device ID             Target device id. Defaults to the first device.
    #|  --build-dir PATH        Build artifact directory. Defaults to
    #|                          `artifacts/<platform>`.
    #|  --output PATH           Manifest output path. Defaults to
    #|                          `artifacts/<platform>/<app>/verify-manifest.json`.
    #|  --require-passed        Exit non-zero when any observation fails.
    #|  --filter FILTER         Logcat/hilog/oslog filter expression.
    #|  --json                  Emit machine-readable output.
    #|  -h, --help              Show this help.
  )
}

///|
fn parse_verify_args(
  args : Array[String],
  cwd : String,
  host : HostPlatform,
) -> Result[ParsedVerify, String] {
  let _ = cwd
  let _ = host
  let help = Ref(false)
  let json = Ref(false)
  let positional : Array[String] = []
  let device : Ref[String?] = Ref(None)
  let build_dir : Ref[String?] = Ref(None)
  let output_path : Ref[String?] = Ref(None)
  let require_passed = Ref(false)
  let filter : Ref[String?] = Ref(None)
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
      "--require-passed" =>
        match flag_without_value(inline, name) {
          Ok(_) => require_passed.val = true
          Err(message) => return Err(message)
        }
      "--device" | "--build-dir" | "--output" | "--filter" =>
        match option_value(args, index, inline, name) {
          Ok((value, next)) => {
            match name {
              "--device" => device.val = Some(value)
              "--build-dir" => build_dir.val = Some(value)
              "--output" => output_path.val = Some(value)
              "--filter" => filter.val = Some(value)
              _ => ()
            }
            index = next
            continue
          }
          Err(message) => return Err(message)
        }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui verify: " + name)
      _ => positional.push(argument)
    }
    index += 1
  }
  if help.val {
    return Ok({ help: true, json: json.val, platform: "", options: None })
  }
  if positional.length() != 2 {
    return Err("usage: moui verify <platform> <app> [options]")
  }
  let platform = positional[0]
  let app = positional[1]
  match platform {
    "android" | "ios" | "harmonyos" => ()
    _ => return Err("unsupported platform for moui verify: " + platform)
  }
  Ok({
    help: false,
    json: json.val,
    platform,
    options: Some({
      app,
      device: device.val,
      build_dir: build_dir.val,
      output_path: output_path.val,
      require_passed: require_passed.val,
      observation_filter: filter.val,
    }),
  })
}

///|
/// Locate the build artifact for the given platform/app. Mirrors the
/// `find_build_artifact` layout used by `moui run`.
fn find_verify_artifact(
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
/// Render the canonical window-hosted verify manifest as JSON.
fn verify_manifest_to_json(
  platform : String,
  app_id : String,
  artifact : String,
  status : String,
  probe : ProbeResult,
) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["schemaVersion"] = Json::number(1.0)
  fields["mode"] = Json::string("window-hosted-runtime-verify")
  fields["generatedBy"] = Json::string(verify_manifest_generated_by_canonical)
  fields["platform"] = Json::string(platform)
  fields["app"] = Json::string(app_id)
  fields["status"] = Json::string(status)
  let build_fields : Map[String, Json] = Map([])
  build_fields["fallbackSkia"] = Json::boolean(false)
  build_fields["artifact"] = Json::string(artifact)
  build_fields["command"] = Json::string(
    "moui_cli verify " + platform + " " + app_id,
  )
  fields["build"] = Json::object(build_fields)
  // Observations map directly from the probe result.
  let observations : Array[Json] = []
  for obs in probe.observations {
    let obs_fields : Map[String, Json] = Map([])
    obs_fields["kind"] = Json::string(obs.kind)
    obs_fields["name"] = Json::string(obs.name)
    obs_fields["value"] = Json::string(obs.value)
    obs_fields["passed"] = Json::boolean(obs.passed)
    observations.push(Json::object(obs_fields))
  }
  fields["observations"] = Json::array(observations)
  fields["evidenceBoundary"] = Json::string(
    "non-fallback matching-host smoke evidence; fallback builds are packaging only",
  )
  Json::object(fields)
}

///|
/// Check whether a `generatedBy` value is the canonical producer.
fn is_accepted_generated_by(value : String) -> Bool {
  value == verify_manifest_generated_by_canonical
}

///|
/// Compute the verify status from the probe result. `"passed"` when all
/// observations pass, `"failed"` otherwise.
fn verify_status_from_probe(probe : ProbeResult) -> String {
  if probe.ok {
    "passed"
  } else {
    "failed"
  }
}

///|
/// Write the verify manifest JSON to disk atomically.
fn write_verify_manifest(
  path : String,
  manifest : Json,
) -> Result[Unit, String] {
  let dir = parent_dir(path)
  if dir != "" && dir != "." {
    match mkdir_p(dir) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  let text = manifest.stringify(indent=2) + "\n"
  let bytes = @utf8.encode(text[:], bom=false)
  replace_file_atomic(path, bytes)
}

///|
/// Resolve the target device for verification. If `--device` was supplied,
/// use it; otherwise pick the first available device for the platform.
fn resolve_verify_device(
  options : VerifyOptions,
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
fn run_verify(parsed : ParsedVerify, host : HostPlatform) -> CliOutcome {
  if parsed.help {
    return stdout_outcome(verify_usage())
  }
  guard parsed.options is Some(options) else {
    return failed_outcome(
      "verify command options are unavailable",
      parsed.json,
      verify_usage(),
    )
  }
  // 1. Read mobile metadata for the app.
  let app = match read_mobile_app(".") {
    Ok(a) => a
    Err(message) =>
      return failed_outcome(
        "could not read moui.mobile.json: " + message,
        parsed.json,
        verify_usage(),
      )
  }
  // 2. Locate build artifacts.
  let build_dir = match options.build_dir {
    Some(d) => d
    None => join_path("artifacts", parsed.platform)
  }
  let artifact = find_verify_artifact(parsed.platform, build_dir, app.id)
  if !path_is_file(artifact) {
    return failed_outcome(
      "build artifact not found: " + artifact + "; run `moui run` first",
      parsed.json,
      verify_usage(),
    )
  }
  // 3. Resolve device.
  let device = match resolve_verify_device(options, parsed.platform, host) {
    Ok(d) => d
    Err(message) => return failed_outcome(message, parsed.json, verify_usage())
  }
  // 4. Run the probe.
  let probe = match parsed.platform {
    "android" => probe_android(device, app.id, app.id, host, 30)
    "ios" => probe_ios(device, app.id, host, 30)
    "harmonyos" => probe_harmonyos(device, app.id, app.id, host, 30)
    _ => { ok: false, observations: [] }
  }
  let status = verify_status_from_probe(probe)
  // 5. Write the manifest.
  let manifest = verify_manifest_to_json(
    parsed.platform,
    app.id,
    artifact,
    status,
    probe,
  )
  let manifest_path = match options.output_path {
    Some(p) => p
    None =>
      join_path(
        join_path(join_path("artifacts", parsed.platform), app.id),
        "verify-manifest.json",
      )
  }
  match write_verify_manifest(manifest_path, manifest) {
    Ok(_) => ()
    Err(message) => return failed_outcome(message, parsed.json, verify_usage())
  }
  // 6. Exit non-zero when --require-passed and probe failed.
  let exit_code = if options.require_passed && !probe.ok { 1 } else { 0 }
  // 7. Emit output.
  if parsed.json {
    let output : Json = {
      "schemaVersion": 1,
      "ok": probe.ok,
      "platform": Json::string(parsed.platform),
      "app": Json::string(app.id),
      "status": Json::string(status),
      "manifest": Json::string(manifest_path),
      "probe": probe_result_to_json(probe),
    }
    { exit_code, stdout: output.stringify(indent=2) + "\n", stderr: "" }
  } else {
    let mut text = "[verify] " + parsed.platform + " app=" + app.id + "\n"
    text += "  status: " + status + "\n"
    text += "  manifest: " + manifest_path + "\n"
    text += probe_result_to_text(probe)
    { exit_code, stdout: text, stderr: "" }
  }
}
