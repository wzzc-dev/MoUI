///|
let xcode_minimum_version : String = "15.4"

///|
let swift_minimum_version : String = "5.0"

///|
let harmonyos_compatible_api : Int = 20

///|
let harmonyos_target_api : Int = 21

///|
let harmonyos_model_version : String = "6.0.1"

///|
fn xcode_developer_roots(selected_root : String) -> Array[String] {
  let home = @env.get_env_var("HOME").unwrap_or("")
  [
    @env.get_env_var("DEVELOPER_DIR").unwrap_or(""),
    selected_root,
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
  let xcode_select = find_executable("xcode-select", host)
  if xcodebuild is None || xcrun is None || xcode_select is None {
    return doctor_check(
      "xcode",
      Fail,
      true,
      "Xcode command-line tools are incomplete",
      detail="xcodebuild=" +
        xcodebuild.unwrap_or("missing") +
        " xcrun=" +
        xcrun.unwrap_or("missing") +
        " xcode-select=" +
        xcode_select.unwrap_or("missing"),
      remediation="Install Xcode and select it with xcode-select or DEVELOPER_DIR.",
    )
  }
  let selected_root = match
    run_doctor_probe(xcode_select.unwrap(), XcodeDeveloperPath) {
    { status: 0, output } if output != "" => output
    probe =>
      return doctor_check(
        "xcode",
        Fail,
        true,
        "The selected Xcode developer directory could not be resolved",
        detail=if probe.output == "" {
          "xcode-select status=" + probe.status.to_string()
        } else {
          probe.output
        },
        remediation="Select a complete Xcode with xcode-select or DEVELOPER_DIR.",
      )
  }
  let xcode_version = match
    probe_version_floor(
      xcodebuild.unwrap(),
      DashVersion,
      "Xcode",
      [15, 4],
      "Xcode",
    ) {
    Ok(value) => value
    Err(message) =>
      return doctor_check(
        "xcode",
        Fail,
        true,
        "Xcode is below the 15.4 floor",
        detail=message,
        remediation="Install Xcode " +
          xcode_minimum_version +
          " or newer and select it with xcode-select or DEVELOPER_DIR.",
      )
  }
  let swift_version = match
    probe_version_floor(
      xcrun.unwrap(),
      SwiftCompilerVersion,
      "Apple Swift version",
      [5, 0],
      "Swift",
    ) {
    Ok(value) => value
    Err(message) =>
      return doctor_check(
        "xcode",
        Fail,
        true,
        "The selected Xcode does not provide Swift 5 language support",
        detail=message,
        remediation="Select a complete Xcode " +
          xcode_minimum_version +
          "+ installation that provides Swift " +
          swift_minimum_version +
          "+.",
      )
  }
  for root in xcode_developer_roots(selected_root) {
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
        detail=root +
          " | xcode=" +
          xcode_version +
          " | swift=" +
          swift_version +
          " | " +
          xcodebuild.unwrap() +
          " | " +
          xcrun.unwrap(),
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
fn harmonyos_doctor_check(
  project_root : String,
  host : HostPlatform,
  required : Bool,
) -> DoctorCheck {
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
    join_path(home, "Library/OpenHarmony/Sdk/21"),
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
  let (sdk_api, sdk_model, sdk_metadata_path) = match
    harmony_sdk_metadata(sdk_root.val) {
    Ok(value) => value
    Err(message) =>
      return doctor_check(
        "harmonyos",
        Fail,
        true,
        "HarmonyOS SDK version metadata is incomplete",
        detail=message,
        remediation="Select a DevEco SDK with API 21 and platformVersion 6.0.1 or newer.",
      )
  }
  let sdk_model_version = match first_numeric_version(sdk_model) {
    Some(value) => value
    None =>
      return doctor_check(
        "harmonyos",
        Fail,
        true,
        "HarmonyOS SDK platformVersion could not be parsed",
        detail=sdk_model + " | " + sdk_metadata_path,
      )
  }
  if sdk_api < harmonyos_target_api ||
    !numeric_version_at_least(sdk_model_version, [6, 0, 1]) {
    return doctor_check(
      "harmonyos",
      Fail,
      true,
      "HarmonyOS SDK is below the API 21 / model 6.0.1 floor",
      detail="api=" +
        sdk_api.to_string() +
        " platformVersion=" +
        sdk_model +
        " | " +
        sdk_metadata_path,
      remediation="Install/select HarmonyOS SDK API 21 with model 6.0.1 or newer.",
    )
  }
  let project_contract = match harmony_project_contract(project_root) {
    Ok(value) => value
    Err(message) =>
      return doctor_check(
        "harmonyos",
        Fail,
        true,
        "HarmonyOS project deployment metadata is incompatible",
        detail=message,
        remediation="Use compatible API " +
          harmonyos_compatible_api.to_string() +
          ", target API " +
          harmonyos_target_api.to_string() +
          ", and modelVersion " +
          harmonyos_model_version +
          ".",
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
      detail="sdkApi=" +
        sdk_api.to_string() +
        " sdkModel=" +
        sdk_model +
        " " +
        project_contract +
        " | " +
        toolchain_path.val +
        " | " +
        hvigor +
        " | " +
        ohpm +
        " | " +
        hdc,
    )
  } else {
    doctor_check(
      "harmonyos",
      Warn,
      true,
      "HarmonyOS build tools are available, but hdc was not found",
      detail="sdkApi=" +
        sdk_api.to_string() +
        " sdkModel=" +
        sdk_model +
        " " +
        project_contract +
        " | " +
        toolchain_path.val,
      remediation="Add the SDK toolchains directory to PATH before device runtime testing.",
    )
  }
}
