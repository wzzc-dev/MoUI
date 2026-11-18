// White-box tests for feature proof coverage: per-feature L1/L2 decisions,
// platform-status summaries, report shape errors, and CLI parsing.

///|
fn gap_reason(result : Result[CoverageGap?, String]) -> String {
  match result {
    Ok(Some(gap)) => gap.reason
    Ok(None) => "<none>"
    Err(message) => "<error:" + message + ">"
  }
}

///|
fn verify_report_error(text : String) -> String {
  match verify_report_text(text) {
    Err(message) => message
    Ok(_) => "<ok>"
  }
}

///|
fn feature_of(text : String) -> Map[String, Json] {
  let parsed = @json.parse(text) catch { _ => Json::string("") }
  match parsed {
    Json::Object(fields) => fields
    _ => Map([])
  }
}

///|
fn bool_text(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn l1_feature(proven : Bool, status_json : String) -> Map[String, Json] {
  feature_of(
    "{\"feature\":\"gpu\",\"level\":\"L1\",\"proven\":" +
    bool_text(proven) +
    ",\"proofJob\":\"pr-profile\",\"status\":" +
    status_json +
    "}",
  )
}

///|
fn l2_feature(
  proven : Bool,
  category_status : String,
  status_json : String,
) -> Map[String, Json] {
  feature_of(
    "{\"feature\":\"gpu\",\"level\":\"L2\",\"proven\":" +
    bool_text(proven) +
    ",\"categoryStatus\":\"" +
    category_status +
    "\",\"status\":" +
    status_json +
    "}",
  )
}

///|
test "evaluate_feature rejects missing or mistyped fields" {
  assert_eq(
    gap_reason(evaluate_feature(Map([]))),
    "<error:feature.feature must be a string>",
  )
  let no_level : Map[String, Json] = Map([("feature", Json::string("gpu"))])
  assert_eq(
    gap_reason(evaluate_feature(no_level)),
    "<error:feature.level must be a string>",
  )
  let bad_proven : Map[String, Json] = Map([
    ("feature", Json::string("gpu")),
    ("level", Json::string("L1")),
    ("proven", Json::string("yes")),
  ])
  assert_eq(
    gap_reason(evaluate_feature(bad_proven)),
    "<error:feature.proven must be a boolean>",
  )
}

///|
test "L1 gaps name the proof job and stringify platform status" {
  assert_eq(gap_reason(evaluate_feature(l1_feature(true, "{}"))), "<none>")
  assert_eq(
    gap_reason(
      evaluate_feature(
        l1_feature(
          false, "{\"windows\":\"failure\",\"macos\":\"success\",\"linux\":\"timeout\"}",
        ),
      ),
    ),
    "L1 job \"pr-profile\" did not pass (status: {\"windows\":\"failure\",\"macos\":\"success\",\"linux\":\"timeout\"})",
  )
  // L3+ features are out of scope for this gate.
  let l3 = feature_of(
    "{\"feature\":\"devtools\",\"level\":\"L3\",\"proven\":false}",
  )
  assert_eq(gap_reason(evaluate_feature(l3)), "<none>")
}

///|
test "L2 gaps honor skipped, partial-proven, and failing categories" {
  assert_eq(
    gap_reason(evaluate_feature(l2_feature(false, "skipped", "{}"))),
    "<none>",
  )
  assert_eq(
    gap_reason(
      evaluate_feature(l2_feature(true, "partial", "{\"web\":\"failure\"}")),
    ),
    "<none>",
  )
  assert_eq(
    gap_reason(
      evaluate_feature(l2_feature(false, "partial", "{\"macos\":\"failure\"}")),
    ),
    "L2 jobs failed: macos=failure",
  )
  // A passing feature needs no platform summary.
  assert_eq(gap_reason(evaluate_feature(l2_feature(true, "", "{}"))), "<none>")
}

///|
test "verify_report_text enforces report shape and summary counters" {
  assert_eq(verify_report_error("{"), "Failed to read report: invalid JSON")
  assert_eq(verify_report_error("[]"), "report must be an object")
  assert_eq(
    verify_report_error("{\"features\":[]}"),
    "report.summary must be an object",
  )
  assert_eq(
    verify_report_error("{\"features\":[],\"summary\":{\"proven\":1}}"),
    "report.summary.gap must be a number",
  )
  match
    verify_report_text("{\"features\":[],\"summary\":{\"proven\":2,\"gap\":0}}") {
    Ok(result) => {
      assert_eq(result.proven, 2)
      assert_eq(result.gap_count, 0)
      assert_eq(result.skipped, 0)
      assert_eq(result.gaps.length(), 0)
    }
    Err(_) => assert_true(false)
  }
  let unproven = "{\"features\":[{\"feature\":\"gpu\",\"level\":\"L1\",\"proven\":false}],\"summary\":{\"proven\":0,\"gap\":1}}"
  match verify_report_text(unproven) {
    Ok(result) => {
      assert_eq(result.gaps.length(), 1)
      assert_eq(result.gap_count, 1)
      assert_eq(
        result.gaps[0].reason,
        "L1 job \"unknown\" did not pass (status: missing)",
      )
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse_cli requires --report and rejects unknown flags" {
  match parse_cli(["--report", "artifacts/feature-proof.json"]) {
    Ok(path) => assert_eq(path, "artifacts/feature-proof.json")
    Err(_) => assert_true(false)
  }
  match parse_cli([]) {
    Err(message) => assert_eq(message, "missing --report")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--help"]) {
    Err(message) => assert_eq(message, "help")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--report"]) {
    Err(message) => assert_eq(message, "missing value for --report")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--wat"]) {
    Err(message) => assert_eq(message, "Unknown argument: --wat")
    Ok(_) => assert_true(false)
  }
}
