// Whitebox tests for `run.mbt`.
//
// Tests focus on `parse_run_args` (pure) and `apply_config_overrides_run`
// (pure). Real build / install / launch is exercised by integration tests
// with hardware attached.

///|
test "test_parse_run_args_basic" {
  let parsed = parse_run_args(
    ["android", "showcase"],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(value) => {
      assert_false(value.help)
      assert_false(value.json)
      inspect(value.platform, content="android")
      guard value.options is Some(options) else {
        fail("expected options")
        return
      }
      inspect(options.app, content="showcase")
      assert_false(options.fallback_skia)
      assert_false(options.ejected_shell)
      assert_false(options.no_build)
      assert_false(options.no_install)
      assert_false(options.no_launch)
      assert_false(options.debug)
      assert_false(options.verify)
    }
    Err(message) => fail("parse_run_args failed: " + message)
  }
}

///|
test "test_parse_run_args_build_only" {
  let parsed = parse_run_args(
    ["ios", "demo", "--build-only"],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(value) => {
      guard value.options is Some(options) else {
        fail("expected options")
        return
      }
      assert_true(options.build_only)
      assert_false(options.prepare_only)
    }
    Err(message) => fail("parse_run_args failed: " + message)
  }
}

///|
test "test_parse_run_args_no_install" {
  let parsed = parse_run_args(
    ["harmonyos", "demo", "--no-install", "--no-launch"],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(value) => {
      guard value.options is Some(options) else {
        fail("expected options")
        return
      }
      assert_true(options.no_install)
      assert_true(options.no_launch)
    }
    Err(message) => fail("parse_run_args failed: " + message)
  }
}

///|
test "test_parse_run_args_options" {
  let parsed = parse_run_args(
    [
      "android", "showcase", "--app-config", "/tmp/shell.json", "--device", "emulator-5554",
      "--renderer", "skia", "--fallback-skia", "--filter", "MoUI:V", "--verify",
      "--json",
    ],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(value) => {
      assert_true(value.json)
      guard value.options is Some(options) else {
        fail("expected options")
        return
      }
      inspect(options.app_config_path, content="Some(/tmp/shell.json)")
      inspect(options.device, content="Some(emulator-5554)")
      inspect(options.renderer, content="Some(skia)")
      inspect(options.filter, content="Some(MoUI:V)")
      assert_true(options.fallback_skia)
      assert_true(options.verify)
    }
    Err(message) => fail("parse_run_args failed: " + message)
  }
}

///|
test "test_parse_run_args_custom_args_passthrough" {
  let parsed = parse_run_args(
    ["ios", "demo", "--", "--debug", "--scene=main"],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(value) => {
      guard value.options is Some(options) else {
        fail("expected options")
        return
      }
      inspect(options.custom_args.length(), content="2")
      inspect(options.custom_args[0], content="--debug")
      inspect(options.custom_args[1], content="--scene=main")
      // --debug before `--` is a flag; --debug after `--` is a custom arg.
      assert_false(options.debug)
    }
    Err(message) => fail("parse_run_args failed: " + message)
  }
}

///|
test "test_parse_run_args_help_flag" {
  let parsed = parse_run_args(["--help"], "/tmp", detect_host_platform())
  match parsed {
    Ok(value) => {
      assert_true(value.help)
      inspect(value.platform, content="")
      assert_true(value.options.is_none())
    }
    Err(message) => fail("parse_run_args failed: " + message)
  }
}

///|
test "test_parse_run_args_rejects_desktop" {
  let parsed = parse_run_args(["web", "demo"], "/tmp", detect_host_platform())
  match parsed {
    Ok(_) => fail("expected parse error for desktop platform")
    Err(message) => assert_true(message.contains("use `moon run`"))
  }
}

///|
test "test_parse_run_args_rejects_missing_positional" {
  let parsed = parse_run_args(["android"], "/tmp", detect_host_platform())
  match parsed {
    Ok(_) => fail("expected parse error for missing app")
    Err(message) => assert_true(message.contains("usage"))
  }
}

///|
test "test_parse_run_args_rejects_too_many_positional" {
  let parsed = parse_run_args(
    ["android", "demo", "extra"],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(_) => fail("expected parse error for extra positional")
    Err(message) => assert_true(message.contains("exactly two"))
  }
}

///|
test "test_parse_run_args_rejects_unknown_option" {
  let parsed = parse_run_args(
    ["android", "demo", "--bogus"],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(_) => fail("expected parse error for unknown option")
    Err(message) => assert_true(message.contains("unknown option"))
  }
}

///|
test "test_apply_config_overrides_run_preserves_cli_values" {
  let options : RunOptions = {
    app: "demo",
    app_config_path: Some("/cli/shell.json"),
    device: Some("emulator-5554"),
    renderer: Some("skia"),
    fallback_skia: true,
    ejected_shell: false,
    prepare_only: false,
    build_only: false,
    no_build: false,
    no_install: false,
    no_launch: false,
    debug: false,
    filter: None,
    verify: false,
    custom_args: [],
  }
  let config = default_cli_config()
  let overridden = apply_config_overrides_run(options, config)
  inspect(overridden.device, content="Some(emulator-5554)")
  inspect(overridden.renderer, content="Some(skia)")
  inspect(overridden.app_config_path, content="Some(/cli/shell.json)")
}

///|
test "test_apply_config_overrides_run_fills_none_with_defaults" {
  let options : RunOptions = {
    app: "demo",
    app_config_path: None,
    device: None,
    renderer: None,
    fallback_skia: false,
    ejected_shell: false,
    prepare_only: false,
    build_only: false,
    no_build: false,
    no_install: false,
    no_launch: false,
    debug: false,
    filter: None,
    verify: false,
    custom_args: [],
  }
  let config = default_cli_config()
  let overridden = apply_config_overrides_run(options, config)
  assert_true(overridden.device.is_none())
  assert_true(overridden.renderer.is_none())
  assert_true(overridden.app_config_path.is_none())
}

///|
test "test_run_usage_mentions_platforms" {
  let text = run_usage()
  assert_true(text.contains("android"))
  assert_true(text.contains("ios"))
  assert_true(text.contains("harmonyos"))
  assert_true(text.contains("--device"))
  assert_true(text.contains("--verify"))
}

///|
test "test_find_build_artifact_returns_platform_suffix" {
  inspect(
    find_build_artifact("android", "/tmp/build", "demo"),
    content="/tmp/build/demo.apk",
  )
  inspect(
    find_build_artifact("ios", "/tmp/build", "demo"),
    content="/tmp/build/demo.app",
  )
  inspect(
    find_build_artifact("harmonyos", "/tmp/build", "demo"),
    content="/tmp/build/demo.hap",
  )
  inspect(find_build_artifact("unknown", "/tmp", "demo"), content="")
}

///|
test "test_resolve_target_device_uses_supplied_id" {
  let options : RunOptions = {
    app: "demo",
    app_config_path: None,
    device: Some("emulator-5554"),
    renderer: None,
    fallback_skia: false,
    ejected_shell: false,
    prepare_only: false,
    build_only: false,
    no_build: false,
    no_install: false,
    no_launch: false,
    debug: false,
    filter: None,
    verify: false,
    custom_args: [],
  }
  match resolve_target_device(options, "android", detect_host_platform()) {
    Ok(device) => {
      inspect(device.id, content="emulator-5554")
      inspect(device.platform, content="android")
      inspect(device.kind, content="unknown")
    }
    Err(message) => fail("expected device, got: " + message)
  }
}

///|
test "test_run_result_to_text_emits_summary" {
  let device : Device = {
    platform: "android",
    id: "emulator-5554",
    name: "Pixel 6",
    state: "device",
    kind: "emulator",
  }
  let text = run_result_to_text(
    "android",
    "demo",
    device,
    "dev.example.demo",
    "launched",
    None,
  )
  assert_true(text.contains("[run] android app=demo"))
  assert_true(text.contains("emulator-5554 (Pixel 6)"))
  assert_true(text.contains("dev.example.demo"))
  assert_true(text.contains("status: launched"))
}

///|
test "test_run_result_to_json_emits_schema" {
  let device : Device = {
    platform: "ios",
    id: "UUID-DEAD",
    name: "iPhone 15",
    state: "Booted",
    kind: "emulator",
  }
  let json = run_result_to_json(
    "ios",
    "demo",
    device,
    "dev.example.demo",
    "launched",
    None,
  )
  let text = json.stringify(indent=2)
  assert_true(text.contains("\"schemaVersion\": 1"))
  assert_true(text.contains("\"ok\": true"))
  assert_true(text.contains("\"platform\": \"ios\""))
  assert_true(text.contains("\"appId\": \"demo\""))
  assert_true(text.contains("\"deviceId\": \"UUID-DEAD\""))
  assert_true(text.contains("\"bundleId\": \"dev.example.demo\""))
  assert_true(text.contains("\"launchStatus\": \"launched\""))
}

///|
test "test_build_options_from_run_options_preserves_cli_overrides" {
  let options : RunOptions = {
    app: "demo",
    app_config_path: Some("/cli/shell.json"),
    device: Some("emulator-5554"),
    renderer: Some("skia"),
    fallback_skia: true,
    ejected_shell: true,
    prepare_only: true,
    build_only: false,
    no_build: false,
    no_install: false,
    no_launch: false,
    debug: false,
    filter: None,
    verify: false,
    custom_args: [],
  }
  let build_options = build_options_from_run_options(options, ".", None)
  inspect(build_options.app_config_path, content="Some(/cli/shell.json)")
  inspect(build_options.workspace_root, content=".")
  inspect(build_options.moui_root, content="")
  inspect(build_options.skia_root, content="")
  inspect(build_options.build_dir, content="")
  assert_true(build_options.output.is_none())
  inspect(build_options.renderer, content="Some(skia)")
  assert_true(build_options.fallback_skia)
  assert_true(build_options.ejected_shell)
  assert_true(build_options.prepare_only)
  assert_true(build_options.android_project.is_none())
  assert_true(build_options.xcode_project.is_none())
  assert_true(build_options.scheme.is_none())
  assert_true(build_options.product_name.is_none())
  assert_true(build_options.harmonyos_project.is_none())
  assert_true(build_options.abi.is_none())
  assert_true(build_options.compile_sdk.is_none())
  assert_true(build_options.target_sdk.is_none())
  assert_true(build_options.sdk.is_none())
  assert_true(build_options.arch.is_none())
  assert_true(build_options.deployment_target.is_none())
  assert_true(build_options.sdk_home.is_none())
  assert_true(build_options.hvigorw.is_none())
  assert_true(build_options.ohpm.is_none())
  assert_true(build_options.signing_config_file.is_none())
}

///|
test "test_build_options_from_run_options_uses_defaults_when_none" {
  let options : RunOptions = {
    app: "demo",
    app_config_path: None,
    device: None,
    renderer: None,
    fallback_skia: false,
    ejected_shell: false,
    prepare_only: false,
    build_only: false,
    no_build: false,
    no_install: false,
    no_launch: false,
    debug: false,
    filter: None,
    verify: false,
    custom_args: [],
  }
  let build_options = build_options_from_run_options(options, ".", None)
  assert_true(build_options.app_config_path.is_none())
  assert_true(build_options.renderer.is_none())
  assert_false(build_options.fallback_skia)
  assert_false(build_options.ejected_shell)
  assert_false(build_options.prepare_only)
  inspect(build_options.workspace_root, content=".")
}

///|
test "test_build_options_from_run_options_passes_sdk_override" {
  let options : RunOptions = {
    app: "demo",
    app_config_path: None,
    device: None,
    renderer: None,
    fallback_skia: false,
    ejected_shell: false,
    prepare_only: false,
    build_only: false,
    no_build: false,
    no_install: false,
    no_launch: false,
    debug: false,
    filter: None,
    verify: false,
    custom_args: [],
  }
  let with_override = build_options_from_run_options(
    options,
    ".",
    Some("iphonesimulator"),
  )
  inspect(with_override.sdk, content="Some(iphonesimulator)")
  let without_override = build_options_from_run_options(options, ".", None)
  assert_true(without_override.sdk.is_none())
}

///|
test "test_is_ios_simulator_udid_detects_uuid_format" {
  // Simulator UDIDs are UUIDs with dashes.
  assert_true(is_ios_simulator_udid("33E45CC1-A8C6-4245-B820-CAFBC9AB6E5C"))
  assert_true(is_ios_simulator_udid("8C2B2851-2D6F-4750-A8C4-D321482D2E8D"))
  assert_true(is_ios_simulator_udid("00008110-001E35880EE1003C"))
  // Physical device UDIDs have no dashes (25 or 40 hex chars).
  assert_false(is_ios_simulator_udid("00008110-001E35880EE1003C-extra"))
  assert_false(is_ios_simulator_udid("abcd1234"))
  assert_false(
    is_ios_simulator_udid("1234567890abcdef1234567890abcdef12345678"),
  )
  // Empty / malformed inputs.
  assert_false(is_ios_simulator_udid(""))
  assert_false(is_ios_simulator_udid("---"))
  assert_false(is_ios_simulator_udid("XYZ-123"))
}

///|
test "test_resolve_ios_sdk_override_returns_simulator_for_uuid" {
  let simulator_device : Device = {
    platform: "ios",
    id: "33E45CC1-A8C6-4245-B820-CAFBC9AB6E5C",
    name: "iPad Pro 13-inch (M5)",
    state: "Booted",
    kind: "emulator",
  }
  inspect(
    resolve_ios_sdk_override("ios", simulator_device),
    content="Some(iphonesimulator)",
  )
  let physical_device : Device = {
    platform: "ios",
    id: "00008111001E35880EE1003C",
    name: "iPhone 15 Pro",
    state: "device",
    kind: "physical",
  }
  // Physical device: returns None so build_command.mbt applies its own
  // default (iphoneos) or the user's `moui config ios.sdk`.
  assert_true(resolve_ios_sdk_override("ios", physical_device).is_none())
  // Non-iOS platforms: always None.
  let android_device : Device = {
    platform: "android",
    id: "emulator-5554",
    name: "Pixel 6",
    state: "device",
    kind: "emulator",
  }
  assert_true(resolve_ios_sdk_override("android", android_device).is_none())
}
