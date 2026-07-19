///|
fn validate_shell_source(
  repo_root : String,
  failures : Array[String],
  label : String,
  path : String,
  required_tokens : Array[String],
) -> Unit {
  require_path(repo_root, failures, label, path)
  match read_repo_text(repo_root, path) {
    Ok(source) => require_tokens(failures, label, source, required_tokens)
    Err(_) => ()
  }
}

///|
fn validate_no_legacy_shell_sources(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let paths = [
    "moui_shell/scripts/build-android-apk.sh", "moui_shell/scripts/build-ios-app.sh",
    "moui_shell/scripts/build-harmonyos-hap.sh", "moui_shell/scripts/prepare-native-build.mjs",
    "moui_shell/android/embedder/prepare-plugins.mjs",
  ]
  for path in paths {
    match read_repo_text(repo_root, path) {
      Ok(source) =>
        if source.contains("--legacy") ||
          source.contains("legacy-shell") ||
          source.contains("legacy-uikit") ||
          source.contains("runnerMode === \"legacy\"") {
          failures.push(
            "shell source must not retain a legacy compatibility branch: " +
            path,
          )
        }
      Err(_) => ()
    }
  } nobreak {
    ()
  }
}

///|
fn validate_shell_owned_abi_exports(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for
    path in [
      "moui/backend/android/moon.pkg", "moui/backend/ios/moon.pkg", "moui/backend/harmonyos/moon.pkg",
    ] {
    match read_repo_text(repo_root, path) {
      Ok(source) if source.contains("moui_embedding_") =>
        failures.push(
          "platform backend must not export the shell-owned embedding ABI: " +
          path,
        )
      _ => ()
    }
  } nobreak {
    ()
  }
}

///|
fn embedding_api_export_names() -> Array[String] {
  [
    "moui_embedding_take_host_updates_json", "moui_embedding_take_host_update_envelope_json",
    "moui_embedding_dispatch_host_response_envelope_json", "moui_embedding_renderer_configure",
    "moui_embedding_renderer_status_json", "moui_embedding_dispatch_text_input",
    "moui_embedding_dispatch_command", "moui_embedding_dispatch_accessibility", "moui_embedding_complete_clipboard",
    "moui_embedding_complete_clipboard_v1", "moui_embedding_attach_surface", "moui_embedding_resize",
    "moui_embedding_dispatch_pointer", "moui_embedding_dispatch_scroll", "moui_embedding_frame_tick",
    "moui_embedding_render_frame", "moui_embedding_detach_surface", "moui_embedding_destroy_application",
  ]
}

///|
fn mobile_embedding_entrypoint_dirs() -> Array[String] {
  [
    "examples/counter/android_skia", "examples/counter/ios_skia", "examples/showcase/android_skia",
    "examples/showcase/ios_skia", "examples/showcase/harmonyos_skia", "examples/harmonyos_demo/harmonyos_skia",
  ]
}

///|
fn missing_embedding_forwarders(source : String) -> Array[String] {
  let missing : Array[String] = []
  for export_name in embedding_api_export_names() {
    if !source.contains("pub fn " + export_name) ||
      !source.contains("@shell_embedding." + export_name) {
      missing.push(export_name)
    }
  } nobreak {
    ()
  }
  missing
}

///|
fn validate_mobile_embedding_entrypoints(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let export_names = embedding_api_export_names()
  for entrypoint_dir in mobile_embedding_entrypoint_dirs() {
    let manifest = entrypoint_dir + "/moon.pkg"
    validate_shell_source(
      repo_root, failures, "mobile executable embedding ABI manifest", manifest,
      export_names,
    )
    let forwarding_source = entrypoint_dir + "/embedding_exports.mbt"
    require_path(
      repo_root, failures, "mobile executable embedding ABI forwarders", forwarding_source,
    )
    match read_repo_text(repo_root, forwarding_source) {
      Ok(source) =>
        for export_name in missing_embedding_forwarders(source) {
          failures.push(
            "mobile executable embedding ABI forwarders " +
            forwarding_source +
            " must forward " +
            export_name,
          )
        }
      Err(_) => ()
    }
  } nobreak {
    ()
  }
}

///|
fn validate_platform_shell_layout(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for
    path in [
      "moui_shell/contract/moon.pkg", "moui_shell/embedding/moon.pkg", "moui_shell/embedding/embedding.mbt",
      "moui_shell/embedding/runtime_callbacks.mbt", "moui_shell/embedding/native/moui_embedding_api_v1.cpp",
      "moui_shell/include/moui_embedding_api_v1.h", "moui_shell/android/moon.pkg",
      "moui_shell/android/platform.mbt", "moui_shell/android/embedder/cmake/MoUIShellAndroid.cmake",
      "moui_shell/android/embedder/src/main/cpp/moui_embedding_jni.cpp", "moui_shell/android/embedder/src/main/kotlin/dev/wzzc/moui/shell/MoUIActivity.kt",
      "moui_shell/android/runner/shell-app.gradle", "moui_shell/android/runner/resolve-shell.mjs",
      "moui_shell/android/runner/template/app/src/main/AndroidManifest.xml", "moui_shell/ios/moon.pkg",
      "moui_shell/ios/platform.mbt", "moui_shell/ios/embedder/bridge/MoUIMobileRuntimeBridge.mm",
      "moui_shell/ios/embedder/Sources/MoUIMobileShell/MoUIMobileShell.swift", "moui_shell/ios/runner/resolve-shell.mjs",
      "moui_shell/ios/runner/template/Info.plist", "moui_shell/harmonyos/moon.pkg",
      "moui_shell/harmonyos/platform.mbt", "moui_shell/harmonyos/embedder/src/main/cpp/moui_embedding_harmonyos_napi.cpp",
      "moui_shell/harmonyos/runner/resolve-shell.mjs", "moui_shell/harmonyos/runner/template/entry/src/main/module.json5",
    ] {
    require_path(repo_root, failures, "platform-first shell layout", path)
  } nobreak {
    ()
  }
  validate_shell_source(
    repo_root,
    failures,
    "shared embedding API",
    "moui_shell/embedding/embedding.mbt",
    [
      "pub(all) struct ShellSession", "pub struct ShellFrameScheduler", "pub struct ShellChannel",
      "pub fn ShellPlatformDescriptor::negotiate",
    ],
  )
  validate_shell_source(
    repo_root,
    failures,
    "shell-owned embedding ABI dispatch",
    "moui_shell/embedding/runtime_callbacks.mbt",
    [
      "pub(all) struct EmbeddingRuntimeCallbacks", "pub fn install_runtime", "pub fn moui_embedding_attach_surface",
      "pub fn moui_embedding_destroy_application",
    ],
  )
  validate_shell_source(
    repo_root,
    failures,
    "Android typed shell API",
    "moui_shell/android/platform.mbt",
    ["pub(all) struct AndroidNativeSurface", "pub fn android_descriptor"],
  )
  validate_shell_source(
    repo_root,
    failures,
    "iOS typed shell API",
    "moui_shell/ios/platform.mbt",
    ["pub(all) struct IosNativeView", "pub fn ios_descriptor"],
  )
  validate_shell_source(
    repo_root,
    failures,
    "HarmonyOS typed shell API",
    "moui_shell/harmonyos/platform.mbt",
    ["pub(all) struct HarmonyosNativeSurface", "pub fn harmonyos_descriptor"],
  )
}

///|
fn validate_android_managed_shell(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  validate_platform_shell_layout(repo_root, failures)
  validate_no_legacy_shell_sources(repo_root, failures)
  validate_shell_owned_abi_exports(repo_root, failures)
  validate_mobile_embedding_entrypoints(repo_root, failures)
  validate_shell_source(
    repo_root,
    failures,
    "Android embedder ABI consumer",
    "moui_shell/android/embedder/src/main/cpp/moui_embedding_jni.cpp",
    [
      "JNI_OnLoad", "RegisterNatives", "moui_embedding_get_api_v1", "moui_embedding_api_v1_is_compatible",
    ],
  )
  validate_shell_source(
    repo_root,
    failures,
    "Android managed runner",
    "moui_shell/android/runner/shell-app.gradle",
    ["mouiAndroidShell", "\"managed\"", "\"ejected\"", "MOUI_SHELL_ROOT"],
  )
}
