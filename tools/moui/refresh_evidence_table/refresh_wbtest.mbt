// White-box tests for tools/moui/refresh_evidence_table decision logic.
// They pin table-row rendering, payload field fallbacks, the dry-run template,
// and CLI validation.

///|
fn sample_run() -> EvidenceRun {
  {
    id: "42",
    head_sha: "abc123",
    created_at: "2026-01-02T03:04:05Z",
    html_url: "https://example.test/runs/42",
  }
}

///|
fn sample_details() -> EvidenceDetails {
  { successful_jobs: ["build", "test"], artifacts: ["logs", "coverage"], }
}

///|
test "generate_table_row renders the markdown row and boundary" {
  let row = generate_table_row(sample_run(), sample_details())
  assert_eq(row.workflow, "MoUI CI")
  assert_eq(row.run, "[42](https://example.test/runs/42)")
  assert_eq(row.key_successful_jobs, "build, test")
  assert_eq(row.uploaded_artifact_names, "logs, coverage")
  assert_eq(row.evidence_boundary, "Proves CI run 42 for head SHA `abc123`.")
  assert_eq(
    row.markdown,
    "| MoUI CI | [42](https://example.test/runs/42) | build, test | logs, coverage | Proves CI run 42 for head SHA `abc123`. |",
  )
}

///|
test "parse_run_payload applies field fallbacks and filters job names" {
  let text =
    #|{"run_id":7,"head_sha":"deadbeef","created_at":"2026-02-03T00:00:00Z",
    #|"url":"https://example.test/r/7","successful_jobs":["build",9,"test"],
    #|"artifacts":["logs"]}
  match parse_run_payload(text) {
    Ok((run, details, mode)) => {
      assert_eq(run.id, "7")
      assert_eq(run.head_sha, "deadbeef")
      assert_eq(run.created_at, "2026-02-03T00:00:00Z")
      assert_eq(run.html_url, "https://example.test/r/7")
      assert_eq(details.successful_jobs, ["build", "test"])
      assert_eq(details.artifacts, ["logs"])
      assert_eq(mode, "live")
    }
    Err(message) => fail(message)
  }
  let explicit =
    #|{"run_id":"9","head_sha":"cafe","date":"2026-03-04T00:00:00Z",
    #|"html_url":"https://example.test/r/9","mode":"gh-cli"}
  match parse_run_payload(explicit) {
    Ok((run, details, mode)) => {
      assert_eq(run.created_at, "2026-03-04T00:00:00Z")
      assert_eq(mode, "gh-cli")
      assert_eq(details.successful_jobs, [])
      assert_eq(details.artifacts, [])
    }
    Err(message) => fail(message)
  }
}

///|
test "parse_run_payload reports precise payload errors" {
  match parse_run_payload("{") {
    Ok(_) => fail("invalid JSON must be rejected")
    Err(message) => assert_eq(message, "payload contains invalid JSON")
  }
  match parse_run_payload("[]") {
    Ok(_) => fail("array root must be rejected")
    Err(message) => assert_eq(message, "payload must be a JSON object")
  }
  match parse_run_payload("{\"head_sha\":\"a\"}") {
    Ok(_) => fail("missing run_id must be rejected")
    Err(message) => assert_eq(message, "missing string field 'run_id'")
  }
  match parse_run_payload("{\"run_id\":\"1\"}") {
    Ok(_) => fail("missing head_sha must be rejected")
    Err(message) => assert_eq(message, "missing string field 'head_sha'")
  }
  match parse_run_payload("{\"run_id\":\"1\",\"head_sha\":\"a\"}") {
    Ok(_) => fail("missing run URL must be rejected")
    Err(message) => assert_eq(message, "missing string field 'url'")
  }
}

///|
test "parse_cli collects evidence options and reports errors" {
  match
    parse_cli(["--mode", "gh-cli", "--payload", "{}", "--dry-run", "--no-token"]) {
    Ok(options) => {
      assert_eq(options.mode, "gh-cli")
      assert_eq(options.payload, "{}")
      assert_true(options.dry_run)
      assert_true(options.no_token)
      assert_false(options.help)
      assert_eq(options.payload_file, "")
    }
    Err(message) => fail(message)
  }
  match parse_cli([]) {
    Ok(options) => assert_eq(options.mode, "live")
    Err(message) => fail(message)
  }
  match parse_cli(["--help"]) {
    Ok(options) => assert_true(options.help)
    Err(message) => fail(message)
  }
  match parse_cli(["--mode"]) {
    Ok(_) => fail("missing --mode value must be rejected")
    Err(message) => assert_eq(message, "missing value for --mode")
  }
  match parse_cli(["--payload-file"]) {
    Ok(_) => fail("missing --payload-file value must be rejected")
    Err(message) => assert_eq(message, "missing value for --payload-file")
  }
  match parse_cli(["--wat"]) {
    Ok(_) => fail("unknown option must be rejected")
    Err(message) => assert_eq(message, "Unknown argument: --wat")
  }
}

///|
test "dry_run_template advertises the missing-token fallback" {
  match dry_run_template("no-token") {
    Json::Object(root) => {
      match root.get("mode") {
        Some(Json::String(mode)) => assert_eq(mode, "no-token")
        _ => fail("mode must be a string")
      }
      match root.get("template") {
        Some(Json::Object(template)) => {
          match template.get("run") {
            Some(Json::String(run)) => assert_eq(run, "[<run-id>](<run-url>)")
            _ => fail("template.run must be a string")
          }
          match template.get("evidence_boundary") {
            Some(Json::String(boundary)) =>
              assert_true(boundary.contains("Manual review required."))
            _ => fail("template.evidence_boundary must be a string")
          }
        }
        _ => fail("template must be an object")
      }
    }
    _ => fail("dry-run output must be an object")
  }
}

///|
test "live_report_json echoes the selected mode and row fields" {
  match live_report_json("gh-cli", sample_run(), sample_details()) {
    Json::Object(root) => {
      match root.get("mode") {
        Some(Json::String(mode)) => assert_eq(mode, "gh-cli")
        _ => fail("mode must be a string")
      }
      match root.get("run_id") {
        Some(Json::String(id)) => assert_eq(id, "42")
        _ => fail("run_id must be a string")
      }
      match root.get("markdown") {
        Some(Json::String(markdown)) =>
          assert_eq(
            markdown, "| MoUI CI | [42](https://example.test/runs/42) | build, test | logs, coverage | Proves CI run 42 for head SHA `abc123`. |",
          )
        _ => fail("markdown must be a string")
      }
    }
    _ => fail("live report must be an object")
  }
}
