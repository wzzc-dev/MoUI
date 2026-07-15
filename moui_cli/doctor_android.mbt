///|
let android_compile_sdk : String = "36"

///|
let android_target_sdk : String = "35"

///|
let android_build_tools_version : String = "35.0.0"

///|
let android_cmake_version : String = "3.22.1"

///|
let android_ndk_version : String = "28.2.13676358"

///|
let android_gradle_version : String = "9.6.1"

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
  let requested_ndk = @env.get_env_var("MOUI_ANDROID_NDK_VERSION").unwrap_or(
    android_ndk_version,
  )
  let requested_ndk_version = match first_numeric_version(requested_ndk) {
    Some(value) => value
    None =>
      return doctor_check(
        "android",
        Fail,
        true,
        "MOUI_ANDROID_NDK_VERSION is invalid",
        detail=requested_ndk,
        remediation="Use an installed NDK revision at or above 28.2.",
      )
  }
  if !numeric_version_at_least(requested_ndk_version, [28, 2]) {
    return doctor_check(
      "android",
      Fail,
      true,
      "Configured Android NDK is below the 28.2 floor",
      detail=requested_ndk,
      remediation="Install Android NDK 28.2 and unset or update MOUI_ANDROID_NDK_VERSION.",
    )
  }
  let ndk_candidates = [
    @env.get_env_var("ANDROID_NDK_HOME").unwrap_or(""),
    @env.get_env_var("ANDROID_NDK_ROOT").unwrap_or(""),
    join_path(sdk_root, "ndk/" + requested_ndk),
  ]
  let ndk = Ref("")
  let ndk_revision_text = Ref("")
  let ndk_mismatch = Ref("")
  for candidate in ndk_candidates {
    if candidate == "" || !valid_android_ndk(candidate) {
      continue
    }
    match ndk_revision(candidate) {
      Some(revision) if numeric_version_at_least(revision, [28, 2]) &&
        numeric_version_has_prefix(revision, requested_ndk_version) => {
        ndk.val = candidate
        ndk_revision_text.val = numeric_version_text(revision)
        break
      }
      Some(revision) =>
        ndk_mismatch.val = candidate +
          " reports " +
          numeric_version_text(revision) +
          ", expected " +
          requested_ndk
      None => ndk_mismatch.val = candidate + " has no readable Pkg.Revision"
    }
  }
  if ndk.val == "" {
    return doctor_check(
      "android",
      Fail,
      true,
      "Android SDK is present but the required NDK 28.2 installation was not found",
      detail=if ndk_mismatch.val == "" { sdk_root } else { ndk_mismatch.val },
      remediation="Install Android NDK " +
        requested_ndk +
        " or set MOUI_ANDROID_NDK_VERSION and ANDROID_NDK_HOME to the same complete 28.2+ revision.",
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
  let java_version = match probe_java_floor(java.unwrap()) {
    Ok(value) => value
    Err(message) =>
      return doctor_check(
        "android",
        Fail,
        true,
        "Android builds require Java 17 or newer",
        detail=message,
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
  let gradle_version = match gradle_version_floor(project_root, gradle, host) {
    Some(Ok(value)) => Some(value)
    Some(Err(message)) =>
      return doctor_check(
        "android",
        Fail,
        true,
        "Gradle is below the managed shell floor",
        detail=message,
        remediation="Install Gradle " +
          android_gradle_version +
          "+ or update gradle-wrapper.properties without running the wrapper from doctor.",
      )
    None => None
  }
  let compile_android_jar = join_path(
    sdk_root,
    "platforms/android-" + android_compile_sdk + "/android.jar",
  )
  let target_android_jar = join_path(
    sdk_root,
    "platforms/android-" + android_target_sdk + "/android.jar",
  )
  let build_tools = versioned_android_executable(
    join_path(sdk_root, "build-tools"),
    "aapt2",
    [35, 0, 0],
  )
  let cmake = versioned_android_executable(
    join_path(sdk_root, "cmake"),
    "bin/cmake",
    [3, 22, 1],
  )
  if !path_is_nonempty_file(compile_android_jar) ||
    !path_is_nonempty_file(target_android_jar) ||
    build_tools is None ||
    cmake is None {
    return doctor_check(
      "android",
      Fail,
      true,
      "Android SDK build components are incomplete",
      detail="compileSdk" +
        android_compile_sdk +
        "=" +
        (if path_is_nonempty_file(compile_android_jar) {
          compile_android_jar
        } else {
          "missing"
        }) +
        " targetSdk" +
        android_target_sdk +
        "=" +
        (if path_is_nonempty_file(target_android_jar) {
          target_android_jar
        } else {
          "missing"
        }) +
        " buildTools>=35=" +
        (match build_tools {
          Some((path, _)) => path
          None => "missing"
        }) +
        " cmake>=3.22.1=" +
        (match cmake {
          Some((path, _)) => path
          None => "missing"
        }),
      remediation="Install Android Platforms " +
        android_target_sdk +
        " and " +
        android_compile_sdk +
        ", Build-Tools " +
        android_build_tools_version +
        "+, and CMake " +
        android_cmake_version +
        "+.",
    )
  }
  let (build_tools_path, build_tools_version) = match build_tools {
    Some(value) => value
    None => abort("validated Android build tools must be present")
  }
  let (cmake_path, cmake_directory_version) = match cmake {
    Some(value) => value
    None => abort("validated Android CMake must be present")
  }
  let cmake_version = match
    probe_version_floor(
      cmake_path,
      DoubleDashVersion,
      "cmake version",
      [3, 22, 1],
      "CMake",
    ) {
    Ok(value) => value
    Err(message) =>
      return doctor_check(
        "android",
        Fail,
        true,
        "Android CMake is below the managed shell floor",
        detail=message,
        remediation="Install Android SDK CMake " +
          android_cmake_version +
          " or newer.",
      )
  }
  let warnings : Array[String] = []
  if gradle_version is None {
    warnings.push(
      "Gradle version could not be detected without executing a wrapper",
    )
  }
  let adb = first_executable([
    join_path(sdk_root, "platform-tools/adb"),
    join_path(sdk_root, "platform-tools/adb.exe"),
  ])
  if adb is None {
    warnings.push("adb was not found")
  }
  let detail = "sdk=" +
    sdk_root +
    " compileSdk=" +
    android_compile_sdk +
    " targetSdk=" +
    android_target_sdk +
    " buildTools=" +
    build_tools_version +
    " aapt2=" +
    build_tools_path +
    " ndk=" +
    ndk_revision_text.val +
    " java=" +
    java_version +
    " gradle=" +
    gradle_version.unwrap_or("unknown") +
    " cmake=" +
    cmake_version +
    " (sdk " +
    cmake_directory_version +
    ")" +
    " adb=" +
    adb.unwrap_or("missing")
  if warnings.is_empty() {
    doctor_check(
      "android",
      Pass,
      true,
      "Android SDK and managed shell toolchain floors are satisfied",
      detail~,
    )
  } else {
    doctor_check(
      "android",
      Warn,
      true,
      "Android build floors are satisfied with runtime/tool version warnings",
      detail=detail + " | " + warnings.join("; "),
      remediation="Install Android Platform Tools and expose verifiable Gradle " +
        android_gradle_version +
        "+ metadata before release builds.",
    )
  }
}
