// HarmonyOS build glue. Migrates `moui_shell/scripts/build-harmonyos-hap.sh`
// (540 lines) into MoonBit.
//
// `build_harmonyos` prepares the native build inputs (M5), stages the
// managed hvigor project template or validates the ejected shell lock
// (M9.1), injects signing configs, then either invokes `ohpm install` +
// `hvigorw assembleHap` (non-fallback) or `cmake` + `zip` (fallback).

///|
priv struct BuildHarmonyosOptions {
  app : ShellApp
  harmonyos_project : String?
  app_config : String
  workspace_root : String
  project_root : String
  moui_root : String
  skia_root : String
  arch : String
  renderer : String
  build_dir : String
  output_hap : String
  sdk_home : String?
  hvigorw : String?
  ohpm : String?
  fallback_skia : Bool
  ejected_shell : Bool
  prepare_only : Bool
  signing_config_file : String?
}

///|
/// Strip a minimal subset of JSON5 syntax from `text` so a JSON parser can
/// accept DevEco Studio's `build-profile.json5`:
///   - block comments `/* ... */`
///   - line comments `// ...` (but not `:` URLs like `https://...`)
///   - trailing commas before `}` or `]`
/// Mirrors the inline Node helper at lines 234-250 of
/// `build-harmonyos-hap.sh::inject_harmonyos_signing_config`.
fn strip_json5(text : String) -> String {
  let result = StringBuilder::new()
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
/// Stage the HarmonyOS project tree by copying the canonical project layout
/// (AppScope/build-profile.json5/hvigor/hvigorfile.ts/oh-package.json5/entry/*)
/// from `source` to `target`. Mirrors `stage_harmonyos_project`.
fn stage_harmonyos_project(
  source : String,
  target : String,
) -> Result[Unit, String] {
  remove_tree(target)
  match mkdir_p(join_path(target, "entry")) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let items = [
    "AppScope", "build-profile.json5", "hvigor", "hvigorfile.ts", "oh-package.json5",
  ]
  for item in items {
    let from = join_path(source, item)
    let to = join_path(target, item)
    if path_is_dir(from) {
      match mkdir_p(to) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      match copy_tree(from, to) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    } else if path_is_file(from) {
      match read_file_bytes_optional(from) {
        Some(bytes) =>
          match write_file_bytes_result(to, bytes) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        None => return Err("could not read file: " + from)
      }
    }
  }
  // entry/* items
  let entry_items = [
    "build-profile.json5", "hvigorfile.ts", "obfuscation-rules.txt", "oh-package.json5",
    "src",
  ]
  for item in entry_items {
    let from = join_path(join_path(source, "entry"), item)
    let to = join_path(join_path(target, "entry"), item)
    if path_is_dir(from) {
      match mkdir_p(to) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      match copy_tree(from, to) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    } else if path_is_file(from) {
      match read_file_bytes_optional(from) {
        Some(bytes) =>
          match write_file_bytes_result(to, bytes) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        None => return Err("could not read file: " + from)
      }
    }
  }
  Ok(())
}

///|
/// Inject DevEco signing configs into a staged `build-profile.json5` from a
/// JSON fragment file. Mirrors `inject_harmonyos_signing_config`.
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
/// Apply shell.json identity onto a staged managed HarmonyOS template.
/// Mirrors `moui_shell/harmonyos/runner/resolve-shell.mjs` for the fields
/// required for correct package install + `aa start`.
fn apply_harmonyos_managed_identity(
  project_root : String,
  app : ShellApp,
  renderer : String,
) -> Result[Unit, String] {
  let harmonyos = match app.harmonyos {
    Some(value) => value
    None => return Err("shell.json missing harmonyos section")
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

  // AppScope/app.json5 → app.bundleName
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
  app_scope["app"] = Json::object(app_obj)
  match write_json_file(app_scope_path, Json::object(app_scope)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  // Root oh-package.json5 name/description.
  let root_pkg_path = join_path(project_root, "oh-package.json5")
  let root_pkg = match read_json5_object(root_pkg_path) {
    Ok(fields) => fields
    Err(message) => return Err(message)
  }
  root_pkg["name"] = Json::string(
    app.id.replace_all(old="_", new="-") + "-harmonyos",
  )
  root_pkg["description"] = Json::string(
    app.display_name + " managed HarmonyOS shell",
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
      profile_path + ": canonical shell must contain one entry module",
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
    Err(message) => return Err(message)
  }
  entry_pkg["name"] = Json::string(module_name)
  entry_pkg["description"] = Json::string(
    app.display_name + " managed entry module",
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
    project_root,
    "entry/src/main/resources/base/element/string.json",
  )
  match update_json5_string_resource(entry_strings, "app_name", app_name) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    update_json5_string_resource(
      entry_strings,
      "module_desc",
      module_description,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    update_json5_string_resource(
      entry_strings,
      "entry_desc",
      entry_description,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  // Generated ETS config consumed by EntryAbility.
  let app_argument = "moui-" +
    app.id.replace_all(old="_", new="-") +
    "-harmonyos"
  let fullscreen_lit = if app.shell.fullscreen { "true" } else { "false" }
  let generated = StringBuilder::new()
  generated.write_string(
    "// Generated by moui_cli managed HarmonyOS staging.\n",
  )
  generated.write_string("export interface MoUIGeneratedConfiguration {\n")
  generated.write_string("  appArgument: string;\n")
  generated.write_string("  renderer: string;\n")
  generated.write_string("  fullscreen: boolean;\n")
  generated.write_string("  statusBar: string;\n")
  generated.write_string("  orientation: string;\n")
  generated.write_string("}\n\n")
  generated.write_string(
    "export const mouiGeneratedConfiguration: MoUIGeneratedConfiguration = {\n",
  )
  generated.write_string(
    "  appArgument: \"" + moon_string(app_argument) + "\",\n",
  )
  generated.write_string("  renderer: \"" + moon_string(renderer) + "\",\n")
  generated.write_string("  fullscreen: " + fullscreen_lit + ",\n")
  generated.write_string(
    "  statusBar: \"" + moon_string(app.shell.status_bar) + "\",\n",
  )
  generated.write_string(
    "  orientation: \"" + moon_string(app.shell.orientation) + "\"\n",
  )
  generated.write_string("};\n")
  let config_path = join_path(
    project_root,
    "entry/src/main/ets/moui/MoUIGeneratedConfig.ets",
  )
  match
    write_file_bytes_result(
      config_path,
      @utf8.encode(generated.to_string()[:], bom=false),
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  log_info(
    "[moui-shell-harmonyos] Applied managed identity bundleName=" +
    bundle_name +
    " moduleName=" +
    module_name,
  )
  Ok(())
}

///|
/// Build the HarmonyOS HAP archive. Mirrors `build-harmonyos-hap.sh`.
fn build_harmonyos(
  options : BuildHarmonyosOptions,
  host : HostPlatform,
) -> Result[BuildResult, String] {
  let _ = host
  // 1. Validate ejected lock if applicable.
  let harmonyos_project = match options.harmonyos_project {
    Some(value) =>
      if path_is_absolute(value) {
        value
      } else {
        join_path(options.workspace_root, value)
      }
    None =>
      if options.ejected_shell {
        return Err("--ejected-shell requires --harmonyos-project")
      } else {
        ""
      }
  }
  if options.ejected_shell {
    if harmonyos_project == "" ||
      !path_is_dir(join_path(harmonyos_project, "entry/src/main/cpp")) {
      return Err(
        "--ejected-shell requires --harmonyos-project with entry/src/main/cpp",
      )
    }
    let lock_path = join_path(harmonyos_project, ".moui-shell.json")
    match
      validate_ejected_lock(
        lock_path,
        "harmonyos",
        options.moui_root,
        join_path(options.moui_root, "../moui_shell"),
        options.project_root,
        options.app_config,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  // 2. Call prepare_native_build.
  let contract = match
    managed_platform_contract(
      options.app,
      "harmonyos",
      options.workspace_root,
      join_path(options.moui_root, "../moui_shell"),
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let prepare_options : PrepareOptions = {
    app: options.app,
    app_config_path: options.app_config,
    workspace_root: options.workspace_root,
    moui_root: options.moui_root,
    skia_root: options.skia_root,
    build_dir: options.build_dir,
    abi: "",
    android_shell: "",
    sdk: "",
    arch: options.arch,
    renderer: options.renderer,
    fallback_skia: options.fallback_skia,
    shell_root: join_path(options.moui_root, "../moui_shell"),
    contract,
  }
  let prepare_result = match prepare_native_build(prepare_options) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  // 3. Resolve source_project. For managed shell, stage the canonical
  // HarmonyOS template into <build_dir>/managed-shell (mirrors iOS staging
  // in build_ios.mbt). For ejected shell, use the caller-provided project.
  let source_project = if options.ejected_shell {
    harmonyos_project
  } else {
    let staged_root = join_path(options.build_dir, "managed-shell")
    let stage_marker = join_path(staged_root, ".moui-managed-harmonyos-stage")
    let template_root = join_path(
      join_path(options.moui_root, "../moui_shell"),
      "harmonyos/runner/template",
    )
    if !path_is_file(
        join_path(template_root, "entry/src/main/cpp/CMakeLists.txt"),
      ) ||
      !path_is_file(
        join_path(template_root, "build-profile.json5"),
      ) {
      return Err("MoUI HarmonyOS template is incomplete: " + template_root)
    }
    if path_is_dir(staged_root) && !path_is_file(stage_marker) {
      return Err(
        "refusing to replace an unowned HarmonyOS project: " + staged_root,
      )
    }
    remove_tree(staged_root)
    match mkdir_p(staged_root) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    match write_file_bytes_result(stage_marker, b"") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    match copy_tree(template_root, staged_root) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    match
      apply_harmonyos_managed_identity(
        staged_root,
        options.app,
        options.renderer,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    log_info(
      "[moui-shell-harmonyos] Staged canonical HarmonyOS shell in " +
      staged_root,
    )
    staged_root
  }
  if !path_is_dir(join_path(source_project, "entry/src/main/cpp")) {
    return Err(
      "resolved HarmonyOS shell is missing entry/src/main/cpp: " +
      source_project,
    )
  }
  if options.prepare_only {
    log_info("[moui-shell-harmonyos] Prepared " + options.build_dir)
    return Ok({
      platform: "harmonyos",
      build_dir: options.build_dir,
      output_artifact: "",
      prepare_result,
    })
  }
  // 4. Dispatch to fallback (cmake + zip) or real (ohpm + hvigorw) path.
  if options.fallback_skia {
    return build_harmonyos_fallback(options, source_project, prepare_result)
  }
  build_harmonyos_hvigor(options, source_project, prepare_result)
}

///|
/// Fallback path: invoke `cmake` + `zip` to produce a minimal HAP archive
/// for packaging smoke. Mirrors lines 488-540 of `build-harmonyos-hap.sh`.
fn build_harmonyos_fallback(
  options : BuildHarmonyosOptions,
  source_project : String,
  prepare_result : PrepareResult,
) -> Result[BuildResult, String] {
  let ohos_arch = match
    lookup_static_map(harmonyos_arch_to_ohos_arch, options.arch) {
    Some(value) => value
    None => return Err("unsupported HarmonyOS arch: " + options.arch)
  }
  let cmake_build_dir = join_path(
    options.build_dir,
    "cmake/fallback/" + ohos_arch,
  )
  remove_tree(cmake_build_dir)
  let cmake_config = prepare_result.cmake_config_path.unwrap_or("")
  let shell_root = join_path(options.moui_root, "../moui_shell")
  let mut cmake_args = [
    "-S",
    join_path(source_project, "entry/src/main/cpp"),
    "-B",
    cmake_build_dir,
    "-DMOUI_ROOT=" + options.moui_root,
    "-DMOUI_SHELL_ROOT=" + shell_root,
    "-DMOUI_EMBEDDING_NATIVE_CONFIG=" + cmake_config,
    "-DMOUI_HARMONYOS_FALLBACK=ON",
  ]
  // Prefer Ninja when available.
  if find_in_path("ninja", detect_host_platform()) is Some(_) {
    cmake_args = ["-G", "Ninja", ..cmake_args]
  }
  log_command("cmake", ["cmake", ..cmake_args])
  match process_exec_argv(["cmake", ..cmake_args], capture=false) {
    Ok(result) if result.exit_code == 0 => ()
    Ok(result) =>
      return Err(
        "cmake configure failed (exit " + result.exit_code.to_string() + ")",
      )
    Err(message) => return Err(message)
  }
  log_info("[moui-shell-harmonyos] Building HarmonyOS native library")
  match
    process_exec_argv(["cmake", "--build", cmake_build_dir], capture=false) {
    Ok(result) if result.exit_code == 0 => ()
    Ok(result) =>
      return Err(
        "cmake build failed (exit " + result.exit_code.to_string() + ")",
      )
    Err(message) => return Err(message)
  }
  // Stage and zip the HAP.
  let stage_dir = join_path(options.build_dir, "hap-stage")
  match stage_harmonyos_project(source_project, stage_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let libs_dir = join_path(stage_dir, "entry/libs/" + ohos_arch)
  match mkdir_p(libs_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // Copy shared libs.
  for shared_lib in prepare_result.shared_libs {
    let dest = join_path(libs_dir, basename(shared_lib))
    match copy_file_atomic(shared_lib, dest) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  match mkdir_p(parent_dir(options.output_hap)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    process_exec_argv(
      ["zip", "-q", "-r", options.output_hap, "."],
      cwd=stage_dir,
      capture=false,
    ) {
    Ok(result) if result.exit_code == 0 => ()
    Ok(result) =>
      return Err("zip failed (exit " + result.exit_code.to_string() + ")")
    Err(message) => return Err(message)
  }
  log_info(
    "[moui-shell-harmonyos] Wrote staged HAP archive " + options.output_hap,
  )
  Ok({
    platform: "harmonyos",
    build_dir: options.build_dir,
    output_artifact: options.output_hap,
    prepare_result,
  })
}

///|
/// Real path: invoke `ohpm install` + `hvigorw assembleHap`. Mirrors lines
/// 383-486 of `build-harmonyos-hap.sh`.
fn build_harmonyos_hvigor(
  options : BuildHarmonyosOptions,
  source_project : String,
  prepare_result : PrepareResult,
) -> Result[BuildResult, String] {
  // 1. Resolve SDK home. Prefer explicit option/env, but if the path has no
  // OHOS CMake toolchain fall back to DevEco/OpenHarmony auto-discovery so a
  // partial HARMONYOS_SDK_HOME (e.g. ~/Library/OpenHarmony/Sdk without native)
  // does not hard-fail when DevEco's SDK is installed.
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
      "HARMONYOS_SDK_HOME or OHOS_SDK_HOME must point at a HarmonyOS/OpenHarmony SDK for non-fallback builds. Use --fallback-skia for a packaging-only smoke.",
    )
  }
  if find_ohos_toolchain(sdk_home) == "" {
    return Err("HarmonyOS native CMake toolchain not found under " + sdk_home)
  }
  // 2. Resolve hvigorw + ohpm.
  let hvigorw = match options.hvigorw {
    Some(value) =>
      if path_is_absolute(value) {
        value
      } else {
        join_path(options.workspace_root, value)
      }
    None =>
      match @env.get_env_var("HVIGORW") {
        Some(value) => value
        None => find_deveco_hvigorw()
      }
  }
  if hvigorw == "" || !path_is_executable(hvigorw) {
    return Err(
      "Hvigor wrapper not found. Pass --hvigorw or set HVIGORW for non-fallback builds.",
    )
  }
  let ohpm = match options.ohpm {
    Some(value) =>
      if path_is_absolute(value) {
        value
      } else {
        join_path(options.workspace_root, value)
      }
    None =>
      match @env.get_env_var("OHPM") {
        Some(value) => value
        None => find_deveco_ohpm()
      }
  }
  if ohpm == "" || !path_is_executable(ohpm) {
    return Err(
      "ohpm executable not found. Pass --ohpm or set OHPM for non-fallback builds.",
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
  // 3. Stage the hvigor project.
  let ohos_arch = match
    lookup_static_map(harmonyos_arch_to_ohos_arch, options.arch) {
    Some(value) => value
    None => return Err("unsupported HarmonyOS arch: " + options.arch)
  }
  let hvigor_project_dir = join_path(options.build_dir, "hvigor-project")
  log_info(
    "[moui-shell-harmonyos] Preparing temporary Hvigor project at " +
    hvigor_project_dir,
  )
  match stage_harmonyos_project(source_project, hvigor_project_dir) {
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
  match mkdir_p(join_path(hvigor_project_dir, "entry/libs/" + ohos_arch)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match mkdir_p(join_path(hvigor_project_dir, "hnp")) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // Stage native shared libs.
  for shared_lib in prepare_result.shared_libs {
    let dest = join_path(
      join_path(hvigor_project_dir, "entry/libs/" + ohos_arch),
      basename(shared_lib),
    )
    log_info(
      "[moui-shell-harmonyos] Staging native dependency " +
      basename(shared_lib) +
      " for Hvigor",
    )
    match copy_file_atomic(shared_lib, dest) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  // 4. ohpm install.
  let ohpm_env = moon_build_env()
  ohpm_env.push(("DEVECO_SDK_HOME", deveco_sdk_home))
  ohpm_env.push(("HARMONYOS_SDK_HOME", sdk_home))
  ohpm_env.push(("OHOS_SDK_HOME", sdk_home))
  ohpm_env.push(("OHOS_BASE_SDK_HOME", sdk_home))
  log_info(
    "[moui-shell-harmonyos] Installing HarmonyOS project dependencies with ohpm",
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
  // 5. hvigorw assembleHap.
  let moon_home = @env.get_env_var("MOON_HOME").unwrap_or_else(() => {
    let home = @env.get_env_var("HOME").unwrap_or("")
    join_path(home, ".moon")
  })
  let shell_root = join_path(options.moui_root, "../moui_shell")
  let hvigor_env = moon_build_env()
  hvigor_env.push(("DEVECO_SDK_HOME", deveco_sdk_home))
  hvigor_env.push(("HARMONYOS_SDK_HOME", sdk_home))
  hvigor_env.push(("OHOS_SDK_HOME", sdk_home))
  hvigor_env.push(("OHOS_BASE_SDK_HOME", sdk_home))
  hvigor_env.push(("MOUI_PACKAGE_ROOT", options.moui_root))
  hvigor_env.push(("MOUI_SHELL_PACKAGE_ROOT", shell_root))
  hvigor_env.push(("MOUI_SKIA_ROOT", options.skia_root))
  hvigor_env.push(("MOUI_MOON_HOME", moon_home))
  hvigor_env.push(
    (
      "MOUI_EMBEDDING_NATIVE_CONFIG",
      prepare_result.cmake_config_path.unwrap_or(""),
    ),
  )
  hvigor_env.push(("MOUI_HARMONYOS_FALLBACK", "OFF"))
  log_info(
    "[moui-shell-harmonyos] Building installable HarmonyOS HAP with Hvigor",
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
  // 6. Locate the produced HAP.
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
    "[moui-shell-harmonyos] Wrote Hvigor HAP archive " + options.output_hap,
  )
  log_info(
    "This is build/install evidence only until a device or emulator smoke proves first frame, input, resize, lifecycle, and libskia.so loading.",
  )
  Ok({
    platform: "harmonyos",
    build_dir: options.build_dir,
    output_artifact: options.output_hap,
    prepare_result,
  })
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
