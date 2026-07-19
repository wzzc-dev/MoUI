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
  shell_root : String,
  platform : String,
) -> Result[Array[PlannedFile], String] {
  let files : Array[PlannedFile] = []
  match
    append_mapped_tree(files, shell_root, platform + "/runner/template", "") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let result = match platform {
    "android" =>
      append_shell_source_steps([
        () => {
          append_mapped_tree(
            files, shell_root, "android/embedder/src/main/kotlin", "app/src/main/kotlin",
          )
        },
        () => {
          append_mapped_tree(
            files, shell_root, "android/embedder/src/main/cpp", "app/src/main/cpp",
          )
        },
        () => {
          append_mapped_file(
            files, shell_root, "android/embedder/cmake/MoUIShellAndroid.cmake", "app/src/main/cpp/MoUIShellAndroid.cmake",
          )
        },
        () => {
          append_mapped_file(
            files, shell_root, "android/runner/shell-app.gradle", "moui_shell-app.gradle",
          )
        },
      ])
    "ios" =>
      append_shell_source_steps([
        () => {
          append_mapped_file(
            files, shell_root, "ios/Package.swift", "Package.swift",
          )
        },
        () => {
          append_mapped_tree(
            files, shell_root, "ios/embedder/Sources", "Sources",
          )
        },
        () => {
          append_mapped_tree(files, shell_root, "ios/embedder/bridge", "bridge")
        },
        () => {
          append_mapped_tree(
            files, shell_root, "ios/embedder/include", "include",
          )
        },
        () => {
          append_mapped_file(
            files, shell_root, "ios/moui_ios_compat.c", "moui/ios/moui_ios_compat.c",
          )
        },
        () => {
          append_mapped_file(
            files, shell_root, "scripts/build-ios-app-core.sh", "moui/build-ios-app-core.sh",
          )
        },
      ])
    "harmonyos" =>
      append_shell_source_steps([
        () => {
          append_mapped_tree(
            files, shell_root, "harmonyos/embedder/src/main/cpp", "entry/src/main/cpp/moui",
          )
        },
        () => {
          append_mapped_file(
            files, shell_root, "harmonyos/embedder/cmake/MoUIShellHarmonyOS.cmake",
            "entry/src/main/cpp/MoUIShellHarmonyOS.cmake",
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
        "include/moui_embedding_api_v1.h", "moui_shell/include/moui_embedding_api_v1.h",
      ),
    ] {
    let (source, output) = pair
    match append_mapped_file(files, shell_root, source, output) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  match
    append_mapped_file(
      files, shell_root, "embedding/native/moui_embedding_api_v1.cpp", "moui_shell/embedding/native/moui_embedding_api_v1.cpp",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
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
              #|apply from: file("${resolvedMouiShellRoot}/android/runner/shell-app.gradle")
            ),
            new=(
              #|apply from: file("${rootProject.projectDir}/moui_shell-app.gradle")
            ),
          )
        "app/src/main/cpp/CMakeLists.txt" =>
          value.replace_all(
            old=(
              #|include("${MOUI_SHELL_ROOT}/android/embedder/cmake/MoUIShellAndroid.cmake")
            ),
            new=(
              #|include("${CMAKE_CURRENT_LIST_DIR}/MoUIShellAndroid.cmake")
            ),
          )
        "moui_shell-app.gradle" =>
          value
          .replace_all(
            old=(
              #|file("${mouiShellRoot}/android/embedder/src/main/kotlin")
            ),
            new=(
              #|file("${rootProject.projectDir}/app/src/main/kotlin")
            ),
          )
          .replace_all(
            old=(
              #|file("${mouiShellRoot}/android/embedder")
            ),
            new=(
              #|file("${rootProject.projectDir}/app")
            ),
          )
        "app/src/main/cpp/MoUIShellAndroid.cmake" => {
          let ejected_root = "${CMAKE_CURRENT_LIST_DIR}/../../../.."
          value
          .replace_all(
            old="${MOUI_SHELL_ROOT}/include",
            new=ejected_root + "/moui_shell/include",
          )
          .replace_all(
            old="${MOUI_SHELL_ROOT}/embedding/native/moui_embedding_api_v1.cpp",
            new=ejected_root +
              "/moui_shell/embedding/native/moui_embedding_api_v1.cpp",
          )
          .replace_all(
            old="${MOUI_SHELL_ROOT}/android/embedder",
            new="${CMAKE_CURRENT_LIST_DIR}",
          )
          .replace_all(
            old="${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/src/main/cpp/moui_embedding_jni.cpp",
            new="${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/moui_embedding_jni.cpp",
          )
          .replace_all(
            old="${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/src/main/cpp/moui_android_compat.c",
            new="${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/moui_android_compat.c",
          )
          .replace_all(
            old="${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/src/main/cpp/moui_android_compat.h",
            new="${MOUI_EMBEDDING_SHARED_ANDROID_DIR}/moui_android_compat.h",
          )
        }
        _ => value
      }
    "ios" =>
      match path {
        "MoUIShellApp.xcodeproj/project.pbxproj" =>
          value
          .replace_all(
            old=(
              #|: \"${MOUI_SHELL_PACKAGE_ROOT:?MOUI_SHELL_PACKAGE_ROOT is required}\"
            ),
            new=(
              #|export MOUI_EMBEDDING_WORKSPACE_ROOT=\"${MOUI_EMBEDDING_WORKSPACE_ROOT:-${PROJECT_DIR}/..}\"\nexport MOUI_EMBEDDING_PROJECT_ROOT=\"${MOUI_EMBEDDING_PROJECT_ROOT:-${PROJECT_DIR}/..}\"\nexport MOUI_PACKAGE_ROOT=\"${MOUI_PACKAGE_ROOT:-${MOUI_EMBEDDING_WORKSPACE_ROOT}/.mooncakes/wzzc-dev/moui}\"\nexport MOUI_EMBEDDING_SHELL_ROOT=\"${PROJECT_DIR}\"\n: \"${MOUI_PACKAGE_ROOT:?MOUI_PACKAGE_ROOT is required}\"
            ),
          )
          .replace_all(
            old="SWIFT_VERSION = 5.0;",
            new="MOUI_EMBEDDING_IOS_SHELL = ejected;\n        SWIFT_VERSION = 5.0;",
          )
          .replace_all(
            old=(
              #|"-lc \"\\\"${MOUI_SHELL_PACKAGE_ROOT}/scripts/build-ios-app-core.sh\\\" --app ${MOUI_EMBEDDING_APP:-my_app}\""
            ),
            new=(
              #|"-lc \"MOUI_EMBEDDING_SHELL_ROOT=\\\"${PROJECT_DIR}\\\" \\\"${PROJECT_DIR}/moui/build-ios-app-core.sh\\\" --app ${MOUI_EMBEDDING_APP:-my_app}\""
            ),
          )
          .replace_all(
            old=(
              #|\"$MOUI_SHELL_PACKAGE_ROOT/scripts/build-ios-app-core.sh\" --app \"${MOUI_EMBEDDING_APP:-my_app}\"
            ),
            new=(
              #|MOUI_EMBEDDING_SHELL_ROOT=\"${PROJECT_DIR}\" /bin/bash \"${PROJECT_DIR}/moui/build-ios-app-core.sh\" --app \"${MOUI_EMBEDDING_APP:-my_app}\"
            ),
          )
        "moui/build-ios-app-core.sh" =>
          value
          .replace_all(
            old="$shell_root/ios/embedder/bridge/include",
            new="$shell_root/bridge/include",
          )
          .replace_all(
            old="$shell_root/include",
            new="$shell_root/moui_shell/include",
          )
          .replace_all(
            old="$shell_root/ios/embedder/include",
            new="$shell_root/include",
          )
          .replace_all(
            old=(
              #|compile_c "$shell_root/ios/moui_ios_compat.c"
            ),
            new=(
              #|compile_c "$shell_root/moui/ios/moui_ios_compat.c"
            ),
          )
          .replace_all(
            old=(
              #|compile_cxx "$shell_root/embedding/native/moui_embedding_api_v1.cpp"
            ),
            new=(
              #|compile_cxx "$shell_root/moui_shell/embedding/native/moui_embedding_api_v1.cpp"
            ),
          )
          .replace_all(
            old="$shell_root/embedding/native/moui_embedding_api_v1.cpp",
            new="$shell_root/moui_shell/embedding/native/moui_embedding_api_v1.cpp",
          )
          .replace_all(
            old=(
              #|compile_objcxx "$shell_root/ios/embedder/bridge/MoUIMobileRuntimeBridge.mm"
            ),
            new=(
              #|compile_objcxx "$shell_root/bridge/MoUIMobileRuntimeBridge.mm"
            ),
          )
          .replace_all(
            old=(
              #|shell_swift_sources=("$shell_root/ios/embedder/Sources/MoUIMobileShell/"*.swift)
            ),
            new=(
              #|shell_swift_sources=("$shell_root/Sources/MoUIMobileShell/"*.swift)
            ),
          )
          .replace_all(
            old=(
              #|"$shell_root/ios/runner/template/Sources/MoUIMobileApp.swift"
            ),
            new=(
              #|"$shell_root/Sources/MoUIMobileApp.swift"
            ),
          )
        "bridge/MoUIMobileRuntimeBridge.mm" =>
          value.replace_all(
            old=(
              #|#include "../../include/moui_embedding_api_v1.h"
            ),
            new=(
              #|#include "moui_embedding_api_v1.h"
            ),
          )
        _ => value
      }
    "harmonyos" =>
      match path {
        "entry/src/main/cpp/CMakeLists.txt" =>
          value.replace_all(
            old=(
              #|include("${MOUI_SHELL_ROOT}/harmonyos/embedder/cmake/MoUIShellHarmonyOS.cmake")
            ),
            new=(
              #|include("${CMAKE_CURRENT_LIST_DIR}/MoUIShellHarmonyOS.cmake")
            ),
          )
        "entry/src/main/cpp/MoUIShellHarmonyOS.cmake" => {
          let ejected_root = "${CMAKE_CURRENT_LIST_DIR}/../../../.."
          value
          .replace_all(
            old=(
              #|set(MOUI_EMBEDDING_SHARED_HARMONYOS_DIR "${MOUI_SHELL_ROOT}/harmonyos/embedder")
            ),
            new=(
              #|set(MOUI_EMBEDDING_SHARED_HARMONYOS_DIR "${CMAKE_CURRENT_LIST_DIR}/moui")
            ),
          )
          .replace_all(
            old="${MOUI_EMBEDDING_SHARED_HARMONYOS_DIR}/src/main/cpp/moui_embedding_harmonyos_napi.cpp",
            new="${MOUI_EMBEDDING_SHARED_HARMONYOS_DIR}/moui_embedding_harmonyos_napi.cpp",
          )
          .replace_all(
            old="${MOUI_SHELL_ROOT}/include",
            new=ejected_root + "/moui_shell/include",
          )
          .replace_all(
            old="${MOUI_SHELL_ROOT}/embedding/native/moui_embedding_api_v1.cpp",
            new=ejected_root +
              "/moui_shell/embedding/native/moui_embedding_api_v1.cpp",
          )
        }
        _ => value
      }
    _ => value
  }
}
