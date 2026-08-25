// Window-hosted HarmonyOS packaging.
// HarmonyOS HAP packaging now uses the window-hosted template at
// `window/modules/window/harmonyos/template/` +
// `examples/<app>/harmonyos_window_hosted` entrypoint.
//
// `build_harmonyos` generates MoonBit C, stages the window-hosted hvigor
// project template, applies app identity (bundleName / moduleName / appName),
// optionally injects a signing config, then invokes `ohpm install` +
// `hvigorw assembleHap` with the `MBW_*` env vars consumed by the template's
// `entry/src/main/cpp/CMakeLists.txt`.

///|
priv struct BuildHarmonyosOptions {
  app : MobileApp
  workspace_root : String
  skia_root : String
  arch : String
  renderer : String
  build_dir : String
  output_hap : String
  sdk_home : String?
  hvigorw : String?
  ohpm : String?
  fallback_skia : Bool
  prepare_only : Bool
  signing_config_file : String?
}

///|
/// Strip a minimal subset of JSON5 syntax from `text` so a JSON parser can
/// accept DevEco Studio's `build-profile.json5`:
///   - block comments `/* ... */`
///   - line comments `// ...` (but not `:` URLs like `https://...`)
///   - trailing commas before `}` or `]`
fn strip_json5(text : String) -> String {
  let result = StringBuilder()
  // `String::op_get` returns `UInt16` (UTF-16 code unit), but we need `Char`
  // for `StringBuilder::write_char` and `Char` literal comparisons. Convert
  // once to `Array[Char]` so all indexing yields `Char` directly. JSON5 source
  // is ASCII for the constructs we strip (comments, trailing commas), so this
  // is safe and cheap.
  let chars = text.to_array()
  let length = chars.length()
  let mut i = 0
  let mut prev_significant = ' '
  while i < length {
    let ch = chars[i]
    // Block comment
    if ch == '/' && i + 1 < length && chars[i + 1] == '*' {
      i += 2
      while i + 1 < length && !(chars[i] == '*' && chars[i + 1] == '/') {
        i += 1
      }
      i += 2
      continue
    }
    // Line comment — skip `// ...` to end of line, but only when the
    // preceding non-whitespace char is not `:`. This preserves `https://`.
    if ch == '/' && i + 1 < length && chars[i + 1] == '/' {
      if prev_significant == ':' {
        result.write_char(ch)
        i += 1
        continue
      }
      i += 2
      while i < length && chars[i] != '\n' {
        i += 1
      }
      continue
    }
    // Trailing comma before `}` or `]` (with intervening whitespace).
    if ch == ',' {
      let mut j = i + 1
      while j < length {
        let next_ch = chars[j]
        if next_ch == ' ' ||
          next_ch == '\t' ||
          next_ch == '\n' ||
          next_ch == '\r' {
          j += 1
          continue
        }
        if next_ch == '}' || next_ch == ']' {
          // Skip the comma without emitting it.
          i += 1
          break
        }
        result.write_char(ch)
        i += 1
        break
      }
      if j == length {
        // Trailing comma at EOF — drop it.
        i += 1
        continue
      }
      if i < length && chars[i] == ',' {
        // Already handled above; loop again.
        continue
      }
      continue
    }
    result.write_char(ch)
    prev_significant = if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      prev_significant
    } else {
      ch
    }
    i += 1
  }
  result.to_string()
}

///|
/// Locate the OpenHarmony OHOS CMake toolchain file under `sdk_home`.
/// Returns an empty string when the toolchain cannot be found.
fn find_ohos_toolchain(sdk_home : String) -> String {
  let candidates = [
    "native/build/cmake/ohos.toolchain.cmake", "default/openharmony/native/build/cmake/ohos.toolchain.cmake",
    "default/hms/native/build/cmake/ohos.toolchain.cmake", "openharmony/native/build/cmake/ohos.toolchain.cmake",
  ]
  for candidate in candidates {
    let path = join_path(sdk_home, candidate)
    if path_is_file(path) {
      return path
    }
  }
  // Fall back to scanning `sdk_home` recursively. We only look two levels
  // deep to avoid traversing huge SDK trees.
  let entries = @fs.read_dir(sdk_home) catch { _ => return "" }
  for entry in entries {
    let child = join_path(sdk_home, entry)
    if path_is_dir(child) {
      let target = join_path(child, "native/build/cmake/ohos.toolchain.cmake")
      if path_is_file(target) {
        return target
      }
      let sub_entries = @fs.read_dir(child) catch { _ => continue }
      for sub in sub_entries {
        let grandchild = join_path(child, sub)
        let target = join_path(
          grandchild, "native/build/cmake/ohos.toolchain.cmake",
        )
        if path_is_file(target) {
          return target
        }
      }
    }
  }
  ""
}

///|
/// Discover the HarmonyOS/OpenHarmony SDK home on macOS by scanning
/// well-known DevEco-Studio install locations.
fn find_harmonyos_sdk_home() -> String {
  let home = @env.get_env_var("HOME").unwrap_or("")
  let candidates = [
    "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony",
    "/Applications/DevEco-Studio.app/Contents/sdk/default/hms",
    join_path(home, "Library/OpenHarmony/Sdk/20"),
  ]
  for candidate in candidates {
    if find_ohos_toolchain(candidate) != "" {
      return candidate
    }
  }
  ""
}

///|
/// Discover the `hvigorw` wrapper on macOS by scanning DevEco-Studio paths.
fn find_deveco_hvigorw() -> String {
  let candidates = [
    "/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw", "/Applications/DevEco Studio.app/Contents/tools/hvigor/bin/hvigorw",
  ]
  for candidate in candidates {
    if path_is_executable(candidate) {
      return candidate
    }
  }
  ""
}

///|
/// Discover the `ohpm` executable on macOS by scanning DevEco-Studio paths.
fn find_deveco_ohpm() -> String {
  let candidates = [
    "/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm", "/Applications/DevEco Studio.app/Contents/tools/ohpm/bin/ohpm",
  ]
  for candidate in candidates {
    if path_is_executable(candidate) {
      return candidate
    }
  }
  ""
}

///|
/// Resolve the DevEco SDK root from a given `sdk_home` by walking up the
/// path tree until `default/openharmony` or `default/hms` is found.
fn find_deveco_sdk_home(sdk_home : String) -> String {
  let candidates = [
    sdk_home,
    join_path(sdk_home, ".."),
    join_path(sdk_home, "../.."),
    "/Applications/DevEco-Studio.app/Contents/sdk",
  ]
  for candidate in candidates {
    if path_is_dir(join_path(candidate, "default/openharmony")) ||
      path_is_dir(join_path(candidate, "default/hms")) {
      return candidate
    }
  }
  ""
}

///|
/// Write `value` as pretty-printed JSON to `path`.
fn write_json_file(path : String, value : Json) -> Result[Unit, String] {
  let text = value.stringify(indent=2) + "\n"
  write_file_bytes_result(path, @utf8.encode(text[:], bom=false))
}

///|
/// Read a JSON/JSON5 object file, stripping JSON5 comments/trailing commas.
fn read_json5_object(path : String) -> Result[Map[String, Json], String] {
  let text = match read_file_string_optional(path) {
    Some(value) => value
    None => return Err("could not read: " + path)
  }
  let json = @json.parse(strip_json5(text)) catch {
    _ => return Err("invalid JSON/JSON5: " + path)
  }
  guard json is Object(fields) else {
    return Err("expected object root: " + path)
  }
  Ok(fields)
}

///|
/// Update a HarmonyOS string resource `{ "string": [ { "name", "value" } ] }`.
fn update_json5_string_resource(
  path : String,
  name : String,
  value : String,
) -> Result[Unit, String] {
  let root = match read_json5_object(path) {
    Ok(fields) => fields
    Err(message) => return Err(message)
  }
  let strings = match root.get("string") {
    Some(Array(values)) => values
    _ => return Err(path + ": missing string array")
  }
  let mut found = false
  let updated : Array[Json] = []
  for item in strings {
    match item {
      Object(fields) =>
        match fields.get("name") {
          Some(String(item_name)) if item_name == name => {
            fields["value"] = Json::string(value)
            updated.push(Json::object(fields))
            found = true
          }
          _ => updated.push(item)
        }
      _ => updated.push(item)
    }
  }
  if !found {
    return Err(path + ": missing string resource " + name)
  }
  root["string"] = Json::array(updated)
  write_json_file(path, Json::object(root))
}

///|
/// Inject DevEco signing configs into a staged `build-profile.json5` from a
/// JSON fragment file. The
/// window-hosted template ships with an empty `signingConfigs` array.
fn inject_harmonyos_signing_config(
  project_dir : String,
  signing_config_file : String,
) -> Result[Unit, String] {
  if signing_config_file == "" {
    return Ok(())
  }
  if !path_is_file(signing_config_file) {
    return Err(
      "MOUI_HARMONYOS_SIGNING_CONFIG_FILE not found: " + signing_config_file,
    )
  }
  let profile_path = join_path(project_dir, "build-profile.json5")
  let profile_text = match read_file_string_optional(profile_path) {
    Some(value) => value
    None => return Err("could not read build-profile.json5: " + profile_path)
  }
  let fragment_text = match read_file_string_optional(signing_config_file) {
    Some(value) => value
    None => return Err("could not read signing config: " + signing_config_file)
  }
  let stripped_profile = strip_json5(profile_text)
  let stripped_fragment = strip_json5(fragment_text)
  let profile_json = @json.parse(stripped_profile) catch {
    _ => return Err("build-profile.json5 is not valid JSON after strip")
  }
  let fragment_json = @json.parse(stripped_fragment) catch {
    _ => return Err("signing config fragment is not valid JSON after strip")
  }
  // Extract signingConfigs array from the fragment. Accept:
  //   - an array
  //   - { signingConfigs: [...] }
  //   - { material: { ... }, name?: ..., type?: ... }
  //   - a single material object with storeFile
  let signing_configs : Array[Json] = []
  match fragment_json {
    Array(values) =>
      for value in values {
        signing_configs.push(value)
      }
    Object(fields) =>
      match fields.get("signingConfigs") {
        Some(Array(values)) =>
          for value in values {
            signing_configs.push(value)
          }
        _ =>
          match fields.get("material") {
            Some(_) => signing_configs.push(fragment_json)
            None =>
              match fields.get("storeFile") {
                Some(_) =>
                  signing_configs.push({
                    "name": Json::string("default"),
                    "type": Json::string("HarmonyOS"),
                    "material": fragment_json,
                  })
                None =>
                  return Err(
                    "MOUI_HARMONYOS_SIGNING_CONFIG must be a signingConfigs array, material object, or {signingConfigs:[...]}",
                  )
              }
          }
      }
    _ =>
      return Err("MOUI_HARMONYOS_SIGNING_CONFIG must be a JSON array or object")
  }
  // Merge into profile.app.signingConfigs.
  guard profile_json is Object(profile_root) else {
    return Err("build-profile.json5 root must be an object")
  }
  let app = match profile_root.get("app") {
    Some(Object(value)) => value
    _ => {
      let empty : Map[String, Json] = Map([])
      empty
    }
  }
  app["signingConfigs"] = Json::array(signing_configs)
  profile_root["app"] = Json::object(app)
  let updated = Json::object(profile_root).stringify(indent=2) + "\n"
  match
    write_file_bytes_result(profile_path, @utf8.encode(updated[:], bom=false)) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
/// Apply mobile app identity onto a staged window-hosted HarmonyOS template.
/// Updates bundleName, moduleName, app_name, module_desc, entry_desc and SDK
/// versions. Targets
/// the window-hosted template's file layout.
fn apply_harmonyos_window_hosted_identity(
  project_root : String,
  app : MobileApp,
  _renderer : String,
) -> Result[Unit, String] {
  let harmonyos = match app.harmonyos {
    Some(value) => value
    None => return Err("moui.mobile.json missing harmonyos section")
  }
  let bundle_name = harmonyos.bundle_name
  let module_name = match harmonyos.module_name {
    Some(value) => value
    None => "entry"
  }
  let app_name = match harmonyos.app_name {
    Some(value) => value
    None => app.display_name
  }
  let module_description = match harmonyos.module_description {
    Some(value) => value
    None => app.display_name + " HarmonyOS app"
  }
  let entry_description = match harmonyos.entry_description {
    Some(value) => value
    None => app.display_name + " HarmonyOS entry ability"
  }

  // AppScope/app.json5 → app.bundleName + vendor + version.
  let app_scope_path = join_path(project_root, "AppScope/app.json5")
  let app_scope = match read_json5_object(app_scope_path) {
    Ok(fields) => fields
    Err(message) => return Err(message)
  }
  let app_obj = match app_scope.get("app") {
    Some(Object(fields)) => fields
    _ => return Err(app_scope_path + ": missing app object")
  }
  app_obj["bundleName"] = Json::string(bundle_name)
  app_obj["vendor"] = Json::string("wzzc-dev")
  app_obj["versionCode"] = Json::number(1.0)
  app_obj["versionName"] = Json::string("0.1.0")
  app_scope["app"] = Json::object(app_obj)
  match write_json_file(app_scope_path, Json::object(app_scope)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  // Root oh-package.json5 name/description.
  let root_pkg_path = join_path(project_root, "oh-package.json5")
  let root_pkg = match read_json5_object(root_pkg_path) {
    Ok(fields) => fields
    Err(_) => {
      // Tolerate missing file: write a minimal stub.
      let fields : Map[String, Json] = Map([])
      fields
    }
  }
  root_pkg["name"] = Json::string(
    app.id.replace_all(old="_", new="-") + "-harmonyos",
  )
  root_pkg["description"] = Json::string(
    app.display_name + " window-hosted HarmonyOS app",
  )
  match write_json_file(root_pkg_path, Json::object(root_pkg)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  // build-profile.json5 module name + SDK versions.
  let profile_path = join_path(project_root, "build-profile.json5")
  let profile = match read_json5_object(profile_path) {
    Ok(fields) => fields
    Err(message) => return Err(message)
  }
  let modules = match profile.get("modules") {
    Some(Array(values)) => values
    _ => return Err(profile_path + ": missing modules array")
  }
  if modules.length() != 1 {
    return Err(
      profile_path + ": window-hosted template must contain one entry module",
    )
  }
  let module0 = match modules[0] {
    Object(fields) => fields
    _ => return Err(profile_path + ": modules[0] must be an object")
  }
  module0["name"] = Json::string(module_name)
  profile["modules"] = Json::array([Json::object(module0)])
  let compatible_sdk = if harmonyos.compatible_sdk_version == 20 {
    "6.0.0(20)"
  } else {
    "6.0.1(21)"
  }
  match profile.get("app") {
    Some(Object(app_fields)) =>
      match app_fields.get("products") {
        Some(Array(products)) => {
          let updated_products : Array[Json] = []
          for product in products {
            match product {
              Object(pfields) => {
                pfields["targetSdkVersion"] = Json::string("6.0.1(21)")
                pfields["compatibleSdkVersion"] = Json::string(compatible_sdk)
                updated_products.push(Json::object(pfields))
              }
              _ => updated_products.push(product)
            }
          }
          app_fields["products"] = Json::array(updated_products)
          profile["app"] = Json::object(app_fields)
        }
        _ => ()
      }
    _ => ()
  }
  match write_json_file(profile_path, Json::object(profile)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  // entry/src/main/module.json5 module.name
  let module_path = join_path(project_root, "entry/src/main/module.json5")
  let module_root = match read_json5_object(module_path) {
    Ok(fields) => fields
    Err(message) => return Err(message)
  }
  let module_obj = match module_root.get("module") {
    Some(Object(fields)) => fields
    _ => return Err(module_path + ": missing module object")
  }
  module_obj["name"] = Json::string(module_name)
  module_root["module"] = Json::object(module_obj)
  match write_json_file(module_path, Json::object(module_root)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  // entry/oh-package.json5
  let entry_pkg_path = join_path(project_root, "entry/oh-package.json5")
  let entry_pkg = match read_json5_object(entry_pkg_path) {
    Ok(fields) => fields
    Err(_) => {
      let fields : Map[String, Json] = Map([])
      fields
    }
  }
  entry_pkg["name"] = Json::string(module_name)
  entry_pkg["description"] = Json::string(
    app.display_name + " window-hosted entry module",
  )
  match write_json_file(entry_pkg_path, Json::object(entry_pkg)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  // String resources (display name + descriptions).
  match
    update_json5_string_resource(
      join_path(project_root, "AppScope/resources/base/element/string.json"),
      "app_name",
      app_name,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let entry_strings = join_path(
    project_root, "entry/src/main/resources/base/element/string.json",
  )
  match update_json5_string_resource(entry_strings, "app_name", app_name) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    update_json5_string_resource(
      entry_strings, "module_desc", module_description,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    update_json5_string_resource(entry_strings, "entry_desc", entry_description) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  log_info(
    "[moui-window-hosted-harmonyos] Applied identity bundleName=" +
    bundle_name +
    " moduleName=" +
    module_name,
  )
  Ok(())
}

///|
/// Stage the window-hosted HarmonyOS template into `target_project` and
/// write the `.moui-window-hosted-stage` marker so future runs can replace
/// it safely.
fn stage_harmonyos_window_hosted_project(
  template_root : String,
  target_project : String,
) -> Result[Unit, String] {
  let stage_marker = join_path(target_project, ".moui-window-hosted-stage")
  if path_is_dir(target_project) && !path_is_file(stage_marker) {
    return Err(
      "refusing to replace an unowned HarmonyOS project: " + target_project,
    )
  }
  remove_tree(target_project)
  match mkdir_p(target_project) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match copy_tree(template_root, target_project) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match write_file_bytes_result(stage_marker, b"") {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
/// Build the HarmonyOS HAP archive using the window-hosted template.
fn build_harmonyos(
  options : BuildHarmonyosOptions,
  host : HostPlatform,
) -> Result[BuildResult, String] {
  let _ = host
  // Make build_dir + workspace_root absolute so MBW_* env vars consumed by
  // CMake (which runs with cwd=<hvigor-project>) resolve correctly regardless
  // of the user's original cwd. hvigorw spawns CMake in a child cwd, so any
  // relative path passed via env vars would fail `EXISTS` checks.
  let workspace_root_abs = make_absolute(
    options.workspace_root,
    @env.get_env_var("PWD").unwrap_or("."),
  )
  let build_dir_abs = make_absolute(options.build_dir, workspace_root_abs)
  // 2. Resolve the upstream window package root and template.
  let window_root = window_package_root(workspace_root_abs)
  let template_root = window_template_root(workspace_root_abs, "harmonyos")
  if !path_is_file(
      join_path(template_root, "entry/src/main/cpp/CMakeLists.txt"),
    ) ||
    !path_is_file(join_path(template_root, "build-profile.json5")) ||
    !path_is_file(join_path(template_root, "oh-package.json5")) {
    return Err(
      "MoUI window-hosted HarmonyOS template is incomplete: " + template_root,
    )
  }
  // 3. Generate MoonBit C from the entrypoint package.
  let entrypoint_package = match
    mobile_entrypoint_package(
      options.app.metadata_path,
      "harmonyos",
      workspace_root_abs,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let moonbit_c = match
    generate_moonbit_c(
      workspace_root_abs,
      entrypoint_package,
      base_name(entrypoint_package) + ".c",
      build_dir_abs,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !path_is_file(moonbit_c) {
    return Err("MoonBit generated C was not found: " + moonbit_c)
  }
  // Resolve real Skia (same contract as Android/iOS). Stub-only builds present
  // a black XComponent because moonbit_skia_available() returns 0.
  let renderer_selected = if options.fallback_skia {
    "skia-raster"
  } else if options.renderer == "skia-raster" {
    "skia-raster"
  } else {
    "skia-gpu"
  }
  // HarmonyOS auto/skia-gpu must use static: locked libskia.so hides Ganesh
  // symbols required by libskia_ganesh_ext.a (see docs/examples.md).
  let link_mode = @env.get_env_var("MOUI_SKIA_LINK_MODE").unwrap_or_else(() => {
    if renderer_selected == "skia-gpu" {
      "static"
    } else {
      "dynamic"
    }
  })
  let gpu_env : Array[(String, String)] = if renderer_selected == "skia-gpu" {
    [("MOUI_SKIA_ENABLE_GPU_EGL", "1")]
  } else {
    []
  }
  let skia_root_abs = make_absolute(options.skia_root, workspace_root_abs)
  let skia_link = match
    resolve_skia(
      skia_root_abs,
      "harmonyos",
      options.arch,
      link_mode,
      options.fallback_skia,
      gpu_env,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let native_dir = join_path(build_dir_abs, "native")
  let skia_cxx_rsp = join_path(native_dir, "skia-cxx-flags.rsp")
  let skia_link_rsp = join_path(native_dir, "skia-link-flags.rsp")
  match write_rsp(skia_cxx_rsp, skia_link.stub_flags) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match write_rsp(skia_link_rsp, skia_link.link_flags) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // 4. Stage the window-hosted template into <build_dir>/hvigor-project.
  let hvigor_project_dir = join_path(build_dir_abs, "hvigor-project")
  match
    stage_harmonyos_window_hosted_project(template_root, hvigor_project_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    apply_harmonyos_window_hosted_identity(
      hvigor_project_dir,
      options.app,
      options.renderer,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    inject_harmonyos_signing_config(
      hvigor_project_dir,
      options.signing_config_file.unwrap_or(""),
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // Clean stale Hvigor state.
  for
    stale in [
      ".hvigor", "build", "entry/build", "oh_modules", "entry/oh_modules", "oh-package-lock.json5",
      "entry/oh-package-lock.json5",
    ] {
    remove_tree(join_path(hvigor_project_dir, stale))
  }
  if options.prepare_only {
    log_info(
      "[moui-window-hosted-harmonyos] Prepared " +
      build_dir_abs +
      " (moonbit_c=" +
      moonbit_c +
      ")",
    )
    return Ok({ build_dir: build_dir_abs, output_artifact: "" })
  }
  // 5. Resolve SDK home + hvigorw + ohpm.
  let requested_sdk_home = match options.sdk_home {
    Some(value) => value
    None =>
      match @env.get_env_var("HARMONYOS_SDK_HOME") {
        Some(value) => value
        None => @env.get_env_var("OHOS_SDK_HOME").unwrap_or("")
      }
  }
  let sdk_home = if requested_sdk_home != "" &&
    find_ohos_toolchain(requested_sdk_home) != "" {
    requested_sdk_home
  } else {
    let discovered = find_harmonyos_sdk_home()
    if discovered != "" {
      discovered
    } else {
      requested_sdk_home
    }
  }
  if sdk_home == "" {
    return Err(
      "HARMONYOS_SDK_HOME or OHOS_SDK_HOME must point at a HarmonyOS/OpenHarmony SDK. Use --sdk-home to pass it explicitly.",
    )
  }
  if find_ohos_toolchain(sdk_home) == "" {
    return Err("HarmonyOS native CMake toolchain not found under " + sdk_home)
  }
  let hvigorw = match options.hvigorw {
    Some(value) =>
      if path_is_absolute(value) {
        value
      } else {
        join_path(workspace_root_abs, value)
      }
    None =>
      match @env.get_env_var("HVIGORW") {
        Some(value) => value
        None => find_deveco_hvigorw()
      }
  }
  if hvigorw == "" || !path_is_executable(hvigorw) {
    return Err(
      "Hvigor wrapper not found. Pass --hvigorw or set HVIGORW for HarmonyOS builds.",
    )
  }
  let ohpm = match options.ohpm {
    Some(value) =>
      if path_is_absolute(value) {
        value
      } else {
        join_path(workspace_root_abs, value)
      }
    None =>
      match @env.get_env_var("OHPM") {
        Some(value) => value
        None => find_deveco_ohpm()
      }
  }
  if ohpm == "" || !path_is_executable(ohpm) {
    return Err(
      "ohpm executable not found. Pass --ohpm or set OHPM for HarmonyOS builds.",
    )
  }
  let deveco_sdk_home = find_deveco_sdk_home(sdk_home)
  if deveco_sdk_home == "" {
    return Err(
      "DevEco SDK root not found for " +
      sdk_home +
      ". Set DEVECO_SDK_HOME or pass --sdk-home under DevEco Studio's sdk tree.",
    )
  }
  // 6. ohpm install.
  let ohpm_env = moon_build_env()
  ohpm_env.push(("DEVECO_SDK_HOME", deveco_sdk_home))
  ohpm_env.push(("HARMONYOS_SDK_HOME", sdk_home))
  ohpm_env.push(("OHOS_SDK_HOME", sdk_home))
  ohpm_env.push(("OHOS_BASE_SDK_HOME", sdk_home))
  log_info(
    "[moui-window-hosted-harmonyos] Installing project dependencies with ohpm",
  )
  match
    process_exec_argv(
      [ohpm, "install", "--all", "--no-link"],
      cwd=hvigor_project_dir,
      env=ohpm_env,
      capture=false,
    ) {
    Ok(result) if result.exit_code == 0 => ()
    Ok(result) =>
      return Err(
        "ohpm install failed (exit " + result.exit_code.to_string() + ")",
      )
    Err(message) => return Err(message)
  }
  // 7. hvigorw assembleHap with MBW_* env vars consumed by the template's
  //    entry/src/main/cpp/CMakeLists.txt.
  let moon_home = make_absolute(
    @env.get_env_var("MOON_HOME").unwrap_or_else(() => {
      let home = @env.get_env_var("HOME").unwrap_or("")
      join_path(home, ".moon")
    }),
    workspace_root_abs,
  )
  let hvigor_env = moon_build_env()
  hvigor_env.push(("DEVECO_SDK_HOME", deveco_sdk_home))
  hvigor_env.push(("HARMONYOS_SDK_HOME", sdk_home))
  hvigor_env.push(("OHOS_SDK_HOME", sdk_home))
  hvigor_env.push(("OHOS_BASE_SDK_HOME", sdk_home))
  hvigor_env.push(("MBW_WORKSPACE_ROOT", workspace_root_abs))
  hvigor_env.push(("MBW_WINDOW_ROOT", window_root))
  hvigor_env.push(("MBW_MOON_HOME", moon_home))
  hvigor_env.push(("MBW_MOONBIT_C", moonbit_c))
  hvigor_env.push(("MBW_SKIA_CXX_RSP", skia_cxx_rsp))
  hvigor_env.push(("MBW_SKIA_LINK_RSP", skia_link_rsp))
  // Do not force MOUI_SKIA_DISABLE_PREBUILD_SKIA here: CMake already consumes
  // resolved rsp flags. Stripping disable is handled inside resolve_skia.
  log_info(
    "[moui-window-hosted-harmonyos] Building installable HAP with Hvigor (skia=" +
    renderer_selected +
    " link_mode=" +
    link_mode +
    ")",
  )
  match
    process_exec_argv(
      [hvigorw, "--no-daemon", "assembleHap"],
      cwd=hvigor_project_dir,
      env=hvigor_env,
      capture=false,
    ) {
    Ok(result) if result.exit_code == 0 => ()
    Ok(result) =>
      return Err(
        "hvigorw assembleHap failed (exit " + result.exit_code.to_string() + ")",
      )
    Err(message) => return Err(message)
  }
  // 8. Locate the produced HAP and copy it to options.output_hap.
  let hap_search_dir = join_path(hvigor_project_dir, "entry/build")
  let built_hap = find_first_file_with_suffix(hap_search_dir, "-signed.hap")
  let built_hap = if built_hap != "" {
    built_hap
  } else {
    find_first_file_with_suffix(hap_search_dir, ".hap")
  }
  if built_hap == "" {
    return Err("Hvigor did not produce a HAP under " + hap_search_dir)
  }
  match mkdir_p(parent_dir(options.output_hap)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match copy_file_atomic(built_hap, options.output_hap) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  log_info(
    "[moui-window-hosted-harmonyos] Wrote HAP archive " + options.output_hap,
  )
  log_info(
    "This is build/install evidence only until a device or emulator smoke proves first frame, input, resize, lifecycle, and real Skia present.",
  )
  Ok({ build_dir: build_dir_abs, output_artifact: options.output_hap })
}

///|
/// Walk `root` recursively looking for the first file whose name ends with
/// `suffix`. Returns an empty string when no match is found.
fn find_first_file_with_suffix(root : String, suffix : String) -> String {
  let entries = @fs.read_dir(root) catch { _ => return "" }
  for entry in entries {
    let path = join_path(root, entry)
    if path_is_dir(path) {
      let found = find_first_file_with_suffix(path, suffix)
      if found != "" {
        return found
      }
    } else if path_is_file(path) && entry.has_suffix(suffix) {
      return path
    }
  }
  ""
}
