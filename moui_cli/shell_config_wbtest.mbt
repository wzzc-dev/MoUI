// Whitebox tests for `shell_config.mbt`. Writes synthetic shell.json fixtures
// into a temp directory (matching the pattern in `eject_transaction_wbtest.mbt`).
// The strict v1 schema is enforced via `read_shell_app`.

///|
fn shell_config_write(path : String, value : String) -> Unit raise {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => fail("could not create parent dir: " + message)
  }
  @fs.write_string_to_file(path, value) catch {
    _ => fail("could not write shell test file: " + path)
  }
}

///|
fn shell_config_counter_text() -> String {
  (
    {
      "schemaVersion": 1,
      "id": "counter",
      "displayName": "MoUI Counter",
      "artifactName": "counter",
      "appPackage": "examples/counter/app",
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
        "applicationId": "dev.wzzc.moui.counter",
        "runnerMode": "managed",
        "minSdk": 23,
      },
      "ios": {
        "bundleId": "dev.wzzc.moui.counter",
        "productName": "MoUICounter",
        "runnerMode": "managed",
        "deploymentTarget": "15.0",
      },
    } : Json).stringify(indent=2) +
  "\n"
}

///|
fn shell_config_prepare_counter(root : String) -> Unit raise {
  shell_config_write(join_path(root, "shell.json"), shell_config_counter_text())
  // The android entrypoint package directory must exist for
  // managed_entrypoint_package to resolve to `android` instead of `android_skia`.
  match mkdir_p(join_path(root, "android")) {
    Ok(_) => ()
    Err(message) => fail("could not create android entrypoint dir: " + message)
  }
  @fs.write_string_to_file(join_path(root, "android/moon.pkg"), "{}") catch {
    _ => fail("could not write android/moon.pkg")
  }
}

///|
test "test_fixed_embedding_exports" {
  let exports = fixed_embedding_exports()
  inspect(exports.length(), content="9")
  assert_true(exports.contains("moui_embedding_attach_surface"))
  assert_true(exports.contains("moui_embedding_resize"))
  assert_true(exports.contains("moui_embedding_dispatch_pointer"))
  assert_true(exports.contains("moui_embedding_dispatch_scroll"))
  assert_true(exports.contains("moui_embedding_frame_tick"))
  assert_true(exports.contains("moui_embedding_render_frame"))
  assert_true(exports.contains("moui_embedding_detach_surface"))
  assert_true(exports.contains("moui_embedding_destroy_application"))
  assert_true(
    exports.contains("moui_embedding_dispatch_host_response_envelope_json"),
  )
}

///|
test "path_relative_to canonicalizes mixed relative and absolute roots" {
  let root = canonical_path(".").unwrap_or(".")
  let target = join_path(root, "moon.pkg")
  match path_relative_to(".", target) {
    Ok(value) => inspect(value, content="moon.pkg")
    Err(message) => fail(message)
  }
}

///|
fn shell_config_run_counter_read(
  root : String,
) -> Result[ShellApp, String] raise {
  shell_config_prepare_counter(root)
  read_shell_app(root)
}

///|
test "test_read_shell_app_counter" {
  let root = test_temp_path("shell-config-read")
  remove_tree(root)
  let outcome = shell_config_run_counter_read(root)
  remove_tree(root)
  let app = match outcome {
    Ok(value) => value
    Err(message) => {
      println("read_shell_app failed: " + message)
      fail("read_shell_app failed")
    }
  }
  inspect(app.id, content="counter")
  inspect(app.display_name, content="MoUI Counter")
  inspect(app.artifact_name, content="counter")
  inspect(app.app_package, content="examples/counter/app")
  inspect(app.schema_version, content="1")
  inspect(app.shell_api_version, content="1")
  inspect(app.embedding_api_version, content="1")
  inspect(app.shell.profile, content="handheld")
  inspect(app.shell.renderer, content="auto")
  inspect(app.shell.status_bar, content="auto")
  inspect(app.shell.orientation, content="any")
  inspect(app.shell.fullscreen, content="false")
  inspect(app.shell.supports_scroll, content="true")
  inspect(app.shell.resources.length(), content="0")
  inspect(app.shell.permissions.length(), content="0")
  inspect(app.shell.plugins.length(), content="0")
  inspect(app.plugins.length(), content="0")
  match app.android {
    Some(android) => {
      inspect(android.application_id, content="dev.wzzc.moui.counter")
      inspect(android.runner_mode, content="managed")
      inspect(android.min_sdk, content="23")
    }
    None => fail("expected android configuration in counter shell.json")
  }
  match app.ios {
    Some(ios) => {
      inspect(ios.bundle_id, content="dev.wzzc.moui.counter")
      inspect(ios.product_name, content="MoUICounter")
      inspect(ios.runner_mode, content="managed")
      inspect(ios.deployment_target, content="15.0")
    }
    None => fail("expected ios configuration in counter shell.json")
  }
  assert_true(app.harmonyos.is_empty())
}

///|
fn shell_config_run_android_contract(
  root : String,
) -> Result[ManagedContract, String] raise {
  shell_config_prepare_counter(root)
  let app = match read_shell_app(root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let shell_root = join_path(root, "moui_shell")
  managed_platform_contract(app, "android", root, shell_root)
}

///|
test "test_managed_platform_contract_android" {
  let root = test_temp_path("shell-config-android")
  remove_tree(root)
  let outcome = shell_config_run_android_contract(root)
  remove_tree(root)
  let contract = match outcome {
    Ok(value) => value
    Err(message) => {
      println("managed_platform_contract(android) failed: " + message)
      fail("managed_platform_contract(android) failed")
    }
  }
  inspect(contract.platform, content="android")
  inspect(contract.app_id, content="counter")
  inspect(contract.entrypoint_arg, content="moui-counter-android")
  inspect(
    contract.moonbit_main_alias,
    content="moui_embedding_moonbit_generated_main",
  )
  inspect(contract.entrypoint_package, content="android")
  inspect(contract.generated_c, content="android.c")
  inspect(contract.embedding_exports.length(), content="9")
  match contract.native_library {
    Some(library) => inspect(library, content="moui_counter_android")
    None => fail("expected native library on android contract")
  }
  assert_true(contract.info_plist.is_empty())
}

///|
fn shell_config_run_ios_contract(
  root : String,
) -> Result[ManagedContract, String] raise {
  shell_config_prepare_counter(root)
  let app = match read_shell_app(root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let shell_root = join_path(root, "moui_shell")
  managed_platform_contract(app, "ios", root, shell_root)
}

///|
test "test_managed_platform_contract_ios" {
  let root = test_temp_path("shell-config-ios")
  remove_tree(root)
  let outcome = shell_config_run_ios_contract(root)
  remove_tree(root)
  let contract = match outcome {
    Ok(value) => value
    Err(message) => {
      println("managed_platform_contract(ios) failed: " + message)
      fail("managed_platform_contract(ios) failed")
    }
  }
  inspect(contract.platform, content="ios")
  inspect(contract.entrypoint_arg, content="moui-counter-ios")
  inspect(contract.embedding_exports.length(), content="9")
  assert_true(contract.native_library.is_empty())
  let expected_info_plist = join_path(
    join_path(root, "moui_shell"),
    "ios/runner/template/Info.plist",
  )
  match contract.info_plist {
    Some(path) => inspect(path, content=expected_info_plist)
    None => fail("expected Info.plist path on ios contract")
  }
}

///|
fn shell_config_run_harmonyos_contract(
  root : String,
) -> Result[ManagedContract, String] raise {
  shell_config_prepare_counter(root)
  let app = match read_shell_app(root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let shell_root = join_path(root, "moui_shell")
  managed_platform_contract(app, "harmonyos", root, shell_root)
}

///|
test "test_managed_platform_contract_harmonyos" {
  let root = test_temp_path("shell-config-harmonyos")
  remove_tree(root)
  let outcome = shell_config_run_harmonyos_contract(root)
  remove_tree(root)
  let contract = match outcome {
    Ok(value) => value
    Err(message) => {
      println("managed_platform_contract(harmonyos) failed: " + message)
      fail("managed_platform_contract(harmonyos) failed")
    }
  }
  inspect(contract.platform, content="harmonyos")
  inspect(contract.entrypoint_arg, content="moui-counter-harmonyos")
  inspect(contract.embedding_exports.length(), content="9")
  match contract.native_library {
    Some(library) => inspect(library, content="moui_embedding_harmonyos")
    None => fail("expected native library on harmonyos contract")
  }
  assert_true(contract.info_plist.is_empty())
}

///|
fn shell_config_run_resolve_ios(
  root : String,
  mode : String,
) -> Result[IosShellResolution, String] raise {
  shell_config_prepare_counter(root)
  let app = match read_shell_app(root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let moui_root = join_path(root, "moui")
  resolve_ios_shell(app, root, moui_root, "auto", mode)
}

///|
test "test_resolve_ios_shell_managed" {
  let root = test_temp_path("shell-config-resolve")
  remove_tree(root)
  let outcome = shell_config_run_resolve_ios(root, "managed")
  remove_tree(root)
  let resolution = match outcome {
    Ok(value) => value
    Err(message) => {
      println("resolve_ios_shell failed: " + message)
      fail("resolve_ios_shell failed")
    }
  }
  inspect(resolution.runner_mode, content="managed")
  inspect(resolution.deployment_target, content="15.0")
  inspect(resolution.entrypoint_arg, content="moui-counter-ios")
  inspect(resolution.status_bar, content="auto")
  inspect(resolution.orientation, content="any")
  inspect(resolution.fullscreen, content="false")
  inspect(resolution.permissions.length(), content="0")
  inspect(resolution.swift_sources.length(), content="0")
  inspect(resolution.objcxx_sources.length(), content="0")
  inspect(resolution.plugin_types.length(), content="0")
}

///|
test "test_resolve_ios_shell_rejects_wrong_mode" {
  let root = test_temp_path("shell-config-wrong-mode")
  remove_tree(root)
  let outcome = shell_config_run_resolve_ios(root, "ejected")
  remove_tree(root)
  match outcome {
    Ok(_) =>
      fail("expected resolve_ios_shell to fail when runner mode mismatches")
    Err(message) => assert_true(message.contains("runnerMode"))
  }
}

///|
fn shell_config_run_resolve_bogus_permission(
  root : String,
) -> Result[Unit, String] raise {
  shell_config_write(
    join_path(root, "shell.json"),
    (
      {
        "schemaVersion": 1,
        "id": "permtest",
        "displayName": "Perm Test",
        "artifactName": "permtest",
        "appPackage": "examples/permtest/app",
        "shellApiVersion": 1,
        "embeddingApiVersion": 1,
        "shell": {
          "profile": "handheld",
          "renderer": "auto",
          "systemUi": { "fullscreen": false, "statusBar": "auto" },
          "orientation": "any",
          "resources": [],
          "permissions": ["camera", "totally-bogus"],
          "plugins": [],
        },
        "ios": {
          "bundleId": "dev.wzzc.permtest",
          "productName": "PermTest",
          "runnerMode": "managed",
          "deploymentTarget": "15.0",
        },
      } : Json).stringify(indent=2) +
    "\n",
  )
  let app = match read_shell_app(root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match resolve_ios_shell(app, root, root, "auto", "managed") {
    Ok(_) => Err("expected resolve_ios_shell to reject unsupported permission")
    Err(message) =>
      if message.contains("totally-bogus") {
        Ok(())
      } else {
        Err("unexpected error: " + message)
      }
  }
}

///|
test "test_resolve_ios_shell_rejects_unsupported_permission" {
  let root = test_temp_path("shell-config-bogus-perm")
  remove_tree(root)
  let outcome = shell_config_run_resolve_bogus_permission(root)
  remove_tree(root)
  match outcome {
    Ok(_) => ()
    Err(message) => {
      println("unexpected outcome: " + message)
      fail("unexpected outcome")
    }
  }
}

///|
fn shell_config_run_read_with_unknown_field(
  root : String,
) -> Result[Unit, String] raise {
  shell_config_write(
    join_path(root, "shell.json"),
    (
      {
        "schemaVersion": 1,
        "id": "unknown",
        "displayName": "Unknown",
        "artifactName": "unknown",
        "appPackage": "examples/unknown/app",
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
          "applicationId": "dev.wzzc.unknown",
          "runnerMode": "managed",
          "minSdk": 23,
        },
        "totallyUnknownField": "oops",
      } : Json).stringify(indent=2) +
    "\n",
  )
  match read_shell_app(root) {
    Ok(_) => Err("expected read_shell_app to reject unknown field")
    Err(message) =>
      if message.contains("unknown field") {
        Ok(())
      } else {
        Err("unexpected error: " + message)
      }
  }
}

///|
test "test_read_shell_app_rejects_unknown_field" {
  let root = test_temp_path("shell-config-unknown")
  remove_tree(root)
  let outcome = shell_config_run_read_with_unknown_field(root)
  remove_tree(root)
  match outcome {
    Ok(_) => ()
    Err(message) => {
      println("unexpected outcome: " + message)
      fail("unexpected outcome")
    }
  }
}

///|
fn shell_config_run_read_bad_schema(
  root : String,
) -> Result[Unit, String] raise {
  shell_config_write(
    join_path(root, "shell.json"),
    (
      {
        "schemaVersion": 2,
        "id": "bad",
        "displayName": "Bad",
        "artifactName": "bad",
        "appPackage": "examples/bad/app",
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
          "applicationId": "dev.wzzc.bad",
          "runnerMode": "managed",
          "minSdk": 23,
        },
      } : Json).stringify(indent=2) +
    "\n",
  )
  match read_shell_app(root) {
    Ok(_) => Err("expected read_shell_app to reject schemaVersion=2")
    Err(message) =>
      if message.contains("schemaVersion must be 1") {
        Ok(())
      } else {
        Err("unexpected error: " + message)
      }
  }
}

///|
test "test_read_shell_app_rejects_bad_schema_version" {
  let root = test_temp_path("shell-config-bad-schema")
  remove_tree(root)
  let outcome = shell_config_run_read_bad_schema(root)
  remove_tree(root)
  match outcome {
    Ok(_) => ()
    Err(message) => {
      println("unexpected outcome: " + message)
      fail("unexpected outcome")
    }
  }
}
