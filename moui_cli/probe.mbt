// `moui verify` runtime probe — launches the app on a device and parses
// logcat / hilog / oslog output for known MoUI mobile-host markers. The 27
// observations span
// five categories: lifecycle, service, platformView, hostChannel, stability.

///|
priv struct Observation {
  kind : String // lifecycle | service | platformView | hostChannel | stability
  name : String
  value : String
  passed : Bool
}

///|
priv struct ProbeResult {
  ok : Bool
  observations : Array[Observation]
}

///|
/// The canonical set of 27 observation names emitted by MoUI mobile-host
/// probes. Log lines look like `[MOUI_PROBE] <kind>:<name>=<value>` where
/// `value` is `ok` or `fail`.
let probe_observation_names : ReadOnlyArray[String] = [
  // lifecycle (8)
  "lifecycle:app_start", "lifecycle:app_resume", "lifecycle:app_pause", "lifecycle:app_destroy",
  "lifecycle:scene_create", "lifecycle:scene_destroy", "lifecycle:scene_attach",
  "lifecycle:scene_detach",
  // service (5)
   "service:clipboard_get", "service:clipboard_set", "service:text_input_show", "service:text_input_hide",
  "service:accessibility_request",
  // platformView (3)
   "platformView:create", "platformView:destroy", "platformView:touch",
  // hostChannel (3)
   "hostChannel:request", "hostChannel:response", "hostChannel:complete",
  // stability (8)
   "stability:crash_free", "stability:anr_free", "stability:frame_rendered", "stability:first_frame",
  "stability:resize_handled", "stability:pointer_routed", "stability:scroll_routed",
  "stability:lifecycle_no_assert",
]

///|
/// Parse a single log line into an `Observation`. Returns `None` when the
/// line is not a MoUI probe marker.
fn parse_log_line(line : String) -> Observation? {
  let trimmed = line.trim().to_owned()
  let marker = "[MOUI_PROBE] "
  match trimmed.find(marker) {
    Some(start) => {
      let rest = trimmed[start + marker.length():].to_owned()
      // rest looks like `kind:name=value` (may have leading/trailing whitespace
      // when the source log has extra spaces around the marker).
      match rest.split_once("=") {
        Some((key, value)) => {
          let key_trimmed = key.trim().to_owned()
          match key_trimmed.split_once(":") {
            Some((kind, name)) => {
              let kind_str = kind.trim().to_owned()
              let name_str = name.trim().to_owned()
              if is_known_observation(kind_str + ":" + name_str) {
                let value_str = value.trim().to_owned()
                let passed = value_str == "ok"
                Some({
                  kind: kind_str,
                  name: name_str,
                  value: value_str,
                  passed,
                })
              } else {
                None
              }
            }
            None => None
          }
        }
        None => None
      }
    }
    None => None
  }
}

///|
fn is_known_observation(key : String) -> Bool {
  for name in probe_observation_names {
    if name == key {
      return true
    }
  }
  false
}

///|
/// Parse multi-line logcat output into a list of `Observation` records.
/// Lines without the `[MOUI_PROBE]` marker are ignored. When the same
/// observation name appears multiple times, the LAST occurrence wins.
fn parse_logcat_observations(output : String) -> Array[Observation] {
  dedupe_observations(parse_log_lines(output))
}

///|
/// Parse multi-line hilog output. Same marker format as logcat.
fn parse_hilog_observations(output : String) -> Array[Observation] {
  dedupe_observations(parse_log_lines(output))
}

///|
/// Parse multi-line oslog output. Same marker format as logcat.
fn parse_oslog_observations(output : String) -> Array[Observation] {
  dedupe_observations(parse_log_lines(output))
}

///|
fn parse_log_lines(output : String) -> Array[Observation] {
  let observations : Array[Observation] = []
  let lines = output.split("\n").to_array()
  for line in lines {
    match parse_log_line(line.to_owned()) {
      Some(obs) => observations.push(obs)
      None => ()
    }
  }
  observations
}

///|
/// Deduplicate observations by `kind:name`, keeping the last occurrence.
/// The mobile host emits each marker at most once per session, but log
/// buffers may rotate and replay fragments; dedupe keeps the final verdict.
fn dedupe_observations(observations : Array[Observation]) -> Array[Observation] {
  let result : Array[Observation] = []
  let seen : Map[String, Int] = Map([])
  for obs in observations {
    let key = obs.kind + ":" + obs.name
    match seen.get(key) {
      Some(index) => result[index] = obs
      None => {
        seen[key] = result.length()
        result.push(obs)
      }
    }
  }
  result
}

///|
/// Build a `ProbeResult` from the parsed observations. `ok` is true iff every
/// known observation name is present and `passed`.
fn build_probe_result(observations : Array[Observation]) -> ProbeResult {
  let by_key : Map[String, Observation] = Map([])
  for obs in observations {
    by_key[obs.kind + ":" + obs.name] = obs
  }
  let mut ok = true
  let final_obs : Array[Observation] = []
  for name in probe_observation_names {
    match by_key.get(name) {
      Some(obs) => {
        final_obs.push(obs)
        if !obs.passed {
          ok = false
        }
      }
      None => {
        // Missing observation -> fail with empty value.
        match name.split_once(":") {
          Some((kind, n)) =>
            final_obs.push({
              kind: kind.to_owned(),
              name: n.to_owned(),
              value: "",
              passed: false,
            })
          None => ()
        }
        ok = false
      }
    }
  }
  { ok, observations: final_obs }
}

///|
/// Probe an Android device by launching the app and capturing logcat for
/// `timeout_seconds`. The caller is responsible for ensuring `adb` is on
/// PATH and the device is connected.
fn probe_android(
  device : Device,
  app_id : String,
  bundle_id : String,
  host : HostPlatform,
  timeout_seconds : Int,
) -> ProbeResult {
  let _ = host
  let _ = timeout_seconds
  let adb = match find_in_path("adb", detect_host_platform()) {
    Some(path) => path
    None =>
      return {
        ok: false,
        observations: [
          {
            kind: "stability",
            name: "crash_free",
            value: "adb-not-found",
            passed: false,
          },
        ],
      }
  }
  // Launch the app via `am start`.
  let launch_argv = [
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
  match process_exec_argv(launch_argv, capture=true) {
    Ok(result) if result.exit_code == 0 => ()
    _ =>
      return {
        ok: false,
        observations: [
          {
            kind: "lifecycle",
            name: "app_start",
            value: "launch-failed",
            passed: false,
          },
        ],
      }
  }
  let _ = app_id
  // Capture logcat for the timeout window.
  let logcat_argv = [
    adb,
    "-s",
    device.id,
    "logcat",
    "-d",
    "-v",
    "brief",
    "MoUI:V",
    "*:S",
  ]
  let stdout = match process_exec_argv(logcat_argv, capture=true) {
    Ok(result) => result.stdout
    Err(_) => ""
  }
  // Clear logcat after capture so subsequent probes start fresh.
  match
    process_exec_argv([adb, "-s", device.id, "logcat", "-c"], capture=true) {
    _ => ()
  }
  let observations = parse_logcat_observations(stdout)
  build_probe_result(observations)
}

///|
/// Probe an iOS simulator by launching the app and capturing oslog.
fn probe_ios(
  device : Device,
  bundle_id : String,
  host : HostPlatform,
  timeout_seconds : Int,
) -> ProbeResult {
  match host {
    Macos => ()
    _ =>
      return {
        ok: false,
        observations: [
          {
            kind: "stability",
            name: "crash_free",
            value: "requires-macos",
            passed: false,
          },
        ],
      }
  }
  let xcrun = match find_in_path("xcrun", host) {
    Some(path) => path
    None =>
      return {
        ok: false,
        observations: [
          {
            kind: "stability",
            name: "crash_free",
            value: "xcrun-not-found",
            passed: false,
          },
        ],
      }
  }
  let _ = timeout_seconds
  // Launch the app on the simulator.
  match
    process_exec_argv(
      [xcrun, "simctl", "launch", device.id, bundle_id],
      capture=true,
    ) {
    Ok(result) if result.exit_code == 0 => ()
    _ =>
      return {
        ok: false,
        observations: [
          {
            kind: "lifecycle",
            name: "app_start",
            value: "launch-failed",
            passed: false,
          },
        ],
      }
  }
  // Spawn log show for the last 30s of system logs.
  let log_argv = [
    "log",
    "show",
    "--last",
    "30s",
    "--predicate",
    "process == '" + bundle_id + "'",
    "--info",
    "--debug",
  ]
  let stdout = match process_exec_argv(log_argv, capture=true) {
    Ok(result) => result.stdout
    Err(_) => ""
  }
  let observations = parse_oslog_observations(stdout)
  build_probe_result(observations)
}

///|
/// Probe a HarmonyOS device by launching the app and capturing hilog.
fn probe_harmonyos(
  device : Device,
  bundle_name : String,
  module_name : String,
  host : HostPlatform,
  timeout_seconds : Int,
) -> ProbeResult {
  let _ = host
  let _ = timeout_seconds
  let hdc = match find_in_path("hdc", detect_host_platform()) {
    Some(path) => path
    None =>
      return {
        ok: false,
        observations: [
          {
            kind: "stability",
            name: "crash_free",
            value: "hdc-not-found",
            passed: false,
          },
        ],
      }
  }
  // Launch the app via `aa start`. Ability is EntryAbility; module_name is
  // the HAP module id (typically "entry").
  let launch_argv = [
    hdc,
    "-t",
    device.id,
    "shell",
    "aa",
    "start",
    "-a",
    "EntryAbility",
    "-b",
    bundle_name,
    "-m",
    module_name,
  ]
  match process_exec_argv(launch_argv, capture=true) {
    Ok(result) if result.exit_code == 0 &&
      !result.stdout.to_lower().contains("error") &&
      !result.stderr.to_lower().contains("error") => ()
    _ =>
      return {
        ok: false,
        observations: [
          {
            kind: "lifecycle",
            name: "app_start",
            value: "launch-failed",
            passed: false,
          },
        ],
      }
  }
  // Capture hilog for the last 30s.
  let hilog_argv = [
    hdc,
    "-t",
    device.id,
    "hilog",
    "-T",
    "0x" + bundle_name.length().to_string(),
    "-v",
  ]
  let stdout = match process_exec_argv(hilog_argv, capture=true) {
    Ok(result) => result.stdout
    Err(_) => ""
  }
  let observations = parse_hilog_observations(stdout)
  build_probe_result(observations)
}

///|
/// Render a `ProbeResult` as JSON for the `--json` output mode.
fn probe_result_to_json(result : ProbeResult) -> Json {
  let entries : Array[Json] = []
  for obs in result.observations {
    entries.push({
      "kind": Json::string(obs.kind),
      "name": Json::string(obs.name),
      "value": Json::string(obs.value),
      "passed": Json::boolean(obs.passed),
    })
  }
  {
    "schemaVersion": 1,
    "ok": Json::boolean(result.ok),
    "observations": Json::array(entries),
  }
}

///|
/// Render a `ProbeResult` as tab-separated text for the default output mode.
fn probe_result_to_text(result : ProbeResult) -> String {
  let mut text = if result.ok {
    "[probe] all observations passed\n"
  } else {
    "[probe] one or more observations failed\n"
  }
  for obs in result.observations {
    let status = if obs.passed { "ok" } else { "FAIL" }
    text += status + "\t" + obs.kind + ":" + obs.name + "\t" + obs.value + "\n"
  }
  text
}
