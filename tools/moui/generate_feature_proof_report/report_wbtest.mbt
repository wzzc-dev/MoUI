///|
/// White-box tests for the report construction rules in
/// `generate_feature_proof_report`: status lookup/validation, L1-vs-L2
/// proven/gap/skipped accounting, and the Markdown failure summary.

///|
fn report_status_map(job_status : String) -> Map[String, String] {
  let statuses : Map[String, String] = Map([])
  for item in l1_features() {
    statuses[item.job] = job_status
  }
  for job in l2_jobs() {
    statuses[job] = job_status
  }
  statuses
}

///|
test "lookup_job_status reports missing jobs instead of fabricating a status" {
  let statuses : Map[String, String] = Map([])
  statuses["pr-profile"] = "success"
  assert_eq(lookup_job_status(statuses, "pr-profile"), "success")
  assert_eq(lookup_job_status(statuses, "linux-platform"), "missing")
}

///|
test "parse_status_map accepts only an object of string statuses" {
  match parse_status_map("{\"pr-profile\":\"success\"}") {
    Ok(statuses) =>
      assert_eq(lookup_job_status(statuses, "pr-profile"), "success")
    Err(message) => fail(message)
  }
  match parse_status_map("not json") {
    Ok(_) => fail("invalid JSON must be rejected")
    Err(message) =>
      assert_eq(message, "Failed to parse --status JSON: invalid JSON")
  }
  match parse_status_map("[]") {
    Ok(_) => fail("non-object JSON must be rejected")
    Err(message) =>
      assert_eq(message, "Failed to parse --status JSON: expected object")
  }
  match parse_status_map("{\"pr-profile\":1}") {
    Ok(_) => fail("non-string statuses must be rejected")
    Err(message) =>
      assert_eq(
        message, "Failed to parse --status JSON: values must be strings",
      )
  }
}

///|
test "build_report counts L1 and L2 features as proven when all jobs pass" {
  let report = build_report(
    report_status_map("success"),
    "https://ci/run/1",
    "2026-11-18T00:00:00Z",
  )
  assert_eq(report.features.length(), 29)
  assert_eq(report.proven, 29)
  assert_eq(report.gap, 0)
  assert_eq(report.skipped, 0)
}

///|
test "build_report marks failed L2 platforms as gaps" {
  let statuses = report_status_map("success")
  statuses["linux-real-skia"] = "failed"
  let report = build_report(statuses, "", "2026-11-18T00:00:00Z")
  assert_eq(report.proven, 12)
  assert_eq(report.gap, 17)
  let mut failed_l2 = 0
  for feature in report.features {
    if feature.level == "L2" && feature.category_status == "failed" {
      failed_l2 += 1
    }
  }
  assert_eq(failed_l2, 17)
}

///|
test "build_report treats all-missing L2 jobs as proven-but-skipped" {
  // No statuses at all: every job resolves to "missing", so L2 rows are
  // rewritten to skipped while L1 rows stay unproven.
  let report = build_report(Map([]), "", "2026-11-18T00:00:00Z")
  assert_eq(report.proven, 17)
  assert_eq(report.gap, 12)
  let mut skipped_jobs = 0
  for feature in report.features {
    if feature.level == "L2" &&
      platform_status(feature, "linux-real-skia") == "skipped" {
      skipped_jobs += 1
    }
  }
  assert_eq(skipped_jobs, 17)
}

///|
test "build_report keeps a macOS-only gap as partial and proven" {
  let statuses = report_status_map("success")
  statuses["macos-real-skia"] = "missing"
  let report = build_report(statuses, "", "2026-11-18T00:00:00Z")
  assert_eq(report.gap, 0)
  let mut partial = 0
  for feature in report.features {
    if feature.level == "L2" && feature.category_status == "partial" {
      partial += 1
    }
  }
  assert_eq(partial, 17)
}

///|
test "report_to_markdown prints the proven and gap totals" {
  let statuses = report_status_map("success")
  statuses["linux-real-skia"] = "failed"
  let text = report_to_markdown(
    build_report(statuses, "", "2026-11-18T00:00:00Z"),
  )
  assert_true(text.contains("- **Total features**: 29"))
  assert_true(text.contains("- **Proven**: 12"))
  assert_true(text.contains("- **Gap**: 17"))
  // The skipped line is only emitted when the report actually has skips.
  assert_false(text.contains("**Skipped**"))
}

///|
test "feature_to_json maps each level onto its documented fields" {
  let l1 : FeatureEntry = {
    feature: "Core API",
    level: "L1",
    proof_job: "pr-profile",
    proof_jobs: [],
    status_text: "success",
    status_map: Map([]),
    proven: true,
    category_status: "",
  }
  match feature_to_json(l1) {
    Json::Object(fields) => {
      match fields.get("level") {
        Some(Json::String(level)) => assert_eq(level, "L1")
        _ => fail("L1 entry must record its level")
      }
      match fields.get("proofJob") {
        Some(Json::String(job)) => assert_eq(job, "pr-profile")
        _ => fail("L1 entry must record the proof job")
      }
      match fields.get("proven") {
        Some(Json::True) => ()
        _ => fail("proven entries must serialize as true")
      }
    }
    _ => fail("feature JSON must be an object")
  }
  let statuses : Map[String, String] = Map([])
  statuses["macos-real-skia"] = "missing"
  statuses["linux-real-skia"] = "failed"
  let l2 : FeatureEntry = {
    feature: "Rect",
    level: "L2",
    proof_job: "",
    proof_jobs: ["macos-real-skia", "linux-real-skia"],
    status_text: "",
    status_map: statuses,
    proven: false,
    category_status: "failed",
  }
  match feature_to_json(l2) {
    Json::Object(fields) =>
      match fields.get("categoryStatus") {
        Some(Json::String(status)) => assert_eq(status, "failed")
        _ => fail("L2 entry must record categoryStatus")
      }
    _ => fail("feature JSON must be an object")
  }
}

///|
test "build_report tolerates push-only jobs skipped on a pull request" {
  let statuses : Map[String, String] = Map([])
  for feature in l1_features() {
    let push_only = feature.job == "macos-packaging" ||
      feature.job == "benchmark-scaffold"
    statuses[feature.job] = if push_only { "skipped" } else { "success" }
  }
  let pr = build_report_with_context(statuses, "", "t", "pull_request", false)
  assert_eq(pr.gap, 0)
  let push = build_report_with_context(statuses, "", "t", "push", false)
  assert_eq(push.gap, 2)
}

///|
test "build_report tolerates native jobs skipped for a docs-only change" {
  let statuses : Map[String, String] = Map([])
  for feature in l1_features() {
    statuses[feature.job] = "skipped"
  }
  statuses["pr-static"] = "success"
  let report = build_report_with_context(statuses, "", "t", "push", true)
  assert_eq(report.gap, 0)
}
