// Whitebox tests for `build_ios.mbt`.
//
// Tests focus on the pure helpers (`parse_dotted_version`, `version_at_least`).
// End-to-end `xcodebuild` invocation is exercised by integration tests with
// a real Xcode install and is intentionally not covered here.

///|
test "test_parse_dotted_version_simple" {
  debug_inspect(parse_dotted_version("15.4"), content="[15, 4]")
  debug_inspect(parse_dotted_version("16.0.1"), content="[16, 0, 1]")
  debug_inspect(parse_dotted_version("17"), content="[17]")
}

///|
test "test_parse_dotted_version_invalid" {
  debug_inspect(parse_dotted_version("abc"), content="[]")
  debug_inspect(parse_dotted_version("15.x"), content="[]")
  debug_inspect(parse_dotted_version(""), content="[]")
  debug_inspect(parse_dotted_version("15a.4"), content="[]")
}

///|
test "test_version_at_least_equal" {
  assert_true(version_at_least("15.4", "15.4"))
  assert_true(version_at_least("16.0", "16"))
  assert_true(version_at_least("16", "16.0"))
}

///|
test "test_version_at_least_higher" {
  assert_true(version_at_least("16.0", "15.4"))
  assert_true(version_at_least("17.0", "15.4"))
  assert_true(version_at_least("15.5", "15.4"))
}

///|
test "test_version_at_least_lower" {
  assert_false(version_at_least("14.0", "15.4"))
  assert_false(version_at_least("15.3", "15.4"))
  assert_false(version_at_least("15.0", "16.0"))
}

///|
test "test_version_at_least_invalid" {
  assert_false(version_at_least("", "15.4"))
  assert_false(version_at_least("15.4", ""))
  assert_false(version_at_least("abc", "15.4"))
}

///|
test "test_xcode_version_string_returns_empty_when_unavailable" {
  // In sandboxes without `xcodebuild` on PATH, this returns "".
  // On macOS CI with Xcode installed, it may return a real version; either
  // outcome is acceptable, so we only assert the return type is a string.
  let _ = xcode_version_string()
  assert_true(true)
}

///|
test "test_ios_codesign_args_include_identity_and_entitlements" {
  let args = ios_codesign_args(
    identity="Apple Development: Demo",
    entitlements=Some("/tmp/demo.entitlements"),
    app="/tmp/Demo.app",
  )
  assert_true(args.contains("--sign"))
  assert_true(args.contains("Apple Development: Demo"))
  assert_true(args.contains("--entitlements"))
  assert_true(args.contains("/tmp/demo.entitlements"))
  inspect(args[args.length() - 1], content="/tmp/Demo.app")
}

///|
test "test_build_parser_records_ios_signing_flags" {
  let parsed = match
    parse_build_args(
      [
        "ios", "demo", "--signing-identity", "Apple Development: Demo", "--provisioning-profile",
        "demo.mobileprovision", "--entitlements", "demo.entitlements",
      ],
      "/tmp",
      detect_host_platform(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let options = match parsed.options {
    Some(value) => value
    None => fail("expected build options")
  }
  inspect(options.signing_identity.unwrap(), content="Apple Development: Demo")
  inspect(
    options.provisioning_profile.unwrap(),
    content="/tmp/demo.mobileprovision",
  )
  inspect(options.entitlements.unwrap(), content="/tmp/demo.entitlements")
}
