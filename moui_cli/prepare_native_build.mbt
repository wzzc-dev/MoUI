// Native build preparation pipeline. Migrates
// `moui_shell/scripts/prepare-native-build.mjs` (670 lines),
// `moui_shell/scripts/android-ndk.mjs` (106 lines), and
// `moui_shell/scripts/harmonyos-skia-link.mjs` (15 lines) into MoonBit.
//
// The pipeline is the contract between `moui run`/`moui verify` and the
// platform-specific build commands: it generates MoonBit C, resolves the
// Skia link, copies shared libraries, and writes the per-platform
// `shell-build.json` consumed by Gradle/Xcode/hvigor.

///|
let android_default_abi : String = "arm64-v8a"

///|
let android_default_shell_mode : String = "managed"

///|
let ios_default_sdk : String = "iphonesimulator"

///|
let ios_default_arch : String = "arm64"

///|
let harmonyos_default_arch : String = "arm64"

///|
let default_renderer_mode : String = "auto"

///|
let default_android_ndk_version : String = "28.2.13676358"

///|
/// Android ABI -> Skia arch.
let android_abi_to_skia_arch : Array[(String, String)] = [
  ("arm64-v8a", "arm64"),
  ("x86_64", "x64"),
  ("riscv64", "riscv64"),
]

///|
/// Android ABI -> LLVM triple.
let android_abi_to_triple : Array[(String, String)] = [
  ("arm64-v8a", "aarch64-linux-android"),
  ("x86_64", "x86_64-linux-android"),
  ("riscv64", "riscv64-linux-android"),
]

///|
/// iOS SDK -> Skia platform.
let ios_sdk_to_skia_platform : Array[(String, String)] = [
  ("iphonesimulator", "iosSim"),
  ("iphoneos", "ios"),
]

///|
/// iOS arch -> Skia arch.
let ios_arch_to_skia_arch : Array[(String, String)] = [
  ("arm64", "arm64"),
  ("x86_64", "x64"),
]

///|
/// HarmonyOS arch -> OHOS arch.
let harmonyos_arch_to_ohos_arch : Array[(String, String)] = [
  ("arm64", "arm64-v8a"),
]

///|
/// iOS Skia stub source files referenced by the shell-builder rsp files.
let skia_stub_sources : Array[String] = [
  "native/skia_stub.cpp", "native/skia_stub_common.cpp", "native/skia_stub_surface_image_data.cpp",
  "native/skia_stub_canvas.cpp", "native/skia_stub_path.cpp", "native/skia_stub_text_font.cpp",
  "native/skia_stub_paragraph.cpp", "native/skia_stub_shader_filter.cpp", "native/skia_stub_picture.cpp",
  "native/android_vulkan_loader.cpp", "native/skia_stub_gpu_worker.cpp",
]

///|
/// Environment variables that must be stripped from a `moon build` spawn so
/// Xcode-injected SDK settings do not leak into a host native build.
let moon_build_env_blocked_keys : Array[String] = [
  "SDKROOT", "SDK_NAME", "PLATFORM_NAME", "EFFECTIVE_PLATFORM_NAME", "ARCHS", "VALID_ARCHS",
  "IPHONEOS_DEPLOYMENT_TARGET", "LLVM_TARGET_TRIPLE_OS_VERSION", "LLVM_TARGET_TRIPLE_SUFFIX",
  "LLVM_TARGET_TRIPLE_VENDOR",
]

///|
priv struct RendererSelection {
  requested : String
  selected : String
  gpu_promoted : Bool
  fallback_reason : String?
} derive(Eq)

///|
priv struct SkiaLink {
  stub_flags : String
  link_flags : String
} derive(Eq)

///|
priv struct PrepareOptions {
  app : ShellApp
  app_config_path : String
  workspace_root : String
  moui_root : String
  skia_root : String
  build_dir : String
  abi : String
  android_shell : String
  sdk : String
  arch : String
  renderer : String
  fallback_skia : Bool
  shell_root : String
  contract : ManagedContract
}

///|
priv struct PrepareResult {
  platform : String
  build_json_path : String
  cmake_config_path : String?
  skia_cxx_rsp : String?
  skia_link_rsp : String?
  jni_libs_dir : String?
  moonbit_c : String
  renderer : RendererSelection
  skia_link : SkiaLink
  shared_libs : Array[String]
}

///|
fn lookup_static_map(
  entries : Array[(String, String)],
  key : String,
) -> String? {
  for entry in entries {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
/// Read a file as bytes, returning `None` when the read fails so the caller
/// can keep processing remaining entries (e.g. copying more shared libs).
fn read_file_bytes_optional(path : String) -> Bytes? {
  Some(@fs.read_file_to_bytes(path)) catch {
    _ => None
  }
}

///|
/// Write bytes to a file, returning `Err` if the write fails.
fn write_file_bytes_result(
  path : String,
  bytes : Bytes,
) -> Result[Unit, String] {
  @fs.write_bytes_to_file(path, bytes) catch {
    _ => return Err("could not write file: " + path)
  }
  Ok(())
}

///|
/// Quote a value for safe embedding inside a CMake `set(...)` literal. Escapes
/// backslashes and double quotes — matches `quoteCmake` from the .mjs.
fn quote_cmake(value : String) -> String {
  let result = StringBuilder::new()
  for ch in value {
    match ch {
      '\\' => result.write_string("\\\\")
      '"' => result.write_string("\\\"")
      _ => result.write_char(ch)
    }
  }
  result.to_string()
}

///|
/// Split a shell-style flag string into tokens by whitespace. Empty/blank input
/// returns an empty array.
fn split_flags(flags : String) -> Array[String] {
  let trimmed = flags.trim()
  if trimmed == "" {
    return []
  }
  let result : Array[String] = []
  let current = StringBuilder::new()
  let mut in_token = false
  for ch in trimmed {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if in_token {
        result.push(current.to_string())
        current.reset()
        in_token = false
      }
    } else {
      current.write_char(ch)
      in_token = true
    }
  }
  if in_token {
    result.push(current.to_string())
  }
  result
}

///|
fn first_link_dir(flags : String) -> String {
  for flag in split_flags(flags) {
    if flag.has_prefix("-L") && flag.length() > 2 {
      return flag[2:].to_owned()
    }
  }
  ""
}

///|
fn contains_flag(flags : String, expected : String) -> Bool {
  split_flags(flags).contains(expected)
}

///|
/// Locate `libc++_shared.so` for an Android ABI inside an NDK prebuilt sysroot.
fn android_libcxx_shared_path(ndk_home : String, abi : String) -> String {
  let triple = match lookup_static_map(android_abi_to_triple, abi) {
    Some(value) => value
    None => return ""
  }
  let prebuilt_root = join_path(ndk_home, "toolchains/llvm/prebuilt")
  let hosts = @fs.read_dir(prebuilt_root) catch { _ => return "" }
  let sorted_hosts = hosts.copy()
  sorted_hosts.sort_by((a, b) => a.lexical_compare(b))
  for host in sorted_hosts {
    let candidate = join_path(
      join_path(join_path(prebuilt_root, host), "sysroot/usr/lib"),
      triple + "/libc++_shared.so",
    )
    if path_is_file(candidate) {
      return candidate
    }
  }
  ""
}

///|
/// Determine the Android NDK home for the requested version. Replaces
/// `moui_shell/scripts/android-ndk.mjs::resolveAndroidNdkHome`. Returns an
/// empty string when no complete NDK installation is found.
fn resolve_android_ndk_home(sdk_root : String) -> String {
  let requested = @env.get_env_var("MOUI_ANDROID_NDK_VERSION").unwrap_or(
    default_android_ndk_version,
  )
  let requested_version = match first_numeric_version(requested) {
    Some(value) => value
    None => return ""
  }
  if !numeric_version_at_least(requested_version, [28, 2]) {
    return ""
  }
  let candidates = [
    @env.get_env_var("ANDROID_NDK_HOME").unwrap_or(""),
    @env.get_env_var("ANDROID_NDK_ROOT").unwrap_or(""),
    join_path(sdk_root, "ndk/" + requested),
  ]
  for candidate in candidates {
    if candidate == "" || !valid_android_ndk(candidate) {
      continue
    }
    match ndk_revision(candidate) {
      Some(revision) if numeric_version_at_least(revision, [28, 2]) &&
        numeric_version_has_prefix(revision, requested_version) =>
        return candidate
      _ => ()
    }
  }
  ""
}

///|
/// Detect the Android SDK root from `ANDROID_HOME` / `ANDROID_SDK_ROOT` or the
/// default per-user install location. Returns an empty string when missing.
fn android_sdk_home() -> String {
  match @env.get_env_var("ANDROID_HOME") {
    Some(value) if value != "" => return value
    _ => ()
  }
  match @env.get_env_var("ANDROID_SDK_ROOT") {
    Some(value) if value != "" => return value
    _ => ()
  }
  let home = @env.get_env_var("HOME").unwrap_or("")
  for
    candidate in [
      join_path(home, "Library/Android/sdk"),
      join_path(home, "Android/Sdk"),
    ] {
    if path_is_dir(candidate) {
      return candidate
    }
  }
  ""
}

///|
/// Replaces `selectRenderer` from `prepare-native-build.mjs`. The product
/// default is GPU for `auto`/`skia-gpu` when a real Skia package is linked.
/// `fallback_skia` builds cannot provide a native GPU route, so they stay
/// raster.
fn select_renderer(
  requested : String,
  fallback_skia : Bool,
) -> Result[RendererSelection, String] {
  if !["auto", "skia-gpu", "skia-raster"].contains(requested) {
    return Err(
      "--renderer must be auto, skia-gpu, or skia-raster: " + requested,
    )
  }
  if requested == "skia-raster" {
    return Ok({
      requested,
      selected: "skia-raster",
      gpu_promoted: false,
      fallback_reason: None,
    })
  }
  if fallback_skia {
    return Ok({
      requested,
      selected: "skia-raster",
      gpu_promoted: false,
      fallback_reason: Some(
        "fallback Skia build cannot provide a native GPU route",
      ),
    })
  }
  Ok({
    requested,
    selected: "skia-gpu",
    gpu_promoted: true,
    fallback_reason: None,
  })
}

///|
/// Resolve the macOS SDK path and toolchain via `xcrun`. Returns an empty
/// string when `xcrun` cannot locate the requested value.
fn xcrun_value(args : Array[String]) -> String {
  let argv = ["xcrun", ..args]
  match process_exec_argv(argv, capture=true) {
    Ok(result) if result.exit_code == 0 => result.stdout.trim().to_string()
    _ => ""
  }
}

///|
/// Build the environment array for a `moon build` spawn. Removes the SDK
/// variables that Xcode injects so they do not leak into a host native build,
/// pins the MoUI Skia/PDFium prebuild flags, and — on macOS — points `SDKROOT`
/// and `CC`/`CXX` at the macOS SDK via `xcrun`. Replaces
/// `prepare-native-build.mjs::moonBuildEnv`.
fn moon_build_env() -> Array[(String, String)] {
  let base = @env.get_env_vars()
  let result : Array[(String, String)] = []
  for key, value in base {
    if moon_build_env_blocked_keys.contains(key) {
      continue
    }
    result.push((key, value))
  }
  result.push(("MOUI_SKIA_DISABLE_PREBUILD_SKIA", "1"))
  result.push(("MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM", "1"))
  result.push(("MOONBIT_NEW_NATIVE", "0"))
  if detect_host_platform() is Macos {
    let macos_sdk = xcrun_value(["--sdk", "macosx", "--show-sdk-path"])
    if macos_sdk != "" {
      result.push(("SDKROOT", macos_sdk))
      result.push(("SDK_NAME", "macosx"))
      result.push(("PLATFORM_NAME", "macosx"))
    }
    let macos_cc = xcrun_value(["--sdk", "macosx", "--find", "clang"])
    if macos_cc != "" {
      result.push(("CC", macos_cc))
    }
    let macos_cxx = xcrun_value(["--sdk", "macosx", "--find", "clang++"])
    if macos_cxx != "" {
      result.push(("CXX", macos_cxx))
    }
  }
  result
}

///|
/// Compute the path MoonBit writes for a given package + generated C file.
/// Mirrors `moonbitCPath` in the .mjs.
fn moonbit_c_path(
  build_dir : String,
  moon_package : String,
  generated_c : String,
) -> String {
  join_path(
    join_path(
      join_path(join_path(build_dir, "moonbit"), "native/debug/build"),
      moon_package,
    ),
    generated_c,
  )
}

///|
/// Run `moon build <moon_package> --target native --target-dir <build_dir>`.
/// Replaces `generateMoonbitC`. The spawn uses the cleaned env from
/// `moon_build_env()` so Xcode SDK injection does not corrupt the host build.
fn generate_moonbit_c(
  workspace_root : String,
  moon_package : String,
  generated_c : String,
  build_dir : String,
) -> Result[String, String] {
  let moonbit_target_dir = join_path(build_dir, "moonbit")
  remove_tree(moonbit_target_dir)
  match mkdir_p(moonbit_target_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let argv = [
    "moon", "build", moon_package, "--target", "native", "--target-dir", moonbit_target_dir,
  ]
  log_command("generate_moonbit_c", argv)
  let env = moon_build_env()
  let result = match
    process_exec_argv(argv, cwd=workspace_root, env~, capture=false) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let moonbit_c = moonbit_c_path(build_dir, moon_package, generated_c)
  if result.exit_code != 0 && !path_is_file(moonbit_c) {
    return Err(
      "moon build " +
      moon_package +
      " --target native --target-dir " +
      moonbit_target_dir +
      " failed with exit code " +
      result.exit_code.to_string(),
    )
  }
  if result.exit_code != 0 {
    log_warn(
      "moon build returned " +
      result.exit_code.to_string() +
      "; continuing because generated C exists: " +
      moonbit_c,
    )
  }
  Ok(moonbit_c)
}

///|
/// Resolve Skia link flags by invoking `node build.js` inside the moui_skia
/// root. Replaces `resolveSkia`. Returns an empty `SkiaLink` when `fallback`
/// is true (no real Skia package is available).
fn resolve_skia(
  skia_root : String,
  platform : String,
  arch : String,
  link_mode : String,
  fallback : Bool,
  gpu_env : Array[(String, String)],
) -> Result[SkiaLink, String] {
  if fallback {
    return Ok({ stub_flags: "", link_flags: "" })
  }
  let env = moon_build_env()
  env.push(("MOUI_SKIA_PLATFORM", platform))
  env.push(("MOUI_SKIA_ARCH", arch))
  env.push(("MOUI_SKIA_LINK_MODE", link_mode))
  for entry in gpu_env {
    env.push(entry)
  }
  let argv = ["node", "build.js"]
  log_command("resolve_skia", argv)
  match process_exec_argv(argv, cwd=skia_root, env~, capture=true) {
    Ok(result) if result.exit_code == 0 => {
      let parsed = @json.parse(result.stdout) catch {
        _ => return Err("moui_skia build.js produced invalid JSON")
      }
      guard parsed is Object(fields) else {
        return Err("moui_skia build.js output is not an object")
      }
      let vars = match fields.get("vars") {
        Some(Object(value)) => value
        _ => return Err("moui_skia build.js output is missing .vars object")
      }
      let stub_flags = match vars.get("MOUI_SKIA_STUB_CC_FLAGS") {
        Some(Json::String(value)) => value
        _ => ""
      }
      let link_flags = match vars.get("MOUI_SKIA_CC_LINK_FLAGS") {
        Some(Json::String(value)) => value
        _ => ""
      }
      Ok({ stub_flags, link_flags })
    }
    Ok(result) =>
      Err(
        "node build.js failed with exit code " +
        result.exit_code.to_string() +
        (if result.stderr != "" { ": " + result.stderr } else { "" }),
      )
    Err(message) => Err(message)
  }
}

///|
/// Copy `libc++_shared.so` and (when `-lskia` is requested) `libskia.so` into
/// the AGP-compatible `jniLibs/<abi>/` directory. Replaces
/// `copyAndroidSharedLibs`. Enforces the >=2MB size check — a stripped/minimal
/// libc++ copy is a known crash source at dlopen time.
fn copy_android_shared_libs(
  abi : String,
  ndk_home : String,
  skia_link_flags : String,
  jni_libs_dir : String,
) -> Result[Unit, String] {
  let abi_dir = join_path(jni_libs_dir, abi)
  remove_tree(abi_dir)
  match mkdir_p(abi_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let libcxx = android_libcxx_shared_path(ndk_home, abi)
  if libcxx != "" && path_is_file(libcxx) {
    let dest = join_path(abi_dir, "libc++_shared.so")
    match read_file_bytes_optional(libcxx) {
      Some(bytes) => {
        match write_file_bytes_result(dest, bytes) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        let size = bytes.length()
        if size < 2_000_000 {
          return Err(
            "Android libc++_shared.so from " +
            libcxx +
            " is only " +
            size.to_string() +
            " bytes; expected a full NDK libc++ (>=2MB). " +
            "Pin ANDROID_NDK_HOME to a complete NDK and wipe artifacts/*/jniLibs before rebuild.",
          )
        }
        log_info(
          "packaged libc++_shared.so from " +
          libcxx +
          " (" +
          size.to_string() +
          " bytes)",
        )
      }
      None =>
        log_warn(
          "libc++_shared.so not readable for abi=" +
          abi +
          " ndkHome=" +
          ndk_home,
        )
    }
  } else {
    log_warn(
      "libc++_shared.so not found for abi=" +
      abi +
      " ndkHome=" +
      ndk_home +
      "; AGP will supply STL from its ndkVersion",
    )
  }
  if contains_flag(skia_link_flags, "-lskia") {
    let skia_lib_dir = first_link_dir(skia_link_flags)
    if skia_lib_dir != "" {
      let skia_so = join_path(skia_lib_dir, "libskia.so")
      if path_is_file(skia_so) {
        match read_file_bytes_optional(skia_so) {
          Some(bytes) =>
            match
              write_file_bytes_result(join_path(abi_dir, "libskia.so"), bytes) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
          None => ()
        }
      }
    }
  }
  Ok(())
}

///|
/// Validate HarmonyOS Skia link flags. Replaces
/// `moui_shell/scripts/harmonyos-skia-link.mjs::validateHarmonyosSkiaLinkCompatibility`.
/// `skia-gpu` cannot link the locked dynamic Skia provider when the static
/// Ganesh extension is also referenced — internal symbols hidden by
/// `libskia.so` would fail to resolve.
fn validate_harmonyos_skia_link_compatibility(
  renderer : String,
  link_flags : String,
) -> Result[Unit, String] {
  if renderer != "skia-gpu" {
    return Ok(())
  }
  let uses_dynamic_skia = contains_flag(link_flags, "-lskia")
  let uses_static_ganesh = link_flags.contains("libskia_ganesh_ext.a")
  if uses_dynamic_skia && uses_static_ganesh {
    return Err(
      "HarmonyOS skia-gpu cannot link the locked dynamic Skia provider: " +
      "libskia_ganesh_ext.a references internal symbols hidden by libskia.so. " +
      "Unset MOUI_SKIA_LINK_MODE or set it to static until the shared provider " +
      "integrates Ganesh or exports the required symbols.",
    )
  }
  Ok(())
}

///|
/// Write a response file: one flag per line. Mirrors `writeRsp`.
fn write_rsp(path : String, flags : String) -> Result[Unit, String] {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let tokens = split_flags(flags)
  let text = tokens.join("\n") + "\n"
  match write_file_bytes_result(path, @utf8.encode(text[:], bom=false)) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
/// Write a JSON build manifest with pretty-printed indentation. Mirrors
/// `writeBuildJson`.
fn write_build_json(path : String, value : Json) -> Result[Unit, String] {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let text = value.stringify(indent=2) + "\n"
  match write_file_bytes_result(path, @utf8.encode(text[:], bom=false)) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
/// Generate `moui-shell-native.cmake` for the Android Gradle build. Mirrors
/// `writeAndroidCmakeConfig`.
fn write_android_cmake_config(
  path : String,
  contract : ManagedContract,
  app_id : String,
  moonbit_c : String,
  skia : SkiaLink,
  abi : String,
  renderer : RendererSelection,
  workspace_root : String,
  moui_root : String,
  skia_root : String,
  shell_root : String,
) -> Result[Unit, String] {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let moon_home = @env.get_env_var("MOON_HOME").unwrap_or_else(() => {
    let home = @env.get_env_var("HOME").unwrap_or("")
    join_path(home, ".moon")
  })
  let native_library = contract.native_library.unwrap_or("")
  let lines : Array[String] = []
  lines.push("# Generated by moui_cli prepare_native_build.")
  lines.push("set(MOUI_WORKSPACE_ROOT \"" + quote_cmake(workspace_root) + "\")")
  lines.push("set(MOUI_ROOT \"" + quote_cmake(moui_root) + "\")")
  lines.push("set(MOUI_SHELL_ROOT \"" + quote_cmake(shell_root) + "\")")
  lines.push("set(MOUI_SKIA_ROOT \"" + quote_cmake(skia_root) + "\")")
  lines.push("set(MOUI_MOON_HOME \"" + quote_cmake(moon_home) + "\")")
  lines.push(
    "set(MOUI_EMBEDDING_LIBRARY_NAME \"" + quote_cmake(native_library) + "\")",
  )
  lines.push("set(MOUI_EMBEDDING_MOONBIT_C \"" + quote_cmake(moonbit_c) + "\")")
  lines.push(
    "set(MOUI_EMBEDDING_APP_ARG \"" +
    quote_cmake(contract.entrypoint_arg) +
    "\")",
  )
  lines.push("set(MOUI_EMBEDDING_APP_ID \"" + quote_cmake(app_id) + "\")")
  lines.push(
    "set(MOUI_EMBEDDING_RENDERER_REQUESTED \"" +
    quote_cmake(renderer.requested) +
    "\")",
  )
  lines.push(
    "set(MOUI_EMBEDDING_RENDERER_SELECTED \"" +
    quote_cmake(renderer.selected) +
    "\")",
  )
  lines.push(
    "set(MOUI_SKIA_STUB_CC_FLAGS \"" + quote_cmake(skia.stub_flags) + "\")",
  )
  lines.push(
    "set(MOUI_SKIA_CC_LINK_FLAGS \"" + quote_cmake(skia.link_flags) + "\")",
  )
  lines.push("set(MOUI_EMBEDDING_ANDROID_ABI \"" + quote_cmake(abi) + "\")")
  lines.push("")
  let text = lines.join("\n")
  match write_file_bytes_result(path, @utf8.encode(text[:], bom=false)) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
/// Generate `moui-shell-harmonyos.cmake` for the hvigor build. Mirrors
/// `writeHarmonyosCmakeConfig`.
fn write_harmonyos_cmake_config(
  path : String,
  contract : ManagedContract,
  app_id : String,
  moonbit_c : String,
  skia : SkiaLink,
  ohos_arch : String,
  renderer : RendererSelection,
  workspace_root : String,
  moui_root : String,
  skia_root : String,
  shell_root : String,
) -> Result[Unit, String] {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let moon_home = @env.get_env_var("MOON_HOME").unwrap_or_else(() => {
    let home = @env.get_env_var("HOME").unwrap_or("")
    join_path(home, ".moon")
  })
  let native_library = contract.native_library.unwrap_or("")
  let exports = contract.embedding_exports
  let attach = if exports.length() > 0 { exports[0] } else { "" }
  let resize = if exports.length() > 1 { exports[1] } else { "" }
  let dispatch_pointer = if exports.length() > 2 { exports[2] } else { "" }
  let dispatch_scroll_raw = if exports.length() > 3 { exports[3] } else { "" }
  let dispatch_scroll = if dispatch_scroll_raw != "" {
    dispatch_scroll_raw
  } else {
    "moui_embedding_no_scroll"
  }
  let frame_tick = if exports.length() > 4 { exports[4] } else { "" }
  let render_frame = if exports.length() > 5 { exports[5] } else { "" }
  let detach = if exports.length() > 6 { exports[6] } else { "" }
  let lines : Array[String] = []
  lines.push("# Generated by moui_cli prepare_native_build.")
  lines.push("set(MOUI_WORKSPACE_ROOT \"" + quote_cmake(workspace_root) + "\")")
  lines.push("set(MOUI_ROOT \"" + quote_cmake(moui_root) + "\")")
  lines.push("set(MOUI_SHELL_ROOT \"" + quote_cmake(shell_root) + "\")")
  lines.push("set(MOUI_SKIA_ROOT \"" + quote_cmake(skia_root) + "\")")
  lines.push("set(MOUI_MOON_HOME \"" + quote_cmake(moon_home) + "\")")
  lines.push(
    "set(MOUI_EMBEDDING_LIBRARY_NAME \"" + quote_cmake(native_library) + "\")",
  )
  lines.push("set(MOUI_EMBEDDING_MOONBIT_C \"" + quote_cmake(moonbit_c) + "\")")
  lines.push(
    "set(MOUI_EMBEDDING_MOONBIT_MAIN_ALIAS \"" +
    quote_cmake(contract.moonbit_main_alias) +
    "\")",
  )
  lines.push(
    "set(MOUI_EMBEDDING_APP_ARG \"" +
    quote_cmake(contract.entrypoint_arg) +
    "\")",
  )
  lines.push("set(MOUI_EMBEDDING_APP_ID \"" + quote_cmake(app_id) + "\")")
  lines.push(
    "set(MOUI_EMBEDDING_RENDERER_REQUESTED \"" +
    quote_cmake(renderer.requested) +
    "\")",
  )
  lines.push(
    "set(MOUI_EMBEDDING_RENDERER_SELECTED \"" +
    quote_cmake(renderer.selected) +
    "\")",
  )
  lines.push(
    "set(MOUI_EMBEDDING_HARMONYOS_OHOS_ARCH \"" + quote_cmake(ohos_arch) + "\")",
  )
  lines.push(
    "set(MOUI_EMBEDDING_ATTACH_SURFACE_SYMBOL \"" + quote_cmake(attach) + "\")",
  )
  lines.push(
    "set(MOUI_EMBEDDING_RESIZE_SYMBOL \"" + quote_cmake(resize) + "\")",
  )
  lines.push(
    "set(MOUI_EMBEDDING_DISPATCH_POINTER_SYMBOL \"" +
    quote_cmake(dispatch_pointer) +
    "\")",
  )
  lines.push(
    "set(MOUI_EMBEDDING_DISPATCH_SCROLL_SYMBOL \"" +
    quote_cmake(dispatch_scroll) +
    "\")",
  )
  lines.push(
    "set(MOUI_EMBEDDING_FRAME_TICK_SYMBOL \"" + quote_cmake(frame_tick) + "\")",
  )
  lines.push(
    "set(MOUI_EMBEDDING_RENDER_FRAME_SYMBOL \"" +
    quote_cmake(render_frame) +
    "\")",
  )
  lines.push(
    "set(MOUI_EMBEDDING_DETACH_SURFACE_SYMBOL \"" + quote_cmake(detach) + "\")",
  )
  lines.push(
    "set(MOUI_SKIA_STUB_CC_FLAGS \"" + quote_cmake(skia.stub_flags) + "\")",
  )
  lines.push(
    "set(MOUI_SKIA_CC_LINK_FLAGS \"" + quote_cmake(skia.link_flags) + "\")",
  )
  lines.push("")
  let text = lines.join("\n")
  match write_file_bytes_result(path, @utf8.encode(text[:], bom=false)) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
fn build_json_object(pairs : Array[(String, Json)]) -> Json {
  let fields : Map[String, Json] = Map([])
  for pair in pairs {
    fields[pair.0] = pair.1
  }
  Json::object(fields)
}

///|
fn json_string_array(values : Array[String]) -> Json {
  let items : Array[Json] = []
  for value in values {
    items.push(Json::string(value))
  }
  Json::array(items)
}

///|
fn renderer_selection_to_json(value : RendererSelection) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["requested"] = Json::string(value.requested)
  fields["selected"] = Json::string(value.selected)
  fields["gpuPromoted"] = Json::boolean(value.gpu_promoted)
  match value.fallback_reason {
    Some(reason) => fields["fallbackReason"] = Json::string(reason)
    None => fields["fallbackReason"] = Json::null()
  }
  Json::object(fields)
}

///|
/// Prepare the Android native build inputs. Replaces `prepareAndroid`.
/// Validates the ABI, generates MoonBit C, resolves Skia, copies shared
/// libraries, writes the CMake config, and emits `shell-build.json`.
fn prepare_android(options : PrepareOptions) -> Result[PrepareResult, String] {
  if lookup_static_map(android_abi_to_skia_arch, options.abi) is None {
    return Err("unsupported Android ABI: " + options.abi)
  }
  guard options.app.android is Some(android) else {
    return Err("app " + options.app.id + " does not configure Android")
  }
  if android.runner_mode != options.android_shell {
    return Err(
      "app " +
      options.app.id +
      " requests Android runnerMode=" +
      android.runner_mode +
      "; " +
      options.android_shell +
      " shell required",
    )
  }
  if options.android_shell != "managed" && options.android_shell != "ejected" {
    return Err("--android-shell must be managed or ejected")
  }
  let moonbit_c = match
    generate_moonbit_c(
      options.workspace_root,
      options.contract.entrypoint_package,
      options.contract.generated_c,
      options.build_dir,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !path_is_file(moonbit_c) {
    return Err("MoonBit generated C was not found: " + moonbit_c)
  }
  let renderer_selection = match
    select_renderer(options.renderer, options.fallback_skia) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let skia_arch = match
    lookup_static_map(android_abi_to_skia_arch, options.abi) {
    Some(value) => value
    None => return Err("unsupported Android ABI: " + options.abi)
  }
  let link_mode = @env.get_env_var("MOUI_SKIA_LINK_MODE").unwrap_or_else(() => {
    if renderer_selection.selected == "skia-gpu" {
      "static"
    } else {
      "dynamic"
    }
  })
  let gpu_env : Array[(String, String)] = if renderer_selection.selected ==
    "skia-gpu" {
    [("MOUI_SKIA_ENABLE_GPU_VULKAN", "1"), ("MOUI_SKIA_ENABLE_GPU_EGL", "1")]
  } else {
    []
  }
  let skia = match
    resolve_skia(
      options.skia_root,
      "android",
      skia_arch,
      link_mode,
      options.fallback_skia,
      gpu_env,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let sdk_root = android_sdk_home()
  let jni_libs_dir = join_path(options.build_dir, "jniLibs")
  let mut ndk_copied = false
  if sdk_root != "" {
    let ndk_home = resolve_android_ndk_home(sdk_root)
    if ndk_home != "" {
      match
        copy_android_shared_libs(
          options.abi,
          ndk_home,
          skia.link_flags,
          jni_libs_dir,
        ) {
        Ok(_) => ndk_copied = true
        Err(message) => return Err(message)
      }
    }
  }
  let cmake_path = join_path(
    join_path(options.build_dir, "native"),
    "moui-shell-native.cmake",
  )
  match
    write_android_cmake_config(
      cmake_path,
      options.contract,
      options.app.id,
      moonbit_c,
      skia,
      options.abi,
      renderer_selection,
      options.workspace_root,
      options.moui_root,
      options.skia_root,
      options.shell_root,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let build_json = build_json_object([
    ("schemaVersion", Json::number(1.0)),
    ("platform", Json::string("android")),
    ("app", Json::string(options.app.id)),
    ("moonbitC", Json::string(moonbit_c)),
    ("cmakeConfig", Json::string(cmake_path)),
    ("jniLibsDir", Json::string(jni_libs_dir)),
    ("fallbackSkia", Json::boolean(options.fallback_skia)),
    ("renderer", renderer_selection_to_json(renderer_selection)),
    ("runnerMode", Json::string(options.android_shell)),
  ])
  let build_json_path = join_path(options.build_dir, "shell-build.json")
  match write_build_json(build_json_path, build_json) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok({
    platform: "android",
    build_json_path,
    cmake_config_path: Some(cmake_path),
    skia_cxx_rsp: None,
    skia_link_rsp: None,
    jni_libs_dir: if ndk_copied {
      Some(jni_libs_dir)
    } else {
      None
    },
    moonbit_c,
    renderer: renderer_selection,
    skia_link: skia,
    shared_libs: [],
  })
}

///|
/// Prepare the iOS native build inputs. Replaces `prepareIos`. Validates the
/// SDK/arch combination, generates MoonBit C, resolves Skia (Metal GPU when
/// promoted), and emits rsp + `shell-build.json` for the iOS shell builder.
fn prepare_ios(options : PrepareOptions) -> Result[PrepareResult, String] {
  if lookup_static_map(ios_sdk_to_skia_platform, options.sdk) is None {
    return Err("unsupported iOS SDK: " + options.sdk)
  }
  if lookup_static_map(ios_arch_to_skia_arch, options.arch) is None {
    return Err("unsupported iOS arch: " + options.arch)
  }
  if options.sdk == "iphoneos" && options.arch == "x86_64" {
    return Err("x86_64 is only valid for iphonesimulator")
  }
  let moonbit_c = match
    generate_moonbit_c(
      options.workspace_root,
      options.contract.entrypoint_package,
      options.contract.generated_c,
      options.build_dir,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !path_is_file(moonbit_c) {
    return Err("MoonBit generated C was not found: " + moonbit_c)
  }
  let renderer_selection = match
    select_renderer(options.renderer, options.fallback_skia) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
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
  let gpu_env : Array[(String, String)] = if renderer_selection.selected ==
    "skia-gpu" {
    [("MOUI_SKIA_ENABLE_GPU_METAL", "1")]
  } else {
    []
  }
  let skia = match
    resolve_skia(
      options.skia_root,
      skia_platform,
      skia_arch,
      link_mode,
      options.fallback_skia,
      gpu_env,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let native_dir = join_path(options.build_dir, "native")
  let cxx_rsp = join_path(native_dir, "skia-cxx-flags.rsp")
  let link_rsp = join_path(native_dir, "skia-link-flags.rsp")
  match write_rsp(cxx_rsp, skia.stub_flags) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match write_rsp(link_rsp, skia.link_flags) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let info_plist = match options.contract.info_plist {
    Some(value) =>
      if path_is_absolute(value) {
        value
      } else {
        join_path(options.workspace_root, value)
      }
    None => ""
  }
  let stub_sources = skia_stub_sources
    .copy()
    .map(path => join_path(options.skia_root, path))
  let build_json = build_json_object([
    ("schemaVersion", Json::number(1.0)),
    ("platform", Json::string("ios")),
    ("app", Json::string(options.app.id)),
    ("moonbitC", Json::string(moonbit_c)),
    ("skiaCxxRsp", Json::string(cxx_rsp)),
    ("skiaLinkRsp", Json::string(link_rsp)),
    ("fallbackSkia", Json::boolean(options.fallback_skia)),
    ("renderer", renderer_selection_to_json(renderer_selection)),
    ("appArg", Json::string(options.contract.entrypoint_arg)),
    ("moonbitMainAlias", Json::string(options.contract.moonbit_main_alias)),
    ("infoPlist", Json::string(info_plist)),
    ("workspaceRoot", Json::string(options.workspace_root)),
    ("mouiRoot", Json::string(options.moui_root)),
    ("skiaRoot", Json::string(options.skia_root)),
    ("skiaStubSources", json_string_array(stub_sources)),
  ])
  let build_json_path = join_path(options.build_dir, "shell-build.json")
  match write_build_json(build_json_path, build_json) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok({
    platform: "ios",
    build_json_path,
    cmake_config_path: None,
    skia_cxx_rsp: Some(cxx_rsp),
    skia_link_rsp: Some(link_rsp),
    jni_libs_dir: None,
    moonbit_c,
    renderer: renderer_selection,
    skia_link: skia,
    shared_libs: [],
  })
}

///|
/// Prepare the HarmonyOS native build inputs. Replaces `prepareHarmonyos`.
/// Validates the arch, generates MoonBit C, resolves Skia (EGL GPU when
/// promoted), enforces the dynamic/static Ganesh compatibility rule, writes
/// the CMake config, and emits `shell-build.json`.
fn prepare_harmonyos(options : PrepareOptions) -> Result[PrepareResult, String] {
  if lookup_static_map(harmonyos_arch_to_ohos_arch, options.arch) is None {
    return Err("unsupported HarmonyOS arch: " + options.arch)
  }
  let moonbit_c = match
    generate_moonbit_c(
      options.workspace_root,
      options.contract.entrypoint_package,
      options.contract.generated_c,
      options.build_dir,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !path_is_file(moonbit_c) {
    return Err("MoonBit generated C was not found: " + moonbit_c)
  }
  let renderer_selection = match
    select_renderer(options.renderer, options.fallback_skia) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let link_mode = @env.get_env_var("MOUI_SKIA_LINK_MODE").unwrap_or_else(() => {
    if renderer_selection.selected == "skia-gpu" {
      "static"
    } else {
      "dynamic"
    }
  })
  let gpu_env : Array[(String, String)] = if renderer_selection.selected ==
    "skia-gpu" {
    [("MOUI_SKIA_ENABLE_GPU_EGL", "1")]
  } else {
    []
  }
  let skia = match
    resolve_skia(
      options.skia_root,
      "harmonyos",
      options.arch,
      link_mode,
      options.fallback_skia,
      gpu_env,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match
    validate_harmonyos_skia_link_compatibility(
      renderer_selection.selected,
      skia.link_flags,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let ohos_arch = match
    lookup_static_map(harmonyos_arch_to_ohos_arch, options.arch) {
    Some(value) => value
    None => return Err("unsupported HarmonyOS arch: " + options.arch)
  }
  let cmake_path = join_path(
    join_path(options.build_dir, "native"),
    "moui-shell-harmonyos.cmake",
  )
  match
    write_harmonyos_cmake_config(
      cmake_path,
      options.contract,
      options.app.id,
      moonbit_c,
      skia,
      ohos_arch,
      renderer_selection,
      options.workspace_root,
      options.moui_root,
      options.skia_root,
      options.shell_root,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let shared_libs : Array[String] = []
  if contains_flag(skia.link_flags, "-lskia") {
    let skia_lib_dir = first_link_dir(skia.link_flags)
    if skia_lib_dir != "" {
      let skia_so = join_path(skia_lib_dir, "libskia.so")
      if path_is_file(skia_so) {
        shared_libs.push(skia_so)
      }
    }
  }
  let build_json = build_json_object([
    ("schemaVersion", Json::number(1.0)),
    ("platform", Json::string("harmonyos")),
    ("app", Json::string(options.app.id)),
    ("moonbitC", Json::string(moonbit_c)),
    ("cmakeConfig", Json::string(cmake_path)),
    ("fallbackSkia", Json::boolean(options.fallback_skia)),
    ("renderer", renderer_selection_to_json(renderer_selection)),
    ("appArg", Json::string(options.contract.entrypoint_arg)),
    ("moonbitMainAlias", Json::string(options.contract.moonbit_main_alias)),
    (
      "nativeLibrary",
      Json::string(options.contract.native_library.unwrap_or("")),
    ),
    ("ohosArch", Json::string(ohos_arch)),
    ("workspaceRoot", Json::string(options.workspace_root)),
    ("mouiRoot", Json::string(options.moui_root)),
    ("skiaRoot", Json::string(options.skia_root)),
    ("sharedLibs", json_string_array(shared_libs)),
  ])
  let build_json_path = join_path(options.build_dir, "shell-build.json")
  match write_build_json(build_json_path, build_json) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok({
    platform: "harmonyos",
    build_json_path,
    cmake_config_path: Some(cmake_path),
    skia_cxx_rsp: None,
    skia_link_rsp: None,
    jni_libs_dir: None,
    moonbit_c,
    renderer: renderer_selection,
    skia_link: skia,
    shared_libs,
  })
}

///|
/// Dispatch to the right per-platform prepare function. Mirrors the platform
/// switch in `prepare-native-build.mjs::run`.
fn prepare_native_build(
  options : PrepareOptions,
) -> Result[PrepareResult, String] {
  match options.contract.platform {
    "android" => prepare_android(options)
    "ios" => prepare_ios(options)
    "harmonyos" => prepare_harmonyos(options)
    other => Err("unsupported platform: " + other)
  }
}
