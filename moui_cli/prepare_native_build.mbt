// Shared support for embedded-runtime builds on the window-hosted route.
//
// This file contains only the common MoonBit-C, Skia, Android NDK, and response
// file helpers consumed by the Android, iOS, and HarmonyOS window templates.

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
/// Environment variables that must be stripped from a `moon build` spawn so
/// Xcode-injected SDK settings do not leak into a host native build.
let moon_build_env_blocked_keys : Array[String] = [
  "SDKROOT", "SDK_NAME", "PLATFORM_NAME", "EFFECTIVE_PLATFORM_NAME", "ARCHS", "VALID_ARCHS",
  "IPHONEOS_DEPLOYMENT_TARGET", "LLVM_TARGET_TRIPLE_OS_VERSION", "LLVM_TARGET_TRIPLE_SUFFIX",
  "LLVM_TARGET_TRIPLE_VENDOR",
]

///|
priv struct SkiaLink {
  stub_flags : String
  link_flags : String
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
fn read_file_bytes_optional(path : String) -> Bytes? {
  Some(@fs.read_file_to_bytes(path)) catch {
    _ => None
  }
}

///|
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
fn split_flags(flags : String) -> Array[String] {
  let trimmed = flags.trim()
  if trimmed == "" {
    return []
  }
  let result : Array[String] = []
  let current = StringBuilder()
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
fn xcrun_value(args : Array[String]) -> String {
  let argv = ["xcrun", ..args]
  match process_exec_argv(argv, capture=true) {
    Ok(result) if result.exit_code == 0 => result.stdout.trim().to_owned()
    _ => ""
  }
}

///|
fn normalize_moon_build_env(
  base : Array[(String, String)],
) -> Array[(String, String)] {
  let result : Array[(String, String)] = []
  for entry in base {
    let (key, value) = entry
    if moon_build_env_blocked_keys.contains(key) || key == "MOONBIT_NEW_NATIVE" {
      continue
    }
    result.push((key, value))
  }
  result.push(("MOUI_SKIA_DISABLE_PREBUILD_SKIA", "1"))
  result.push(("MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM", "1"))
  result.push(("MOONBIT_NEW_NATIVE", "0"))
  result
}

///|
fn moon_build_env() -> Array[(String, String)] {
  let result = normalize_moon_build_env(@env.get_env_vars().to_array())
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
  } else {
    log_info("moon build finished; resolving Skia link flags")
  }
  Ok(moonbit_c)
}

///|
fn options_fallback_allows_stub_link(
  fallback : Bool,
  stub_flags : String,
  link_flags : String,
) -> Bool {
  if fallback {
    return true
  }
  if stub_flags.contains("MOUI_SKIA_HAS_SKIA") {
    return true
  }
  link_flags.contains("libskia") || link_flags.contains("-lskia")
}

///|
fn skia_resolve_env() -> Array[(String, String)] {
  let base = @env.get_env_vars()
  let result : Array[(String, String)] = []
  for key, value in base {
    if moon_build_env_blocked_keys.contains(key) {
      continue
    }
    if key == "MOUI_SKIA_DISABLE_PREBUILD_SKIA" ||
      key == "MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM" {
      continue
    }
    result.push((key, value))
  }
  result
}

///|
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
  let env = skia_resolve_env()
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
      if !options_fallback_allows_stub_link(fallback, stub_flags, link_flags) {
        return Err(
          "moui_skia resolved stub-only link flags (no real Skia). " +
          "Unset MOUI_SKIA_DISABLE_PREBUILD_SKIA and ensure the platform Skia release is available under moui_skia/.skia-cache. " +
          "got MOUI_SKIA_CC_LINK_FLAGS=" +
          link_flags,
        )
      }
      log_info(
        "resolved Skia link_mode=" +
        link_mode +
        " platform=" +
        platform +
        " flags_len=" +
        link_flags.length().to_string(),
      )
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
    let destination = join_path(abi_dir, "libc++_shared.so")
    match read_file_bytes_optional(libcxx) {
      Some(bytes) => {
        match write_file_bytes_result(destination, bytes) {
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
fn write_rsp(path : String, flags : String) -> Result[Unit, String] {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let text = split_flags(flags).join("\n") + "\n"
  match write_file_bytes_result(path, @utf8.encode(text[:], bom=false)) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}
