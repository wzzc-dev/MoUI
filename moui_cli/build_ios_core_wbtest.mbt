// Whitebox tests for `build_ios_core.mbt`.
//
// Tests focus on the pure accessor `BuildIosCoreOptions::output_app` which
// reads the `MOUI_EMBEDDING_OUTPUT_APP` env var. End-to-end clang/clang++/
// swiftc compilation is exercised by integration tests with a real Xcode
// toolchain and is intentionally not covered here.

///|
fn build_ios_core_test_options(output_app_env : String?) -> BuildIosCoreOptions {
  // Build a minimal `BuildIosCoreOptions` for env-var-driven accessor tests.
  // The shell fields are irrelevant for `output_app()` which only inspects
  // `MOUI_EMBEDDING_OUTPUT_APP`.
  let app : ShellApp = {
    id: "counter",
    display_name: "Counter",
    artifact_name: "Counter",
    app_package: "dev.example.counter",
    schema_version: 1,
    shell_api_version: 1,
    embedding_api_version: 1,
    shell: {
      profile: "handheld",
      renderer: "skia-gpu",
      status_bar: "default",
      orientation: "portrait",
      resources: [],
      permissions: [],
      plugins: [],
      fullscreen: false,
      supports_scroll: true,
    },
    metadata_path: "/tmp/counter/shell.json",
    plugins: [],
    android: None,
    ios: None,
    harmonyos: None,
  }
  // Set/unset the env var depending on whether the test wants a value.
  match output_app_env {
    Some(value) => @env.set_env_var("MOUI_EMBEDDING_OUTPUT_APP", value)
    None => @env.unset_env_var("MOUI_EMBEDDING_OUTPUT_APP")
  }
  {
    app,
    app_config: "/tmp/counter/shell.json",
    workspace_root: "/tmp/counter",
    project_root: "/tmp/counter",
    moui_root: "/tmp/moui",
    skia_root: "/tmp/skia",
    sdk: "iphonesimulator",
    arch: "arm64",
    deployment_target: "15.0",
    renderer: "skia-gpu",
    fallback_skia: false,
    shell_mode: "managed",
    build_dir: "/tmp/counter/build",
    target_build_dir: None,
    full_product_name: None,
    resolved_swift: None,
    resolved_manifest: None,
    env: [],
  }
}

///|
test "test_build_ios_core_options_output_app_reads_env" {
  let options = build_ios_core_test_options(Some("/tmp/out/Counter.app"))
  inspect(options.output_app(), content="/tmp/out/Counter.app")
  @env.unset_env_var("MOUI_EMBEDDING_OUTPUT_APP")
}

///|
test "test_build_ios_core_options_output_app_returns_empty_when_env_unset" {
  let options = build_ios_core_test_options(None)
  inspect(options.output_app(), content="")
}

///|
test "test_parse_dotted_version_works_for_deployment_target" {
  // Re-affirm the parser used to validate deployment_target >= 15 in
  // build_ios_core. "15.0" -> [15, 0]; major[0] = 15 >= 15 must pass.
  let parsed = parse_dotted_version("15.0")
  inspect(parsed, content="[15, 0]")
  assert_true(parsed[0] >= 15)
  let parsed_legacy = parse_dotted_version("14.5")
  inspect(parsed_legacy, content="[14, 5]")
  assert_false(parsed_legacy[0] >= 15)
}
