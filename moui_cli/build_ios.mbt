// Window-hosted iOS packaging.
// iOS .app packaging now uses the window-hosted template at
// `window/modules/window/ios/template/` +
// `examples/<app>/ios_window_hosted` entrypoint.
//
// `build_ios` generates MoonBit C, stages the window-hosted UIKit template
// (Sources/main.m + Sources/MBWHostedAppDelegate.{h,m} + Info.plist), applies
// app identity (CFBundleIdentifier / CFBundleName / MinimumOSVersion), then
// invokes `clang`/`clang++` via `xcrun --sdk iphonesimulator|iphoneos` to
// compile and link the executable directly — no xcodebuild. Mirrors
// `window/modules/window/ios/scripts/build-hosted-sim-app.sh`.

///|
priv struct BuildIosOptions {
  app : MobileApp
  product_name : String?
  workspace_root : String
  sdk : String
  arch : String
  deployment_target : String?
  renderer : String
  build_dir : String
  output_app : String
  fallback_skia : Bool
  prepare_only : Bool
}

///|
/// Locate the Xcode version via `xcodebuild -version`. Returns the first
/// numeric version token (e.g. `"15.4"`). Empty string when `xcodebuild` is
/// unavailable.
fn xcode_version_string() -> String {
  match process_exec_argv(["xcodebuild", "-version"], capture=true) {
    Ok(result) if result.exit_code == 0 => {
      let line = result.stdout.split("\n").to_array()[0].to_owned()
      // "Xcode 15.4\n..." -> take the second whitespace-delimited token.
      let parts = line.split(" ").to_array()
      if parts.length() >= 2 {
        parts[1].to_owned()
      } else {
        ""
      }
    }
    _ => ""
  }
}

///|
/// Parse a dotted numeric version into an array of integers. Trailing
/// non-numeric parts are dropped. Empty array when parsing fails.
fn parse_dotted_version(value : String) -> Array[Int] {
  let parts = value.split(".").to_array()
  let result : Array[Int] = []
  for part in parts {
    let trimmed = part.trim()
    if trimmed == "" {
      return []
    }
    let mut num = 0
    let mut ok = true
    for ch in trimmed {
      if ch >= '0' && ch <= '9' {
        num = num * 10 + (ch.to_int() - '0'.to_int())
      } else {
        ok = false
        break
      }
    }
    if !ok {
      return []
    }
    result.push(num)
  }
  result
}

///|
/// Returns `true` when `actual >= floor` using dotted numeric comparison.
fn version_at_least(actual : String, floor : String) -> Bool {
  let left = parse_dotted_version(actual)
  let right = parse_dotted_version(floor)
  if left.is_empty() || right.is_empty() {
    return false
  }
  let length = if left.length() > right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<length {
    let l = if i < left.length() { left[i] } else { 0 }
    let r = if i < right.length() { right[i] } else { 0 }
    if l > r {
      return true
    }
    if l < r {
      return false
    }
  }
  true
}

///|
/// Resolve `xcrun --sdk <sdk> --show-sdk-path` to the iOS SDK root. Returns
/// an empty string when the lookup fails.
fn ios_sdk_path(sdk : String) -> String {
  match
    process_exec_argv(["xcrun", "--sdk", sdk, "--show-sdk-path"], capture=true) {
    Ok(result) if result.exit_code == 0 => result.stdout.trim().to_owned()
    _ => ""
  }
}

///|
/// Resolve `xcrun --sdk <sdk> --find <tool>` to a tool path. Returns an
/// empty string when the lookup fails.
fn ios_find_tool(sdk : String, tool : String) -> String {
  match
    process_exec_argv(["xcrun", "--sdk", sdk, "--find", tool], capture=true) {
    Ok(result) if result.exit_code == 0 => result.stdout.trim().to_owned()
    _ => ""
  }
}

///|
/// Stage the window-hosted iOS template into `target_root` and write the
/// `.moui-window-hosted-stage` marker so future runs can replace it safely.
/// The template lives at `window/modules/window/ios/template/` and ships `Sources/`,
/// `Info.plist`, and `README.md`.
fn stage_ios_window_hosted_project(
  template_root : String,
  target_root : String,
) -> Result[Unit, String] {
  let stage_marker = join_path(target_root, ".moui-window-hosted-stage")
  if path_is_dir(target_root) && !path_is_file(stage_marker) {
    return Err("refusing to replace an unowned iOS project: " + target_root)
  }
  remove_tree(target_root)
  match mkdir_p(target_root) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match copy_tree(template_root, target_root) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match write_file_bytes_result(stage_marker, b"") {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
/// Patch `key` inside an XML plist body. Replaces the first
/// `<key>key</key>` followed by a `<TYPE>old</TYPE>` sibling with the new
/// value. When the key is absent the plist is returned unchanged.
fn patch_plist_string_value(
  text : String,
  key : String,
  new_value : String,
) -> String {
  let key_pattern = "<key>" + key + "</key>"
  let key_pos = match text.find(key_pattern) {
    Some(pos) => pos
    None => return text
  }
  // After the key, find the next `<X>...</X>` sibling and rewrite it.
  let search_from = key_pos + key_pattern.length()
  let after = text[search_from:].to_owned()
  let open = match after.find("<") {
    Some(pos) => pos
    None => return text
  }
  let close = match after[open:].find(">") {
    Some(pos) => pos
    None => return text
  }
  // Tag name inside `<...>` (skipping attributes if any — Info.plist has none).
  // `close` is the offset of `>` within `after[open:]`, so the
  // tag name (relative to `after`) spans `[open + 1, open + close)`.
  let tag_body = after[open + 1:open + close].to_owned()
  let tag_name = tag_body.trim().to_owned()
  let value_open = open + close + 1
  let value_close = match after[value_open:].find("</" + tag_name + ">") {
    Some(pos) => pos
    None => return text
  }
  let prefix = text[:search_from + value_open].to_owned()
  let suffix = after[value_open + value_close:].to_owned()
  prefix + new_value + suffix
}

///|
/// Apply mobile app identity onto a staged window-hosted iOS template.
/// Patches `Info.plist`:
///   - CFBundleExecutable -> product_name
///   - CFBundleName -> product_name
///   - CFBundleIdentifier -> bundle_id
///   - MinimumOSVersion -> deployment_target
fn apply_ios_window_hosted_identity(
  project_root : String,
  app : MobileApp,
  product_name : String,
  deployment_target : String,
) -> Result[Unit, String] {
  let ios = match app.ios {
    Some(value) => value
    None => return Err("moui.mobile.json missing ios section")
  }
  let bundle_id = ios.bundle_id
  let plist_path = join_path(project_root, "Info.plist")
  let plist_text = match read_file_string_optional(plist_path) {
    Some(value) => value
    None => return Err("could not read: " + plist_path)
  }
  let patched = patch_plist_string_value(
    plist_text, "CFBundleExecutable", product_name,
  )
  let patched = patch_plist_string_value(patched, "CFBundleName", product_name)
  let patched = patch_plist_string_value(
    patched, "CFBundleIdentifier", bundle_id,
  )
  let patched = patch_plist_string_value(
    patched, "MinimumOSVersion", deployment_target,
  )
  match
    write_file_bytes_result(plist_path, @utf8.encode(patched[:], bom=false)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  log_info(
    "[moui-window-hosted-ios] Applied identity CFBundleIdentifier=" +
    bundle_id +
    " CFBundleExecutable=" +
    product_name +
    " MinimumOSVersion=" +
    deployment_target,
  )
  Ok(())
}

///|
/// Build the common compile flags for an iOS window-hosted build. Mirrors
/// the `COMMON_FLAGS` array in
/// `window/modules/window/ios/scripts/build-hosted-sim-app.sh`.
/// `target_triple` already encodes the SDK (simulator vs device) and
/// deployment target.
fn ios_common_compile_flags(
  sdk_path : String,
  target_triple : String,
  moon_home : String,
  window_ios_root : String,
  workspace_root : String,
) -> Array[String] {
  let flags : Array[String] = [
    "-isysroot",
    sdk_path,
    "-target",
    target_triple,
    "-fobjc-arc",
    "-O0",
    "-g",
    "-I" + moon_home + "/include",
    "-I" + window_ios_root,
    "-I" + window_ios_root + "/native/include",
    "-I" + workspace_root + "/moui_skia/native",
    "-D__APPLE__",
    "-DTARGET_OS_IPHONE=1",
    "-DMBW_IOS_MOONBIT_MAIN=mbw_ios_moonbit_main",
  ]
  flags
}

///|
/// Compile a single source file to an object file. Returns `Err` when the
/// compiler invocation fails. `lang` controls `-x objective-c` / `-x c++`
/// injection when the source extension is ambiguous; pass an empty string to
/// rely on the file extension.
fn compile_ios_object(
  compiler : String,
  common_flags : Array[String],
  source : String,
  output : String,
  lang : String,
  extra_flags : Array[String],
) -> Result[Unit, String] {
  let argv : Array[String] = [compiler]
  for flag in common_flags {
    argv.push(flag)
  }
  if lang != "" {
    argv.push("-x")
    argv.push(lang)
  }
  for flag in extra_flags {
    argv.push(flag)
  }
  argv.push("-c")
  argv.push(source)
  argv.push("-o")
  argv.push(output)
  log_command("compile_ios_object", argv)
  match process_exec_argv(argv, capture=false) {
    Ok(result) if result.exit_code == 0 => Ok(())
    Ok(result) =>
      Err(
        "clang failed (exit " +
        result.exit_code.to_string() +
        ") compiling " +
        source,
      )
    Err(message) => Err(message)
  }
}

///|
/// Build the iOS .app bundle. Mirrors
/// `window/modules/window/ios/scripts/build-hosted-sim-app.sh`. On macOS only.
fn build_ios(
  options : BuildIosOptions,
  host : HostPlatform,
) -> Result[BuildResult, String] {
  match host {
    Macos => ()
    _ => return Err("iOS builds require macOS with Xcode installed")
  }
  // Make build_dir + workspace_root absolute so paths passed to clang and
  // referenced in BuildResult stay valid regardless of the user's cwd.
  let workspace_root_abs = make_absolute(
    options.workspace_root,
    @env.get_env_var("PWD").unwrap_or("."),
  )
  let build_dir_abs = make_absolute(options.build_dir, workspace_root_abs)
  // 2. Xcode version floor (clang + iOS SDK must be present).
  let found = xcode_version_string()
  if !version_at_least(found, "15.4") {
    return Err(
      "MoUI iOS window-hosted build requires Xcode 15.4 or newer; found " +
      (if found == "" { "unknown" } else { found }),
    )
  }
  // 3. Resolve the upstream window package template and native glue.
  let template_root = window_template_root(workspace_root_abs, "ios")
  let ios_pkg_root = window_platform_root(workspace_root_abs, "ios")
  if !path_is_file(join_path(template_root, "Info.plist")) ||
    !path_is_file(join_path(template_root, "Sources/main.m")) ||
    !path_is_file(join_path(template_root, "Sources/MBWHostedAppDelegate.m")) {
    return Err(
      "MoUI window-hosted iOS template is incomplete: " + template_root,
    )
  }
  if !path_is_file(join_path(ios_pkg_root, "native_ios_host.c")) {
    return Err(
      "MoUI window-hosted iOS package sources missing: " +
      join_path(ios_pkg_root, "native_ios_host.c"),
    )
  }
  // 4. Generate MoonBit C from the entrypoint package.
  let entrypoint_package = match
    mobile_entrypoint_package(
      options.app.metadata_path,
      "ios",
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
  // Resolve real Skia link flags via `node moui_skia/build.js`. Mirrors the
  // legacy `prepare_ios` path: when fallback_skia is false, build.js returns
  // `-DMOUI_SKIA_HAS_SKIA ...` (stub_flags) + `libskia.a <frameworks> ...`
  // (link_flags). When fallback_skia is true, returns empty SkiaLink and the
  // stubs link without `MOUI_SKIA_HAS_SKIA`, so `skia_available()` returns
  // false at runtime — the stub-only build-evidence path.
  let skia_platform = match
    lookup_static_map(ios_sdk_to_skia_platform, options.sdk) {
    Some(value) => value
    None => return Err("unsupported iOS SDK: " + options.sdk)
  }
  let skia_arch = match lookup_static_map(ios_arch_to_skia_arch, options.arch) {
    Some(value) => value
    None => return Err("unsupported iOS arch: " + options.arch)
  }
  let link_mode = @env.get_env_var("MOUI_SKIA_LINK_MODE").unwrap_or("static")
  let renderer_selected = if options.fallback_skia {
    "skia-raster"
  } else if options.renderer == "skia-raster" {
    "skia-raster"
  } else {
    "skia-gpu"
  }
  let gpu_env : Array[(String, String)] = if renderer_selected == "skia-gpu" {
    [("MOUI_SKIA_ENABLE_GPU_METAL", "1")]
  } else {
    []
  }
  let skia_root_abs = make_absolute(
    join_path(workspace_root_abs, "moui_skia"),
    workspace_root_abs,
  )
  let skia_link = match
    resolve_skia(
      skia_root_abs,
      skia_platform,
      skia_arch,
      link_mode,
      options.fallback_skia,
      gpu_env,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  // 5. Stage the window-hosted template into <build_dir>/ios-project.
  let ios_project = join_path(build_dir_abs, "ios-project")
  match stage_ios_window_hosted_project(template_root, ios_project) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // Resolve product_name + deployment_target first so the identity patch
  // matches the eventual executable name.
  let product_name = match options.product_name {
    Some(value) => value
    None =>
      match options.app.ios {
        Some(ios) => ios.product_name.to_string()
        None => options.app.id.to_string()
      }
  }
  let deployment_target = options.deployment_target.unwrap_or("15.0")
  match
    apply_ios_window_hosted_identity(
      ios_project,
      options.app,
      product_name,
      deployment_target,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  if options.prepare_only {
    log_info(
      "[moui-window-hosted-ios] Prepared " +
      build_dir_abs +
      " (moonbit_c=" +
      moonbit_c +
      ")",
    )
    return Ok({ build_dir: build_dir_abs, output_artifact: "" })
  }
  // 6. Resolve iOS SDK + clang/clang++ via xcrun.
  let sdk = options.sdk
  let sdk_path = ios_sdk_path(sdk)
  if sdk_path == "" {
    return Err(
      "xcrun --sdk " +
      sdk +
      " --show-sdk-path failed; install Xcode and run xcode-select",
    )
  }
  let clang = ios_find_tool(sdk, "clang")
  if clang == "" {
    return Err("xcrun --sdk " + sdk + " --find clang failed")
  }
  let clangxx = ios_find_tool(sdk, "clang++")
  if clangxx == "" {
    return Err("xcrun --sdk " + sdk + " --find clang++ failed")
  }
  // 7. Build target triple + common compile flags.
  //    iphonesimulator -> arm64-apple-ios{MIN}-simulator
  //    iphoneos        -> arm64-apple-ios{MIN}
  let target_triple = if sdk == "iphonesimulator" {
    "arm64-apple-ios" + deployment_target + "-simulator"
  } else {
    "arm64-apple-ios" + deployment_target
  }
  let moon_home = make_absolute(
    @env.get_env_var("MOON_HOME").unwrap_or_else(() => {
      let home = @env.get_env_var("HOME").unwrap_or("")
      join_path(home, ".moon")
    }),
    workspace_root_abs,
  )
  let common_flags = ios_common_compile_flags(
    sdk_path, target_triple, moon_home, ios_pkg_root, workspace_root_abs,
  )
  // 8. Compile every source to <build_dir>/obj/*.o.
  let obj_dir = join_path(build_dir_abs, "obj")
  remove_tree(obj_dir)
  match mkdir_p(obj_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let objs : Array[String] = []
  let mut ok = true
  // MoonBit generated C — `main` is renamed to `mbw_ios_moonbit_main`.
  let moonbit_o = join_path(obj_dir, "moonbit_entry.o")
  let moonbit_extra : Array[String] = ["-Dmain=mbw_ios_moonbit_main"]
  match
    compile_ios_object(
      clang, common_flags, moonbit_c, moonbit_o, "", moonbit_extra,
    ) {
    Ok(_) => objs.push(moonbit_o)
    Err(message) => {
      ok = false
      return Err(message)
    }
  }
  // Moon runtime.
  let runtime_c = join_path(moon_home, "lib/runtime.c")
  if path_is_file(runtime_c) {
    let runtime_o = join_path(obj_dir, "runtime.o")
    let runtime_extra : Array[String] = ["-Dgetentropy=mbw_ios_getentropy"]
    match
      compile_ios_object(
        clang, common_flags, runtime_c, runtime_o, "", runtime_extra,
      ) {
      Ok(_) => objs.push(runtime_o)
      Err(message) => {
        ok = false
        return Err(message)
      }
    }
  } else {
    log_warn("Moon runtime not found at " + runtime_c)
  }
  // Window iOS host glue (Objective-C).
  let native_ios_host_c = join_path(ios_pkg_root, "native_ios_host.c")
  if path_is_file(native_ios_host_c) {
    let obj = join_path(obj_dir, "native_ios_host.o")
    match
      compile_ios_object(
        clang,
        common_flags,
        native_ios_host_c,
        obj,
        "objective-c",
        [],
      ) {
      Ok(_) => objs.push(obj)
      Err(message) => {
        ok = false
        return Err(message)
      }
    }
  }
  // App entry / compat / fs_native / main / delegate.
  // NOTE: window/modules/window/ios/native/mbw_ios_main.m is intentionally NOT compiled —
  // it is a deprecated duplicate of template/Sources/main.m. The reference
  // build script (window/modules/window/ios/scripts/build-hosted-sim-app.sh) only compiles
  // template/Sources/main.m and template/Sources/MBWHostedAppDelegate.m.
  let entry_pairs = [
    (
      join_path(ios_pkg_root, "native/mbw_ios_app_entry.c"),
      "mbw_ios_app_entry.o",
      "",
    ),
    (join_path(ios_pkg_root, "native/mbw_ios_compat.c"), "mbw_ios_compat.o", ""),
    (join_path(ios_project, "Sources/main.m"), "mbw_ios_main.o", "objective-c"),
    (
      join_path(ios_project, "Sources/MBWHostedAppDelegate.m"),
      "mbw_hosted_app_delegate.o",
      "objective-c",
    ),
  ]
  for entry in entry_pairs {
    let (source, obj_name, lang) = entry
    if path_is_file(source) {
      let obj_path = join_path(obj_dir, obj_name)
      match
        compile_ios_object(clang, common_flags, source, obj_path, lang, []) {
        Ok(_) => objs.push(obj_path)
        Err(message) => {
          ok = false
          return Err(message)
        }
      }
    }
  }
  // moonbitlang/x/fs fs_native.c (if vendored under .mooncakes).
  let fs_native = join_path(
    workspace_root_abs, ".mooncakes/moonbitlang/x/fs/fs_native.c",
  )
  if path_is_file(fs_native) {
    let fs_o = join_path(obj_dir, "fs_native.o")
    match compile_ios_object(clang, common_flags, fs_native, fs_o, "", []) {
      Ok(_) => objs.push(fs_o)
      Err(message) => {
        ok = false
        return Err(message)
      }
    }
  }
  // Skia stubs (.cpp) + iOS Skia glue (.mm). The stub_flags from `resolve_skia`
  // carry `-DMOUI_SKIA_HAS_SKIA` (plus paragraph / GPU Metal defines and the
  // Skia include path), which the stubs need to expose `moonbit_skia_available`
  // returning 1 and to wire real Ganesh / paragraph entrypoints.
  let skia_root = join_path(workspace_root_abs, "moui_skia/native")
  let skia_stubs = [
    "skia_stub.cpp", "skia_stub_common.cpp", "skia_stub_surface_image_data.cpp",
    "skia_stub_canvas.cpp", "skia_stub_path.cpp", "skia_stub_text_font.cpp", "skia_stub_paragraph.cpp",
    "skia_stub_shader_filter.cpp", "skia_stub_picture.cpp", "skia_stub_gpu_worker.cpp",
  ]
  let cxx_flags : Array[String] = [
    "-std=c++17",
    ..split_flags(skia_link.stub_flags),
  ]
  for stub in skia_stubs {
    let source = join_path(skia_root, stub)
    if path_is_file(source) {
      let obj_name = stub[:stub.length() - ".cpp".length()].to_owned() + ".o"
      let obj_path = join_path(obj_dir, obj_name)
      match
        compile_ios_object(
          clangxx, common_flags, source, obj_path, "", cxx_flags,
        ) {
        Ok(_) => objs.push(obj_path)
        Err(message) => {
          ok = false
          return Err(message)
        }
      }
    }
  }
  let mm_glue = [
    join_path(workspace_root_abs, "moui/backend/ios/ios_present.mm"),
  ]
  for glue in mm_glue {
    if path_is_file(glue) {
      let base = basename(glue)
      let stem = if base.has_suffix(".mm") {
        base[:base.length() - ".mm".length()].to_owned()
      } else {
        base
      }
      let obj_path = join_path(obj_dir, stem + ".o")
      let mm_flags : Array[String] = ["-std=c++17", "-ObjC++"]
      match
        compile_ios_object(clangxx, common_flags, glue, obj_path, "", mm_flags) {
        Ok(_) => objs.push(obj_path)
        Err(message) => {
          ok = false
          return Err(message)
        }
      }
    }
  }
  if !ok {
    return Err("iOS window-hosted compile step failed")
  }
  // 9. Link the executable into <build_dir>/ios-project/<product_name>.app.
  let app_dir = if options.output_app == "" {
    join_path(ios_project, product_name + ".app")
  } else {
    options.output_app
  }
  match mkdir_p(app_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let executable = join_path(app_dir, product_name)
  let link_argv = [clangxx, ..common_flags]
  link_argv.push("-o")
  link_argv.push(executable)
  for obj in objs {
    link_argv.push(obj)
  }
  // Skia link flags from `resolve_skia`. When fallback_skia is false this
  // carries the real `libskia.a` / `libskia_ganesh_ext.a` absolute paths,
  // paragraph sub-libs, and the Metal/CoreGraphics/UIKit frameworks that
  // Skia depends on. When fallback_skia is true this is empty.
  for flag in split_flags(skia_link.link_flags) {
    link_argv.push(flag)
  }
  // System frameworks / libs required by the window-hosted template itself.
  link_argv.push("-framework")
  link_argv.push("MetalKit")
  link_argv.push("-lc++")
  log_command("clang++ (link)", link_argv)
  match process_exec_argv(link_argv, capture=false) {
    Ok(result) if result.exit_code == 0 => ()
    Ok(result) =>
      return Err(
        "clang++ link failed with exit code " + result.exit_code.to_string(),
      )
    Err(message) => return Err(message)
  }
  // 10. Copy patched Info.plist into the .app bundle.
  let plist_dst = join_path(app_dir, "Info.plist")
  match copy_file_atomic(join_path(ios_project, "Info.plist"), plist_dst) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // Ensure the executable has +x.
  match process_exec_argv(["chmod", "+x", executable], capture=true) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // 11. Resolve output_app path (may differ from app_dir when --output set).
  let final_output = if options.output_app == "" {
    app_dir
  } else {
    options.output_app
  }
  if !path_is_dir(final_output) {
    return Err("iOS .app bundle was not produced: " + final_output)
  }
  log_info("[moui-window-hosted-ios] Wrote " + final_output)
  log_info(
    "This is build/install evidence only until a simulator/device smoke proves first frame, input, resize, and lifecycle.",
  )
  Ok({ build_dir: build_dir_abs, output_artifact: final_output })
}
