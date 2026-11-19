// White-box tests for tools/moui/generate_repo_docs decision logic.
// They pin markdown escaping, catalog path hygiene, moon.work member parsing,
// platform fact statuses, and the embedded runtime contract gates.

///|
fn mobile_facts(
  platform~ : String = "android",
  host_kind~ : String = "window-hosted-android",
  source_status~ : String = "passed",
  source_fact_statuses~ : Array[String] = ["passed"],
  source_verified_on~ : String = "2026-05-01",
  source_matrix_command~ : String = "moui build android",
  renderer_status~ : String = "partial",
  runtime_status~ : String = "partial",
  declared~ : String = "vulkan",
  actual~ : String = "unverified",
  evidence_status~ : String = "unverified",
  evidence_kind~ : String = "none",
  evidence_reference~ : String = "artifacts/android/presenter.md",
) -> MobilePlatformContractFacts {
  {
    platform,
    source_status,
    source_fact_statuses,
    source_verified_on,
    source_matrix_command,
    renderer_status,
    runtime_status,
    host_kind,
    declared_presenter_route: declared,
    actual_presenter_route: actual,
    presenter_evidence_status: evidence_status,
    presenter_evidence_kind: evidence_kind,
    presenter_evidence_reference: evidence_reference,
  }
}

///|
test "parse_cli requires exactly one write/check mode" {
  match parse_cli(["--help"]) {
    Ok(options) => {
      assert_true(options.help)
      assert_eq(options.mode, "")
      assert_eq(options.api_report, "checks/api-surface-report.json")
    }
    Err(message) => fail(message)
  }
  match parse_cli([]) {
    Ok(_) => fail("missing mode must be rejected")
    Err(message) =>
      assert_eq(message, "choose exactly one of --write or --check")
  }
  match parse_cli(["--write", "--check"]) {
    Ok(_) => fail("conflicting modes must be rejected")
    Err(message) =>
      assert_eq(message, "choose exactly one of --write or --check")
  }
  match parse_cli(["--write", "--api-report"]) {
    Ok(_) => fail("missing --api-report value must be rejected")
    Err(message) => assert_eq(message, "missing value for --api-report")
  }
  match parse_cli(["--write", "--wat"]) {
    Ok(_) => fail("unknown option must be rejected")
    Err(message) => assert_eq(message, "unknown argument: --wat")
  }
}

///|
test "markdown_cell escapes pipes and folds newlines" {
  assert_eq(markdown_cell("a|b\nc"), "a\\|b c")
  assert_eq(markdown_cell("plain"), "plain")
}

///|
test "catalog_example_path keeps example paths inside the catalog root" {
  assert_true(catalog_example_path("examples/counter/app"))
  assert_true(catalog_example_path("examples/hello"))
  assert_false(catalog_example_path("counter/app"))
  assert_false(catalog_example_path("examples/counter/../secret"))
  assert_false(catalog_example_path("examples/counter/.."))
  assert_false(catalog_example_path("examples\\counter"))
  assert_false(catalog_example_path("examples/C:/counter"))
}

///|
test "workspace_members parses the moon.work members array" {
  let text =
    #|members = [
    #|  "./moui",
    #|  "./examples/counter",
    #|  # local dev
    #|]
  match workspace_members(text) {
    Ok(members) => assert_eq(members, ["./moui", "./examples/counter"])
    Err(message) => fail(message)
  }
  match workspace_members("members = [\n  abc\n]") {
    Ok(_) => fail("unquoted member must be rejected")
    Err(message) =>
      assert_eq(message, "moon.work contains an invalid members entry: abc")
  }
  match workspace_members("members = [\n  \"./a\"") {
    Ok(_) => fail("unclosed members array must be rejected")
    Err(message) => assert_eq(message, "moon.work members array is not closed")
  }
  match workspace_members("other = 1") {
    Ok(_) => fail("missing members array must be rejected")
    Err(message) => assert_eq(message, "moon.work members array is missing")
  }
}

///|
test "platform_fact_status only accepts passed, partial, or failed" {
  match
    platform_fact_status(Some(Json::string("passed")), "checks/p.json.source") {
    Ok(status) => assert_eq(status, "passed")
    Err(message) => fail(message)
  }
  match
    platform_fact_status(Some(Json::string("done")), "checks/p.json.source") {
    Ok(_) => fail("unknown status must be rejected")
    Err(message) =>
      assert_eq(
        message, "checks/p.json.source must be passed, partial, or failed",
      )
  }
  match platform_fact_status(None, "checks/p.json.source") {
    Ok(_) => fail("missing status must be rejected")
    Err(message) =>
      assert_eq(message, "checks/p.json.source must be a non-empty string")
  }
}

///|
test "embedded_runtime_host_kind maps only embedded platforms" {
  assert_eq(
    embedded_runtime_host_kind("android"),
    Some("window-hosted-android"),
  )
  assert_eq(embedded_runtime_host_kind("ios"), Some("window-hosted-ios"))
  assert_eq(
    embedded_runtime_host_kind("harmonyos"),
    Some("window-hosted-harmonyos"),
  )
  assert_eq(embedded_runtime_host_kind("windows"), None)
}

///|
test "mobile platform contract requires the matching host kind" {
  match validate_mobile_platform_contract(mobile_facts(), "android.platform") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    validate_mobile_platform_contract(
      mobile_facts(platform="windows", host_kind="native"),
      "windows.platform",
    ) {
    Ok(_) => ()
    Err(message) => fail("non-embedded platform must pass: " + message)
  }
  match
    validate_mobile_platform_contract(
      mobile_facts(host_kind="window-hosted-ios"),
      "android.platform",
    ) {
    Ok(_) => fail("wrong host kind must be rejected")
    Err(message) =>
      assert_eq(
        message, "android.platform.hostKind must be window-hosted-android for android",
      )
  }
  match
    validate_mobile_platform_contract(
      mobile_facts(source_status="partial"),
      "android.platform",
    ) {
    Ok(_) => fail("source status aggregate mismatch must be rejected")
    Err(message) =>
      assert_eq(
        message, "android.platform.sourceBuild.status must aggregate windowHosted as passed",
      )
  }
}

///|
test "mobile platform contract gates the actual presenter route" {
  let verified = mobile_facts(
    declared="metal",
    actual="metal",
    evidence_status="verified",
    evidence_kind="matching-device-direct-present",
  )
  match validate_mobile_platform_contract(verified, "android.platform") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    validate_mobile_platform_contract(
      mobile_facts(
        declared="vulkan",
        actual="metal",
        evidence_status="verified",
        evidence_kind="matching-device-direct-present",
      ),
      "android.platform",
    ) {
    Ok(_) => fail("verified route mismatch must be rejected")
    Err(message) =>
      assert_eq(
        message, "android.platform: actual presenter route must match the declared renderer route",
      )
  }
  match
    validate_mobile_platform_contract(
      mobile_facts(
        renderer_status="passed",
        evidence_reference="artifacts/android/presenter.md",
      ),
      "android.platform",
    ) {
    Ok(_) => fail("renderer pass with unverified route must be rejected")
    Err(message) =>
      assert_eq(
        message, "android.platform: rendererL2 cannot pass with an unverified actual presenter route",
      )
  }
}
