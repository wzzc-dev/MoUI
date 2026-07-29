// `moui devices` command — list connected Android / iOS / HarmonyOS devices.
//
// On each platform we look up the canonical tool (`adb`, `xcrun`, `hdc`) on
// PATH, run it with `process_exec_argv`, and parse the well-known output into
// a unified `Device` struct. `list_all_devices` skips platforms whose tool is
// not installed (no error), so `moui devices` is always safe to invoke.

///|
priv struct Device {
  platform : String
  id : String
  name : String
  state : String
  kind : String // emulator | physical | unknown
} derive(Debug, Eq)

///|
priv struct ParsedDevices {
  help : Bool
  json : Bool
  platform : String?
}

///|
fn devices_usage() -> String {
  (
    #|Usage: moui devices [options]
    #|
    #|Lists connected Android, iOS, and HarmonyOS devices/emulators. Platforms
    #|without their tooling installed (adb / xcrun / hdc) are silently skipped.
    #|
    #|Options:
    #|  --platform PLATFORM    Only list devices for the given platform.
    #|                         Values: android, ios, harmonyos.
    #|  --json                 Emit machine-readable output.
    #|  -h, --help             Show this help.
  )
}

///|
fn parse_devices_args(args : Array[String]) -> Result[ParsedDevices, String] {
  let help = Ref(false)
  let json = Ref(false)
  let platform : Ref[String?] = Ref(None)
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
      "--platform" =>
        match option_value(args, index, inline, name) {
          Ok((value, next)) => {
            platform.val = Some(value)
            index = next
          }
          Err(message) => return Err(message)
        }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui devices: " + name)
      _ => return Err("moui devices does not take positional arguments")
    }
    index += 1
  }
  match platform.val {
    Some(value) =>
      if value != "android" && value != "ios" && value != "harmonyos" {
        Err("unsupported --platform for moui devices: " + value)
      } else {
        Ok({ help: help.val, json: json.val, platform: Some(value) })
      }
    None => Ok({ help: help.val, json: json.val, platform: None })
  }
}

///|
/// Parse `adb devices -l` output into a list of `Device` records.
/// Each line after the `List of devices attached` header is parsed as:
///   `<serial>  <state>  key:value key:value ...`
/// Only lines with at least two whitespace-separated tokens are considered.
/// `kind` is detected from `transport_id` presence or device name heuristics.
fn parse_adb_devices(output : String) -> Array[Device] {
  let devices : Array[Device] = []
  let lines = output.split("\n").to_array()
  let mut in_devices = false
  for line in lines {
    let trimmed = line.trim().to_owned()
    if trimmed == "" ||
      trimmed.has_prefix("* daemon") ||
      trimmed.has_prefix("List of devices") {
      if trimmed == "List of devices attached" {
        in_devices = true
      }
      continue
    }
    if !in_devices {
      continue
    }
    // Split on 2+ whitespace runs.
    let tokens = trimmed.split(" ").to_array().filter(v => v != "")
    if tokens.length() < 2 {
      continue
    }
    let id = tokens[0].to_owned()
    let state = tokens[1].to_owned()
    // Look for `device`/`model:`/`transport_id:` keys in remaining tokens.
    let mut name = id
    let mut is_emulator = false
    let mut i = 2
    while i < tokens.length() {
      let token = tokens[i]
      match token.split_once(":") {
        Some((key, value)) =>
          if key == "model" {
            name = value.to_owned()
          } else if key == "device" {
            // `device:emulator-5554` heuristic
            if value.contains("emulator") {
              is_emulator = true
            }
          } else if key == "transport_id" {
            // Both emulators and physicals have transport_id; not authoritative.
            ()
          }
        None => ()
      }
      i += 1
    }
    // Heuristic: emulator serials look like `emulator-<port>` or `localhost:<port>`.
    if id.has_prefix("emulator-") || id.has_prefix("localhost:") {
      is_emulator = true
    }
    let kind = if is_emulator { "emulator" } else { "physical" }
    devices.push({ platform: "android", id, name, state, kind })
  }
  devices
}

///|
/// Parse `xcrun simctl list devices` output into a list of `Device` records.
/// Lines look like:
///   `    iPhone 15 (XXX-XXX-XXX-XXXX-XXXX) (Shutdown)`
/// Platform headers like `== Device Types ==` and `-- iOS 17.0 --` set the
/// current OS section; we capture every device inside the `== Devices ==`
/// section that has a `(<state>)` suffix.
fn parse_simctl_list(output : String) -> Array[Device] {
  let devices : Array[Device] = []
  let lines = output.split("\n").to_array()
  let mut in_devices_section = false
  for line in lines {
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    if trimmed.has_prefix("== ") && trimmed.has_suffix(" ==") {
      in_devices_section = trimmed == "== Devices =="
      continue
    }
    if !in_devices_section {
      continue
    }
    // Skip section separators like `-- iOS 17.0 --`.
    if trimmed.has_prefix("-- ") && trimmed.has_suffix(" --") {
      continue
    }
    // Match: `iPhone 15 (UUID) (State)`. Find the LAST `(` ... `)` pair using
    // `String::find` + manual reverse scan via char array.
    match last_paren_pair(trimmed) {
      Some((state_open, state)) => {
        // head is `trimmed` with the trailing ` (state)` removed.
        let head = trimmed[:state_open].trim().to_owned()
        match last_paren_pair(head) {
          Some((uuid_open, uuid)) =>
            if head.has_suffix(")") {
              let name = head[:uuid_open].trim().to_owned()
              let kind = if name.contains("Simulator") ||
                state.contains("Booted") ||
                state.contains("Shutdown") {
                "emulator"
              } else {
                "unknown"
              }
              devices.push({ platform: "ios", id: uuid, name, state, kind })
            }
          None => ()
        }
      }
      None => ()
    }
  }
  devices
}

///|
/// Find the last `(...)` pair in `text`. Returns `Some((open_index, value))`
/// where `value` is the substring between `open_index+1` and `length-1`, and
/// the closing `)` is the last character of `text`. Returns `None` when the
/// text does not end with `)` or has no `(`.
fn last_paren_pair(text : String) -> (Int, String)? {
  if !text.has_suffix(")") {
    return None
  }
  // Find the last `(` by scanning from the end.
  let chars = text.to_array()
  let mut i = chars.length() - 1
  // Skip trailing `)`.
  let mut depth = 1
  i -= 1
  while i >= 0 {
    if chars[i] == ')' {
      depth += 1
    } else if chars[i] == '(' {
      depth -= 1
      if depth == 0 {
        let value = text[i + 1:chars.length() - 1].to_owned()
        return Some((i, value))
      }
    }
    i -= 1
  }
  None
}

///|
/// Parse `hdc list targets` output into a list of `Device` records.
/// Output format:
///   `   device_id    state`
/// or just `device_id` (assumed state=`connected`).
fn parse_hdc_targets(output : String) -> Array[Device] {
  let devices : Array[Device] = []
  let lines = output.split("\n").to_array()
  for line in lines {
    let trimmed = line.trim().to_owned()
    if trimmed == "" ||
      trimmed.has_prefix("[Empty]") ||
      trimmed.has_prefix("No target") {
      continue
    }
    let tokens = trimmed.split(" ").to_array().filter(v => v != "")
    if tokens.is_empty() {
      continue
    }
    let id = tokens[0].to_owned()
    let state = if tokens.length() >= 2 {
      tokens[1].to_owned()
    } else {
      "connected"
    }
    // hdc does not expose model in `list targets`; default kind=unknown.
    let kind = if id.has_prefix("emulator") || id.contains("-emulator-") {
      "emulator"
    } else {
      "unknown"
    }
    devices.push({ platform: "harmonyos", id, name: id, state, kind })
  }
  devices
}

///|
/// List Android devices by invoking `adb devices -l`. Returns `Err` when
/// `adb` cannot be located or the command fails; callers should treat this as
/// "Android tooling unavailable" and continue scanning other platforms.
fn list_android_devices(host : HostPlatform) -> Result[Array[Device], String] {
  let _ = host
  match find_in_path("adb", detect_host_platform()) {
    None => Err("adb was not found on PATH")
    Some(adb) =>
      match process_exec_argv([adb, "devices", "-l"], capture=true) {
        Ok(result) if result.exit_code == 0 =>
          Ok(parse_adb_devices(result.stdout))
        Ok(result) =>
          Err(
            "adb devices -l failed (exit " + result.exit_code.to_string() + ")",
          )
        Err(message) => Err(message)
      }
  }
}

///|
/// List iOS devices by invoking `xcrun simctl list devices`. Returns `Err`
/// when `xcrun` is unavailable (non-macOS host or missing Xcode). Physical
/// device listing via `xctrace list devices` is merged in but tolerated when
/// unavailable.
fn list_ios_devices(host : HostPlatform) -> Result[Array[Device], String] {
  match host {
    Macos => ()
    _ => return Err("iOS devices require macOS with Xcode installed")
  }
  match find_in_path("xcrun", host) {
    None => Err("xcrun was not found on PATH")
    Some(xcrun) =>
      match
        process_exec_argv([xcrun, "simctl", "list", "devices"], capture=true) {
        Ok(result) if result.exit_code == 0 =>
          Ok(parse_simctl_list(result.stdout))
        Ok(result) =>
          Err(
            "xcrun simctl list devices failed (exit " +
            result.exit_code.to_string() +
            ")",
          )
        Err(message) => Err(message)
      }
  }
}

///|
/// List HarmonyOS devices by invoking `hdc list targets`. Returns `Err` when
/// `hdc` cannot be located (typical on hosts without DevEco Studio).
fn list_harmonyos_devices(host : HostPlatform) -> Result[Array[Device], String] {
  let _ = host
  match find_in_path("hdc", detect_host_platform()) {
    None => Err("hdc was not found on PATH")
    Some(hdc) =>
      match process_exec_argv([hdc, "list", "targets"], capture=true) {
        Ok(result) if result.exit_code == 0 =>
          Ok(parse_hdc_targets(result.stdout))
        Ok(result) =>
          Err(
            "hdc list targets failed (exit " +
            result.exit_code.to_string() +
            ")",
          )
        Err(message) => Err(message)
      }
  }
}

///|
/// List all devices across platforms, skipping any platform whose toolchain
/// is unavailable. Always returns successfully; callers can display an empty
/// list when no platform tooling is installed.
fn list_all_devices(host : HostPlatform) -> Array[Device] {
  let devices : Array[Device] = []
  match list_android_devices(host) {
    Ok(values) =>
      for device in values {
        devices.push(device)
      }
    Err(_) => ()
  }
  match list_ios_devices(host) {
    Ok(values) =>
      for device in values {
        devices.push(device)
      }
    Err(_) => ()
  }
  match list_harmonyos_devices(host) {
    Ok(values) =>
      for device in values {
        devices.push(device)
      }
    Err(_) => ()
  }
  devices
}

///|
fn run_devices(parsed : ParsedDevices, host : HostPlatform) -> CliOutcome {
  if parsed.help {
    return stdout_outcome(devices_usage())
  }
  let devices = match parsed.platform {
    Some(platform) =>
      match platform {
        "android" =>
          match list_android_devices(host) {
            Ok(values) => values
            Err(message) =>
              return failed_outcome(message, parsed.json, devices_usage())
          }
        "ios" =>
          match list_ios_devices(host) {
            Ok(values) => values
            Err(message) =>
              return failed_outcome(message, parsed.json, devices_usage())
          }
        "harmonyos" =>
          match list_harmonyos_devices(host) {
            Ok(values) => values
            Err(message) =>
              return failed_outcome(message, parsed.json, devices_usage())
          }
        _ =>
          return failed_outcome(
            "unsupported platform: " + platform,
            parsed.json,
            "",
          )
      }
    None => list_all_devices(host)
  }
  if parsed.json {
    let entries : Array[Json] = []
    for device in devices {
      entries.push({
        "platform": Json::string(device.platform),
        "id": Json::string(device.id),
        "name": Json::string(device.name),
        "state": Json::string(device.state),
        "kind": Json::string(device.kind),
      })
    }
    let value : Json = {
      "schemaVersion": 1,
      "ok": true,
      "devices": Json::array(entries),
    }
    stdout_outcome(value.stringify(indent=2) + "\n")
  } else {
    if devices.is_empty() {
      return stdout_outcome("(no devices found)\n")
    }
    let mut text = ""
    for device in devices {
      text += device.platform +
        "\t" +
        device.id +
        "\t" +
        device.state +
        "\t" +
        device.kind +
        "\t" +
        device.name +
        "\n"
    }
    stdout_outcome(text)
  }
}
