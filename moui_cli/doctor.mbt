///|
priv enum DoctorStatus {
  Pass
  Warn
  Fail
  Skip
} derive(Eq)

///|
fn DoctorStatus::name(self : DoctorStatus) -> String {
  match self {
    Pass => "pass"
    Warn => "warn"
    Fail => "fail"
    Skip => "skip"
  }
}

///|
priv struct DoctorCheck {
  id : String
  status : DoctorStatus
  required : Bool
  summary : String
  detail : String
  remediation : String
}

///|
priv struct DoctorReport {
  schema_version : Int
  ok : Bool
  host : String
  project_root : String
  platforms : Array[String]
  checks : Array[DoctorCheck]
}

///|
priv struct DoctorOptions {
  project_root : String
  platforms : Array[String]
  all : Bool
}

///|
let android_compile_sdk : String = "36"

///|
let android_build_tools_version : String = "35.0.0"

///|
let android_cmake_version : String = "3.22.1"

///|
fn doctor_check(
  id : String,
  status : DoctorStatus,
  required : Bool,
  summary : String,
  detail? : String = "",
  remediation? : String = "",
) -> DoctorCheck {
  { id, status, required, summary, detail, remediation }
}

///|
fn skipped_check(id : String, summary : String) -> DoctorCheck {
  doctor_check(id, Skip, false, summary)
}

///|
fn path_is_file(path : String) -> Bool {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
fn path_is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
fn first_existing_file(paths : Array[String]) -> String? {
  for path in paths {
    if path != "" && path_is_file(path) {
      return Some(path)
    }
  }
  None
}

///|
fn path_is_nonempty_file(path : String) -> Bool {
  if !path_is_file(path) {
    return false
  }
  let bytes = @fs.read_file_to_bytes(path) catch { _ => return false }
  !bytes.is_empty()
}

///|
fn first_executable(paths : Array[String]) -> String? {
  for path in paths {
    if path != "" && path_is_nonempty_file(path) && path_is_executable(path) {
      return Some(path)
    }
  }
  None
}

///|
fn path_entries(host : HostPlatform) -> Array[String] {
  match @env.get_env_var("PATH") {
    Some(value) => {
      let separator = if host == Windows { ";" } else { ":" }
      value.split(separator).map(part => part.to_owned()).to_array()
    }
    None => []
  }
}

///|
fn executable_names(name : String, host : HostPlatform) -> Array[String] {
  if host == Windows {
    if name.to_lower().has_suffix(".exe") {
      [name]
    } else {
      [name + ".exe", name + ".cmd", name + ".bat", name]
    }
  } else {
    [name]
  }
}

///|
fn find_executable(name : String, host : HostPlatform) -> String? {
  for directory in path_entries(host) {
    let root = if directory == "" { "." } else { directory }
    for candidate in executable_names(name, host) {
      let path = join_path(root, candidate)
      if path_is_nonempty_file(path) && path_is_executable(path) {
        return Some(path)
      }
    }
  }
  None
}

///|
fn find_executable_in_home(
  name : String,
  home : String?,
  host : HostPlatform,
) -> String? {
  match home {
    Some(root) => {
      let candidates : Array[String] = []
      for executable in executable_names(name, host) {
        candidates.push(join_path(root, "bin/" + executable))
      }
      match first_executable(candidates) {
        Some(path) => return Some(path)
        None => ()
      }
    }
    None => ()
  }
  find_executable(name, host)
}

///|
fn env_directory(names : Array[String]) -> String? {
  for name in names {
    match @env.get_env_var(name) {
      Some(value) if path_is_dir(value) => return Some(value)
      _ => ()
    }
  }
  None
}

///|
fn valid_skia_root(root : String) -> Bool {
  path_is_dir(root) &&
  path_is_nonempty_file(join_path(root, "moon.mod")) &&
  path_is_nonempty_file(join_path(root, "build.js")) &&
  path_is_nonempty_file(join_path(root, "skia-provider-lock.json")) &&
  path_is_nonempty_file(join_path(root, "native/capabilities.json"))
}

///|
fn doctor_platforms(
  options : DoctorOptions,
  host : HostPlatform,
) -> Result[Array[String], String] {
  if options.all {
    return Ok([ for platform in platform_order => platform ])
  }
  if !options.platforms.is_empty() {
    let selected : Map[String, Bool] = Map([])
    for platform in options.platforms {
      let platform = platform.to_lower()
      if !is_platform(platform) {
        return Err("unsupported doctor platform: " + platform)
      }
      selected[platform] = true
    }
    let result : Array[String] = []
    for platform in platform_order {
      if selected.contains(platform) {
        result.push(platform)
      }
    }
    return Ok(result)
  }
  let manifest_path = join_path(options.project_root, "moui.project.json")
  if !@fs.path_exists(manifest_path) {
    return Ok(default_platforms(host))
  }
  match read_project_manifest(options.project_root) {
    Ok(manifest) => Ok(manifest.platforms)
    Err(message) => Err(message)
  }
}

///|
fn moonbit_doctor_check(host : HostPlatform) -> DoctorCheck {
  match find_executable("moon", host) {
    Some(path) =>
      doctor_check(
        "moonbit",
        Pass,
        true,
        "MoonBit CLI is available",
        detail=path,
      )
    None =>
      doctor_check(
        "moonbit",
        Fail,
        true,
        "MoonBit CLI is missing from PATH",
        remediation="Install MoonBit and ensure the moon executable is on PATH.",
      )
  }
}

///|
fn skia_doctor_check(project_root : String, required : Bool) -> DoctorCheck {
  if !required {
    return skipped_check(
      "skia", "Skia is not required by the selected Web-only project",
    )
  }
  let env_root = @env.get_env_var("MOUI_SKIA_ROOT").unwrap_or("")
  let candidates = [
    env_root,
    join_path(project_root, "moui_skia"),
    join_path(project_root, ".mooncakes/wzzc-dev/moui_skia"),
  ]
  let invalid_root = Ref("")
  for path in candidates {
    if valid_skia_root(path) {
      return doctor_check(
        "skia",
        Pass,
        true,
        "MoUI Skia package is available",
        detail=path,
      )
    }
    if invalid_root.val == "" && path_is_dir(path) {
      invalid_root.val = path
    }
  }
  doctor_check(
    "skia",
    Fail,
    true,
    if invalid_root.val == "" {
      "No local MoUI Skia package or override was found"
    } else {
      "The resolved MoUI Skia package is incomplete"
    },
    detail=invalid_root.val,
    remediation="Run moon update/build to resolve wzzc-dev/moui_skia, or set MOUI_SKIA_ROOT to a complete package root.",
  )
}

///|
fn valid_msvc_zlib_root(root : String) -> Bool {
  path_is_nonempty_file(join_path(root, "include/zlib.h")) &&
  (
    path_is_nonempty_file(join_path(root, "lib/zlib.lib")) ||
    path_is_nonempty_file(join_path(root, "lib/zlibstatic.lib"))
  )
}

///|
fn msvc_zlib_root(project_root : String) -> String? {
  let vcpkg_root = @env.get_env_var("VCPKG_ROOT").unwrap_or("")
  let vcpkg_installation = @env.get_env_var("VCPKG_INSTALLATION_ROOT").unwrap_or(
    "",
  )
  let candidates = [
    @env.get_env_var("MOUI_MSVC_ZLIB_TRIPLET_ROOT").unwrap_or(""),
    join_path(vcpkg_root, "installed/x64-windows"),
    join_path(vcpkg_installation, "installed/x64-windows"),
    join_path(project_root, ".tools/vcpkg-msvc/vcpkg_installed/x64-windows"),
    join_path(project_root, "vcpkg_installed/x64-windows"),
  ]
  for root in candidates {
    if root != "" && valid_msvc_zlib_root(root) {
      return Some(root)
    }
  }
  None
}

///|
fn msvc_doctor_check(
  project_root : String,
  host : HostPlatform,
  required : Bool,
) -> DoctorCheck {
  if !required {
    return skipped_check(
      "msvc", "MSVC is not required by the selected platforms",
    )
  }
  let configured = @env.get_env_var("VCToolsInstallDir") is Some(_) ||
    @env.get_env_var("VCINSTALLDIR") is Some(_) ||
    @env.get_env_var("VSINSTALLDIR") is Some(_)
  match find_executable("cl", host) {
    Some(path) => {
      if find_executable("node", host) is None {
        return doctor_check(
          "msvc",
          Fail,
          true,
          "MSVC is available, but Node.js is missing from PATH",
          detail=path,
          remediation="Install Node.js for MoonBit native build hooks.",
        )
      }
      match msvc_zlib_root(project_root) {
        Some(zlib) =>
          doctor_check(
            "msvc",
            Pass,
            true,
            "MSVC and the x64-windows zlib dependency are available",
            detail=path + " | " + zlib,
          )
        None =>
          doctor_check(
            "msvc",
            Fail,
            true,
            "MSVC is available, but zlib:x64-windows was not detected",
            detail=path,
            remediation="Run scripts/windows/setup_msvc_deps.ps1 -InstallZlib, then initialize scripts/windows/msvc_env.ps1.",
          )
      }
    }
    None if configured =>
      doctor_check(
        "msvc",
        Fail,
        true,
        "Visual Studio is configured but cl.exe is not on PATH",
        remediation="Run moui from a Visual Studio Developer PowerShell or initialize the MSVC environment.",
      )
    None =>
      doctor_check(
        "msvc",
        Fail,
        true,
        "MSVC Build Tools were not detected",
        remediation="Install Visual Studio Build Tools with the Desktop development with C++ workload.",
      )
  }
}

///|
fn wayland_doctor_check(host : HostPlatform, required : Bool) -> DoctorCheck {
  if !required {
    return skipped_check(
      "wayland", "Wayland is not required by the selected platforms",
    )
  }
  let scanner = find_executable("wayland-scanner", host)
  let pkg_config = find_executable("pkg-config", host)
  if scanner is None || pkg_config is None {
    return doctor_check(
      "wayland",
      Fail,
      true,
      "Wayland build tools are incomplete",
      detail="wayland-scanner=" +
        scanner.unwrap_or("missing") +
        " pkg-config=" +
        pkg_config.unwrap_or("missing"),
      remediation="Install wayland-scanner, pkg-config, libwayland-dev, and wayland-protocols.",
    )
  }
  let detail = scanner.unwrap() + " | " + pkg_config.unwrap()
  if @env.get_env_var("WAYLAND_DISPLAY") is None {
    doctor_check(
      "wayland",
      Warn,
      true,
      "Wayland build tools are available, but no active Wayland display is set",
      detail~,
      remediation="Set WAYLAND_DISPLAY when running native window smoke tests.",
    )
  } else {
    doctor_check(
      "wayland",
      Pass,
      true,
      "Wayland build and display environment is available",
      detail~,
    )
  }
}

///|
fn valid_android_ndk(root : String) -> Bool {
  if !path_is_nonempty_file(join_path(root, "source.properties")) {
    return false
  }
  let prebuilt = join_path(root, "toolchains/llvm/prebuilt")
  if !path_is_dir(prebuilt) {
    return false
  }
  let hosts : Array[String] = @fs.read_dir(prebuilt) catch { _ => [] }
  hosts.any(name => {
    first_executable([
      join_path(prebuilt, name + "/bin/clang"),
      join_path(prebuilt, name + "/bin/clang.exe"),
    ])
    is Some(_)
  })
}

///|
fn android_doctor_check(
  project_root : String,
  host : HostPlatform,
  required : Bool,
) -> DoctorCheck {
  if !required {
    return skipped_check(
      "android", "Android is not required by the selected platforms",
    )
  }
  let sdk = env_directory(["ANDROID_SDK_ROOT", "ANDROID_HOME"])
  guard sdk is Some(sdk_root) else {
    return doctor_check(
      "android",
      Fail,
      true,
      "Android SDK root was not detected",
      remediation="Set ANDROID_SDK_ROOT or ANDROID_HOME to an installed Android SDK.",
    )
  }
  let ndk_version = @env.get_env_var("MOUI_ANDROID_NDK_VERSION").unwrap_or(
    "28.2.13676358",
  )
  let ndk_candidates = [
    @env.get_env_var("ANDROID_NDK_HOME").unwrap_or(""),
    @env.get_env_var("ANDROID_NDK_ROOT").unwrap_or(""),
    join_path(sdk_root, "ndk/" + ndk_version),
  ]
  let ndk = Ref("")
  for candidate in ndk_candidates {
    if candidate != "" && valid_android_ndk(candidate) {
      ndk.val = candidate
      break
    }
  }
  if ndk.val == "" {
    return doctor_check(
      "android",
      Fail,
      true,
      "Android SDK is present but no complete NDK installation was found",
      detail=sdk_root,
      remediation="Install Android NDK " +
        ndk_version +
        " or set ANDROID_NDK_HOME to a complete NDK.",
    )
  }
  let java_home = env_directory(["JAVA_HOME"])
  let java = find_executable_in_home("java", java_home, host)
  let javac = find_executable_in_home("javac", java_home, host)
  let jlink = find_executable_in_home("jlink", java_home, host)
  if java is None || javac is None || jlink is None {
    return doctor_check(
      "android",
      Fail,
      true,
      "Android builds require a complete JDK",
      detail="java=" +
        java.unwrap_or("missing") +
        " javac=" +
        javac.unwrap_or("missing") +
        " jlink=" +
        jlink.unwrap_or("missing"),
      remediation="Install a Java 17+ JDK (Java 21 recommended) and set JAVA_HOME.",
    )
  }
  if find_executable("node", host) is None {
    return doctor_check(
      "android",
      Fail,
      true,
      "Node.js is missing from PATH",
      remediation="Install Node.js for the MoUI mobile build preparation step.",
    )
  }
  let gradle = first_executable([
    join_path(project_root, "gradlew"),
    join_path(project_root, "gradlew.bat"),
  ]).unwrap_or_else(() => find_executable("gradle", host).unwrap_or(""))
  if gradle == "" {
    return doctor_check(
      "android",
      Fail,
      true,
      "Gradle was not found",
      remediation="Add a Gradle wrapper at the project root or install Gradle.",
    )
  }
  let android_jar = join_path(
    sdk_root,
    "platforms/android-" + android_compile_sdk + "/android.jar",
  )
  let aapt2 = first_executable([
    join_path(sdk_root, "build-tools/" + android_build_tools_version + "/aapt2"),
    join_path(
      sdk_root,
      "build-tools/" + android_build_tools_version + "/aapt2.exe",
    ),
  ])
  let cmake = first_executable([
    join_path(sdk_root, "cmake/" + android_cmake_version + "/bin/cmake"),
    join_path(sdk_root, "cmake/" + android_cmake_version + "/bin/cmake.exe"),
  ])
  if !path_is_nonempty_file(android_jar) || aapt2 is None || cmake is None {
    return doctor_check(
      "android",
      Fail,
      true,
      "Android SDK build components are incomplete",
      detail="compileSdk" +
        android_compile_sdk +
        "=" +
        (if path_is_nonempty_file(android_jar) {
          android_jar
        } else {
          "missing"
        }) +
        " buildTools" +
        android_build_tools_version +
        "=" +
        aapt2.unwrap_or("missing") +
        " cmake" +
        android_cmake_version +
        "=" +
        cmake.unwrap_or("missing"),
      remediation="Install Android Platform " +
        android_compile_sdk +
        ", Build-Tools " +
        android_build_tools_version +
        ", and CMake " +
        android_cmake_version +
        ".",
    )
  }
  let adb = first_executable([
    join_path(sdk_root, "platform-tools/adb"),
    join_path(sdk_root, "platform-tools/adb.exe"),
  ])
  match adb {
    Some(path) =>
      doctor_check(
        "android",
        Pass,
        true,
        "Android SDK, NDK, JDK, Gradle, CMake, and adb are available",
        detail=path + " | " + ndk.val + " | " + gradle,
      )
    None =>
      doctor_check(
        "android",
        Warn,
        true,
        "Android build tools are available, but adb was not found",
        detail=sdk_root,
        remediation="Install Android SDK Platform Tools before device runtime testing.",
      )
  }
}

///|
fn xcode_developer_roots() -> Array[String] {
  let home = @env.get_env_var("HOME").unwrap_or("")
  [
    @env.get_env_var("DEVELOPER_DIR").unwrap_or(""),
    "/Applications/Xcode.app/Contents/Developer",
    "/Applications/Xcode-beta.app/Contents/Developer",
    join_path(home, "Applications/Xcode.app/Contents/Developer"),
    "/Library/Developer/CommandLineTools",
  ]
}

///|
fn has_valid_apple_sdk(root : String) -> Bool {
  if !path_is_dir(root) {
    return false
  }
  let entries : Array[String] = @fs.read_dir(root) catch { _ => [] }
  entries.any(name => {
    path_is_nonempty_file(join_path(root, name + "/SDKSettings.json"))
  })
}

///|
fn xcode_root_supports_macos(root : String) -> Bool {
  has_valid_apple_sdk(
    join_path(root, "Platforms/MacOSX.platform/Developer/SDKs"),
  ) ||
  has_valid_apple_sdk(join_path(root, "SDKs"))
}

///|
fn xcode_root_supports_ios(root : String) -> Bool {
  has_valid_apple_sdk(
    join_path(root, "Platforms/iPhoneOS.platform/Developer/SDKs"),
  ) &&
  has_valid_apple_sdk(
    join_path(root, "Platforms/iPhoneSimulator.platform/Developer/SDKs"),
  )
}

///|
fn xcode_doctor_check(
  host : HostPlatform,
  macos_required : Bool,
  ios_required : Bool,
) -> DoctorCheck {
  if !macos_required && !ios_required {
    return skipped_check(
      "xcode", "Xcode is not required by the selected platforms",
    )
  }
  let xcodebuild = find_executable("xcodebuild", host)
  let xcrun = find_executable("xcrun", host)
  if xcodebuild is None || xcrun is None {
    return doctor_check(
      "xcode",
      Fail,
      true,
      "Xcode command-line tools are incomplete",
      detail="xcodebuild=" +
        xcodebuild.unwrap_or("missing") +
        " xcrun=" +
        xcrun.unwrap_or("missing"),
      remediation="Install Xcode and select it with xcode-select or DEVELOPER_DIR.",
    )
  }
  for root in xcode_developer_roots() {
    if root != "" &&
      (!macos_required || xcode_root_supports_macos(root)) &&
      (!ios_required || xcode_root_supports_ios(root)) {
      return doctor_check(
        "xcode",
        Pass,
        true,
        if ios_required {
          "Xcode macOS and iOS SDKs are available"
        } else {
          "Xcode macOS SDK is available"
        },
        detail=root + " | " + xcodebuild.unwrap() + " | " + xcrun.unwrap(),
      )
    }
  }
  doctor_check(
    "xcode",
    Fail,
    true,
    if ios_required {
      "Xcode was found, but the iOS device/simulator SDKs are incomplete"
    } else {
      "Xcode command-line tools were found, but no macOS SDK was detected"
    },
    remediation="Install/select a complete Xcode developer directory.",
  )
}

///|
fn harmonyos_doctor_check(host : HostPlatform, required : Bool) -> DoctorCheck {
  if !required {
    return skipped_check(
      "harmonyos", "HarmonyOS is not required by the selected platforms",
    )
  }
  let home = @env.get_env_var("HOME").unwrap_or("")
  let sdk_candidates = [
    @env.get_env_var("HARMONYOS_SDK_HOME").unwrap_or(""),
    @env.get_env_var("OHOS_SDK_HOME").unwrap_or(""),
    "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony",
    "/Applications/DevEco-Studio.app/Contents/sdk/default/hms",
    "/Applications/DevEco Studio.app/Contents/sdk/default/openharmony",
    "/Applications/DevEco Studio.app/Contents/sdk/default/hms",
    join_path(home, "Library/OpenHarmony/Sdk/20"),
  ]
  let sdk_root = Ref("")
  let toolchain_path = Ref("")
  for candidate in sdk_candidates {
    let toolchain = first_existing_file([
      join_path(candidate, "native/build/cmake/ohos.toolchain.cmake"),
      join_path(
        candidate, "default/openharmony/native/build/cmake/ohos.toolchain.cmake",
      ),
      join_path(
        candidate, "default/hms/native/build/cmake/ohos.toolchain.cmake",
      ),
      join_path(
        candidate, "openharmony/native/build/cmake/ohos.toolchain.cmake",
      ),
    ])
    match toolchain {
      Some(path) if path_is_nonempty_file(path) => {
        sdk_root.val = candidate
        toolchain_path.val = path
        break
      }
      _ => ()
    }
  }
  if sdk_root.val == "" {
    return doctor_check(
      "harmonyos",
      Fail,
      true,
      "HarmonyOS/OpenHarmony SDK root was not detected",
      remediation="Install DevEco Studio and set HARMONYOS_SDK_HOME.",
    )
  }
  let hvigor = first_executable([
    @env.get_env_var("HVIGORW").unwrap_or(""),
    "/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw",
    "/Applications/DevEco Studio.app/Contents/tools/hvigor/bin/hvigorw",
  ]).unwrap_or_else(() => find_executable("hvigorw", host).unwrap_or(""))
  let ohpm = first_executable([
    @env.get_env_var("OHPM").unwrap_or(""),
    "/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm",
    "/Applications/DevEco Studio.app/Contents/tools/ohpm/bin/ohpm",
  ]).unwrap_or_else(() => find_executable("ohpm", host).unwrap_or(""))
  let node = find_executable("node", host)
  let cmake = find_executable("cmake", host)
  let zip = find_executable("zip", host)
  if hvigor == "" || ohpm == "" || node is None || cmake is None || zip is None {
    return doctor_check(
      "harmonyos",
      Fail,
      true,
      "HarmonyOS build tools are incomplete",
      detail="hvigorw=" +
        (if hvigor == "" { "missing" } else { hvigor }) +
        " ohpm=" +
        (if ohpm == "" { "missing" } else { ohpm }) +
        " node=" +
        node.unwrap_or("missing") +
        " cmake=" +
        cmake.unwrap_or("missing") +
        " zip=" +
        zip.unwrap_or("missing"),
      remediation="Install DevEco Hvigor/ohpm plus Node.js, CMake, and zip; set HVIGORW/OHPM or add them to PATH.",
    )
  }
  let hdc = first_executable([
    join_path(sdk_root.val, "toolchains/hdc"),
    join_path(sdk_root.val, "toolchains/hdc.exe"),
    join_path(sdk_root.val, "../toolchains/hdc"),
    join_path(sdk_root.val, "../toolchains/hdc.exe"),
  ]).unwrap_or_else(() => find_executable("hdc", host).unwrap_or(""))
  if hdc != "" {
    doctor_check(
      "harmonyos",
      Pass,
      true,
      "HarmonyOS SDK, Hvigor, ohpm, native tools, and hdc are available",
      detail=toolchain_path.val + " | " + hvigor + " | " + ohpm + " | " + hdc,
    )
  } else {
    doctor_check(
      "harmonyos",
      Warn,
      true,
      "HarmonyOS build tools are available, but hdc was not found",
      detail=toolchain_path.val,
      remediation="Add the SDK toolchains directory to PATH before device runtime testing.",
    )
  }
}

///|
fn project_entrypoint_checks(
  project_root : String,
  platforms : Array[String],
) -> Array[DoctorCheck] {
  let checks : Array[DoctorCheck] = []
  for platform in ["android", "ios", "harmonyos"] {
    if platforms.contains(platform) {
      let package_path = join_path(project_root, platform + "_skia/moon.pkg")
      let main_path = join_path(project_root, platform + "_skia/main.mbt")
      let package_text = @fs.read_file_to_string(package_path) catch { _ => "" }
      let main_text = @fs.read_file_to_string(main_path) catch { _ => "" }
      let common_markers = [
        "moui_mobile_take_host_update_envelope_json", "moui_mobile_dispatch_host_response_envelope_json",
        "moui_mobile_renderer_configure", "moui_mobile_renderer_status_json", "moui_mobile_dispatch_text_input",
        "moui_mobile_dispatch_command", "moui_mobile_dispatch_accessibility", "moui_mobile_complete_clipboard_v1",
        "moui_mobile_attach_surface", "moui_mobile_resize", "moui_mobile_dispatch_pointer",
        "moui_mobile_dispatch_scroll", "moui_mobile_frame_tick", "moui_mobile_render_frame",
        "moui_mobile_detach_surface", "moui_mobile_destroy_application",
      ]
      let missing : Array[String] = []
      for marker in common_markers {
        if !package_text.contains(marker) || !main_text.contains(marker) {
          missing.push(marker)
        }
      }
      if path_is_nonempty_file(package_path) &&
        path_is_nonempty_file(main_path) &&
        missing.is_empty() {
        checks.push(
          doctor_check(
            "project." + platform + ".entrypoint",
            Pass,
            true,
            platform + " MoonBit entrypoint is present",
            detail=package_path + " | " + main_path,
          ),
        )
      } else {
        checks.push(
          doctor_check(
            "project." + platform + ".entrypoint",
            Warn,
            true,
            platform +
            " shell metadata is present but its MoonBit entrypoint contract is incomplete",
            detail=if missing.is_empty() {
              "expected nonempty " + package_path + " and " + main_path
            } else {
              "missing markers: " + missing.join(", ")
            },
            remediation="Generate or add the platform entrypoint before building the native shell.",
          ),
        )
      }
    }
  }
  checks
}

///|
fn run_doctor(options : DoctorOptions) -> Result[DoctorReport, String] {
  let host_platform = detect_host_platform()
  let project_manifest_path = join_path(
    options.project_root,
    "moui.project.json",
  )
  if @fs.path_exists(project_manifest_path) {
    match read_project_manifest(options.project_root) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  let platforms = match doctor_platforms(options, host_platform) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let native_selected = platforms.any(platform => platform != "web")
  let checks = [
    moonbit_doctor_check(host_platform),
    skia_doctor_check(options.project_root, native_selected),
    msvc_doctor_check(
      options.project_root,
      host_platform,
      platforms.contains("windows"),
    ),
    wayland_doctor_check(host_platform, platforms.contains("linux")),
    android_doctor_check(
      options.project_root,
      host_platform,
      platforms.contains("android"),
    ),
    xcode_doctor_check(
      host_platform,
      platforms.contains("macos"),
      platforms.contains("ios"),
    ),
    harmonyos_doctor_check(host_platform, platforms.contains("harmonyos")),
  ]
  for check in project_entrypoint_checks(options.project_root, platforms) {
    checks.push(check)
  }
  for check in mobile_project_doctor_checks(options.project_root, platforms) {
    checks.push(check)
  }
  let ok = !checks.any(check => check.required && check.status == Fail)
  Ok({
    schema_version: 1,
    ok,
    host: host_platform.name(),
    project_root: options.project_root,
    platforms,
    checks,
  })
}

///|
fn doctor_check_json(check : DoctorCheck) -> Json {
  (
    {
      "id": check.id,
      "status": check.status.name(),
      "required": check.required,
      "summary": check.summary,
      "detail": check.detail,
      "remediation": check.remediation,
    } : Json)
}

///|
fn DoctorReport::to_json_text(self : DoctorReport) -> String {
  let checks = self.checks.map(doctor_check_json)
  let value : Json = {
    "schemaVersion": self.schema_version,
    "ok": self.ok,
    "host": self.host,
    "projectRoot": self.project_root,
    "platforms": self.platforms,
    "checks": checks,
  }
  value.stringify(indent=2) + "\n"
}

///|
fn DoctorReport::to_human_text(self : DoctorReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string("MoUI doctor host=" + self.host + "\n")
  for check in self.checks {
    builder.write_string(
      "[" + check.status.name() + "] " + check.id + ": " + check.summary + "\n",
    )
    if check.detail != "" {
      builder.write_string("  " + check.detail + "\n")
    }
    if check.remediation != "" {
      builder.write_string("  Fix: " + check.remediation + "\n")
    }
  }
  builder.write_string(
    if self.ok {
      "Doctor completed without required failures.\n"
    } else {
      "Doctor found required environment failures.\n"
    },
  )
  builder.to_string()
}
