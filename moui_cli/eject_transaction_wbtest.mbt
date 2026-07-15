///|
fn eject_test_temp_path(label : String) -> String {
  let root = match @env.get_env_var("TMPDIR") {
    Some(value) => value
    None =>
      match @env.get_env_var("TEMP") {
        Some(value) => value
        None => @env.get_env_var("TMP").unwrap_or(".")
      }
  }
  join_path(root, "moui-cli-eject-" + label + "-" + @env.now().to_string())
}

///|
fn eject_test_write_text(path : String, value : String) -> Unit raise {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @fs.write_string_to_file(path, value) catch {
    _ => fail("could not write eject test file: " + path)
  }
}

///|
fn eject_test_mobile_text() -> String {
  let value : Json = {
    "schemaVersion": 2,
    "id": "sample_app",
    "displayName": "Sample App",
    "artifactName": "sample_app",
    "appPackage": "app",
    "shellApiVersion": 1,
    "runtimeAbiVersion": 1,
    "mobile": {
      "renderer": "auto",
      "systemUi": { "fullscreen": false, "statusBar": "auto" },
      "orientation": "any",
      "resources": [],
      "permissions": [],
      "plugins": [],
    },
    "android": {
      "shellMode": "managed",
      "applicationId": "dev.example.sample",
      "minSdk": 23,
    },
  }
  value.stringify(indent=2) + "\n"
}

///|
fn eject_test_manifest_text() -> String {
  let manifest : ProjectManifest = {
    schema_version: 1,
    id: "sample_app",
    title: "Sample App",
    module_name: "example/sample_app",
    moui_version: "0.1.7",
    platforms: ["web", "android"],
    bundle_id: Some("dev.example.sample"),
  }
  manifest.to_json_text()
}

///|
fn eject_test_prepare_project(root : String, moui_root : String) -> Unit raise {
  eject_test_write_text(
    join_path(root, "moui.project.json"),
    eject_test_manifest_text(),
  )
  eject_test_write_text(
    join_path(root, "mobile.json"),
    eject_test_mobile_text(),
  )
  eject_test_write_text(
    join_path(moui_root, "mobile/android/template/README.md"),
    "dev.example.myapp|my_app|my-app|MoUIMobileAndroid\n",
  )
  for
    path in [
      "mobile/android/src/main/kotlin/dev/example/Shell.kt", "mobile/android/src/main/cpp/glue.cpp",
      "mobile/android/cmake/MoUIMobileAndroid.cmake", "mobile/android/mobile-app.gradle",
      "mobile/include/moui_mobile_runtime_v1.h", "mobile/runtime/moui_mobile_runtime_v1.cpp",
    ] {
    eject_test_write_text(join_path(moui_root, path), "fixture\n")
  }
}

///|
test "framework package resolution uses the nearest workspace ancestor" {
  let root = eject_test_temp_path("workspace-root")
  let project = join_path(root, "examples/sample")
  let moui_root = join_path(root, "moui")
  remove_tree(root)
  eject_test_write_text(join_path(root, "moon.work"), "members = []\n")
  eject_test_write_text(join_path(moui_root, "mobile/.keep"), "fixture\n")
  match mkdir_p(project) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let resolved = match
    resolve_moui_root({
      project_root: project,
      platform: "android",
      output: "",
      moui_root: None,
    }) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  remove_tree(root)
  inspect(resolved, content=moui_root)
}

///|
test "mobile eject commits updated config and matching lock digest" {
  let root = eject_test_temp_path("commit")
  let moui_root = join_path(root, "moui-package")
  remove_tree(root)
  eject_test_prepare_project(root, moui_root)
  let result = match
    eject_mobile_shell({
      project_root: root,
      platform: "android",
      output: "",
      moui_root: Some(moui_root),
    }) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let mobile_path = join_path(root, "mobile.json")
  let mobile_text = @fs.read_file_to_string(mobile_path) catch {
    _ => fail("could not read committed mobile.json")
  }
  let mobile_json = @json.parse(mobile_text) catch {
    _ => fail("committed mobile.json must parse")
  }
  guard mobile_json is Object(root_fields) else {
    fail("committed mobile.json must be an object")
  }
  guard root_fields.get("android") is Some(Object(android)) else {
    fail("committed mobile.json must contain android")
  }
  inspect(android.get("shellMode") is Some(String("ejected")), content="true")
  let mobile_bytes = @fs.read_file_to_bytes(mobile_path) catch {
    _ => fail("could not read mobile config bytes")
  }
  let config_bytes = match project_config_bytes(root, mobile_bytes, "android") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let expected_digest = sha256_hex(config_bytes)
  inspect(result.config_digest == expected_digest, content="true")
  let lock_text = @fs.read_file_to_string(
    join_path(result.output, ".moui-shell.json"),
  ) catch {
    _ => fail("could not read ejected shell lock")
  }
  inspect(
    lock_text.contains("\"configDigest\": \"sha256:" + expected_digest + "\""),
    content="true",
  )
  inspect(
    lock_text.contains(
      "\"pluginDigest\": \"sha256:" + doctor_plugins_digest([]) + "\"",
    ),
    content="true",
  )
  let identity = @fs.read_file_to_string(join_path(result.output, "README.md")) catch {
    _ => fail("could not read rendered identity file")
  }
  inspect(
    identity,
    content="dev.example.sample|sample_app|sample-app|SampleApp\n",
  )
  remove_tree(root)
}

///|
test "mobile eject refuses an existing target without changing project state" {
  let root = eject_test_temp_path("existing")
  let moui_root = join_path(root, "moui-package")
  remove_tree(root)
  eject_test_prepare_project(root, moui_root)
  let output = join_path(root, "android_app")
  let marker = join_path(output, "keep.txt")
  eject_test_write_text(marker, "keep\n")
  let mobile_path = join_path(root, "mobile.json")
  let original_mobile = @fs.read_file_to_string(mobile_path) catch {
    _ => fail("could not read original mobile config")
  }
  let result = eject_mobile_shell({
    project_root: root,
    platform: "android",
    output: "",
    moui_root: Some(moui_root),
  })
  let final_mobile = @fs.read_file_to_string(mobile_path) catch {
    _ => fail("could not read mobile config after refused eject")
  }
  let marker_text = @fs.read_file_to_string(marker) catch {
    _ => fail("could not read existing target marker")
  }
  remove_tree(root)
  inspect(
    result is Err(message) && message.contains("target already exists"),
    content="true",
  )
  inspect(final_mobile == original_mobile, content="true")
  inspect(marker_text, content="keep\n")
}

///|
test "structured JSON ejection preserves hostile display titles" {
  let title = "A \"quoted\" \\ title\nwith <xml> & data"
  let manifest : ProjectManifest = {
    schema_version: 1,
    id: "sample_app",
    title,
    module_name: "example/sample_app",
    moui_version: "0.1.7",
    platforms: ["harmonyos"],
    bundle_id: Some("dev.example.sample"),
  }
  let source = [
    text_file(
      "AppScope/resources/base/element/string.json",
      (
        #|{
        #|  "string": [{ "name": "app_name", "value": "My MoUI App" }]
        #|}
      ),
    ),
    text_file(
      "AppScope/app.json5",
      (
        #|{
        #|  "app": { "bundleName": "dev.example.mouiapp" }
        #|}
      ),
    ),
  ]
  let rendered = match render_ejected_files(source, manifest, "harmonyos") {
    Ok(files) => files
    Err(message) => fail(message)
  }
  let string_text = test_planned_text(
    rendered, "AppScope/resources/base/element/string.json",
  )
  let parsed = @json.parse(string_text) catch {
    _ => fail("rendered HarmonyOS string resource must remain valid JSON")
  }
  guard parsed is Object(root) else {
    fail("string resource must be an object")
  }
  guard root.get("string") is Some(Array([Object(entry)])) else {
    fail("string resource must retain its entry")
  }
  inspect(entry.get("value") == Some(title.to_json()), content="true")
  let app_text = test_planned_text(rendered, "AppScope/app.json5")
  inspect(app_text.contains("dev.example.sample"), content="true")
  inspect(@json.parse(app_text) is Object(_), content="true")
}

///|
test "unstructured display title placeholders fail closed" {
  let manifest : ProjectManifest = {
    schema_version: 1,
    id: "sample_app",
    title: "Unsafe \"title\"",
    module_name: "example/sample_app",
    moui_version: "0.1.7",
    platforms: ["android"],
    bundle_id: Some("dev.example.sample"),
  }
  inspect(
    render_ejected_files(
      [text_file("unexpected.txt", "My MoUI App")],
      manifest,
      "android",
    )
    is Err(_),
    content="true",
  )
}

///|
test "Android ejection preserves fixed framework CMake include names" {
  let manifest : ProjectManifest = {
    schema_version: 1,
    id: "sample_app",
    title: "Sample App",
    module_name: "example/sample_app",
    moui_version: "0.1.7",
    platforms: ["android"],
    bundle_id: Some("dev.example.sample"),
  }
  let rendered = match
    render_ejected_files(
      [
        text_file(
          "app/src/main/cpp/CMakeLists.txt", "include(\"${MOUI_ROOT}/mobile/android/cmake/MoUIMobileAndroid.cmake\")",
        ),
        text_file("settings.gradle", "rootProject.name = \"MoUIMobileAndroid\""),
      ],
      manifest,
      "android",
    ) {
    Ok(files) => files
    Err(message) => fail(message)
  }
  inspect(
    test_planned_text(rendered, "app/src/main/cpp/CMakeLists.txt").contains(
      "${CMAKE_CURRENT_LIST_DIR}/MoUIMobileAndroid.cmake",
    ),
    content="true",
  )
  inspect(
    test_planned_text(rendered, "settings.gradle").contains(
      "rootProject.name = \"SampleApp\"",
    ),
    content="true",
  )
}

///|
test "Android ejection rewrites runtime ABI paths to the local snapshot" {
  let source =
    #|if(NOT EXISTS "${MOUI_ROOT}/mobile/include/moui_mobile_runtime_v1.h")
    #|  message(FATAL_ERROR "missing runtime ABI")
    #|endif()
    #|list(APPEND sources "${MOUI_ROOT}/mobile/runtime/moui_mobile_runtime_v1.cpp")
    #|target_include_directories(shell PRIVATE "${MOUI_ROOT}/mobile/include")
  let rendered = patch_ejected_shell_text(
    "app/src/main/cpp/MoUIMobileAndroid.cmake", source, "android",
  )
  let local_root = "${CMAKE_CURRENT_LIST_DIR}/../../../../moui/runtime"
  inspect(
    rendered.contains(local_root + "/moui_mobile_runtime_v1.h"),
    content="true",
  )
  inspect(
    rendered.contains(local_root + "/moui_mobile_runtime_v1.cpp"),
    content="true",
  )
  inspect(rendered.contains("${MOUI_ROOT}/mobile/include"), content="false")
  inspect(rendered.contains("${MOUI_ROOT}/mobile/runtime"), content="false")
}

///|
test "HarmonyOS ejection uses local shell glue and runtime ABI snapshot" {
  let source =
    #|set(MOUI_MOBILE_SHARED_HARMONYOS_DIR "${MOUI_ROOT}/mobile/harmonyos")
    #|list(APPEND sources "${MOUI_MOBILE_SHARED_HARMONYOS_DIR}/src/main/cpp/moui_mobile_harmonyos_napi.cpp")
    #|if(NOT EXISTS "${MOUI_ROOT}/mobile/include/moui_mobile_runtime_v1.h")
    #|  message(FATAL_ERROR "missing runtime ABI")
    #|endif()
    #|list(APPEND sources "${MOUI_ROOT}/mobile/runtime/moui_mobile_runtime_v1.cpp")
    #|target_include_directories(shell PRIVATE "${MOUI_ROOT}/mobile/include")
  let rendered = patch_ejected_shell_text(
    "entry/src/main/cpp/MoUIMobileHarmonyOS.cmake", source, "harmonyos",
  )
  let local_runtime = "${CMAKE_CURRENT_LIST_DIR}/../../../../moui/runtime"
  inspect(
    rendered.contains(
      (
        #|set(MOUI_MOBILE_SHARED_HARMONYOS_DIR "${CMAKE_CURRENT_LIST_DIR}/moui")
      ),
    ),
    content="true",
  )
  inspect(
    rendered.contains(local_runtime + "/moui_mobile_runtime_v1.h"),
    content="true",
  )
  inspect(
    rendered.contains(local_runtime + "/moui_mobile_runtime_v1.cpp"),
    content="true",
  )
  inspect(
    rendered.contains(
      "${MOUI_MOBILE_SHARED_HARMONYOS_DIR}/moui_mobile_harmonyos_napi.cpp",
    ),
    content="true",
  )
  inspect(
    rendered.contains("${MOUI_MOBILE_SHARED_HARMONYOS_DIR}/src/main/cpp"),
    content="false",
  )
  inspect(rendered.contains("${MOUI_ROOT}/mobile/include"), content="false")
  inspect(rendered.contains("${MOUI_ROOT}/mobile/runtime"), content="false")
}

///|
test "iOS ejection invokes the local build script from PBX" {
  let source =
    #|SWIFT_VERSION = 5.0;
    #|shellScript = "set -euo pipefail\n: \"${MOUI_PACKAGE_ROOT:?MOUI_PACKAGE_ROOT is required}\"\n\"$MOUI_PACKAGE_ROOT/scripts/mobile/build-ios-app-core.sh\" --app \"${MOUI_MOBILE_APP:-my_app}\"\n";
  let rendered = patch_ejected_shell_text(
    "MoUIMobileApp.xcodeproj/project.pbxproj", source, "ios",
  )
  inspect(
    rendered.contains(
      (
        #|MOUI_MOBILE_SHELL_ROOT=\"${PROJECT_DIR}\" /bin/bash \"${PROJECT_DIR}/moui/build-ios-app-core.sh\"
      ),
    ),
    content="true",
  )
  inspect(
    rendered.contains("$MOUI_PACKAGE_ROOT/scripts/mobile/build-ios-app-core.sh"),
    content="false",
  )
  inspect(
    rendered.contains("${MOUI_PACKAGE_ROOT:?MOUI_PACKAGE_ROOT is required}"),
    content="true",
  )
  inspect(
    rendered.contains("MOUI_MOBILE_WORKSPACE_ROOT:-${PROJECT_DIR}/.."),
    content="true",
  )
  inspect(rendered.contains("MOUI_MOBILE_IOS_SHELL = ejected;"), content="true")
}

///|
test "iOS ejection compiles shell-owned sources and headers locally" {
  let source =
    #|workspace_root="${MOUI_MOBILE_WORKSPACE_ROOT:-$(pwd)}"
    #|swift_flags=(
    #|  -I "$moui_root/mobile/ios/bridge/include"
    #|)
    #|include_flags=(
    #|  -I "$moui_root/mobile/include"
    #|  -I "$moui_root/mobile/ios/include"
    #|  -I "$moui_root/mobile/ios/bridge/include"
    #|)
    #|compile_c "$moui_root/mobile/ios/moui_ios_compat.c"
    #|compile_cxx "$moui_root/mobile/runtime/moui_mobile_runtime_v1.cpp"
    #|compile_objcxx "$moui_root/mobile/ios/bridge/MoUIMobileRuntimeBridge.mm"
    #|shell_swift_sources=("$moui_root/mobile/ios/Sources/MoUIMobileShell/"*.swift)
    #|app_swift_sources=(
    #|  "$moui_root/mobile/ios/template/Sources/MoUIMobileApp.swift"
    #|)
  let rendered = patch_ejected_shell_text(
    "moui/build-ios-app-core.sh", source, "ios",
  )
  for
    expected in [
      (
        #|moui_shell_root="${MOUI_MOBILE_SHELL_ROOT:-$moui_root}"
      ),
      (
        #|workspace_root="${MOUI_MOBILE_WORKSPACE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
      ),
      (
        #|-I "$moui_shell_root/moui/runtime"
      ),
      (
        #|-I "$moui_shell_root/include"
      ),
      (
        #|-I "$moui_shell_root/bridge/include"
      ),
      (
        #|compile_c "$moui_shell_root/moui/ios/moui_ios_compat.c"
      ),
      (
        #|compile_cxx "$moui_shell_root/moui/runtime/moui_mobile_runtime_v1.cpp"
      ),
      (
        #|compile_objcxx "$moui_shell_root/bridge/MoUIMobileRuntimeBridge.mm"
      ),
      (
        #|shell_swift_sources=("$moui_shell_root/Sources/MoUIMobileShell/"*.swift)
      ),
      (
        #|"$moui_shell_root/Sources/MoUIMobileApp.swift"
      ),
    ] {
    inspect(rendered.contains(expected), content="true")
  }
  for
    stale in [
      "$moui_root/mobile/include", "$moui_root/mobile/ios/include", "$moui_root/mobile/ios/bridge/include",
      "$moui_root/mobile/ios/moui_ios_compat.c", "$moui_root/mobile/runtime/moui_mobile_runtime_v1.cpp",
      "$moui_root/mobile/ios/bridge/MoUIMobileRuntimeBridge.mm", "$moui_root/mobile/ios/Sources/MoUIMobileShell",
      "$moui_root/mobile/ios/template/Sources/MoUIMobileApp.swift",
    ] {
    inspect(rendered.contains(stale), content="false")
  }
}

///|
test "iOS ejection resolves the runtime ABI header from the local include path" {
  let source =
    #|#include "../../include/moui_mobile_runtime_v1.h"
  let rendered = patch_ejected_shell_text(
    "bridge/MoUIMobileRuntimeBridge.mm", source, "ios",
  )
  inspect(
    rendered.contains(
      (
        #|#include "moui_mobile_runtime_v1.h"
      ),
    ),
    content="true",
  )
  inspect(rendered.contains("../../include"), content="false")
}

///|
test "iOS identity rendering keeps the renamed app source on the local shell" {
  let manifest : ProjectManifest = {
    schema_version: 1,
    id: "sample_app",
    title: "Sample App",
    module_name: "example/sample_app",
    moui_version: "0.1.7",
    platforms: ["ios"],
    bundle_id: Some("dev.example.sample"),
  }
  let source = [
    text_file(
      "MoUIMobileApp.xcodeproj/project.pbxproj",
      (
        #|shellScript = "set -euo pipefail\n: \"${MOUI_PACKAGE_ROOT:?MOUI_PACKAGE_ROOT is required}\"\n\"$MOUI_PACKAGE_ROOT/scripts/mobile/build-ios-app-core.sh\" --app \"${MOUI_MOBILE_APP:-my_app}\"\n";
      ),
    ),
    text_file("Sources/MoUIMobileApp.swift", "struct MoUIMobileApp {}"),
    text_file(
      "moui/build-ios-app-core.sh",
      (
        #|workspace_root="${MOUI_MOBILE_WORKSPACE_ROOT:-$(pwd)}"
        #|app_swift_sources=(
        #|  "$moui_root/mobile/ios/template/Sources/MoUIMobileApp.swift"
        #|)
      ),
    ),
  ]
  let rendered = match render_ejected_files(source, manifest, "ios") {
    Ok(files) => files
    Err(message) => fail(message)
  }
  inspect(
    rendered.any(file => file.path == "Sources/SampleApp.swift"),
    content="true",
  )
  let project = test_planned_text(
    rendered, "SampleApp.xcodeproj/project.pbxproj",
  )
  inspect(
    project.contains(
      (
        #|MOUI_MOBILE_SHELL_ROOT=\"${PROJECT_DIR}\" /bin/bash \"${PROJECT_DIR}/moui/build-ios-app-core.sh\"
      ),
    ),
    content="true",
  )
  inspect(
    project.contains("$MOUI_PACKAGE_ROOT/scripts/mobile/build-ios-app-core.sh"),
    content="false",
  )
  let script = test_planned_text(rendered, "moui/build-ios-app-core.sh")
  inspect(
    script.contains("$moui_shell_root/Sources/SampleApp.swift"),
    content="true",
  )
  inspect(
    script.contains("$moui_root/mobile/ios/template/Sources"),
    content="false",
  )
}
