///|
let mobile_config_schema_version : Int = 1

///|
priv struct MobileAndroid {
  application_id : String
  min_sdk : Int
} derive(Eq)

///|
priv struct MobileIos {
  bundle_id : String
  product_name : String
  deployment_target : String
} derive(Eq)

///|
priv struct MobileHarmonyos {
  bundle_name : String
  product_name : String
  app_name : String?
  module_name : String?
  module_description : String?
  entry_description : String?
  compatible_sdk_version : Int
} derive(Eq)

///|
priv struct MobileApp {
  id : String
  display_name : String
  artifact_name : String
  app_package : String
  schema_version : Int
  metadata_path : String
  android : MobileAndroid?
  ios : MobileIos?
  harmonyos : MobileHarmonyos?
} derive(Eq)

///|
fn mobile_optional_string(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Result[String?, String] {
  match fields.get(key) {
    Some(String(value)) if value.trim() != "" => Ok(Some(value))
    Some(_) => Err(label + "." + key + " must be a non-empty string")
    None => Ok(None)
  }
}

///|
fn mobile_numeric_dotted_version_at_least(
  value : String,
  major : Int,
  minor : Int,
) -> Bool {
  let parts = value.split(".").to_array()
  if parts.is_empty() || parts.length() > 3 {
    return false
  }
  let parsed : Array[Int] = []
  for part in parts {
    let text = part.to_owned()
    if text == "" || !text.all(char => char >= '0' && char <= '9') {
      return false
    }
    let number = Ref(0)
    for unit in text {
      number.val = number.val * 10 + unit.to_int() - '0'.to_int()
    }
    parsed.push(number.val)
  }
  let actual_major = parsed[0]
  let actual_minor = if parsed.length() > 1 { parsed[1] } else { 0 }
  actual_major > major || (actual_major == major && actual_minor >= minor)
}

///|
fn parse_mobile_android(
  value : Json,
  label : String,
) -> Result[MobileAndroid, String] {
  let fields = match
    json_exact_object(
      value,
      ["applicationId", "minSdk"],
      ["applicationId", "minSdk"],
      label,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let application_id = match
    json_required_string(fields, "applicationId", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let min_sdk = match json_required_int(fields, "minSdk", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if min_sdk < 23 {
    return Err(label + ".minSdk must be at least 23")
  }
  Ok({ application_id, min_sdk })
}

///|
fn parse_mobile_ios(value : Json, label : String) -> Result[MobileIos, String] {
  let fields = match
    json_exact_object(
      value,
      ["bundleId", "productName", "deploymentTarget"],
      ["bundleId", "productName", "deploymentTarget"],
      label,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let bundle_id = match json_required_string(fields, "bundleId", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let product_name = match json_required_string(fields, "productName", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let deployment_target = match
    json_required_string(fields, "deploymentTarget", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if !mobile_numeric_dotted_version_at_least(deployment_target, 15, 0) {
    return Err(label + ".deploymentTarget must be at least 15.0")
  }
  Ok({ bundle_id, product_name, deployment_target })
}

///|
fn parse_mobile_harmonyos(
  value : Json,
  label : String,
) -> Result[MobileHarmonyos, String] {
  let fields = match
    json_exact_object(
      value,
      [
        "bundleName", "productName", "appName", "moduleName", "moduleDescription",
        "entryDescription", "compatibleSdkVersion",
      ],
      ["bundleName", "productName", "compatibleSdkVersion"],
      label,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let bundle_name = match json_required_string(fields, "bundleName", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let product_name = match json_required_string(fields, "productName", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let app_name = match mobile_optional_string(fields, "appName", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let module_name = match mobile_optional_string(fields, "moduleName", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let module_description = match
    mobile_optional_string(fields, "moduleDescription", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let entry_description = match
    mobile_optional_string(fields, "entryDescription", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let compatible_sdk_version = match
    json_required_int(fields, "compatibleSdkVersion", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if compatible_sdk_version < 20 {
    return Err(label + ".compatibleSdkVersion must be at least 20")
  }
  Ok({
    bundle_name,
    product_name,
    app_name,
    module_name,
    module_description,
    entry_description,
    compatible_sdk_version,
  })
}

///|
fn read_mobile_app_at(metadata_path : String) -> Result[MobileApp, String] {
  let text = @fs.read_file_to_string(metadata_path) catch {
    _ => return Err("mobile configuration not found: " + metadata_path)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("mobile configuration is invalid JSON: " + metadata_path)
  }
  let fields = match
    json_exact_object(
      parsed,
      [
        "schemaVersion", "id", "displayName", "artifactName", "appPackage", "android",
        "ios", "harmonyos",
      ],
      ["schemaVersion", "id", "displayName", "artifactName", "appPackage"],
      metadata_path,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let schema_version = match
    json_required_int(fields, "schemaVersion", metadata_path) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if schema_version != mobile_config_schema_version {
    return Err(metadata_path + ".schemaVersion must be 1")
  }
  let id = match json_required_string(fields, "id", metadata_path) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let display_name = match
    json_required_string(fields, "displayName", metadata_path) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let artifact_name = match
    json_required_string(fields, "artifactName", metadata_path) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let app_package = match
    json_required_string(fields, "appPackage", metadata_path) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let android = match fields.get("android") {
    Some(value) =>
      match parse_mobile_android(value, metadata_path + ".android") {
        Ok(result) => Some(result)
        Err(message) => return Err(message)
      }
    None => None
  }
  let ios = match fields.get("ios") {
    Some(value) =>
      match parse_mobile_ios(value, metadata_path + ".ios") {
        Ok(result) => Some(result)
        Err(message) => return Err(message)
      }
    None => None
  }
  let harmonyos = match fields.get("harmonyos") {
    Some(value) =>
      match parse_mobile_harmonyos(value, metadata_path + ".harmonyos") {
        Ok(result) => Some(result)
        Err(message) => return Err(message)
      }
    None => None
  }
  if android is None && ios is None && harmonyos is None {
    return Err(
      metadata_path +
      " must configure at least one of android, ios, or harmonyos",
    )
  }
  Ok({
    id,
    display_name,
    artifact_name,
    app_package,
    schema_version,
    metadata_path,
    android,
    ios,
    harmonyos,
  })
}

///|
fn read_mobile_app(project_root : String) -> Result[MobileApp, String] {
  read_mobile_app_at(join_path(project_root, "moui.mobile.json"))
}

///|
fn mobile_entrypoint_package(
  metadata_path : String,
  platform : String,
  workspace_root : String,
) -> Result[String, String] {
  let app_root = parent_dir(metadata_path)
  let selected = join_path(app_root, platform + "_window_hosted")
  let has_pkg = @fs.is_file(join_path(selected, "moon.pkg")) catch {
    _ => false
  }
  if !has_pkg {
    return Err(
      "window-hosted " + platform + " entrypoint is missing under " + app_root,
    )
  }
  match mobile_path_relative_to(workspace_root, selected) {
    Ok(value) => Ok(value)
    Err(_) => Ok(selected)
  }
}

///|
fn mobile_path_relative_to(
  workspace_root : String,
  target : String,
) -> Result[String, String] {
  match
    mobile_relative_path_from_normalized(
      normalized_path(workspace_root),
      normalized_path(target),
    ) {
    Ok(value) => return Ok(value)
    Err(_) => ()
  }
  let root = match canonical_path(workspace_root) {
    Some(value) => normalized_path(value)
    None => return Err("target is not inside workspace root")
  }
  let candidate = match canonical_path(target) {
    Some(value) => normalized_path(value)
    None => return Err("target is not inside workspace root")
  }
  mobile_relative_path_from_normalized(root, candidate)
}

///|
fn mobile_relative_path_from_normalized(
  root : String,
  candidate : String,
) -> Result[String, String] {
  if !candidate.has_prefix(root) {
    return Err("target is not inside workspace root")
  }
  let prefix_length = root.length()
  if candidate.length() == prefix_length {
    Ok("")
  } else if candidate.length() > prefix_length &&
    candidate[prefix_length] == '/' {
    Ok(candidate[prefix_length + 1:].to_owned())
  } else {
    Err("target is not inside workspace root")
  }
}
