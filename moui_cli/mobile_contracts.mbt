///|
priv struct MobileDoctorConfig {
  schema_version : Int
  shell_api_version : Int
  runtime_abi_version : Int
  permissions : Array[String]
  plugin_paths : Array[String]
  shell_modes : Map[String, String]
}

///|
priv struct DoctorPlugin {
  id : String
  platforms : Array[String]
  permissions : Array[String]
  platform_view_kinds : Array[String]
  host_channels : Array[String]
  files : Array[PlannedFile]
}

///|
fn doctor_exact_object(
  value : Json,
  allowed : Array[String],
  required : Array[String],
  label : String,
) -> Result[Map[String, Json], String] {
  guard value is Object(fields) else {
    return Err(label + " must be an object")
  }
  for key, _ in fields {
    if !allowed.contains(key) {
      return Err(label + " contains unknown field: " + key)
    }
  }
  for key in required {
    if !fields.contains(key) {
      return Err(label + " is missing required field: " + key)
    }
  }
  Ok(fields)
}

///|
fn doctor_required_string(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Result[String, String] {
  match fields.get(key) {
    Some(String(value)) if value.trim() != "" => Ok(value)
    _ => Err(label + "." + key + " must be a non-empty string")
  }
}

///|
fn doctor_required_int(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Result[Int, String] {
  match fields.get(key) {
    Some(Number(value, repr=_)) if value.to_int().to_double() == value =>
      Ok(value.to_int())
    _ => Err(label + "." + key + " must be an integer")
  }
}

///|
fn doctor_unique_strings(
  value : Json,
  label : String,
  paths? : Bool = false,
) -> Result[Array[String], String] {
  guard value is Array(values) else { return Err(label + " must be an array") }
  let result : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for index, value in values {
    guard value is String(text) && text.trim() != "" else {
      return Err(
        label + "[" + index.to_string() + "] must be a non-empty string",
      )
    }
    if seen.contains(text) {
      return Err(label + " must not contain duplicates: " + text)
    }
    if paths {
      match validate_relative_path(text) {
        Ok(_) => ()
        Err(_) =>
          return Err(label + " contains an unsafe relative path: " + text)
      }
    }
    seen[text] = true
    result.push(text)
  }
  Ok(result)
}

///|
fn doctor_identifier(value : String, label : String) -> Result[Unit, String] {
  if value == "moui" || value.has_prefix("moui.") {
    return Err(label + " uses the reserved moui.* namespace")
  }
  if value.contains("/") || value.contains("\\") || value.contains("\u0000") {
    return Err(label + " must not contain path separators or NUL")
  }
  Ok(())
}

///|
fn numeric_dotted_version_at_least(
  value : String,
  floor_major : Int,
  floor_minor : Int,
) -> Bool {
  let components = value.split(".").to_array()
  if components.is_empty() || components.length() > 3 {
    return false
  }
  let parsed : Array[Int] = []
  for component in components {
    let component = component.to_owned()
    if component == "" || !component.all(char => char >= '0' && char <= '9') {
      return false
    }
    let number = Ref(0)
    for unit in component {
      number.val = number.val * 10 + unit.to_int() - '0'.to_int()
    }
    parsed.push(number.val)
  }
  let major = parsed[0]
  let minor = if parsed.length() > 1 { parsed[1] } else { 0 }
  major > floor_major || (major == floor_major && minor >= floor_minor)
}

///|
fn validate_mobile_platform_config(
  platform : String,
  value : Json,
) -> Result[String, String] {
  let (allowed, required) = match platform {
    "android" =>
      (
        ["applicationId", "shellMode", "minSdk"],
        ["applicationId", "shellMode", "minSdk"],
      )
    "ios" =>
      (
        ["bundleId", "productName", "shellMode", "deploymentTarget"],
        ["bundleId", "productName", "shellMode", "deploymentTarget"],
      )
    "harmonyos" =>
      (
        [
          "bundleName", "productName", "appName", "moduleName", "moduleDescription",
          "entryDescription", "shellMode", "compatibleSdkVersion",
        ],
        ["bundleName", "productName", "shellMode", "compatibleSdkVersion"],
      )
    _ => return Err("unsupported mobile platform: " + platform)
  }
  let label = "mobile.json." + platform
  let fields = match doctor_exact_object(value, allowed, required, label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let mode = match doctor_required_string(fields, "shellMode", label) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if mode != "managed" && mode != "ejected" {
    return Err(label + ".shellMode must be managed or ejected")
  }
  match platform {
    "android" => {
      match doctor_required_string(fields, "applicationId", label) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      let minimum = match doctor_required_int(fields, "minSdk", label) {
        Ok(result) => result
        Err(message) => return Err(message)
      }
      if minimum < 23 {
        return Err(label + ".minSdk must be at least 23")
      }
    }
    "ios" => {
      for key in ["bundleId", "productName"] {
        match doctor_required_string(fields, key, label) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
      let deployment = match
        doctor_required_string(fields, "deploymentTarget", label) {
        Ok(result) => result
        Err(message) => return Err(message)
      }
      if !numeric_dotted_version_at_least(deployment, 15, 0) {
        return Err(label + ".deploymentTarget must be at least 15.0")
      }
    }
    "harmonyos" => {
      for key in ["bundleName", "productName"] {
        match doctor_required_string(fields, key, label) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
      for
        key in [
          "appName", "moduleName", "moduleDescription", "entryDescription",
        ] {
        match fields.get(key) {
          Some(String(value)) if value.trim() != "" => ()
          Some(_) =>
            return Err(label + "." + key + " must be a non-empty string")
          None => ()
        }
      }
      let compatible = match
        doctor_required_int(fields, "compatibleSdkVersion", label) {
        Ok(result) => result
        Err(message) => return Err(message)
      }
      if compatible < 20 {
        return Err(label + ".compatibleSdkVersion must be at least 20")
      }
    }
    _ => ()
  }
  Ok(mode)
}

///|
fn read_mobile_doctor_config(
  project_root : String,
) -> Result[MobileDoctorConfig, String] {
  let path = join_path(project_root, "mobile.json")
  let text = @fs.read_file_to_string(path) catch {
    _ => return Err("mobile config not found: " + path)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("mobile.json is invalid JSON")
  }
  let fields = match
    doctor_exact_object(
      parsed,
      [
        "schemaVersion", "id", "displayName", "artifactName", "appPackage", "shellApiVersion",
        "runtimeAbiVersion", "mobile", "android", "ios", "harmonyos",
      ],
      [
        "schemaVersion", "id", "displayName", "artifactName", "appPackage", "shellApiVersion",
        "runtimeAbiVersion", "mobile",
      ],
      "mobile.json",
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  for key in ["id", "displayName", "artifactName", "appPackage"] {
    match doctor_required_string(fields, key, "mobile.json") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  let schema_version = match
    doctor_required_int(fields, "schemaVersion", "mobile.json") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let shell_api_version = match
    doctor_required_int(fields, "shellApiVersion", "mobile.json") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let runtime_abi_version = match
    doctor_required_int(fields, "runtimeAbiVersion", "mobile.json") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let mobile_value = fields.get("mobile").unwrap()
  let mobile = match
    doctor_exact_object(
      mobile_value,
      [
        "renderer", "systemUi", "orientation", "resources", "permissions", "plugins",
      ],
      [
        "renderer", "systemUi", "orientation", "resources", "permissions", "plugins",
      ],
      "mobile.json.mobile",
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let renderer = match
    doctor_required_string(mobile, "renderer", "mobile.json.mobile") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if !["auto", "skia-gpu", "skia-raster"].contains(renderer) {
    return Err(
      "mobile.json.mobile.renderer must be auto, skia-gpu, or skia-raster",
    )
  }
  let orientation = match
    doctor_required_string(mobile, "orientation", "mobile.json.mobile") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if !["any", "portrait", "landscape"].contains(orientation) {
    return Err(
      "mobile.json.mobile.orientation must be any, portrait, or landscape",
    )
  }
  let system_ui = match
    doctor_exact_object(
      mobile.get("systemUi").unwrap(),
      ["fullscreen", "statusBar"],
      ["fullscreen", "statusBar"],
      "mobile.json.mobile.systemUi",
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  guard system_ui.get("fullscreen") is Some(True | False) else {
    return Err("mobile.json.mobile.systemUi.fullscreen must be a boolean")
  }
  let status_bar = match
    doctor_required_string(
      system_ui, "statusBar", "mobile.json.mobile.systemUi",
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if !["auto", "visible", "hidden"].contains(status_bar) {
    return Err(
      "mobile.json.mobile.systemUi.statusBar must be auto, visible, or hidden",
    )
  }
  let resources = match
    doctor_unique_strings(
      mobile.get("resources").unwrap(),
      "mobile.json.mobile.resources",
      paths=true,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  for resource in resources {
    let path = join_path(project_root, resource)
    if (!path_is_file(path) && !path_is_dir(path)) ||
      path_is_symlink(path) ||
      !path_resolves_within(project_root, path) {
      return Err(
        "mobile.json.mobile.resources path is missing or unsafe: " + resource,
      )
    }
  }
  let permissions = match
    doctor_unique_strings(
      mobile.get("permissions").unwrap(),
      "mobile.json.mobile.permissions",
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let plugin_paths = match
    doctor_unique_strings(
      mobile.get("plugins").unwrap(),
      "mobile.json.mobile.plugins",
      paths=true,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let shell_modes : Map[String, String] = Map([])
  for platform in ["android", "ios", "harmonyos"] {
    match fields.get(platform) {
      Some(value) => {
        let mode = match validate_mobile_platform_config(platform, value) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        shell_modes[platform] = mode
      }
      None => ()
    }
  }
  if shell_modes.is_empty() {
    return Err("mobile.json must configure at least one mobile platform")
  }
  Ok({
    schema_version,
    shell_api_version,
    runtime_abi_version,
    permissions,
    plugin_paths,
    shell_modes,
  })
}

///|
fn plugin_file_extension(path : String) -> String {
  let name = base_name(path)
  let dot = Ref(-1)
  for index in 0..<name.length() {
    if name[index] == '.' {
      dot.val = index
    }
  }
  if dot.val < 0 {
    ""
  } else {
    name[dot.val:].to_owned().to_lower()
  }
}

///|
fn plugin_path_contains_component(path : String, component : String) -> Bool {
  normalized_path(path).split("/").any(part => part == component)
}

///|
fn validate_plugin_tree(
  manifest_path : String,
  files : Array[PlannedFile],
) -> Result[Unit, String] {
  let forbidden = [
    "CMakeLists.txt", "Package.swift", "Podfile", "build-profile.json5", "build.gradle",
    "build.gradle.kts", "hvigorfile.ts", "hvigor-config.json5", "oh-package.json5",
    "package.json", "settings.gradle", "settings.gradle.kts",
  ]
  let native_extensions = [
    ".a", ".aar", ".dylib", ".jar", ".klib", ".so", ".swiftmodule",
  ]
  for file in files {
    if file.path == base_name(manifest_path) {
      continue
    }
    let name = base_name(file.path)
    let extension = plugin_file_extension(name)
    if forbidden.contains(name) ||
      name.has_suffix(".cmake") ||
      name.has_suffix(".gradle") {
      return Err(
        "managed plugin contains a build/dependency script: " + file.path,
      )
    }
    if native_extensions.contains(extension) ||
      plugin_path_contains_component(file.path, "jniLibs") ||
      file.path.contains(".framework/") ||
      file.path.contains(".xcframework/") {
      return Err("managed plugin contains a native dependency: " + file.path)
    }
  }
  Ok(())
}

///|
fn validate_plugin_path_tree(
  plugin_root : String,
  relative? : String = "",
) -> Result[Unit, String] {
  let directory = if relative == "" {
    plugin_root
  } else {
    join_path(plugin_root, relative)
  }
  let entries : Array[String] = @fs.read_dir(directory) catch {
    _ => return Err("could not read plugin directory: " + directory)
  }
  for name in entries {
    let child_relative = if relative == "" {
      name
    } else {
      relative + "/" + name
    }
    let child = join_path(plugin_root, child_relative)
    if path_is_symlink(child) {
      return Err("managed plugin symlinks are not allowed: " + child_relative)
    }
    if !path_resolves_within(plugin_root, child) {
      return Err("managed plugin path escapes its root: " + child_relative)
    }
    if path_is_dir(child) {
      match validate_plugin_path_tree(plugin_root, relative=child_relative) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok(())
}

///|
fn plugin_source_extensions(platform : String) -> Array[String] {
  match platform {
    "android" => [".kt", ".java"]
    "ios" => [".swift", ".mm", ".h", ".hpp"]
    "harmonyos" => [".ets", ".ts"]
    _ => []
  }
}

///|
fn validate_plugin_source_path(
  plugin_root : String,
  relative : String,
  platform : String,
  label : String,
) -> Result[Unit, String] {
  match validate_relative_path(relative) {
    Ok(_) => ()
    Err(_) => return Err(label + " contains an unsafe path: " + relative)
  }
  let path = join_path(plugin_root, relative)
  if !path_is_file(path) && !path_is_dir(path) {
    return Err(label + " path does not exist: " + relative)
  }
  if path_is_symlink(path) || !path_resolves_within(plugin_root, path) {
    return Err(label + " path escapes the plugin root: " + relative)
  }
  let files = if path_is_dir(path) {
    match collect_template_files(path) {
      Ok(result) => result
      Err(message) => return Err(message)
    }
  } else {
    let bytes = @fs.read_file_to_bytes(path) catch {
      _ => return Err("could not read plugin source: " + path)
    }
    [{ path: base_name(path), bytes }]
  }
  let allowed = plugin_source_extensions(platform)
  for file in files {
    let extension = plugin_file_extension(file.path)
    if !allowed.contains(extension) {
      return Err(
        label + " has unsupported " + platform + " source: " + file.path,
      )
    }
  }
  Ok(())
}

///|
fn read_doctor_plugin(
  project_root : String,
  manifest_relative : String,
) -> Result[DoctorPlugin, String] {
  match validate_relative_path(manifest_relative) {
    Ok(_) => ()
    Err(_) => return Err("plugin manifest path is unsafe: " + manifest_relative)
  }
  if base_name(manifest_relative) != "moui.plugin.json" {
    return Err(
      "plugin manifest must be named moui.plugin.json: " + manifest_relative,
    )
  }
  let manifest_path = join_path(project_root, manifest_relative)
  if path_is_symlink(manifest_path) ||
    !path_resolves_within(project_root, manifest_path) {
    return Err("plugin manifest escapes the workspace: " + manifest_relative)
  }
  let plugin_root = parent_dir(manifest_path)
  let text = @fs.read_file_to_string(manifest_path) catch {
    _ => return Err("plugin manifest could not be read: " + manifest_relative)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("plugin manifest is invalid JSON: " + manifest_relative)
  }
  let fields = match
    doctor_exact_object(
      parsed,
      [
        "schemaVersion", "id", "shellApi", "platforms", "platformViewKinds", "hostChannels",
        "permissions",
      ],
      [
        "schemaVersion", "id", "shellApi", "platforms", "platformViewKinds", "hostChannels",
        "permissions",
      ],
      manifest_relative,
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let schema_version = match
    doctor_required_int(fields, "schemaVersion", manifest_relative) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let shell_api = match
    doctor_required_int(fields, "shellApi", manifest_relative) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if schema_version != 1 || shell_api != 1 {
    return Err(manifest_relative + " requires schemaVersion=1 and shellApi=1")
  }
  let id = match doctor_required_string(fields, "id", manifest_relative) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  match doctor_identifier(id, manifest_relative + ".id") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let platform_fields = match
    doctor_exact_object(
      fields.get("platforms").unwrap(),
      ["android", "ios", "harmonyos"],
      [],
      manifest_relative + ".platforms",
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if platform_fields.is_empty() {
    return Err(
      manifest_relative + ".platforms must configure at least one platform",
    )
  }
  let platforms : Array[String] = []
  for platform in ["android", "ios", "harmonyos"] {
    match platform_fields.get(platform) {
      Some(value) => {
        let label = manifest_relative + ".platforms." + platform
        let config = match
          doctor_exact_object(
            value,
            ["sources", "resources", "entry"],
            ["sources", "resources", "entry"],
            label,
          ) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        let sources = match
          doctor_unique_strings(
            config.get("sources").unwrap(),
            label + ".sources",
            paths=true,
          ) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        if sources.is_empty() {
          return Err(label + ".sources must not be empty")
        }
        for source in sources {
          match
            validate_plugin_source_path(
              plugin_root,
              source,
              platform,
              label + ".sources",
            ) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        }
        let resources = match
          doctor_unique_strings(
            config.get("resources").unwrap(),
            label + ".resources",
            paths=true,
          ) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        for resource in resources {
          let path = join_path(plugin_root, resource)
          if !path_is_file(path) && !path_is_dir(path) {
            return Err(label + ".resources path does not exist: " + resource)
          }
          if path_is_symlink(path) || !path_resolves_within(plugin_root, path) {
            return Err(
              label + ".resources path escapes the plugin root: " + resource,
            )
          }
        }
        match doctor_required_string(config, "entry", label) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        platforms.push(platform)
      }
      None => ()
    }
  }
  let platform_view_kinds = match
    doctor_unique_strings(
      fields.get("platformViewKinds").unwrap(),
      manifest_relative + ".platformViewKinds",
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let host_channels = match
    doctor_unique_strings(
      fields.get("hostChannels").unwrap(),
      manifest_relative + ".hostChannels",
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let permissions = match
    doctor_unique_strings(
      fields.get("permissions").unwrap(),
      manifest_relative + ".permissions",
    ) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  for
    pair in [
      ("platformViewKinds", platform_view_kinds),
      ("hostChannels", host_channels),
      ("permissions", permissions),
    ] {
    let (label, values) = pair
    for value in values {
      match doctor_identifier(value, manifest_relative + "." + label) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  match validate_plugin_path_tree(plugin_root) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let files = match collect_template_files(plugin_root) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  match validate_plugin_tree(manifest_path, files) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok({ id, platforms, permissions, platform_view_kinds, host_channels, files })
}

///|
fn read_doctor_plugins(
  project_root : String,
  config : MobileDoctorConfig,
) -> Result[Array[DoctorPlugin], String] {
  let plugins : Array[DoctorPlugin] = []
  let ids : Map[String, Bool] = Map([])
  let views : Map[String, String] = Map([])
  let channels : Map[String, String] = Map([])
  for path in config.plugin_paths {
    let plugin = match read_doctor_plugin(project_root, path) {
      Ok(result) => result
      Err(message) => return Err(message)
    }
    if ids.contains(plugin.id) {
      return Err("mobile.json contains duplicate plugin id: " + plugin.id)
    }
    ids[plugin.id] = true
    for permission in plugin.permissions {
      if !config.permissions.contains(permission) {
        return Err(
          "plugin " +
          plugin.id +
          " requires undeclared permission: " +
          permission,
        )
      }
    }
    for kind in plugin.platform_view_kinds {
      match views.get(kind) {
        Some(owner) =>
          return Err(
            "PlatformView kind " +
            kind +
            " is declared by " +
            owner +
            " and " +
            plugin.id,
          )
        None => views[kind] = plugin.id
      }
    }
    for channel in plugin.host_channels {
      match channels.get(channel) {
        Some(owner) =>
          return Err(
            "Host Service channel " +
            channel +
            " is declared by " +
            owner +
            " and " +
            plugin.id,
          )
        None => channels[channel] = plugin.id
      }
    }
    plugins.push(plugin)
  }
  Ok(plugins)
}

///|
fn plugin_digest_plan(plugins : Array[DoctorPlugin]) -> Array[PlannedFile] {
  let files : Array[PlannedFile] = []
  for index, plugin in plugins {
    for file in plugin.files {
      files.push({
        path: index.to_string() + "/" + file.path,
        bytes: file.bytes,
      })
    }
  }
  files
}

///|
fn doctor_plugins_digest(plugins : Array[DoctorPlugin]) -> String {
  file_plan_digest(plugin_digest_plan(plugins))
}

///|
fn plugin_snapshot_plan(plugins : Array[DoctorPlugin]) -> Array[PlannedFile] {
  let files : Array[PlannedFile] = []
  for plugin in plugins {
    for file in plugin.files {
      files.push({
        path: "moui/plugins/" + plugin.id + "/" + file.path,
        bytes: file.bytes,
      })
    }
  }
  files
}
