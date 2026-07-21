// Shell.json v1 schema parser and managed-platform contract derivation.
// Migrates `moui_shell/scripts/shell-config-schema.mjs` (217 lines) and
// `moui_shell/scripts/app-config.mjs` (164 lines) into MoonBit. The strict
// v1 schema is the sole source of truth: there is no contract registry or
// alternate metadata branch.

///|
let shell_schema_version : Int = 1

///|
let shell_api_version : Int = 1

///|
let embedding_api_version : Int = 1

///|
priv struct Shell {
  profile : String
  renderer : String
  status_bar : String
  orientation : String
  resources : Array[String]
  permissions : Array[String]
  plugins : Array[String]
  fullscreen : Bool
  supports_scroll : Bool
} derive(Eq)

///|
priv struct ShellAndroid {
  application_id : String
  runner_mode : String
  min_sdk : Int
} derive(Eq)

///|
priv struct ShellIos {
  bundle_id : String
  product_name : String
  runner_mode : String
  deployment_target : String
} derive(Eq)

///|
priv struct ShellHarmonyos {
  bundle_name : String
  product_name : String
  app_name : String?
  module_name : String?
  module_description : String?
  entry_description : String?
  runner_mode : String
  compatible_sdk_version : Int
} derive(Eq)

///|
priv struct ShellApp {
  id : String
  display_name : String
  artifact_name : String
  app_package : String
  schema_version : Int
  shell_api_version : Int
  embedding_api_version : Int
  shell : Shell
  metadata_path : String
  plugins : Array[String]
  android : ShellAndroid?
  ios : ShellIos?
  harmonyos : ShellHarmonyos?
} derive(Eq)

///|
priv struct ManagedContract {
  app_id : String
  platform : String
  metadata_path : String
  workspace_root : String
  shell_root : String
  entrypoint_package : String
  generated_c : String
  entrypoint_arg : String
  moonbit_main_alias : String
  embedding_exports : Array[String]
  native_library : String?
  info_plist : String?
} derive(Eq)

///|
priv struct IosShellResolution {
  runner_mode : String
  deployment_target : String
  permissions : Array[String]
  swift_sources : Array[String]
  objcxx_sources : Array[String]
  resources : Array[String]
  plugin_types : Array[String]
  entrypoint_arg : String
  status_bar : String
  orientation : String
  fullscreen : Bool
}

///|
fn fixed_embedding_exports() -> Array[String] {
  [
    "moui_embedding_attach_surface", "moui_embedding_resize", "moui_embedding_dispatch_pointer",
    "moui_embedding_dispatch_scroll", "moui_embedding_frame_tick", "moui_embedding_render_frame",
    "moui_embedding_detach_surface", "moui_embedding_destroy_application", "moui_embedding_dispatch_host_response_envelope_json",
  ]
}

///|
fn parse_shell_system_ui(
  value : Json,
  label : String,
) -> Result[(Bool, String), String] {
  let fields = match
    json_exact_object(
      value,
      ["fullscreen", "statusBar"],
      ["fullscreen", "statusBar"],
      label,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let fullscreen = match fields.get("fullscreen") {
    Some(True) => true
    Some(False) => false
    _ => return Err(label + ".fullscreen must be a boolean")
  }
  let status_bar = match json_required_string(fields, "statusBar", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if !["auto", "visible", "hidden"].contains(status_bar) {
    return Err(label + ".statusBar must be auto, visible, or hidden")
  }
  Ok((fullscreen, status_bar))
}

///|
fn parse_shell_section(value : Json, label : String) -> Result[Shell, String] {
  let fields = match
    json_exact_object(
      value,
      [
        "profile", "renderer", "systemUi", "orientation", "resources", "permissions",
        "plugins",
      ],
      [
        "profile", "renderer", "systemUi", "orientation", "resources", "permissions",
        "plugins",
      ],
      label,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  match json_required_string(fields, "profile", label) {
    Ok("handheld") => ()
    Ok(_) => return Err(label + ".profile must be handheld")
    Err(message) => return Err(message)
  }
  let renderer = match json_required_string(fields, "renderer", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if !["auto", "skia-gpu", "skia-raster"].contains(renderer) {
    return Err(label + ".renderer must be auto, skia-gpu, or skia-raster")
  }
  let orientation = match json_required_string(fields, "orientation", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if !["any", "portrait", "landscape"].contains(orientation) {
    return Err(label + ".orientation must be any, portrait, or landscape")
  }
  let (fullscreen, status_bar) = match
    parse_shell_system_ui(fields.get("systemUi").unwrap(), label + ".systemUi") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let resources = match
    json_unique_strings(
      fields.get("resources").unwrap(),
      label + ".resources",
      paths=true,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let permissions = match
    json_unique_strings(
      fields.get("permissions").unwrap(),
      label + ".permissions",
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let plugins = match
    json_unique_strings(
      fields.get("plugins").unwrap(),
      label + ".plugins",
      paths=true,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  Ok({
    profile: "handheld",
    renderer,
    status_bar,
    orientation,
    resources,
    permissions,
    plugins,
    fullscreen,
    supports_scroll: true,
  })
}

///|
fn parse_shell_android(
  value : Json,
  label : String,
) -> Result[ShellAndroid, String] {
  let fields = match
    json_exact_object(
      value,
      ["applicationId", "runnerMode", "minSdk"],
      ["applicationId", "runnerMode", "minSdk"],
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
  let runner_mode = match json_required_string(fields, "runnerMode", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if runner_mode != "managed" && runner_mode != "ejected" {
    return Err(label + ".runnerMode must be managed or ejected")
  }
  let min_sdk = match json_required_int(fields, "minSdk", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if min_sdk < 23 {
    return Err(label + ".minSdk must be at least 23")
  }
  Ok({ application_id, runner_mode, min_sdk })
}

///|
fn parse_shell_ios(value : Json, label : String) -> Result[ShellIos, String] {
  let fields = match
    json_exact_object(
      value,
      ["bundleId", "productName", "runnerMode", "deploymentTarget"],
      ["bundleId", "productName", "runnerMode", "deploymentTarget"],
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
  let runner_mode = match json_required_string(fields, "runnerMode", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if runner_mode != "managed" && runner_mode != "ejected" {
    return Err(label + ".runnerMode must be managed or ejected")
  }
  let deployment_target = match
    json_required_string(fields, "deploymentTarget", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if !numeric_dotted_version_at_least(deployment_target, 15, 0) {
    return Err(label + ".deploymentTarget must be at least 15.0")
  }
  Ok({ bundle_id, product_name, runner_mode, deployment_target })
}

///|
fn parse_shell_harmonyos(
  value : Json,
  label : String,
) -> Result[ShellHarmonyos, String] {
  let fields = match
    json_exact_object(
      value,
      [
        "bundleName", "productName", "appName", "moduleName", "moduleDescription",
        "entryDescription", "runnerMode", "compatibleSdkVersion",
      ],
      ["bundleName", "productName", "runnerMode", "compatibleSdkVersion"],
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
  let app_name = match fields.get("appName") {
    Some(String(value)) if value.trim() != "" => Some(value)
    Some(_) => return Err(label + ".appName must be a non-empty string")
    None => None
  }
  let module_name = match fields.get("moduleName") {
    Some(String(value)) if value.trim() != "" => Some(value)
    Some(_) => return Err(label + ".moduleName must be a non-empty string")
    None => None
  }
  let module_description = match fields.get("moduleDescription") {
    Some(String(value)) if value.trim() != "" => Some(value)
    Some(_) =>
      return Err(label + ".moduleDescription must be a non-empty string")
    None => None
  }
  let entry_description = match fields.get("entryDescription") {
    Some(String(value)) if value.trim() != "" => Some(value)
    Some(_) =>
      return Err(label + ".entryDescription must be a non-empty string")
    None => None
  }
  let runner_mode = match json_required_string(fields, "runnerMode", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if runner_mode != "managed" && runner_mode != "ejected" {
    return Err(label + ".runnerMode must be managed or ejected")
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
    runner_mode,
    compatible_sdk_version,
  })
}

///|
/// Read and validate one strict `shell.json` file. The path parameter is the
/// directory that contains `shell.json`. Returns a structured `ShellApp` for
/// downstream build commands (M5/M6). This replaces `app-config.mjs::readShellApp`.
fn read_shell_app(project_root : String) -> Result[ShellApp, String] {
  let metadata_path = join_path(project_root, "shell.json")
  let text = @fs.read_file_to_string(metadata_path) catch {
    _ => return Err("shell config not found: " + metadata_path)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("shell.json is invalid JSON: " + metadata_path)
  }
  let fields = match
    json_exact_object(
      parsed,
      [
        "schemaVersion", "id", "displayName", "artifactName", "appPackage", "shellApiVersion",
        "embeddingApiVersion", "shell", "android", "ios", "harmonyos",
      ],
      [
        "schemaVersion", "id", "displayName", "artifactName", "appPackage", "shellApiVersion",
        "embeddingApiVersion", "shell",
      ],
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
  if schema_version != shell_schema_version {
    return Err(metadata_path + ".schemaVersion must be 1")
  }
  let shell_api_version = match
    json_required_int(fields, "shellApiVersion", metadata_path) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if shell_api_version != shell_api_version {
    return Err(metadata_path + ".shellApiVersion must be 1")
  }
  let embedding_abi_version = match
    json_required_int(fields, "embeddingApiVersion", metadata_path) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if embedding_abi_version != embedding_api_version {
    return Err(metadata_path + ".embeddingApiVersion must be 1")
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
  let shell = match
    parse_shell_section(fields.get("shell").unwrap(), metadata_path + ".shell") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let android = match fields.get("android") {
    Some(value) =>
      match parse_shell_android(value, metadata_path + ".android") {
        Ok(result) => Some(result)
        Err(message) => return Err(message)
      }
    None => None
  }
  let ios = match fields.get("ios") {
    Some(value) =>
      match parse_shell_ios(value, metadata_path + ".ios") {
        Ok(result) => Some(result)
        Err(message) => return Err(message)
      }
    None => None
  }
  let harmonyos = match fields.get("harmonyos") {
    Some(value) =>
      match parse_shell_harmonyos(value, metadata_path + ".harmonyos") {
        Ok(result) => Some(result)
        Err(message) => return Err(message)
      }
    None => None
  }
  if android.is_empty() && ios.is_empty() && harmonyos.is_empty() {
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
    shell_api_version,
    embedding_api_version: embedding_abi_version,
    shell,
    metadata_path,
    plugins: shell.plugins,
    android,
    ios,
    harmonyos,
  })
}

///|
/// Locate the managed entrypoint moon.pkg for a given platform under the same
/// directory as `metadata_path`. Prefers `<platform>_skia` over `<platform>`.
fn managed_entrypoint_package(
  metadata_path : String,
  platform : String,
  workspace_root : String,
) -> Result[String, String] {
  let app_root = parent_dir(metadata_path)
  let candidates = [
    join_path(app_root, platform + "_skia"),
    join_path(app_root, platform),
  ]
  let mut selected = ""
  for candidate in candidates {
    let has_pkg = @fs.is_file(join_path(candidate, "moon.pkg")) catch {
      _ => false
    }
    if has_pkg {
      selected = candidate
      break
    }
  }
  if selected == "" {
    selected = candidates[0]
  }
  let relative = match path_relative_to(workspace_root, selected) {
    Ok(value) => value
    Err(_) => selected
  }
  Ok(relative)
}

///|
/// Replace non-identifier characters in an app id so it can be used as part
/// of a native library name (`moui_<safe_id>_android`).
fn safe_identifier(value : String) -> String {
  let result = StringBuilder::new()
  for ch in value {
    if (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '_' {
      result.write_char(ch)
    } else {
      result.write_char('_')
    }
  }
  result.to_string()
}

///|
/// Replace `_` with `-` so the value can be used in `moui-<slug>-<platform>`.
fn app_slug(value : String) -> String {
  value.replace_all(old="_", new="-")
}

///|
/// Derive the fixed v1 managed-platform contract for an app. Replaces
/// `app-config.mjs::managedPlatformContract`. iOS contracts populate
/// `info_plist`; Android and HarmonyOS contracts populate `native_library`.
fn managed_platform_contract(
  app : ShellApp,
  platform : String,
  workspace_root : String,
  shell_root : String,
) -> Result[ManagedContract, String] {
  let entrypoint_package = match
    managed_entrypoint_package(app.metadata_path, platform, workspace_root) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let safe_id = safe_identifier(app.id)
  let slug = app_slug(app.id)
  let entrypoint_arg = "moui-" + slug + "-" + platform
  let generated_c = base_name(entrypoint_package) + ".c"
  let exports = fixed_embedding_exports()
  let native_library : String? = match platform {
    "android" => Some("moui_" + safe_id + "_android")
    "harmonyos" => Some("moui_embedding_harmonyos")
    _ => None
  }
  let info_plist : String? = if platform == "ios" {
    Some(join_path(shell_root, "ios/runner/template/Info.plist"))
  } else {
    None
  }
  Ok({
    app_id: app.id,
    platform,
    metadata_path: app.metadata_path,
    workspace_root,
    shell_root,
    entrypoint_package,
    generated_c,
    entrypoint_arg,
    moonbit_main_alias: "moui_embedding_moonbit_generated_main",
    embedding_exports: exports,
    native_library,
    info_plist,
  })
}

///|
/// Permission -> Info.plist usage description entries. Notifications and
/// clipboard have no usage-description key because they use runtime
/// authorization/privacy APIs.
fn managed_ios_permission_descriptions(
  permission : String,
  display_name : String,
) -> Result[Array[(String, String)], String] {
  match permission {
    "camera" =>
      Ok([
        (
          "NSCameraUsageDescription",
          display_name +
          " needs camera access for app features you choose to use.",
        ),
      ])
    "microphone" =>
      Ok([
        (
          "NSMicrophoneUsageDescription",
          display_name +
          " needs microphone access for app features you choose to use.",
        ),
      ])
    "location" =>
      Ok([
        (
          "NSLocationWhenInUseUsageDescription",
          display_name + " needs your location while you use the app.",
        ),
      ])
    "photos" =>
      Ok([
        (
          "NSPhotoLibraryUsageDescription",
          display_name +
          " needs photo library access for app features you choose to use.",
        ),
      ])
    "notifications" => Ok([])
    "clipboard" => Ok([])
    _ =>
      Err(
        "managed iOS shell does not support shell.permissions entry: " +
        permission,
      )
  }
}

///|
/// Resolve iOS shell sources, resources, and permission usage descriptions.
/// Replaces the inline logic in `moui_shell/ios/runner/resolve-shell.mjs`.
/// `moui_root` is currently unused but kept for future source-collection
/// extensions (it mirrors the .mjs signature).
fn resolve_ios_shell(
  app : ShellApp,
  workspace_root : String,
  _moui_root : String,
  renderer : String,
  runner_mode : String,
) -> Result[IosShellResolution, String] {
  guard app.ios is Some(ios) else {
    return Err("app " + app.id + " does not configure iOS")
  }
  if runner_mode != "managed" && runner_mode != "ejected" {
    return Err("runner_mode must be managed or ejected")
  }
  if ios.runner_mode != runner_mode {
    return Err(
      "app " +
      app.id +
      " requests iOS runnerMode=" +
      ios.runner_mode +
      "; " +
      runner_mode +
      " shell required",
    )
  }
  let swift_sources : Array[String] = []
  let objcxx_sources : Array[String] = []
  let plugin_types : Array[String] = []
  let resources : Array[String] = []
  for resource in app.shell.resources {
    let absolute = join_path(workspace_root, resource)
    if !path_is_file(absolute) && !path_is_dir(absolute) {
      return Err("managed iOS resource does not exist: " + resource)
    }
    resources.push(absolute)
  }
  let entrypoint_arg = "moui-" + app_slug(app.id) + "-ios"
  if runner_mode == "managed" {
    for permission in app.shell.permissions {
      let descriptions = match
        managed_ios_permission_descriptions(permission, app.display_name) {
        Ok(result) => result
        Err(message) => return Err(message)
      }
      // descriptions intentionally not surfaced in IosShellResolution; they
      // are computed at build_ios time when Info.plist is rewritten. We only
      // validate here so that invalid permissions fail fast.
      let _ = descriptions
    }
  }
  Ok({
    runner_mode: ios.runner_mode,
    deployment_target: ios.deployment_target,
    permissions: app.shell.permissions,
    swift_sources,
    objcxx_sources,
    resources,
    plugin_types,
    entrypoint_arg,
    status_bar: app.shell.status_bar,
    orientation: app.shell.orientation,
    fullscreen: app.shell.fullscreen,
  })
}

///|
/// Best-effort relative path computation. When the lexical paths use different
/// aliases for the same directory (for example a symlink and its real mount),
/// retry with canonical filesystem paths before failing.
fn path_relative_to(
  workspace_root : String,
  target : String,
) -> Result[String, String] {
  match
    relative_path_from_normalized(
      normalized_path(workspace_root), normalized_path(target),
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
  relative_path_from_normalized(root, candidate)
}

///|
fn relative_path_from_normalized(
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
