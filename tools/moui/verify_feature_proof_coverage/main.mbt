///|
struct CoverageGap {
  feature : String
  level : String
  reason : String
}

///|
struct CoverageResult {
  gaps : Array[CoverageGap]
  proven : Int
  gap_count : Int
  skipped : Int
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/verify_feature_proof_coverage --report <path>
    #|
    #|Validates a feature proof report JSON for unproven L1/L2 features.
    #|
  )
}

///|
fn status_string(value : Json) -> String {
  match value {
    Json::String(text) => text
    other => other.stringify()
  }
}

///|
fn failed_platform_summary(status : Json) -> String {
  match status {
    Json::Object(fields) => {
      let parts : Array[String] = []
      for key in @tools.sorted_map_keys(fields) {
        let value = status_string(fields[key])
        if value != "success" {
          parts.push(key + "=" + value)
        }
      }
      parts.join(", ")
    }
    other => status_string(other)
  }
}

///|
fn evaluate_feature(
  feature_obj : Map[String, Json],
) -> Result[CoverageGap?, String] {
  let feature = match feature_obj.get("feature") {
    Some(Json::String(text)) => text
    _ => return Err("feature.feature must be a string")
  }
  let level = match feature_obj.get("level") {
    Some(Json::String(text)) => text
    _ => return Err("feature.level must be a string")
  }
  let proven = match feature_obj.get("proven") {
    Some(Json::True) => true
    Some(Json::False) => false
    _ => return Err("feature.proven must be a boolean")
  }
  if level == "L1" {
    if proven {
      Ok(None)
    } else {
      let proof_job = match feature_obj.get("proofJob") {
        Some(Json::String(text)) => text
        _ => "unknown"
      }
      let status = match feature_obj.get("status") {
        Some(value) => status_string(value)
        None => "missing"
      }
      Ok(
        Some(
          {
            feature,
            level,
            reason: "L1 job \"" +
            proof_job +
            "\" did not pass (status: " +
            status +
            ")",
          },
        ),
      )
    }
  } else if level == "L2" {
    let category_status = match feature_obj.get("categoryStatus") {
      Some(Json::String(text)) => text
      _ => ""
    }
    if category_status == "skipped" {
      Ok(None)
    } else if category_status == "partial" && proven {
      Ok(None)
    } else if proven {
      Ok(None)
    } else {
      let status = match feature_obj.get("status") {
        Some(value) => value
        None => Json::string("missing")
      }
      Ok(
        Some(
          {
            feature,
            level,
            reason: "L2 jobs failed: " + failed_platform_summary(status),
          },
        ),
      )
    }
  } else {
    Ok(None)
  }
}

///|
fn verify_report_json(report : Json) -> Result[CoverageResult, String] {
  let root = match report {
    Json::Object(fields) => fields
    _ => return Err("report must be an object")
  }
  let features = match root.get("features") {
    Some(Json::Array(values)) => values
    _ => return Err("report.features must be an array")
  }
  let gaps : Array[CoverageGap] = []
  for feature_value in features {
    let feature_obj = match feature_value {
      Json::Object(fields) => fields
      _ => return Err("report.features entries must be objects")
    }
    match evaluate_feature(feature_obj) {
      Ok(None) => ()
      Ok(Some(gap)) => gaps.push(gap)
      Err(message) => return Err(message)
    }
  }
  let summary = match root.get("summary") {
    Some(Json::Object(fields)) => fields
    _ => return Err("report.summary must be an object")
  }
  let proven = match summary.get("proven") {
    Some(Json::Number(number, repr=_)) => number.to_int()
    _ => return Err("report.summary.proven must be a number")
  }
  let gap_count = match summary.get("gap") {
    Some(Json::Number(number, repr=_)) => number.to_int()
    _ => return Err("report.summary.gap must be a number")
  }
  let skipped = match summary.get("skipped") {
    Some(Json::Number(number, repr=_)) => number.to_int()
    None => 0
    _ => return Err("report.summary.skipped must be a number when present")
  }
  Ok({ gaps, proven, gap_count, skipped })
}

///|
fn verify_report_text(text : String) -> Result[CoverageResult, String] {
  let report = @json.parse(text) catch {
    _ => return Err("Failed to read report: invalid JSON")
  }
  verify_report_json(report)
}

///|
fn parse_cli(args : Array[String]) -> Result[String, String] {
  let mut report_path = ""
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => return Err("help")
      "--report" => {
        if index + 1 >= args.length() {
          return Err("missing value for --report")
        }
        report_path = args[index + 1]
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  if report_path == "" {
    Err("missing --report")
  } else {
    Ok(report_path)
  }
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Err("help") | Err("missing --report") => {
      println(usage())
      2
    }
    Err(message) => {
      println(message)
      println(usage())
      2
    }
    Ok(report_path) => {
      let text = match
        @tools.read_required_text(report_path, "feature proof report") {
        Ok(value) => value
        Err(message) => {
          println("Failed to read report: " + message)
          return 2
        }
      }
      match verify_report_text(text) {
        Err(message) => {
          println(message)
          2
        }
        Ok(result) =>
          if result.gaps.length() > 0 {
            println("Feature proof coverage verification FAILED.")
            println("")
            println("Unproven features:")
            for gap in result.gaps {
              println(
                "  - [" + gap.level + "] " + gap.feature + ": " + gap.reason,
              )
            }
            println("")
            println("Total gaps: " + result.gaps.length().to_string())
            1
          } else {
            println("Feature proof coverage verification PASSED.")
            let skipped_msg = if result.skipped > 0 {
              ", Skipped: " + result.skipped.to_string()
            } else {
              ""
            }
            println(
              "  Proven: " +
              result.proven.to_string() +
              ", Gap: " +
              result.gap_count.to_string() +
              skipped_msg,
            )
            0
          }
      }
    }
  }
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
