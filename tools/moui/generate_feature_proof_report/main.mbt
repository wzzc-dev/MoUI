///|
struct L1Feature {
  feature : String
  job : String
}

///|
struct FeatureEntry {
  feature : String
  level : String
  proof_job : String
  proof_jobs : Array[String]
  status_text : String
  status_map : Map[String, String]
  proven : Bool
  category_status : String
}

///|
struct ProofReport {
  ci_run_url : String
  timestamp : String
  features : Array[FeatureEntry]
  proven : Int
  gap : Int
  skipped : Int
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/generate_feature_proof_report --status <json> --output <path> [--run-url <url>] [--timestamp <iso8601>]
    #|
    #|Builds feature proof JSON/Markdown reports from CI job status JSON.
    #|
  )
}

///|
fn l1_features() -> Array[L1Feature] {
  [
    { feature: "Core API (View/Element/Layout/Animation)", job: "pr-profile" },
    { feature: "Runtime lifecycle", job: "pr-profile" },
    { feature: "Views controls", job: "pr-profile" },
    { feature: "Host services protocol", job: "pr-profile" },
    { feature: "Web wasm-gc build", job: "pr-profile" },
    { feature: "Renderer capability report consistency", job: "pr-profile" },
    { feature: "Text conformance", job: "pr-profile" },
    { feature: "API surface stability", job: "api-surface" },
    { feature: "Linux backend contracts", job: "linux-platform" },
    { feature: "Windows backend contracts", job: "windows-native" },
    { feature: "macOS packaging", job: "macos-packaging" },
    { feature: "Benchmark scaffold", job: "benchmark-scaffold" },
  ]
}

///|
fn l2_feature_names() -> Array[String] {
  [
    "Rect", "RoundedRect", "Gradient", "Shadow", "Text", "Image", "Clip", "Transform",
    "Opacity", "LayerCompositing", "BlendMode", "FilterEffect", "PathVector", "ShaderEffect",
    "TextShaping", "EmojiText", "AsyncImage",
  ]
}

///|
fn l2_jobs() -> Array[String] {
  ["macos-real-skia", "linux-real-skia", "windows-real-skia"]
}

///|
fn lookup_job_status(statuses : Map[String, String], job : String) -> String {
  match statuses.get(job) {
    Some(value) => value
    None => "missing"
  }
}

///|
fn parse_status_map(text : String) -> Result[Map[String, String], String] {
  let json = @json.parse(text) catch {
    _ => return Err("Failed to parse --status JSON: invalid JSON")
  }
  let root = match json {
    Json::Object(fields) => fields
    _ => return Err("Failed to parse --status JSON: expected object")
  }
  let result : Map[String, String] = Map([])
  for key, value in root {
    match value {
      Json::String(status) => result[key] = status
      _ => return Err("Failed to parse --status JSON: values must be strings")
    }
  }
  Ok(result)
}

///|
fn build_report(
  statuses : Map[String, String],
  run_url : String,
  timestamp : String,
) -> ProofReport {
  let features : Array[FeatureEntry] = []
  for item in l1_features() {
    let status = lookup_job_status(statuses, item.job)
    features.push({
      feature: item.feature,
      level: "L1",
      proof_job: item.job,
      proof_jobs: [],
      status_text: status,
      status_map: Map([]),
      proven: status == "success",
      category_status: "",
    })
  }
  let jobs = l2_jobs()
  for feature in l2_feature_names() {
    let per_platform : Map[String, String] = Map([])
    let mut all_passed = true
    let mut any_missing = false
    let mut macos_skipped = false
    for job in jobs {
      let status = lookup_job_status(statuses, job)
      per_platform[job] = status
      if status == "missing" && job == "macos-real-skia" {
        macos_skipped = true
      } else if status != "success" {
        all_passed = false
      }
      if status == "missing" && job != "macos-real-skia" {
        any_missing = true
      }
    }
    let l2_all_missing = jobs.all(job => {
      lookup_job_status(statuses, job) == "missing"
    })
    let mut category_status = ""
    let mut proven = false
    if l2_all_missing {
      category_status = "skipped"
      proven = true
      for job in jobs {
        per_platform[job] = "skipped"
      }
    } else if macos_skipped && all_passed {
      category_status = "partial"
      proven = true
    } else {
      category_status = if all_passed {
        "success"
      } else if any_missing {
        "partial"
      } else {
        "failed"
      }
      proven = all_passed
    }
    features.push({
      feature,
      level: "L2",
      proof_job: "",
      proof_jobs: jobs,
      status_text: "",
      status_map: per_platform,
      proven,
      category_status,
    })
  }
  let mut proven = 0
  let mut gap = 0
  let mut skipped = 0
  for feature in features {
    if feature.proven {
      proven += 1
    } else if feature.category_status == "skipped" {
      skipped += 1
    } else {
      gap += 1
    }
  }
  { ci_run_url: run_url, timestamp, features, proven, gap, skipped }
}

///|
fn feature_to_json(feature : FeatureEntry) -> Json {
  if feature.level == "L1" {
    let object : Map[String, Json] = Map([])
    object["feature"] = Json::string(feature.feature)
    object["level"] = Json::string("L1")
    object["proofJob"] = Json::string(feature.proof_job)
    object["status"] = Json::string(feature.status_text)
    object["proven"] = Json::boolean(feature.proven)
    Json::object(object)
  } else {
    let status_fields : Map[String, Json] = Map([])
    for key in @tools.sorted_map_keys(feature.status_map) {
      status_fields[key] = Json::string(feature.status_map[key])
    }
    let object : Map[String, Json] = Map([])
    object["feature"] = Json::string(feature.feature)
    object["level"] = Json::string("L2")
    object["proofJobs"] = Json::array(
      feature.proof_jobs.map(job => Json::string(job)),
    )
    object["status"] = Json::object(status_fields)
    object["proven"] = Json::boolean(feature.proven)
    object["categoryStatus"] = Json::string(feature.category_status)
    object["platforms"] = Json::array(
      ["macOS", "Linux", "Windows"].map(name => Json::string(name)),
    )
    Json::object(object)
  }
}

///|
fn report_to_json(report : ProofReport) -> Json {
  let features = report.features.map(feature_to_json)
  let summary : Map[String, Json] = Map([])
  summary["totalFeatures"] = Json::number(
    report.features.length().to_double(),
    repr=report.features.length().to_string(),
  )
  summary["proven"] = Json::number(
    report.proven.to_double(),
    repr=report.proven.to_string(),
  )
  summary["gap"] = Json::number(
    report.gap.to_double(),
    repr=report.gap.to_string(),
  )
  summary["skipped"] = Json::number(
    report.skipped.to_double(),
    repr=report.skipped.to_string(),
  )
  let object : Map[String, Json] = Map([])
  object["ciRunUrl"] = Json::string(report.ci_run_url)
  object["timestamp"] = Json::string(report.timestamp)
  object["features"] = Json::array(features)
  object["summary"] = Json::object(summary)
  Json::object(object)
}

///|
fn platform_status(feature : FeatureEntry, job : String) -> String {
  match feature.status_map.get(job) {
    Some(value) => value
    None => "missing"
  }
}

///|
fn feature_gap_status(feature : FeatureEntry) -> String {
  if feature.level == "L1" {
    feature.status_text
  } else {
    match feature_to_json(feature) {
      Json::Object(fields) =>
        match fields.get("status") {
          Some(value) => value.stringify()
          None => "missing"
        }
      _ => "missing"
    }
  }
}

///|
fn report_to_markdown(report : ProofReport) -> String {
  let lines : Array[String] = []
  lines.push("# Feature Proof Summary")
  lines.push("")
  let ci = if report.ci_run_url == "" { "N/A" } else { report.ci_run_url }
  lines.push("- **CI Run**: " + ci)
  lines.push("- **Timestamp**: " + report.timestamp)
  lines.push("- **Total features**: " + report.features.length().to_string())
  lines.push("- **Proven**: " + report.proven.to_string())
  lines.push("- **Gap**: " + report.gap.to_string())
  if report.skipped > 0 {
    lines.push("- **Skipped** (no PR context): " + report.skipped.to_string())
  }
  lines.push("")
  lines.push("## L1 Features")
  lines.push("")
  lines.push("| Feature | Proof job | Status | Proven |")
  lines.push("|---------|-----------|--------|--------|")
  for feature in report.features {
    if feature.level == "L1" {
      let proven = if feature.proven { "yes" } else { "no" }
      lines.push(
        "| " +
        feature.feature +
        " | " +
        feature.proof_job +
        " | " +
        feature.status_text +
        " | " +
        proven +
        " |",
      )
    }
  }
  lines.push("")
  lines.push("## L2 Features")
  lines.push("")
  lines.push("| Feature | macOS | Linux | Windows | Proven |")
  lines.push("|---------|-------|-------|---------|--------|")
  for feature in report.features {
    if feature.level == "L2" {
      let proven = if feature.proven { "yes" } else { "no" }
      lines.push(
        "| " +
        feature.feature +
        " | " +
        platform_status(feature, "macos-real-skia") +
        " | " +
        platform_status(feature, "linux-real-skia") +
        " | " +
        platform_status(feature, "windows-real-skia") +
        " | " +
        proven +
        " |",
      )
    }
  }
  if report.gap > 0 {
    lines.push("")
    lines.push("## Gaps")
    lines.push("")
    for feature in report.features {
      if !feature.proven && feature.category_status != "skipped" {
        lines.push(
          "- **" +
          feature.feature +
          "** (" +
          feature.level +
          "): status=" +
          feature_gap_status(feature),
        )
      }
    }
  }
  lines.push("")
  lines.join("\n")
}

///|
fn parent_dir(path : String) -> String {
  let normalized = path.replace(old="\\", new="/")
  let mut slash = -1
  for i = 0; i < normalized.length(); i = i + 1 {
    if normalized[i] == '/' {
      slash = i
    }
  }
  if slash <= 0 {
    if normalized.has_prefix("/") {
      "/"
    } else {
      "."
    }
  } else {
    normalized[:slash].to_owned()
  }
}

///|
fn create_dir_if_missing(path : String) -> Result[Unit, String] {
  if path == "" || @tools.directory_exists(path) {
    return Ok(())
  }
  @fs.create_dir(path) catch {
    _ => return Err("could not create directory: " + path)
  }
  Ok(())
}

///|
fn mkdir_p(path : String) -> Result[Unit, String] {
  if path == "" || @tools.directory_exists(path) {
    return Ok(())
  }
  let normalized = path.replace(old="\\", new="/")
  let current = Ref(if normalized.has_prefix("/") { "/" } else { "" })
  for part in normalized.split("/") {
    if part == "" {
      continue
    }
    let part = part.to_owned()
    if current.val == "" || current.val == "/" {
      current.val = current.val + part
    } else {
      current.val = current.val + "/" + part
    }
    match create_dir_if_missing(current.val) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
fn ensure_parent_dir(path : String) -> Result[Unit, String] {
  mkdir_p(parent_dir(path))
}

///|
fn markdown_path_for(output : String) -> String {
  match @tools.strip_suffix(output, ".json") {
    Some(stem) => stem + ".md"
    None => output + ".md"
  }
}

///|
struct CliOptions {
  status_json : String
  run_url : String
  output : String
  timestamp : String
  help : Bool
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut status_json = ""
  let mut run_url = ""
  let mut output = ""
  let mut timestamp = ""
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help = true
        index += 1
      }
      "--status" => {
        if index + 1 >= args.length() {
          return Err("missing value for --status")
        }
        status_json = args[index + 1]
        index += 2
      }
      "--run-url" => {
        if index + 1 >= args.length() {
          return Err("missing value for --run-url")
        }
        run_url = args[index + 1]
        index += 2
      }
      "--output" => {
        if index + 1 >= args.length() {
          return Err("missing value for --output")
        }
        output = args[index + 1]
        index += 2
      }
      "--timestamp" => {
        if index + 1 >= args.length() {
          return Err("missing value for --timestamp")
        }
        timestamp = args[index + 1]
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  Ok({ status_json, run_url, output, timestamp, help })
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Err(message) => {
      println(message)
      println(usage())
      2
    }
    Ok(options) => {
      if options.help {
        println(usage())
        return 0
      }
      if options.status_json == "" || options.output == "" {
        println(usage())
        return 2
      }
      let statuses = match parse_status_map(options.status_json) {
        Ok(value) => value
        Err(message) => {
          println(message)
          return 2
        }
      }
      let timestamp = if options.timestamp == "" {
        "unknown"
      } else {
        options.timestamp
      }
      let report = build_report(statuses, options.run_url, timestamp)
      let json_text = report_to_json(report).stringify(indent=2) + "\n"
      let md_text = report_to_markdown(report)
      match ensure_parent_dir(options.output) {
        Ok(_) => ()
        Err(message) => {
          println(message)
          return 1
        }
      }
      match @tools.write_text_file(options.output, json_text, "proof report") {
        Ok(_) => ()
        Err(message) => {
          println(message)
          return 1
        }
      }
      let md_path = markdown_path_for(options.output)
      match @tools.write_text_file(md_path, md_text, "proof markdown report") {
        Ok(_) => ()
        Err(message) => {
          println(message)
          return 1
        }
      }
      println("Feature proof report written to " + options.output)
      println("Markdown report written to " + md_path)
      let skipped_note = if report.skipped > 0 {
        ", " + report.skipped.to_string() + " skipped"
      } else {
        ""
      }
      println(
        "Summary: " +
        report.proven.to_string() +
        " proven, " +
        report.gap.to_string() +
        " gap" +
        skipped_note,
      )
      0
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
