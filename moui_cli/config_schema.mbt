// CLI configuration schema (XDG-backed). Stores user preferences that
// cannot be inferred from the project: SDK locations, default device, etc.
// The schema is intentionally minimal — every field is optional so a
// missing config file degrades gracefully into `default_cli_config()`.

///|
priv struct HarmonyosConfig {
  sdk_home : String?
  hvigorw : String?
  ohpm : String?
  signing_config_file : String?
} derive(Eq)

///|
priv struct AndroidConfig {
  sdk_home : String?
  ndk_home : String?
  abi : Array[String]
  compile_sdk : Int?
  target_sdk : Int?
} derive(Eq)

///|
priv struct IosConfig {
  sdk : String?
  arch : String?
  deployment_target : Int?
} derive(Eq)

///|
priv struct PathsConfig {
  moon_home : String?
  moui_root : String?
  skia_root : String?
} derive(Eq)

///|
priv struct CliConfig {
  schema_version : Int
  harmonyos : HarmonyosConfig
  android : AndroidConfig
  ios : IosConfig
  paths : PathsConfig
} derive(Eq)

///|
fn default_harmonyos_config() -> HarmonyosConfig {
  { sdk_home: None, hvigorw: None, ohpm: None, signing_config_file: None }
}

///|
fn default_android_config() -> AndroidConfig {
  {
    sdk_home: None,
    ndk_home: None,
    abi: [],
    compile_sdk: None,
    target_sdk: None,
  }
}

///|
fn default_ios_config() -> IosConfig {
  { sdk: None, arch: None, deployment_target: None }
}

///|
fn default_paths_config() -> PathsConfig {
  { moon_home: None, moui_root: None, skia_root: None }
}

///|
fn default_cli_config() -> CliConfig {
  {
    schema_version: 1,
    harmonyos: default_harmonyos_config(),
    android: default_android_config(),
    ios: default_ios_config(),
    paths: default_paths_config(),
  }
}

///|
let cli_config_schema_version : Int = 1

///|
fn validate_cli_config(config : CliConfig) -> Result[Unit, String] {
  if config.schema_version != cli_config_schema_version {
    return Err(
      "cli config schemaVersion must be " +
      cli_config_schema_version.to_string() +
      ", got " +
      config.schema_version.to_string(),
    )
  }
  Ok(())
}

///|
fn harmonyos_config_to_json(config : HarmonyosConfig) -> Json {
  let fields : Map[String, Json] = Map([])
  match config.sdk_home {
    Some(value) => fields["sdkHome"] = Json::string(value)
    None => ()
  }
  match config.hvigorw {
    Some(value) => fields["hvigorw"] = Json::string(value)
    None => ()
  }
  match config.ohpm {
    Some(value) => fields["ohpm"] = Json::string(value)
    None => ()
  }
  match config.signing_config_file {
    Some(value) => fields["signingConfigFile"] = Json::string(value)
    None => ()
  }
  Json::object(fields)
}

///|
fn android_config_to_json(config : AndroidConfig) -> Json {
  let fields : Map[String, Json] = Map([])
  match config.sdk_home {
    Some(value) => fields["sdkHome"] = Json::string(value)
    None => ()
  }
  match config.ndk_home {
    Some(value) => fields["ndkHome"] = Json::string(value)
    None => ()
  }
  let abi : Array[Json] = []
  for value in config.abi {
    abi.push(Json::string(value))
  }
  fields["abi"] = Json::array(abi)
  match config.compile_sdk {
    Some(value) => fields["compileSdk"] = Json::number(value.to_double())
    None => ()
  }
  match config.target_sdk {
    Some(value) => fields["targetSdk"] = Json::number(value.to_double())
    None => ()
  }
  Json::object(fields)
}

///|
fn ios_config_to_json(config : IosConfig) -> Json {
  let fields : Map[String, Json] = Map([])
  match config.sdk {
    Some(value) => fields["sdk"] = Json::string(value)
    None => ()
  }
  match config.arch {
    Some(value) => fields["arch"] = Json::string(value)
    None => ()
  }
  match config.deployment_target {
    Some(value) => fields["deploymentTarget"] = Json::number(value.to_double())
    None => ()
  }
  Json::object(fields)
}

///|
fn paths_config_to_json(config : PathsConfig) -> Json {
  let fields : Map[String, Json] = Map([])
  match config.moon_home {
    Some(value) => fields["moonHome"] = Json::string(value)
    None => ()
  }
  match config.moui_root {
    Some(value) => fields["mouiRoot"] = Json::string(value)
    None => ()
  }
  match config.skia_root {
    Some(value) => fields["skiaRoot"] = Json::string(value)
    None => ()
  }
  Json::object(fields)
}

///|
fn cli_config_to_json(config : CliConfig) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["schemaVersion"] = Json::number(config.schema_version.to_double())
  fields["harmonyos"] = harmonyos_config_to_json(config.harmonyos)
  fields["android"] = android_config_to_json(config.android)
  fields["ios"] = ios_config_to_json(config.ios)
  fields["paths"] = paths_config_to_json(config.paths)
  Json::object(fields)
}

///|
fn optional_string(
  fields : Map[String, Json],
  key : String,
) -> Result[String?, String] {
  match fields.get(key) {
    None => Ok(None)
    Some(Null) => Ok(None)
    Some(Json::String(value)) => Ok(Some(value))
    Some(_) => Err("config field " + key + " must be a string or null")
  }
}

///|
fn optional_int(
  fields : Map[String, Json],
  key : String,
) -> Result[Int?, String] {
  match fields.get(key) {
    None => Ok(None)
    Some(Null) => Ok(None)
    Some(Json::Number(value, repr=_)) if value.to_int().to_double() == value =>
      Ok(Some(value.to_int()))
    Some(_) => Err("config field " + key + " must be an integer or null")
  }
}

///|
fn required_string_array(
  fields : Map[String, Json],
  key : String,
) -> Result[Array[String], String] {
  match fields.get(key) {
    None => Ok([])
    Some(Null) => Ok([])
    Some(Json::Array(values)) => {
      let result : Array[String] = []
      for value in values {
        guard value is Json::String(text) else {
          return Err("config field " + key + " must be an array of strings")
        }
        result.push(text)
      }
      Ok(result)
    }
    Some(_) => Err("config field " + key + " must be an array")
  }
}

///|
fn harmonyos_config_from_json(value : Json) -> Result[HarmonyosConfig, String] {
  guard value is Object(fields) else {
    return Err("cli config harmonyos must be an object")
  }
  let sdk_home = match optional_string(fields, "sdkHome") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let hvigorw = match optional_string(fields, "hvigorw") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let ohpm = match optional_string(fields, "ohpm") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let signing_config_file = match optional_string(fields, "signingConfigFile") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok({ sdk_home, hvigorw, ohpm, signing_config_file })
}

///|
fn android_config_from_json(value : Json) -> Result[AndroidConfig, String] {
  guard value is Object(fields) else {
    return Err("cli config android must be an object")
  }
  let sdk_home = match optional_string(fields, "sdkHome") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let ndk_home = match optional_string(fields, "ndkHome") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let abi = match required_string_array(fields, "abi") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let compile_sdk = match optional_int(fields, "compileSdk") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let target_sdk = match optional_int(fields, "targetSdk") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok({ sdk_home, ndk_home, abi, compile_sdk, target_sdk })
}

///|
fn ios_config_from_json(value : Json) -> Result[IosConfig, String] {
  guard value is Object(fields) else {
    return Err("cli config ios must be an object")
  }
  let sdk = match optional_string(fields, "sdk") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let arch = match optional_string(fields, "arch") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let deployment_target = match optional_int(fields, "deploymentTarget") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok({ sdk, arch, deployment_target })
}

///|
fn paths_config_from_json(value : Json) -> Result[PathsConfig, String] {
  guard value is Object(fields) else {
    return Err("cli config paths must be an object")
  }
  let moon_home = match optional_string(fields, "moonHome") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let moui_root = match optional_string(fields, "mouiRoot") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let skia_root = match optional_string(fields, "skiaRoot") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok({ moon_home, moui_root, skia_root })
}

///|
fn cli_config_from_json(value : Json) -> Result[CliConfig, String] {
  guard value is Object(fields) else {
    return Err("cli config must be an object")
  }
  let schema_version = match fields.get("schemaVersion") {
    Some(Json::Number(value, repr=_)) if value.to_int().to_double() == value =>
      value.to_int()
    _ => return Err("cli config schemaVersion must be an integer")
  }
  let harmonyos = match fields.get("harmonyos") {
    None => default_harmonyos_config()
    Some(value) =>
      match harmonyos_config_from_json(value) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
  }
  let android = match fields.get("android") {
    None => default_android_config()
    Some(value) =>
      match android_config_from_json(value) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
  }
  let ios = match fields.get("ios") {
    None => default_ios_config()
    Some(value) =>
      match ios_config_from_json(value) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
  }
  let paths = match fields.get("paths") {
    None => default_paths_config()
    Some(value) =>
      match paths_config_from_json(value) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
  }
  let config : CliConfig = { schema_version, harmonyos, android, ios, paths }
  match validate_cli_config(config) {
    Ok(_) => Ok(config)
    Err(message) => Err(message)
  }
}
