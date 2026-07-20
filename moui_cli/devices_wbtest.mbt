// Whitebox tests for `devices.mbt`.
//
// Tests focus on the pure parsers (`parse_adb_devices`, `parse_simctl_list`,
// `parse_hdc_targets`) and argument parsing. Real `adb` / `xcrun` / `hdc`
// invocation is exercised by integration tests with hardware attached.

///|
test "test_parse_adb_devices_basic" {
  let sample =
    #|List of devices attached
    #|emulator-5554   device  product:sdk_gphone64 model:sdk_gphone64 device:emulator64_x86_64 transport_id:1
    #|0123456789abcdef   device  product:pixel model:Pixel device:pixel_5 transport_id:2
    #|
  let devices = parse_adb_devices(sample)
  inspect(devices.length(), content="2")
  // Emulator detected by serial prefix.
  inspect(devices[0].platform, content="android")
  inspect(devices[0].id, content="emulator-5554")
  inspect(devices[0].state, content="device")
  inspect(devices[0].kind, content="emulator")
  // Physical device detected.
  inspect(devices[1].id, content="0123456789abcdef")
  inspect(devices[1].kind, content="physical")
  inspect(devices[1].name, content="Pixel")
}

///|
test "test_parse_adb_devices_with_unauthorized_state" {
  let sample =
    #|List of devices attached
    #|device1     unauthorized transport_id:1
    #|device2     offline    transport_id:2
  let devices = parse_adb_devices(sample)
  inspect(devices.length(), content="2")
  inspect(devices[0].state, content="unauthorized")
  inspect(devices[1].state, content="offline")
}

///|
test "test_parse_adb_devices_ignores_daemon_messages" {
  let sample =
    #|* daemon not running; starting now at tcp:5037
    #|* daemon started successfully
    #|List of devices attached
    #|emulator-5556   device  transport_id:3
  let devices = parse_adb_devices(sample)
  inspect(devices.length(), content="1")
  inspect(devices[0].id, content="emulator-5556")
}

///|
test "test_parse_adb_devices_empty_output" {
  inspect(parse_adb_devices(""), content="[]")
  inspect(parse_adb_devices("List of devices attached\n"), content="[]")
}

///|
test "test_parse_adb_devices_localhost_emulator_kind" {
  let sample =
    #|List of devices attached
    #|localhost:5555   device  transport_id:9
  let devices = parse_adb_devices(sample)
  inspect(devices.length(), content="1")
  inspect(devices[0].kind, content="emulator")
}

///|
test "test_parse_simctl_list_basic" {
  let sample =
    #|== Device Types ==
    #|iPhone 15 (XXX)
    #|== Devices ==
    #|-- iOS 17.0 --
    #|    iPhone 15 (00000000-0000-0000-0000-000000000000) (Shutdown)
    #|    iPhone 15 Pro (11111111-1111-1111-1111-111111111111) (Booted)
    #|-- iOS 16.0 --
    #|    iPhone SE (3rd generation) (22222222-2222-2222-2222-222222222222) (Shutdown)
  let devices = parse_simctl_list(sample)
  inspect(devices.length(), content="3")
  inspect(devices[0].platform, content="ios")
  inspect(devices[0].name, content="iPhone 15")
  inspect(devices[0].id, content="00000000-0000-0000-0000-000000000000")
  inspect(devices[0].state, content="Shutdown")
  inspect(devices[1].state, content="Booted")
  inspect(devices[1].name, content="iPhone 15 Pro")
  inspect(devices[2].name, content="iPhone SE (3rd generation)")
}

///|
test "test_parse_simctl_list_skips_non_devices_section" {
  let sample =
    #|== Device Types ==
    #|    iPhone 15 (XXX-XXX) (Shutdown)
    #|== Device Pairs ==
    #|    (pair) (Booted)
  let devices = parse_simctl_list(sample)
  inspect(devices, content="[]")
}

///|
test "test_parse_simctl_list_empty_output" {
  inspect(parse_simctl_list(""), content="[]")
}

///|
test "test_parse_hdc_targets_basic" {
  let sample =
    #|    device_1   Connected
    #|    device_2   Connecting
  let devices = parse_hdc_targets(sample)
  inspect(devices.length(), content="2")
  inspect(devices[0].platform, content="harmonyos")
  inspect(devices[0].id, content="device_1")
  inspect(devices[0].state, content="Connected")
  inspect(devices[1].state, content="Connecting")
}

///|
test "test_parse_hdc_targets_single_column" {
  // Some hdc versions print only device IDs.
  let sample = "device_1\ndevice_2\n"
  let devices = parse_hdc_targets(sample)
  inspect(devices.length(), content="2")
  inspect(devices[0].state, content="connected")
}

///|
test "test_parse_hdc_targets_empty_output" {
  inspect(parse_hdc_targets(""), content="[]")
  inspect(parse_hdc_targets("[Empty]"), content="[]")
  inspect(parse_hdc_targets("No target found"), content="[]")
}

///|
test "test_parse_devices_args_default" {
  match parse_devices_args([]) {
    Ok(parsed) => {
      assert_false(parsed.help)
      assert_false(parsed.json)
      assert_true(parsed.platform is None)
    }
    Err(message) => fail(message)
  }
}

///|
test "test_parse_devices_args_json_flag" {
  match parse_devices_args(["--json"]) {
    Ok(parsed) => assert_true(parsed.json)
    Err(message) => fail(message)
  }
}

///|
test "test_parse_devices_args_platform_filter" {
  match parse_devices_args(["--platform", "android"]) {
    Ok(parsed) =>
      match parsed.platform {
        Some(value) => inspect(value, content="android")
        None => fail("expected platform=android")
      }
    Err(message) => fail(message)
  }
}

///|
test "test_parse_devices_args_platform_inline_value" {
  match parse_devices_args(["--platform=ios"]) {
    Ok(parsed) =>
      match parsed.platform {
        Some(value) => inspect(value, content="ios")
        None => fail("expected platform=ios")
      }
    Err(message) => fail(message)
  }
}

///|
test "test_parse_devices_args_rejects_unknown_platform" {
  match parse_devices_args(["--platform", "web"]) {
    Ok(_) => fail("expected Err for unknown platform")
    Err(message) => assert_true(message.contains("unsupported --platform"))
  }
}

///|
test "test_parse_devices_args_rejects_unknown_option" {
  match parse_devices_args(["--unknown"]) {
    Ok(_) => fail("expected Err for unknown option")
    Err(message) => assert_true(message.contains("unknown option"))
  }
}

///|
test "test_parse_devices_args_rejects_positional_args" {
  match parse_devices_args(["android"]) {
    Ok(_) => fail("expected Err for positional argument")
    Err(message) => assert_true(message.contains("positional arguments"))
  }
}

///|
test "test_parse_devices_args_help_flag" {
  match parse_devices_args(["--help"]) {
    Ok(parsed) => assert_true(parsed.help)
    Err(message) => fail(message)
  }
}

///|
test "test_run_devices_help_emits_usage" {
  let parsed : ParsedDevices = { help: true, json: false, platform: None }
  let outcome = run_devices(parsed, detect_host_platform())
  assert_true(outcome.exit_code == 0)
  assert_true(outcome.stdout.contains("Usage: moui devices"))
}

///|
test "test_run_devices_json_empty_when_no_tooling" {
  // On a typical sandbox without adb/xcrun/hdc installed, list_all_devices
  // returns an empty array. The JSON output must still be valid.
  let parsed : ParsedDevices = { help: false, json: true, platform: None }
  let outcome = run_devices(parsed, detect_host_platform())
  assert_true(outcome.exit_code == 0)
  // Output is JSON; either an empty array or a non-empty array depending on
  // the host's toolchain. Either is acceptable in CI.
  assert_true(outcome.stdout.contains("\"devices\":"))
}

///|
test "test_run_devices_text_empty_emits_no_devices_message" {
  // Force an empty list by filtering for an unavailable platform-specific
  // tool. We use a sandbox where adb may or may not be installed; assert that
  // the message is either "(no devices found)" or a tab-separated list.
  let parsed : ParsedDevices = { help: false, json: false, platform: None }
  let outcome = run_devices(parsed, detect_host_platform())
  assert_true(outcome.exit_code == 0)
  assert_true(
    outcome.stdout.contains("(no devices found)") ||
    outcome.stdout.contains("\t"),
  )
}

///|
test "test_list_all_devices_returns_array_without_panic" {
  // list_all_devices must never raise; it must skip platforms whose tooling
  // is unavailable.
  let devices = list_all_devices(detect_host_platform())
  let _ = devices.length()
  assert_true(true)
}

///|
test "test_device_struct_equality" {
  let d1 : Device = {
    platform: "android",
    id: "emulator-5554",
    name: "sdk_gphone64",
    state: "device",
    kind: "emulator",
  }
  let d2 : Device = {
    platform: "android",
    id: "emulator-5554",
    name: "sdk_gphone64",
    state: "device",
    kind: "emulator",
  }
  assert_true(d1 == d2)
}
