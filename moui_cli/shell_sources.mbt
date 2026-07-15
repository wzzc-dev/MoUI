///|
fn mapped_tree_files(
  source_root : String,
  output_prefix : String,
) -> Result[Array[PlannedFile], String] {
  if !path_is_dir(source_root) {
    return Err("canonical shell source directory is missing: " + source_root)
  }
  let files = match collect_template_files(source_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(
    files.map(file => {
      path: if output_prefix == "" {
        file.path
      } else {
        output_prefix + "/" + file.path
      },
      bytes: file.bytes,
    }),
  )
}

///|
fn mapped_source_file(
  moui_root : String,
  source : String,
  output : String,
) -> Result[PlannedFile, String] {
  let path = join_path(moui_root, source)
  if !path_is_nonempty_file(path) {
    return Err("canonical shell source file is missing: " + path)
  }
  let bytes = @fs.read_file_to_bytes(path) catch {
    _ => return Err("could not read canonical shell source file: " + path)
  }
  Ok({ path: output, bytes })
}

///|
fn append_mapped_tree(
  files : Array[PlannedFile],
  moui_root : String,
  source : String,
  output_prefix : String,
) -> Result[Unit, String] {
  let mapped = match
    mapped_tree_files(join_path(moui_root, source), output_prefix) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for file in mapped {
    files.push(file)
  }
  Ok(())
}

///|
fn append_mapped_file(
  files : Array[PlannedFile],
  moui_root : String,
  source : String,
  output : String,
) -> Result[Unit, String] {
  match mapped_source_file(moui_root, source, output) {
    Ok(file) => {
      files.push(file)
      Ok(())
    }
    Err(message) => Err(message)
  }
}

///|
fn append_shell_source_steps(
  steps : Array[() -> Result[Unit, String]],
) -> Result[Unit, String] {
  for step in steps {
    match step() {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
fn canonical_shell_source_plan(
  moui_root : String,
  platform : String,
) -> Result[Array[PlannedFile], String] {
  let files : Array[PlannedFile] = []
  match
    append_mapped_tree(files, moui_root, "mobile/" + platform + "/template", "") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let append_tree = (source, output) => {
    append_mapped_tree(files, moui_root, source, output)
  }
  let append_file = (source, output) => {
    append_mapped_file(files, moui_root, source, output)
  }
  let result = match platform {
    "android" =>
      append_shell_source_steps([
        () => {
          append_tree("mobile/android/src/main/kotlin", "app/src/main/kotlin")
        },
        () => append_tree("mobile/android/src/main/cpp", "app/src/main/cpp"),
        () => {
          append_file(
            "mobile/android/cmake/MoUIMobileAndroid.cmake", "app/src/main/cpp/MoUIMobileAndroid.cmake",
          )
        },
        () => {
          append_file(
            "mobile/android/mobile-app.gradle", "moui/mobile-app.gradle",
          )
        },
      ])
    "ios" =>
      append_shell_source_steps([
        () => append_file("mobile/ios/Package.swift", "Package.swift"),
        () => append_tree("mobile/ios/Sources", "Sources"),
        () => append_tree("mobile/ios/bridge", "bridge"),
        () => append_tree("mobile/ios/include", "include"),
        () => {
          append_file(
            "mobile/ios/moui_ios_compat.c", "moui/ios/moui_ios_compat.c",
          )
        },
        () => {
          append_file(
            "scripts/mobile/build-ios-app-core.sh", "moui/build-ios-app-core.sh",
          )
        },
      ])
    "harmonyos" =>
      append_shell_source_steps([
        () => {
          append_tree(
            "mobile/harmonyos/src/main/cpp", "entry/src/main/cpp/moui",
          )
        },
        () => {
          append_file(
            "mobile/harmonyos/cmake/MoUIMobileHarmonyOS.cmake", "entry/src/main/cpp/MoUIMobileHarmonyOS.cmake",
          )
        },
      ])
    _ => Err("unsupported canonical shell platform: " + platform)
  }
  match result {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for
    pair in [
      (
        "mobile/include/moui_mobile_runtime_v1.h", "moui/runtime/moui_mobile_runtime_v1.h",
      ),
      (
        "mobile/runtime/moui_mobile_runtime_v1.cpp", "moui/runtime/moui_mobile_runtime_v1.cpp",
      ),
    ] {
    let (source, output) = pair
    match append_file(source, output) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  match validate_file_plan(files) {
    Ok(_) => {
      files.sort_by((left, right) => left.path.lexical_compare(right.path))
      Ok(files)
    }
    Err(message) => Err(message)
  }
}

///|
fn patch_ejected_shell_text(
  path : String,
  value : String,
  platform : String,
) -> String {
  match platform {
    "android" =>
      match path {
        "app/build.gradle" =>
          value.replace_all(
            old=(
              #|apply from: file("${resolvedMouiRoot}/mobile/android/mobile-app.gradle")
            ),
            new=(
              #|apply from: file("${rootProject.projectDir}/moui/mobile-app.gradle")
            ),
          )
        "app/src/main/cpp/CMakeLists.txt" =>
          value
          .replace_all(
            old=(
              #|include("${MOUI_ROOT}/mobile/android/cmake/MoUIMobileAndroid.cmake")
            ),
            new=(
              #|include("${CMAKE_CURRENT_LIST_DIR}/MoUIMobileAndroid.cmake")
            ),
          )
          .replace_all(
            old=(
              #|set(MOUI_MOBILE_ANDROID_GLUE_ROOT "${MOUI_ROOT}/mobile/android")
            ),
            new=(
              #|get_filename_component(MOUI_MOBILE_ANDROID_GLUE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
            ),
          )
        "moui/mobile-app.gradle" =>
          value
          .replace_all(
            old=(
              #|file("${mouiRoot}/mobile/android/src/main/kotlin")
            ),
            new=(
              #|file("${rootProject.projectDir}/app/src/main/kotlin")
            ),
          )
          .replace_all(
            old=(
              #|file("${mouiRoot}/mobile/android")
            ),
            new=(
              #|file("${rootProject.projectDir}/app")
            ),
          )
        "app/src/main/cpp/MoUIMobileAndroid.cmake" => {
          let runtime_root = "${CMAKE_CURRENT_LIST_DIR}/../../../../moui/runtime"
          value
          .replace_all(old="${MOUI_ROOT}/mobile/include", new=runtime_root)
          .replace_all(old="${MOUI_ROOT}/mobile/runtime", new=runtime_root)
        }
        _ => value
      }
    "ios" =>
      match path {
        "MoUIMobileApp.xcodeproj/project.pbxproj" =>
          value
          .replace_all(
            old=(
              #|: \"${MOUI_PACKAGE_ROOT:?MOUI_PACKAGE_ROOT is required}\"
            ),
            new=(
              #|export MOUI_MOBILE_WORKSPACE_ROOT=\"${MOUI_MOBILE_WORKSPACE_ROOT:-${PROJECT_DIR}/..}\"\nexport MOUI_PACKAGE_ROOT=\"${MOUI_PACKAGE_ROOT:-${MOUI_MOBILE_WORKSPACE_ROOT}/.mooncakes/wzzc-dev/moui}\"\n: \"${MOUI_PACKAGE_ROOT:?MOUI_PACKAGE_ROOT is required}\"
            ),
          )
          .replace_all(
            old="SWIFT_VERSION = 5.0;",
            new="MOUI_MOBILE_IOS_SHELL = ejected;\n        SWIFT_VERSION = 5.0;",
          )
          .replace_all(
            old=(
              #|"-lc \"\\\"${MOUI_PACKAGE_ROOT:-.mooncakes/wzzc-dev/moui}/scripts/mobile/build-ios-app-core.sh\\\" --app ${MOUI_MOBILE_APP:-my_app}\""
            ),
            new=(
              #|"-lc \"MOUI_MOBILE_SHELL_ROOT=\\\"${PROJECT_DIR}\\\" \\\"${PROJECT_DIR}/moui/build-ios-app-core.sh\\\" --app ${MOUI_MOBILE_APP:-my_app}\""
            ),
          )
          .replace_all(
            old=(
              #|\"$MOUI_PACKAGE_ROOT/scripts/mobile/build-ios-app-core.sh\" --app \"${MOUI_MOBILE_APP:-my_app}\"
            ),
            new=(
              #|MOUI_MOBILE_SHELL_ROOT=\"${PROJECT_DIR}\" /bin/bash \"${PROJECT_DIR}/moui/build-ios-app-core.sh\" --app \"${MOUI_MOBILE_APP:-my_app}\"
            ),
          )
        "moui/build-ios-app-core.sh" =>
          value
          .replace_all(
            old=(
              #|workspace_root="${MOUI_MOBILE_WORKSPACE_ROOT:-$(pwd)}"
            ),
            new=(
              #|workspace_root="${MOUI_MOBILE_WORKSPACE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
              #|moui_shell_root="${MOUI_MOBILE_SHELL_ROOT:-$moui_root}"
            ),
          )
          .replace_all(
            old="$moui_root/mobile/include",
            new="$moui_shell_root/moui/runtime",
          )
          .replace_all(
            old="$moui_root/mobile/ios/include",
            new="$moui_shell_root/include",
          )
          .replace_all(
            old="$moui_root/mobile/ios/bridge/include",
            new="$moui_shell_root/bridge/include",
          )
          .replace_all(
            old=(
              #|compile_c "$moui_root/mobile/ios/moui_ios_compat.c"
            ),
            new=(
              #|compile_c "$moui_shell_root/moui/ios/moui_ios_compat.c"
            ),
          )
          .replace_all(
            old=(
              #|compile_cxx "$moui_root/mobile/runtime/moui_mobile_runtime_v1.cpp"
            ),
            new=(
              #|compile_cxx "$moui_shell_root/moui/runtime/moui_mobile_runtime_v1.cpp"
            ),
          )
          .replace_all(
            old=(
              #|compile_objcxx "$moui_root/mobile/ios/bridge/MoUIMobileRuntimeBridge.mm"
            ),
            new=(
              #|compile_objcxx "$moui_shell_root/bridge/MoUIMobileRuntimeBridge.mm"
            ),
          )
          .replace_all(
            old=(
              #|shell_swift_sources=("$moui_root/mobile/ios/Sources/MoUIMobileShell/"*.swift)
            ),
            new=(
              #|shell_swift_sources=("$moui_shell_root/Sources/MoUIMobileShell/"*.swift)
            ),
          )
          .replace_all(
            old=(
              #|"$moui_root/mobile/ios/template/Sources/MoUIMobileApp.swift"
            ),
            new=(
              #|"$moui_shell_root/Sources/MoUIMobileApp.swift"
            ),
          )
        "bridge/MoUIMobileRuntimeBridge.mm" =>
          value.replace_all(
            old=(
              #|#include "../../include/moui_mobile_runtime_v1.h"
            ),
            new=(
              #|#include "moui_mobile_runtime_v1.h"
            ),
          )
        _ => value
      }
    "harmonyos" =>
      match path {
        "entry/src/main/cpp/CMakeLists.txt" =>
          value.replace_all(
            old=(
              #|include("${MOUI_ROOT}/mobile/harmonyos/cmake/MoUIMobileHarmonyOS.cmake")
            ),
            new=(
              #|include("${CMAKE_CURRENT_LIST_DIR}/MoUIMobileHarmonyOS.cmake")
            ),
          )
        "entry/src/main/cpp/MoUIMobileHarmonyOS.cmake" => {
          let local_runtime = "${CMAKE_CURRENT_LIST_DIR}/../../../../moui/runtime"
          value
          .replace_all(
            old=(
              #|set(MOUI_MOBILE_SHARED_HARMONYOS_DIR "${MOUI_ROOT}/mobile/harmonyos")
            ),
            new=(
              #|set(MOUI_MOBILE_SHARED_HARMONYOS_DIR "${CMAKE_CURRENT_LIST_DIR}/moui")
            ),
          )
          .replace_all(
            old="${MOUI_MOBILE_SHARED_HARMONYOS_DIR}/src/main/cpp/moui_mobile_harmonyos_napi.cpp",
            new="${MOUI_MOBILE_SHARED_HARMONYOS_DIR}/moui_mobile_harmonyos_napi.cpp",
          )
          .replace_all(old="${MOUI_ROOT}/mobile/include", new=local_runtime)
          .replace_all(old="${MOUI_ROOT}/mobile/runtime", new=local_runtime)
        }
        _ => value
      }
    _ => value
  }
}
