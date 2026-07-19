///|
test "ejected source patch keeps Android CMake local to the ejected shell" {
  let source =
    #|include("${MOUI_SHELL_ROOT}/android/embedder/cmake/MoUIShellAndroid.cmake")
  let rendered = patch_ejected_shell_text(
    "app/src/main/cpp/CMakeLists.txt", source, "android",
  )
  inspect(
    rendered.contains("${CMAKE_CURRENT_LIST_DIR}/MoUIShellAndroid.cmake"),
    content="true",
  )
}

///|
test "ejected Android CMake uses its copied JNI and compatibility sources" {
  let source =
    #|set(MOUI_EMBEDDING_SHARED_ANDROID_DIR "${MOUI_SHELL_ROOT}/android/embedder")
    #|add_library(moui SHARED
    #|  "${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/src/main/cpp/moui_embedding_jni.cpp"
    #|)
    #|set_source_files_properties("${MOUI_EMBEDDING_MOONBIT_C}" PROPERTIES
    #|  COMPILE_OPTIONS "-include;${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/src/main/cpp/moui_android_compat.h"
    #|)
  let rendered = patch_ejected_shell_text(
    "app/src/main/cpp/MoUIShellAndroid.cmake", source, "android",
  )
  inspect(
    rendered.contains("${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/moui_embedding_jni.cpp"),
    content="true",
  )
  inspect(
    rendered.contains("${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/moui_android_compat.h"),
    content="true",
  )
  inspect(rendered.contains("src/main/cpp/moui_embedding_jni.cpp"), content="false")
}

///|
test "ejected source patch keeps the HarmonyOS provider in the shell snapshot" {
  let source =
    #|set(MOUI_EMBEDDING_SHARED_HARMONYOS_DIR "${MOUI_SHELL_ROOT}/harmonyos/embedder")
    #|list(APPEND sources "${MOUI_SHELL_ROOT}/embedding/native/moui_embedding_api_v1.cpp")
  let rendered = patch_ejected_shell_text(
    "entry/src/main/cpp/MoUIShellHarmonyOS.cmake", source, "harmonyos",
  )
  inspect(rendered.contains("${CMAKE_CURRENT_LIST_DIR}/moui"), content="true")
  inspect(
    rendered.contains("moui_shell/embedding/native/moui_embedding_api_v1.cpp"),
    content="true",
  )
}

///|
test "ejected source patch uses the copied iOS shell builder" {
  let source =
    #|SWIFT_VERSION = 5.0;
    #|shellScript = "set -euo pipefail\n: \"${MOUI_SHELL_PACKAGE_ROOT:?MOUI_SHELL_PACKAGE_ROOT is required}\"\n\"$MOUI_SHELL_PACKAGE_ROOT/scripts/build-ios-app-core.sh\" --app \"${MOUI_EMBEDDING_APP:-my_app}\"\n";
  let rendered = patch_ejected_shell_text(
    "MoUIShellApp.xcodeproj/project.pbxproj", source, "ios",
  )
  inspect(
    rendered.contains("MOUI_EMBEDDING_IOS_SHELL = ejected;"),
    content="true",
  )
  inspect(
    rendered.contains("${PROJECT_DIR}/moui/build-ios-app-core.sh"),
    content="true",
  )
}

///|
test "ejected iOS builder rewrites a multiline ABI compile source" {
  let source =
    #|compile_cxx
    #|  "$shell_root/embedding/native/moui_embedding_api_v1.cpp"
    #|  "$obj_dir/moui_embedding_api_v1.o"
  let rendered = patch_ejected_shell_text(
    "moui/build-ios-app-core.sh", source, "ios",
  )
  inspect(
    rendered.contains("$shell_root/moui_shell/embedding/native/moui_embedding_api_v1.cpp"),
    content="true",
  )
}

///|
fn eject_test_write_text(path : String, value : String) -> Unit raise {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @fs.write_string_to_file(path, value) catch {
    _ => fail("could not write shell test file: " + path)
  }
}

///|
fn eject_test_mobile_text() -> String {
  (
    {
      "schemaVersion": 1,
      "id": "sample_app",
      "displayName": "Sample App",
      "artifactName": "sample_app",
      "appPackage": "app",
      "shellApiVersion": 1,
      "embeddingApiVersion": 1,
      "shell": {
        "profile": "handheld",
        "renderer": "auto",
        "systemUi": { "fullscreen": false, "statusBar": "auto" },
        "orientation": "any",
        "resources": [],
        "permissions": [],
        "plugins": [],
      },
      "android": {
        "runnerMode": "managed",
        "applicationId": "dev.example.sample",
        "minSdk": 23,
      },
    } : Json).stringify(indent=2) +
  "\n"
}

///|
fn eject_test_prepare_project(root : String, moui_root : String) -> Unit raise {
  let shell_root = join_path(root, "moui_shell")
  eject_test_write_text(
    join_path(root, "moui.project.json"),
    (
      {
        "schemaVersion": 1,
        "id": "sample_app",
        "title": "Sample App",
        "module": "example/sample_app",
        "mouiVersion": "0.1.7",
        "platforms": ["android"],
        "bundleId": "dev.example.sample",
      } : Json).stringify(indent=2) +
    "\n",
  )
  eject_test_write_text(join_path(root, "shell.json"), eject_test_mobile_text())
  eject_test_write_text(
    join_path(moui_root, "moon.mod"),
    "name = \"wzzc-dev/moui\"\nversion = \"0.1.7\"\n",
  )
  eject_test_write_text(
    join_path(shell_root, "moon.mod"),
    "name = \"wzzc-dev/moui_shell\"\nversion = \"0.1.7\"\n",
  )
  eject_test_write_text(join_path(shell_root, "embedding/.keep"), "fixture\n")
  for
    path in [
      "android/runner/template/README.md", "android/embedder/src/main/kotlin/dev/example/Shell.kt",
      "android/embedder/src/main/cpp/glue.cpp", "android/embedder/cmake/MoUIShellAndroid.cmake",
      "android/runner/shell-app.gradle", "include/moui_embedding_api_v1.h",
    ] {
    eject_test_write_text(join_path(shell_root, path), "fixture\n")
  }
  eject_test_write_text(
    join_path(shell_root, "embedding/native/moui_embedding_api_v1.cpp"),
    "fixture\n",
  )
}
