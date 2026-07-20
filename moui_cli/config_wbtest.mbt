// Whitebox tests for cli config schema, JSON roundtrip, and file I/O.
// All tests isolate the XDG path via `MOUI_CONFIG_DIR` so the real user
// config is never touched.

///|
fn setup_test_config_dir(prefix : String) -> String {
  let tmp = @env.get_env_var("TMPDIR").unwrap_or_else(() => {
    @env.get_env_var("TEMP").unwrap_or_else(() => {
      @env.get_env_var("TMP").unwrap_or("/tmp")
    })
  })
  let dir = join_path(
    tmp,
    "moui-config-test-" + prefix + "-" + @env.now().to_string(),
  )
  ignore(mkdir_p(dir))
  @env.set_env_var("MOUI_CONFIG_DIR", dir)
  dir
}

///|
fn teardown_test_config_dir() -> Unit {
  @env.unset_env_var("MOUI_CONFIG_DIR")
}

///|
test "default_cli_config has schema_version 1 and all None fields" {
  let config = default_cli_config()
  assert_eq(config.schema_version, 1)
  assert_eq(config.harmonyos.sdk_home, None)
  assert_eq(config.harmonyos.hvigorw, None)
  assert_eq(config.harmonyos.ohpm, None)
  assert_eq(config.harmonyos.signing_config_file, None)
  assert_eq(config.android.sdk_home, None)
  assert_eq(config.android.ndk_home, None)
  assert_true(config.android.abi.is_empty())
  assert_eq(config.android.compile_sdk, None)
  assert_eq(config.android.target_sdk, None)
  assert_eq(config.ios.sdk, None)
  assert_eq(config.ios.arch, None)
  assert_eq(config.ios.deployment_target, None)
  assert_eq(config.paths.moon_home, None)
  assert_eq(config.paths.moui_root, None)
  assert_eq(config.paths.skia_root, None)
}

///|
test "validate_cli_config accepts schema_version 1" {
  let config = default_cli_config()
  assert_true(validate_cli_config(config).is_ok())
}

///|
test "validate_cli_config rejects schema_version 2" {
  let config = { ..default_cli_config(), schema_version: 2 }
  match validate_cli_config(config) {
    Err(message) => assert_true(message.contains("schemaVersion"))
    _ => fail("expected schema_version 2 to be rejected")
  }
}

///|
test "config_get resolves nested keys" {
  let config = {
    ..default_cli_config(),
    harmonyos: { ..default_harmonyos_config(), sdk_home: Some("/sdk") },
    android: {
      ..default_android_config(),
      compile_sdk: Some(34),
      abi: ["arm64-v8a", "x86_64"],
    },
  }
  match config_get(config, "harmonyos.sdkHome") {
    Ok(value) => assert_eq(value, "/sdk")
    Err(_) => fail("expected harmonyos.sdkHome")
  }
  match config_get(config, "android.compileSdk") {
    Ok(value) => assert_eq(value, "34")
    Err(_) => fail("expected android.compileSdk")
  }
  match config_get(config, "harmonyos.ohpm") {
    Err(message) => assert_true(message.contains("not set"))
    _ => fail("expected unset ohpm to error")
  }
}

///|
test "config_set returns updated config" {
  let config = default_cli_config()
  match config_set(config, "harmonyos.sdkHome", "/Applications/DevEco") {
    Ok(updated) =>
      match config_get(updated, "harmonyos.sdkHome") {
        Ok(value) => assert_eq(value, "/Applications/DevEco")
        _ => fail("expected updated value")
      }
    Err(_) => fail("config_set should succeed")
  }
}

///|
test "config_set rejects unknown section" {
  let config = default_cli_config()
  match config_set(config, "unknown.field", "value") {
    Err(message) => assert_true(message.contains("unknown config section"))
    _ => fail("expected unknown section error")
  }
}

///|
test "config_set parses integer fields" {
  let config = default_cli_config()
  match config_set(config, "android.compileSdk", "34") {
    Ok(updated) => assert_eq(updated.android.compile_sdk, Some(34))
    _ => fail("config_set should parse integer")
  }
}

///|
test "config_set rejects non-integer for integer field" {
  let config = default_cli_config()
  match config_set(config, "android.compileSdk", "abc") {
    Err(message) => assert_true(message.contains("must be an integer"))
    _ => fail("expected integer parse error")
  }
}

///|
test "read_config returns default when file missing" {
  let _ = setup_test_config_dir("missing")
  defer teardown_test_config_dir()
  let host = detect_host_platform()
  match read_config(host) {
    Ok(config) => assert_eq(config.schema_version, 1)
    Err(_) => fail("read_config should fall back to default")
  }
}

///|
test "write_config then read_config roundtrips" {
  let dir = setup_test_config_dir("roundtrip")
  defer teardown_test_config_dir()
  let host = detect_host_platform()
  let original = {
    ..default_cli_config(),
    harmonyos: {
      ..default_harmonyos_config(),
      sdk_home: Some("/Applications/DevEco-Studio.app/Contents/sdk"),
      ohpm: Some("/usr/local/bin/ohpm"),
    },
    android: {
      ..default_android_config(),
      sdk_home: Some("/Users/user/Library/Android/sdk"),
      ndk_home: Some("/Users/user/Library/Android/ndk"),
      abi: ["arm64-v8a", "x86_64"],
      compile_sdk: Some(34),
      target_sdk: Some(34),
    },
    ios: { ..default_ios_config(), sdk: Some("iphonesimulator") },
    paths: { ..default_paths_config(), moui_root: Some("/Volumes/MoUI") },
  }
  match write_config(original, host) {
    Ok(_) => ()
    Err(message) => fail("write_config failed: " + message)
  }
  match read_config(host) {
    Ok(loaded) => assert_eq(loaded.schema_version, original.schema_version)
    Err(message) => fail("read_config after write failed: " + message)
  }
  let path = config_path(host)
  assert_true(path.contains(dir) || path.has_prefix(dir))
}

///|
test "cli_config_to_json and cli_config_from_json roundtrip" {
  let original = {
    ..default_cli_config(),
    harmonyos: {
      ..default_harmonyos_config(),
      sdk_home: Some("/home/sdk"),
      hvigorw: Some("/home/hvigorw"),
      ohpm: Some("/home/ohpm"),
      signing_config_file: Some("/home/signing.json"),
    },
    android: {
      ..default_android_config(),
      sdk_home: Some("/android/sdk"),
      ndk_home: Some("/android/ndk"),
      abi: ["arm64-v8a"],
      compile_sdk: Some(33),
      target_sdk: Some(33),
    },
    ios: {
      ..default_ios_config(),
      sdk: Some("iphonesimulator"),
      arch: Some("arm64"),
      deployment_target: Some(15),
    },
    paths: {
      ..default_paths_config(),
      moon_home: Some("/home/moon"),
      moui_root: Some("/home/moui"),
      skia_root: Some("/home/skia"),
    },
  }
  let json = cli_config_to_json(original)
  match cli_config_from_json(json) {
    Ok(parsed) => assert_eq(parsed.schema_version, original.schema_version)
    Err(message) => fail("roundtrip failed: " + message)
  }
  // Re-serialize and compare JSON text to cover full field roundtrip.
  match cli_config_from_json(json) {
    Ok(parsed) => {
      let reparsed = cli_config_to_json(parsed)
      assert_eq(reparsed.stringify(), json.stringify())
    }
    Err(message) => fail("roundtrip failed: " + message)
  }
}

///|
test "cli_config_from_json rejects non-object root" {
  let value = Json::string("not an object")
  match cli_config_from_json(value) {
    Err(message) => assert_true(message.contains("must be an object"))
    _ => fail("expected non-object root to error")
  }
}

///|
test "config_list_lines omits unset fields" {
  let config = {
    ..default_cli_config(),
    harmonyos: { ..default_harmonyos_config(), sdk_home: Some("/sdk") },
  }
  let lines = config_list_lines(config)
  let mut found = false
  for line in lines {
    if line == "harmonyos.sdkHome = /sdk" {
      found = true
    }
  }
  assert_true(found)
}
