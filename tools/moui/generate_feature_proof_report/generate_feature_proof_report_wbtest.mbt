///|
test "all-success status proves L1 and L2 features" {
  let status : Map[String, String] = {
    "pr-profile": "success",
    "api-surface": "success",
    "linux-platform": "success",
    "windows-native": "success",
    "macos-packaging": "success",
    "benchmark-scaffold": "success",
    "macos-real-skia": "success",
    "linux-real-skia": "success",
    "windows-real-skia": "success",
  }
  let report = build_report(
    status,
    "https://example.test/run/1",
    "2026-07-16T00:00:00.000Z",
  )
  debug_inspect(report.proven, content="29")
  debug_inspect(report.gap, content="0")
  debug_inspect(report.skipped, content="0")
  debug_inspect(report.features.length(), content="29")
}

///|
test "missing L2 jobs are skipped as no PR context" {
  let status : Map[String, String] = {
    "pr-profile": "success",
    "api-surface": "success",
    "linux-platform": "success",
    "windows-native": "success",
    "macos-packaging": "success",
    "benchmark-scaffold": "success",
  }
  let report = build_report(status, "", "2026-07-16T00:00:00.000Z")
  debug_inspect(report.proven, content="29")
  debug_inspect(report.gap, content="0")
  let rect = report.features[12]
  debug_inspect(rect.feature, content="\"Rect\"")
  debug_inspect(rect.category_status, content="\"skipped\"")
  debug_inspect(rect.status_map["macos-real-skia"], content="\"skipped\"")
}

///|
test "macos missing with other platforms success is partial proven" {
  let status : Map[String, String] = {
    "pr-profile": "success",
    "api-surface": "success",
    "linux-platform": "success",
    "windows-native": "success",
    "macos-packaging": "success",
    "benchmark-scaffold": "success",
    "macos-real-skia": "missing",
    "linux-real-skia": "success",
    "windows-real-skia": "success",
  }
  let report = build_report(status, "url", "ts")
  let rect = report.features[12]
  debug_inspect(rect.proven, content="true")
  debug_inspect(rect.category_status, content="\"partial\"")
}

///|
test "markdown includes summary table headers" {
  let status : Map[String, String] = {
    "pr-profile": "failed",
    "api-surface": "success",
    "linux-platform": "success",
    "windows-native": "success",
    "macos-packaging": "success",
    "benchmark-scaffold": "success",
    "macos-real-skia": "success",
    "linux-real-skia": "failed",
    "windows-real-skia": "success",
  }
  let report = build_report(status, "https://ci", "ts")
  let md = report_to_markdown(report)
  debug_inspect(md.contains("## L1 Features"), content="true")
  debug_inspect(md.contains("## L2 Features"), content="true")
  debug_inspect(md.contains("## Gaps"), content="true")
  debug_inspect(report.gap > 0, content="true")
}
