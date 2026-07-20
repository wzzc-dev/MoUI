// Whitebox tests for `build_command.mbt`.
//
// Tests focus on `parse_build_args` (pure) and the
// `build_*_options_from_command` converters (pure). Real `build_android` /
// `build_ios` / `build_harmonyos` invocations are exercised by integration
// tests with hardware attached.

///|
/// Construct a minimal `ShellApp` with all optional platform fields set to
/// `None`. The platform-specific `build_*_options_from_command` converters
/// only read `app.id`, so this is enough for the option-conversion tests.
fn default_shell_for_test() -> Shell {
  {
    profile: "handheld",
    renderer: "auto",
    status_bar: "auto",
    orientation: "any",
    resources: [],
    permissions: [],
    plugins: [],
    fullscreen: false,
    supports_scroll: true,
  }
}

///|
test "test_parse_build_args_basic_android" {
  let parsed = parse_build_args(
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
      inspect(options.workspace_root, content="/tmp")
      inspect(options.moui_root, content="")
      inspect(options.skia_root, content="")
      inspect(options.build_dir, content="")
      assert_false(options.fallback_skia)
      assert_false(options.ejected_shell)
      assert_false(options.prepare_only)
    }
    Err(message) => fail("parse_build_args failed: " + message)
  }
}

///|
test "test_parse_build_args_ios_with_all_options" {
  let parsed = parse_build_args(
    [
      "ios", "demo", "--app-config", "/tmp/shell.json", "--workspace-root", "/repo",
      "--moui-root", "/repo/moui", "--skia-root", "/repo/moui_skia", "--build-dir",
      "/repo/artifacts/ios", "--output", "/repo/demo.app", "--renderer", "skia",
      "--fallback-skia", "--ejected-shell", "--prepare-only", "--xcode-project",
      "/repo/demo.xcodeproj", "--scheme", "demo", "--product-name", "demo", "--sdk",
      "iphoneos", "--arch", "arm64", "--deployment-target", "16.0",
    ],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(value) => {
      inspect(value.platform, content="ios")
      guard value.options is Some(options) else {
        fail("expected options")
        return
      }
      inspect(options.app_config_path, content="Some(/tmp/shell.json)")
      inspect(options.workspace_root, content="/repo")
      inspect(options.moui_root, content="/repo/moui")
      inspect(options.skia_root, content="/repo/moui_skia")
      inspect(options.build_dir, content="/repo/artifacts/ios")
      inspect(options.output, content="Some(/repo/demo.app)")
      inspect(options.renderer, content="Some(skia)")
      assert_true(options.fallback_skia)
      assert_true(options.ejected_shell)
      assert_true(options.prepare_only)
      inspect(options.xcode_project, content="Some(/repo/demo.xcodeproj)")
      inspect(options.scheme, content="Some(demo)")
      inspect(options.product_name, content="Some(demo)")
      inspect(options.sdk, content="Some(iphoneos)")
      inspect(options.arch, content="Some(arm64)")
      inspect(options.deployment_target, content="Some(16.0)")
    }
    Err(message) => fail("parse_build_args failed: " + message)
  }
}

///|
test "test_parse_build_args_harmonyos_options" {
  let parsed = parse_build_args(
    [
      "harmonyos", "demo", "--harmonyos-project", "/repo/hap", "--sdk-home", "/opt/cmd-tools",
      "--hvigorw", "/opt/cmd-tools/bin/hvigorw", "--ohpm", "/opt/cmd-tools/bin/ohpm",
      "--signing-config-file", "/etc/signing.json",
    ],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(value) => {
      inspect(value.platform, content="harmonyos")
      guard value.options is Some(options) else {
        fail("expected options")
        return
      }
      inspect(options.harmonyos_project, content="Some(/repo/hap)")
      inspect(options.sdk_home, content="Some(/opt/cmd-tools)")
      inspect(options.hvigorw, content="Some(/opt/cmd-tools/bin/hvigorw)")
      inspect(options.ohpm, content="Some(/opt/cmd-tools/bin/ohpm)")
      inspect(options.signing_config_file, content="Some(/etc/signing.json)")
    }
    Err(message) => fail("parse_build_args failed: " + message)
  }
}

///|
test "test_parse_build_args_android_int_options" {
  let parsed = parse_build_args(
    [
      "android", "demo", "--abi", "arm64-v8a", "--compile-sdk", "34", "--target-sdk",
      "34", "--android-project", "/repo/android",
    ],
    "/tmp",
    detect_host_platform(),
  )
  match parsed {
    Ok(value) => {
      guard value.options is Some(options) else {
        fail("expected options")
        return
      }
      inspect(options.abi, content="Some(arm64-v8a)")
      inspect(options.compile_sdk, content="Some(34)")
      inspect(options.target_sdk, content="Some(34)")
      inspect(options.android_project, content="Some(/repo/android)")
    }
    Err(message) => fail("parse_build_args failed: " + message)
  }
}

///|
test "test_parse_build_args_rejects_unknown_platform" {
  match parse_build_args(["plan9", "demo"], "/tmp", detect_host_platform()) {
    Ok(_) => fail("expected error for unknown platform")
    Err(message) =>
      assert_true(
        message.contains("unsupported platform for moui build: plan9"),
      )
  }
}

///|
test "test_parse_build_args_rejects_unknown_option" {
  match
    parse_build_args(
      ["android", "demo", "--bogus"],
      "/tmp",
      detect_host_platform(),
    ) {
    Ok(_) => fail("expected error for unknown option")
    Err(message) =>
      assert_true(message.contains("unknown option for moui build: --bogus"))
  }
}

///|
test "test_parse_build_args_rejects_invalid_int" {
  match
    parse_build_args(
      ["android", "demo", "--compile-sdk", "abc"],
      "/tmp",
      detect_host_platform(),
    ) {
    Ok(_) => fail("expected error for non-int value")
    Err(message) =>
      assert_true(message.contains("invalid integer for --compile-sdk"))
  }
}

///|
test "test_parse_build_args_rejects_too_few_positional" {
  match parse_build_args(["android"], "/tmp", detect_host_platform()) {
    Ok(_) => fail("expected error for too few positional args")
    Err(message) =>
      assert_true(message.contains("usage: moui build <platform> <app>"))
  }
}

///|
test "test_parse_build_args_rejects_too_many_positional" {
  match
    parse_build_args(
      ["android", "demo", "extra"],
      "/tmp",
      detect_host_platform(),
    ) {
    Ok(_) => fail("expected error for too many positional args")
    Err(message) =>
      assert_true(
        message.contains("moui build accepts exactly two positional arguments"),
      )
  }
}

///|
test "test_parse_build_args_help" {
  match parse_build_args(["--help"], "/tmp", detect_host_platform()) {
    Ok(value) => assert_true(value.help)
    Err(message) => fail("parse_build_args failed: " + message)
  }
}

///|
test "test_parse_build_args_json" {
  match
    parse_build_args(
      ["android", "demo", "--json"],
      "/tmp",
      detect_host_platform(),
    ) {
    Ok(value) => assert_true(value.json)
    Err(message) => fail("parse_build_args failed: " + message)
  }
}

///|
test "test_parse_build_args_inline_equals_form" {
  match
    parse_build_args(
      ["android", "demo", "--build-dir=/repo/out"],
      "/tmp",
      detect_host_platform(),
    ) {
    Ok(value) => {
      guard value.options is Some(options) else {
        fail("expected options")
        return
      }
      inspect(options.build_dir, content="/repo/out")
    }
    Err(message) => fail("parse_build_args failed: " + message)
  }
}

///|
test "test_parse_int_valid" {
  match parse_int("34") {
    Ok(v) => inspect(v, content="34")
    Err(message) => fail("parse_int failed: " + message)
  }
  match parse_int("0") {
    Ok(v) => inspect(v, content="0")
    Err(message) => fail("parse_int failed: " + message)
  }
}

///|
test "test_parse_int_invalid" {
  assert_true(parse_int("").is_err())
  assert_true(parse_int("abc").is_err())
  assert_true(parse_int("12.5").is_err())
}

///|
test "test_resolve_build_roots_uses_cli_options" {
  let options : BuildCommandOptions = {
    app_config_path: None,
    workspace_root: "/repo",
    moui_root: "/custom/moui",
    skia_root: "/custom/skia",
    build_dir: "",
    output: None,
    renderer: None,
    fallback_skia: false,
    ejected_shell: false,
    prepare_only: false,
    android_project: None,
    xcode_project: None,
    scheme: None,
    product_name: None,
    harmonyos_project: None,
    abi: None,
    compile_sdk: None,
    target_sdk: None,
    sdk: None,
    arch: None,
    deployment_target: None,
    sdk_home: None,
    hvigorw: None,
    ohpm: None,
    signing_config_file: None,
  }
  let config = default_cli_config()
  let (moui_root, skia_root) = resolve_build_roots(options, config)
  inspect(moui_root, content="/custom/moui")
  inspect(skia_root, content="/custom/skia")
}

///|
test "test_resolve_build_roots_falls_back_to_config" {
  let options : BuildCommandOptions = {
    app_config_path: None,
    workspace_root: "/repo",
    moui_root: "",
    skia_root: "",
    build_dir: "",
    output: None,
    renderer: None,
    fallback_skia: false,
    ejected_shell: false,
    prepare_only: false,
    android_project: None,
    xcode_project: None,
    scheme: None,
    product_name: None,
    harmonyos_project: None,
    abi: None,
    compile_sdk: None,
    target_sdk: None,
    sdk: None,
    arch: None,
    deployment_target: None,
    sdk_home: None,
    hvigorw: None,
    ohpm: None,
    signing_config_file: None,
  }
  let config = {
    ..default_cli_config(),
    paths: {
      moon_home: None,
      moui_root: Some("/config/moui"),
      skia_root: Some("/config/skia"),
    },
  }
  let (moui_root, skia_root) = resolve_build_roots(options, config)
  inspect(moui_root, content="/config/moui")
  inspect(skia_root, content="/config/skia")
}

///|
test "test_resolve_build_roots_defaults_to_workspace_subdirs" {
  let options : BuildCommandOptions = {
    app_config_path: None,
    workspace_root: "/repo",
    moui_root: "",
    skia_root: "",
    build_dir: "",
    output: None,
    renderer: None,
    fallback_skia: false,
    ejected_shell: false,
    prepare_only: false,
    android_project: None,
    xcode_project: None,
    scheme: None,
    product_name: None,
    harmonyos_project: None,
    abi: None,
    compile_sdk: None,
    target_sdk: None,
    sdk: None,
    arch: None,
    deployment_target: None,
    sdk_home: None,
    hvigorw: None,
    ohpm: None,
    signing_config_file: None,
  }
  let config = default_cli_config()
  let (moui_root, skia_root) = resolve_build_roots(options, config)
  // Path separator is '/' on Linux/macOS; on Windows the join uses '\'
  // but `join_path` always emits '/' in our impl.
  assert_true(moui_root.contains("moui"))
  assert_true(skia_root.contains("moui_skia"))
}

///|
test "test_default_build_dir_format" {
  let path = default_build_dir("android", "/repo")
  inspect(path, content="/repo/artifacts/android")
}

///|
test "test_build_android_options_from_command_uses_defaults" {
  let app : ShellApp = {
    id: "showcase",
    display_name: "Showcase",
    artifact_name: "showcase",
    app_package: "app",
    schema_version: 1,
    shell_api_version: 1,
    embedding_api_version: 1,
    shell: default_shell_for_test(),
    metadata_path: "",
    plugins: [],
    android: None,
    ios: None,
    harmonyos: None,
  }
  let options : BuildCommandOptions = {
    app_config_path: None,
    workspace_root: "/repo",
    moui_root: "/repo/moui",
    skia_root: "/repo/moui_skia",
    build_dir: "",
    output: None,
    renderer: None,
    fallback_skia: false,
    ejected_shell: false,
    prepare_only: false,
    android_project: None,
    xcode_project: None,
    scheme: None,
    product_name: None,
    harmonyos_project: None,
    abi: None,
    compile_sdk: None,
    target_sdk: None,
    sdk: None,
    arch: None,
    deployment_target: None,
    sdk_home: None,
    hvigorw: None,
    ohpm: None,
    signing_config_file: None,
  }
  let config = default_cli_config()
  let android_options = build_android_options_from_command(options, app, config)
  inspect(android_options.workspace_root, content="/repo")
  inspect(android_options.moui_root, content="/repo/moui")
  inspect(android_options.skia_root, content="/repo/moui_skia")
  inspect(android_options.build_dir, content="/repo/artifacts/android")
  inspect(
    android_options.output_apk,
    content="/repo/artifacts/android/showcase.apk",
  )
  inspect(android_options.abi, content="arm64-v8a")
  inspect(android_options.compile_sdk, content="34")
  inspect(android_options.target_sdk, content="34")
  inspect(android_options.renderer, content="auto")
  inspect(android_options.app_config, content="shell.json")
}

///|
test "test_build_ios_options_from_command_uses_defaults" {
  let app : ShellApp = {
    id: "demo",
    display_name: "Demo",
    artifact_name: "demo",
    app_package: "app",
    schema_version: 1,
    shell_api_version: 1,
    embedding_api_version: 1,
    shell: default_shell_for_test(),
    metadata_path: "",
    plugins: [],
    android: None,
    ios: None,
    harmonyos: None,
  }
  let options : BuildCommandOptions = {
    app_config_path: Some("/tmp/shell.json"),
    workspace_root: "/repo",
    moui_root: "/repo/moui",
    skia_root: "/repo/moui_skia",
    build_dir: "",
    output: None,
    renderer: None,
    fallback_skia: false,
    ejected_shell: false,
    prepare_only: false,
    android_project: None,
    xcode_project: None,
    scheme: None,
    product_name: None,
    harmonyos_project: None,
    abi: None,
    compile_sdk: None,
    target_sdk: None,
    sdk: None,
    arch: None,
    deployment_target: None,
    sdk_home: None,
    hvigorw: None,
    ohpm: None,
    signing_config_file: None,
  }
  let config = default_cli_config()
  let ios_options = build_ios_options_from_command(options, app, config)
  inspect(ios_options.build_dir, content="/repo/artifacts/ios")
  inspect(ios_options.output_app, content="/repo/artifacts/ios/demo.app")
  inspect(ios_options.sdk, content="iphoneos")
  inspect(ios_options.arch, content="arm64")
  inspect(ios_options.deployment_target, content="None")
  inspect(ios_options.renderer, content="auto")
  inspect(ios_options.app_config, content="/tmp/shell.json")
}

///|
test "test_build_harmonyos_options_from_command_uses_defaults" {
  let app : ShellApp = {
    id: "demo",
    display_name: "Demo",
    artifact_name: "demo",
    app_package: "app",
    schema_version: 1,
    shell_api_version: 1,
    embedding_api_version: 1,
    shell: default_shell_for_test(),
    metadata_path: "",
    plugins: [],
    android: None,
    ios: None,
    harmonyos: None,
  }
  let options : BuildCommandOptions = {
    app_config_path: None,
    workspace_root: "/repo",
    moui_root: "/repo/moui",
    skia_root: "/repo/moui_skia",
    build_dir: "",
    output: None,
    renderer: None,
    fallback_skia: false,
    ejected_shell: false,
    prepare_only: false,
    android_project: None,
    xcode_project: None,
    scheme: None,
    product_name: None,
    harmonyos_project: None,
    abi: None,
    compile_sdk: None,
    target_sdk: None,
    sdk: None,
    arch: None,
    deployment_target: None,
    sdk_home: None,
    hvigorw: None,
    ohpm: None,
    signing_config_file: None,
  }
  let config = default_cli_config()
  let harmonyos_options = build_harmonyos_options_from_command(
    options, app, config,
  )
  inspect(harmonyos_options.build_dir, content="/repo/artifacts/harmonyos")
  inspect(
    harmonyos_options.output_hap,
    content="/repo/artifacts/harmonyos/demo.hap",
  )
  inspect(harmonyos_options.arch, content="arm64")
  inspect(harmonyos_options.renderer, content="auto")
  inspect(harmonyos_options.sdk_home, content="None")
  inspect(harmonyos_options.hvigorw, content="None")
}
