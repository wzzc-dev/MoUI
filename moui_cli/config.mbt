// XDG-backed configuration persistence. The config file lives at
// `$XDG_CONFIG_HOME/moui/config.json` (POSIX) or `%APPDATA%\moui\config.json`
// (Windows). Tests override the directory via `MOUI_CONFIG_DIR` so the real
// user config is never touched.

///|
fn config_dir(host : HostPlatform) -> String {
  match @env.get_env_var("MOUI_CONFIG_DIR") {
    Some(value) if value != "" => value
    _ =>
      match host {
        Windows =>
          match @env.get_env_var("APPDATA") {
            Some(value) if value != "" => join_path(value, "moui")
            _ =>
              match @env.get_env_var("USERPROFILE") {
                Some(value) if value != "" =>
                  join_path(join_path(value, "AppData"), "Roaming/moui")
                _ => "moui"
              }
          }
        _ =>
          match @env.get_env_var("XDG_CONFIG_HOME") {
            Some(value) if value != "" => join_path(value, "moui")
            _ =>
              match @env.get_env_var("HOME") {
                Some(value) if value != "" => join_path(value, ".config/moui")
                _ => ".config/moui"
              }
          }
      }
  }
}

///|
fn config_path(host : HostPlatform) -> String {
  join_path(config_dir(host), "config.json")
}

///|
fn read_config(host : HostPlatform) -> Result[CliConfig, String] {
  let path = config_path(host)
  let text = @fs.read_file_to_string(path) catch {
    _ => return Ok(default_cli_config())
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("cli config is invalid JSON: " + path)
  }
  match cli_config_from_json(parsed) {
    Ok(config) => Ok(config)
    Err(message) => Err(message)
  }
}

///|
fn write_config(
  config : CliConfig,
  host : HostPlatform,
) -> Result[Unit, String] {
  let dir = config_dir(host)
  match mkdir_p(dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let path = config_path(host)
  let json_text = cli_config_to_json(config).stringify(indent=2) + "\n"
  let bytes = @utf8.encode(json_text[:], bom=false)
  replace_file_atomic(path, bytes)
}

///|
fn config_get(config : CliConfig, key_path : String) -> Result[String, String] {
  let parts = key_path.split(".").to_array()
  if parts.length() != 2 {
    return Err("config key must be <section>.<field>: " + key_path)
  }
  let section = parts[0].to_owned()
  let field = parts[1].to_owned()
  let raw : Json = match section {
    "harmonyos" => harmonyos_config_to_json(config.harmonyos)
    "android" => android_config_to_json(config.android)
    "ios" => ios_config_to_json(config.ios)
    "paths" => paths_config_to_json(config.paths)
    _ => return Err("unknown config section: " + section)
  }
  guard raw is Object(fields) else {
    return Err("config section " + section + " is not an object")
  }
  match fields.get(field) {
    None => Err("not set: " + key_path)
    Some(Json::Null) => Err("not set: " + key_path)
    Some(Json::String(value)) => Ok(value)
    Some(Json::Number(value, repr=_)) if value.to_int().to_double() == value =>
      Ok(value.to_int().to_string())
    Some(Json::Number(value, repr=_)) => Ok(value.to_string())
    Some(Json::True) => Ok("true")
    Some(Json::False) => Ok("false")
    Some(value) => Ok(value.stringify())
  }
}

///|
fn try_parse_int(value : String) -> Int? {
  if value == "" {
    return None
  }
  let negative = value[0] == '-'
  let digits = if negative { value[1:] } else { value[:] }
  if digits.is_empty() {
    return None
  }
  for c in digits {
    if c < '0' || c > '9' {
      return None
    }
  }
  let number = Ref(0)
  for c in digits {
    number.val = number.val * 10 + c.to_int() - '0'.to_int()
  }
  Some(if negative { -number.val } else { number.val })
}

///|
fn config_set(
  config : CliConfig,
  key_path : String,
  value : String,
) -> Result[CliConfig, String] {
  let parts = key_path.split(".").to_array()
  if parts.length() != 2 {
    return Err("config key must be <section>.<field>: " + key_path)
  }
  let section = parts[0].to_owned()
  let field = parts[1].to_owned()
  match section {
    "harmonyos" => {
      let harmonyos = config.harmonyos
      let new_harmonyos = match field {
        "sdkHome" => { ..harmonyos, sdk_home: Some(value) }
        "hvigorw" => { ..harmonyos, hvigorw: Some(value) }
        "ohpm" => { ..harmonyos, ohpm: Some(value) }
        "signingConfigFile" => { ..harmonyos, signing_config_file: Some(value) }
        _ => return Err("unknown harmonyos field: " + field)
      }
      Ok({ ..config, harmonyos: new_harmonyos })
    }
    "android" => {
      let android = config.android
      let new_android = match field {
        "sdkHome" => { ..android, sdk_home: Some(value) }
        "ndkHome" => { ..android, ndk_home: Some(value) }
        "compileSdk" =>
          match try_parse_int(value) {
            Some(n) => { ..android, compile_sdk: Some(n) }
            None => return Err("android.compileSdk must be an integer")
          }
        "targetSdk" =>
          match try_parse_int(value) {
            Some(n) => { ..android, target_sdk: Some(n) }
            None => return Err("android.targetSdk must be an integer")
          }
        _ => return Err("unknown android field: " + field)
      }
      Ok({ ..config, android: new_android })
    }
    "ios" => {
      let ios = config.ios
      let new_ios = match field {
        "sdk" => { ..ios, sdk: Some(value) }
        "arch" => { ..ios, arch: Some(value) }
        "deploymentTarget" =>
          match try_parse_int(value) {
            Some(n) => { ..ios, deployment_target: Some(n) }
            None => return Err("ios.deploymentTarget must be an integer")
          }
        _ => return Err("unknown ios field: " + field)
      }
      Ok({ ..config, ios: new_ios })
    }
    "paths" => {
      let paths = config.paths
      let new_paths = match field {
        "moonHome" => { ..paths, moon_home: Some(value) }
        "mouiRoot" => { ..paths, moui_root: Some(value) }
        "skiaRoot" => { ..paths, skia_root: Some(value) }
        _ => return Err("unknown paths field: " + field)
      }
      Ok({ ..config, paths: new_paths })
    }
    _ => Err("unknown config section: " + section)
  }
}

///|
fn config_list_lines(config : CliConfig) -> Array[String] {
  let lines : Array[String] = []
  let harmonyos_fields = ["sdkHome", "hvigorw", "ohpm", "signingConfigFile"]
  for field in harmonyos_fields {
    match config_get(config, "harmonyos." + field) {
      Ok(value) => lines.push("harmonyos." + field + " = " + value)
      Err(_) => ()
    }
  }
  let android_fields = ["sdkHome", "ndkHome", "compileSdk", "targetSdk"]
  for field in android_fields {
    match config_get(config, "android." + field) {
      Ok(value) => lines.push("android." + field + " = " + value)
      Err(_) => ()
    }
  }
  if !config.android.abi.is_empty() {
    lines.push("android.abi = " + config.android.abi.join(","))
  }
  let ios_fields = ["sdk", "arch", "deploymentTarget"]
  for field in ios_fields {
    match config_get(config, "ios." + field) {
      Ok(value) => lines.push("ios." + field + " = " + value)
      Err(_) => ()
    }
  }
  let paths_fields = ["moonHome", "mouiRoot", "skiaRoot"]
  for field in paths_fields {
    match config_get(config, "paths." + field) {
      Ok(value) => lines.push("paths." + field + " = " + value)
      Err(_) => ()
    }
  }
  lines
}
