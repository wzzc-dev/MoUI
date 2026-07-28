// `moui doctor` evidence scanning. Looks for `verify-manifest.json` under
// `artifacts/<platform>/<app>/` and summarizes whether runtime evidence is
// ready per platform with a pure MoonBit scan.

///|
priv struct EvidenceStatus {
  platform : String
  app_id : String
  manifest_path : String
  passed : Bool
  observations_summary : String
} derive(Eq, Show)

///|
/// Scan `artifacts/<platform>/*/verify-manifest.json` for the given platforms.
/// Returns a map keyed by `<platform>:<app_id>`. Missing manifests produce no
/// entry; entries with malformed JSON are skipped (pure scan, no exceptions).
fn check_evidence_ready(
  project_root : String,
  platforms : Array[String],
  host : HostPlatform,
) -> Map[String, EvidenceStatus] {
  let _ = host
  let result : Map[String, EvidenceStatus] = Map([])
  for platform in platforms {
    let platform_dir = join_path(join_path(project_root, "artifacts"), platform)
    if !(path_is_dir(platform_dir)) {
      continue
    }
    let entries = @fs.read_dir(platform_dir) catch { _ => continue }
    for entry in entries {
      let app_id = entry
      let manifest_path = join_path(
        join_path(platform_dir, app_id),
        "verify-manifest.json",
      )
      if !(path_is_file(manifest_path)) {
        continue
      }
      match read_evidence_manifest(manifest_path, platform, app_id) {
        Some(status) => result[platform + ":" + app_id] = status
        None => ()
      }
    }
  }
  result
}

///|
/// Read a single `verify-manifest.json` and parse the canonical fields.
/// Returns `None` when the file is missing, malformed, or produced by an
/// unknown generator.
fn read_evidence_manifest(
  manifest_path : String,
  platform : String,
  app_id : String,
) -> EvidenceStatus? {
  let text = @fs.read_file_to_string(manifest_path) catch { _ => return None }
  let parsed = @json.parse(text) catch { _ => return None }
  guard parsed is Object(fields) else { return None }
  let generated_by = match fields.get("generatedBy") {
    Some(Json::String(value)) => value
    _ => return None
  }
  if !(is_accepted_generated_by(generated_by)) {
    return None
  }
  let status = match fields.get("status") {
    Some(Json::String(value)) => value
    _ => "unknown"
  }
  let passed = status == "passed"
  // Summarize observations: count of passed / total.
  let mut passed_count = 0
  let mut total = 0
  match fields.get("observations") {
    Some(Json::Array(items)) =>
      for item in items {
        guard item is Object(obs_fields) else { continue }
        let obs_passed = match obs_fields.get("passed") {
          Some(Json::True) => true
          Some(Json::False) => false
          _ => continue
        }
        total += 1
        if obs_passed {
          passed_count += 1
        }
      }
    _ => ()
  }
  let summary = passed_count.to_string() + "/" + total.to_string() + " passed"
  Some({
    platform,
    app_id,
    manifest_path,
    passed,
    observations_summary: summary,
  })
}

///|
/// Render an `EvidenceStatus` map as a multi-line text block for `moui doctor`.
fn evidence_status_to_text(statuses : Map[String, EvidenceStatus]) -> String {
  if statuses.is_empty() {
    return "(no verify evidence found)\n"
  }
  let mut text = ""
  // Sorted for deterministic output.
  let keys : Array[String] = []
  for key, _value in statuses {
    keys.push(key)
  }
  keys.sort()
  for key in keys {
    match statuses.get(key) {
      Some(status) =>
        text += "[" +
          status.platform +
          "] " +
          status.app_id +
          " : " +
          (if status.passed { "passed" } else { "FAILED" }) +
          " (" +
          status.observations_summary +
          ")\n"
      None => ()
    }
  }
  text
}
