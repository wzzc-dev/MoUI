// Whitebox tests for `doctor_evidence_ready.mbt`.

///|
test "test_evidence_status_show" {
  let status : EvidenceStatus = {
    platform: "android",
    app_id: "demo",
    manifest_path: "/tmp/verify-manifest.json",
    passed: true,
    observations_summary: "27/27 passed",
  }
  inspect(status.platform, content="android")
  inspect(status.app_id, content="demo")
  assert_true(status.passed)
}

///|
test "test_evidence_status_to_text_empty" {
  let statuses : Map[String, EvidenceStatus] = Map([])
  inspect(
    evidence_status_to_text(statuses),
    content="(no verify evidence found)\n",
  )
}

///|
test "test_evidence_status_to_text_with_entries" {
  let statuses : Map[String, EvidenceStatus] = Map([])
  statuses["android:demo"] = {
    platform: "android",
    app_id: "demo",
    manifest_path: "/tmp/m1.json",
    passed: true,
    observations_summary: "27/27 passed",
  }
  statuses["ios:demo"] = {
    platform: "ios",
    app_id: "demo",
    manifest_path: "/tmp/m2.json",
    passed: false,
    observations_summary: "26/27 passed",
  }
  let text = evidence_status_to_text(statuses)
  assert_true(text.contains("[android] demo : passed (27/27 passed)"))
  assert_true(text.contains("[ios] demo : FAILED (26/27 passed)"))
}

///|
test "test_check_evidence_ready_missing_dir_returns_empty" {
  let statuses = check_evidence_ready(
    "/nonexistent/path/for/tests",
    ["android", "ios"],
    detect_host_platform(),
  )
  assert_true(statuses.is_empty())
}

///|
test "test_check_evidence_ready_skips_missing_platforms" {
  let statuses = check_evidence_ready(
    "/nonexistent/path",
    ["android", "ios", "harmonyos"],
    detect_host_platform(),
  )
  assert_true(statuses.is_empty())
}

///|
test "test_read_evidence_manifest_rejects_unknown_generator" {
  // A verify-manifest.json produced by an unknown generator is ignored.
  // We rely on the is_accepted_generated_by helper for the canonical check.
  assert_true(is_accepted_generated_by("moui_cli"))
  assert_true(
    is_accepted_generated_by("scripts/record-shell-runtime-smoke.mjs"),
  )
  assert_false(is_accepted_generated_by("random-tool"))
}
