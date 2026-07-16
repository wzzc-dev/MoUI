///|
fn sample_report(
  l1_status~ : String = "success",
  l2_category~ : String = "success",
  l2_proven~ : Bool = true,
) -> String {
  let l1_proven = l1_status == "success"
  let object : Map[String, Json] = Map([])
  object["features"] = Json::array(
    [
      {
        "feature": Json::string("Core API"),
        "level": Json::string("L1"),
        "proofJob": Json::string("pr-profile"),
        "status": Json::string(l1_status),
        "proven": Json::boolean(l1_proven),
      },
      {
        "feature": Json::string("Rect"),
        "level": Json::string("L2"),
        "proofJobs": Json::array(
          [
            Json::string("macos-real-skia"),
            Json::string("linux-real-skia"),
            Json::string("windows-real-skia"),
          ],
        ),
        "status": {
          "macos-real-skia": Json::string("success"),
          "linux-real-skia": Json::string("success"),
          "windows-real-skia": Json::string("failed"),
        },
        "proven": Json::boolean(l2_proven),
        "categoryStatus": Json::string(l2_category),
      },
    ],
  )
  object["summary"] = {
    "totalFeatures": Json::number(2.0, repr="2"),
    "proven": Json::number(1.0, repr="1"),
    "gap": Json::number(1.0, repr="1"),
    "skipped": Json::number(0.0, repr="0"),
  }
  Json::object(object).stringify()
}

///|
test "passes when all features are proven" {
  let text =
    (
      {
        "features": [
          {
            "feature": "Core API",
            "level": "L1",
            "proofJob": "pr-profile",
            "status": "success",
            "proven": true,
          },
          {
            "feature": "Rect",
            "level": "L2",
            "status": {
              "macos-real-skia": "skipped",
              "linux-real-skia": "success",
              "windows-real-skia": "success",
            },
            "proven": true,
            "categoryStatus": "partial",
          },
        ],
        "summary": { "totalFeatures": 2, "proven": 2, "gap": 0, "skipped": 0 },
      } : Json
    ).stringify()
  match verify_report_text(text) {
    Ok(result) => {
      debug_inspect(result.gaps.length(), content="0")
      debug_inspect(result.proven, content="2")
    }
    Err(message) => fail(message)
  }
}

///|
test "reports L1 and L2 gaps" {
  match verify_report_text(sample_report(l1_status="failed", l2_proven=false)) {
    Ok(result) => {
      debug_inspect(result.gaps.length(), content="2")
      debug_inspect(result.gaps[0].level, content="\"L1\"")
      debug_inspect(result.gaps[1].level, content="\"L2\"")
      debug_inspect(
        result.gaps[1].reason.contains("windows-real-skia=failed"),
        content="true",
      )
    }
    Err(message) => fail(message)
  }
}

///|
test "skips L2 features marked skipped" {
  match verify_report_text(
    sample_report(l2_category="skipped", l2_proven=false),
  ) {
    Ok(result) => debug_inspect(result.gaps.length(), content="0")
    Err(message) => fail(message)
  }
}
