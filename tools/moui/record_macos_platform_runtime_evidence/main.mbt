///|
struct CliOptions {
  repo_root : String
  manifest_path : String
  host : String
  consumer_command : String
  window_evidence_command : String
  runtime_logs : Array[String]
  window_smoke_logs : Array[String]
  app_runtime_logs : Array[String]
  notes : Array[String]
  provenance_kind : String
  provenance_workflow : String
  provenance_job : String
  provenance_run_url : String
  provenance_run_id : String
  provenance_runner : String
  provenance_artifacts : Array[String]
  provenance_notes : Array[String]
  plan_output : String
  help : Bool
}

///|
struct ArtifactPath {
  absolute : String
  relative : String
}

///|
struct WindowSmokeCheck {
  needle : String
  description : String
}

///|
struct TokenCheck {
  label : String
  token : String
}

///|
struct RuntimeObservationCheck {
  key : String
  phrase : String
  token : String
}

///|
let native_ime_observation_keys : Array[String] = [
  "imeCandidateAnchor", "imeSurroundingText", "imeCompositionVisual", "imeCommitDelete",
  "imeCursorUpdate", "imeScrollAnchor", "imeScaleDprAnchor", "imeResizeAnchor",
]

///|
let skia_observation_keys : Array[String] = [
  "providerPreflight", "fallbackUnavailable", "realRendererSmoke", "asyncImageSecondFrame",
  "showcaseFirstFrame",
]

///|
let platform_observation_keys : Array[String] = [
  "windowOpened", "resizeRedraw", "representativeInput", "cleanExit", "surface",
  "redraw", "resizeScale", "consumerInput", "textInput", "rendererHandle", "monitorCursor",
  "cleanShutdown",
]

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/record_macos_platform_runtime_evidence <manifest.json> [options]
    #|
    #|Validates matching-host macOS platform runtime evidence and writes a JSON
    #|plan for the compatibility Node wrapper.
    #|
    #|Options mirror scripts/record-macos-platform-runtime-evidence.mjs.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let manifest_path = Ref("")
  let host = Ref("")
  let consumer_command = Ref("")
  let window_evidence_command = Ref(
    "wzzc-dev/window@0.5.1-0.1.4 package evidence macos --status passed",
  )
  let runtime_logs : Array[String] = []
  let window_smoke_logs : Array[String] = []
  let app_runtime_logs : Array[String] = []
  let notes : Array[String] = []
  let provenance_kind = Ref("")
  let provenance_workflow = Ref("")
  let provenance_job = Ref("")
  let provenance_run_url = Ref("")
  let provenance_run_id = Ref("")
  let provenance_runner = Ref("")
  let provenance_artifacts : Array[String] = []
  let provenance_notes : Array[String] = []
  let plan_output = Ref("")
  let help = Ref(false)
  let positionals : Array[String] = []
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root.val = args[index + 1]
        index += 2
      }
      "--host" => {
        if index + 1 >= args.length() {
          return Err("missing value for --host")
        }
        host.val = args[index + 1]
        index += 2
      }
      "--consumer-command" => {
        if index + 1 >= args.length() {
          return Err("missing value for --consumer-command")
        }
        consumer_command.val = args[index + 1]
        index += 2
      }
      "--window-evidence-command" => {
        if index + 1 >= args.length() {
          return Err("missing value for --window-evidence-command")
        }
        window_evidence_command.val = args[index + 1]
        index += 2
      }
      "--runtime-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --runtime-log")
        }
        runtime_logs.push(args[index + 1])
        index += 2
      }
      "--window-smoke-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --window-smoke-log")
        }
        window_smoke_logs.push(args[index + 1])
        index += 2
      }
      "--app-runtime-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --app-runtime-log")
        }
        app_runtime_logs.push(args[index + 1])
        index += 2
      }
      "--note" => {
        if index + 1 >= args.length() {
          return Err("missing value for --note")
        }
        notes.push(args[index + 1])
        index += 2
      }
      "--provenance-kind" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-kind")
        }
        provenance_kind.val = args[index + 1]
        index += 2
      }
      "--provenance-workflow" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-workflow")
        }
        provenance_workflow.val = args[index + 1]
        index += 2
      }
      "--provenance-job" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-job")
        }
        provenance_job.val = args[index + 1]
        index += 2
      }
      "--provenance-run-url" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-run-url")
        }
        provenance_run_url.val = args[index + 1]
        index += 2
      }
      "--provenance-run-id" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-run-id")
        }
        provenance_run_id.val = args[index + 1]
        index += 2
      }
      "--provenance-runner" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-runner")
        }
        provenance_runner.val = args[index + 1]
        index += 2
      }
      "--provenance-artifact" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-artifact")
        }
        provenance_artifacts.push(args[index + 1])
        index += 2
      }
      "--provenance-note" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-note")
        }
        provenance_notes.push(args[index + 1])
        index += 2
      }
      "--plan-output" => {
        if index + 1 >= args.length() {
          return Err("missing value for --plan-output")
        }
        plan_output.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      value => {
        if value.has_prefix("-") {
          return Err("Unknown argument: " + value)
        }
        positionals.push(value)
        index += 1
      }
    }
  }
  if !help.val {
    if positionals.length() < 1 {
      return Err(usage())
    }
    if positionals.length() > 1 {
      return Err("unexpected argument: " + positionals[1])
    }
  }
  if positionals.length() >= 1 {
    manifest_path.val = positionals[0]
  }
  Ok({
    repo_root: repo_root.val,
    manifest_path: manifest_path.val,
    host: host.val,
    consumer_command: consumer_command.val,
    window_evidence_command: window_evidence_command.val,
    runtime_logs,
    window_smoke_logs,
    app_runtime_logs,
    notes,
    provenance_kind: provenance_kind.val,
    provenance_workflow: provenance_workflow.val,
    provenance_job: provenance_job.val,
    provenance_run_url: provenance_run_url.val,
    provenance_run_id: provenance_run_id.val,
    provenance_runner: provenance_runner.val,
    provenance_artifacts,
    provenance_notes,
    plan_output: plan_output.val,
    help: help.val,
  })
}

///|
fn json_object(value : Json) -> Map[String, Json]? {
  match value {
    Json::Object(fields) => Some(fields)
    _ => None
  }
}

///|
fn optional_object(
  object : Map[String, Json],
  field : String,
) -> Map[String, Json]? {
  match object.get(field) {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn optional_array(object : Map[String, Json], field : String) -> Array[Json] {
  match object.get(field) {
    Some(Json::Array(values)) => values
    _ => []
  }
}

///|
fn optional_string(object : Map[String, Json], field : String) -> String {
  match object.get(field) {
    Some(Json::String(value)) => value
    _ => ""
  }
}

///|
fn json_string_array(values : Array[Json]) -> Array[String] {
  let strings : Array[String] = []
  for value in values {
    match value {
      Json::String(text) if text.trim().to_owned() != "" => strings.push(text)
      _ => ()
    }
  }
  strings
}

///|
fn macos_entry(manifest : Map[String, Json]) -> Map[String, Json]? {
  for value in optional_array(manifest, "platforms") {
    match value {
      Json::Object(entry) if optional_string(entry, "name") == "macos" =>
        return Some(entry)
      _ => ()
    }
  }
  None
}

///|
fn normalize_slashes(path : String) -> String {
  let builder = StringBuilder::new()
  for char in path {
    if char == '\\' {
      builder.write_char('/')
    } else {
      builder.write_char(char)
    }
  }
  builder.to_string()
}

///|
fn collapse_path(path : String) -> String {
  let normalized = normalize_slashes(path)
  let rooted = normalized.has_prefix("/")
  let drive_prefix = normalized.length() >= 2 && normalized[1] == ':'
  let prefix = if drive_prefix {
    normalized[:2].to_owned()
  } else if rooted {
    "/"
  } else {
    ""
  }
  let start = if drive_prefix {
    if normalized.length() >= 3 && normalized[2] == '/' {
      3
    } else {
      2
    }
  } else if rooted {
    1
  } else {
    0
  }
  let parts : Array[String] = []
  for part_view in normalized[start:].split("/") {
    let part = part_view.to_owned()
    if part == "" || part == "." {
      continue
    } else if part == ".." {
      if !parts.is_empty() && parts[parts.length() - 1] != ".." {
        ignore(parts.pop())
      } else if !rooted && !drive_prefix {
        parts.push(part)
      }
    } else {
      parts.push(part)
    }
  }
  let joined = parts.join("/")
  if prefix == "/" {
    if joined == "" {
      "/"
    } else {
      "/" + joined
    }
  } else if drive_prefix {
    if joined == "" {
      prefix
    } else {
      prefix + "/" + joined
    }
  } else {
    joined
  }
}

///|
fn artifact_path(
  repo_root : String,
  raw_path : String,
  label : String,
) -> Result[ArtifactPath, String] {
  let absolute = collapse_path(@tools.resolve_path(repo_root, raw_path))
  let root = collapse_path(repo_root)
  let prefix = if root.has_suffix("/") { root } else { root + "/" }
  let relative = if absolute == root {
    ""
  } else if absolute.has_prefix(prefix) {
    absolute[prefix.length():].to_owned()
  } else {
    return Err(
      label + " must stay under artifacts/platform-evidence/macos/: " + raw_path,
    )
  }
  if !relative.has_prefix("artifacts/platform-evidence/macos/") ||
    relative.contains("../") ||
    relative == ".." {
    return Err(
      label + " must stay under artifacts/platform-evidence/macos/: " + raw_path,
    )
  }
  if !@tools.file_exists(absolute) {
    return Err(label + " does not exist: " + relative)
  }
  Ok({ absolute, relative })
}

///|
fn artifacts_for(
  repo_root : String,
  paths : Array[String],
  label : String,
) -> Result[Array[ArtifactPath], String] {
  let result : Array[ArtifactPath] = []
  for path in paths {
    match artifact_path(repo_root, path, label) {
      Ok(value) => result.push(value)
      Err(message) => return Err(message)
    }
  }
  Ok(result)
}

///|
fn read_artifacts(paths : Array[ArtifactPath]) -> Result[String, String] {
  let parts : Array[String] = []
  for artifact in paths {
    match @tools.read_required_text(artifact.absolute, artifact.relative) {
      Ok(text) => parts.push(text)
      Err(message) => return Err(message)
    }
  }
  Ok(parts.join("\n"))
}

///|
fn is_space(char : UInt16) -> Bool {
  char == ' ' || char == '\n' || char == '\r' || char == '\t'
}

///|
fn has_token(text : String, token : String) -> Bool {
  let start = Ref(-1)
  for index in 0..<text.length() {
    if is_space(text[index]) {
      if start.val >= 0 {
        if text[start.val:index] == token {
          return true
        }
        start.val = -1
      }
    } else if start.val < 0 {
      start.val = index
    }
  }
  if start.val >= 0 {
    text[start.val:] == token
  } else {
    false
  }
}

///|
fn require_contains(
  text : String,
  label : String,
  token : String,
  description : String,
) -> Result[Unit, String] {
  if !text.contains(token) {
    return Err(label + " is missing expected marker: " + description)
  }
  Ok(())
}

///|
fn require_token(
  text : String,
  label : String,
  token : String,
) -> Result[Unit, String] {
  if !has_token(text, token) {
    return Err(
      "macOS platform runtime log is missing expected token for " +
      label +
      ": " +
      token,
    )
  }
  Ok(())
}

///|
fn find_substring(text : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }
  if needle.length() > text.length() {
    return -1
  }
  for index in 0..<=(text.length() - needle.length()) {
    if text[index:index + needle.length()].to_owned() == needle {
      return index
    }
  }
  -1
}

///|
fn validate_window_smoke(text : String) -> Result[Array[String], String] {
  let checks : Array[WindowSmokeCheck] = [
    {
      needle: "MOUIMacSmoke: surface size=",
      description: "MOUIMacSmoke surface size with scale",
    },
    {
      needle: "MOUIMacSmoke: handles window=0x",
      description: "non-zero window and content-view handles",
    },
    {
      needle: "MOUIMacSmoke: monitors count=",
      description: "monitor and current-monitor probe",
    },
    { needle: "MOUIMacSmoke: cursor", description: "cursor probe" },
    {
      needle: "MOUIMacSmoke: resize requested size=",
      description: "requested resize",
    },
    { needle: "MOUIMacSmoke: resize size=", description: "observed resize" },
    {
      needle: "MOUIMacSmoke: redraw pre_present_notify",
      description: "redraw pre_present_notify",
    },
    { needle: "MOUIMacSmoke: pointer x=", description: "pointer input" },
    {
      needle: "MOUIMacSmoke: keyboard text=",
      description: "keyboard text input",
    },
    {
      needle: "MOUIMacSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true",
      description: "IME request/update/disable probe",
    },
    { needle: "MOUIMacSmoke: ready", description: "ready sentinel" },
  ]
  for check in checks {
    match
      require_contains(
        text,
        "macOS window smoke log",
        check.needle,
        check.description,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  let destroyed = find_substring(text, "MOUIMacSmoke: destroyed")
  let finished = find_substring(text, "MOUIMacSmoke: finished")
  if destroyed < 0 || finished < 0 || destroyed >= finished {
    return Err(
      "macOS window smoke log must contain 'MOUIMacSmoke: destroyed' before 'MOUIMacSmoke: finished'",
    )
  }
  if text.contains("MOUIMacSmoke: failed") {
    return Err("macOS window smoke log reported failure")
  }
  Ok([
    "MoUI macOS platform window opened passed window-opened", "MoUI macOS platform resize redraw passed resize-redraw",
    "MoUI macOS platform representative input passed representative-input", "MoUI macOS platform clean exit passed clean-exit",
    "MoUI macOS platform surface passed surface", "MoUI macOS platform redraw passed redraw",
    "MoUI macOS platform resize scale passed resize-scale", "MoUI macOS platform consumer input passed consumer-input",
    "MoUI macOS platform text input passed text-input", "MoUI macOS platform renderer handle passed renderer-handle",
    "MoUI macOS platform monitor cursor passed monitor-cursor", "MoUI macOS platform clean shutdown passed clean-shutdown",
  ])
}

///|
fn validate_app_runtime(text : String) -> Result[String, String] {
  let marker = "macOS renderer presented first frame; exiting by request; title=MoUI Showcase"
  if !text.contains(marker) {
    return Err(
      "macOS app runtime log is missing expected marker: first-frame marker with title=MoUI Showcase",
    )
  }
  if text.contains("smoke timed out") ||
    text.contains("did not print the expected first-frame marker") ||
    text.contains("runtime smoke failed") {
    return Err(
      "macOS app runtime log contains a failed first-frame smoke marker",
    )
  }
  Ok(
    "MoUI macOS platform runtime matching-host native-app platform=macos renderer=skia app=showcase",
  )
}

///|
fn validate_runtime_text(text : String) -> Result[Unit, String] {
  if !text.contains("MoUI macOS platform runtime") {
    return Err(
      "macOS platform runtime log is missing expected marker for common runtime",
    )
  }
  let common_tokens : Array[TokenCheck] = [
    { label: "matching host", token: "matching-host" },
    { label: "native app", token: "native-app" },
    { label: "platform", token: "platform=macos" },
    { label: "renderer", token: "renderer=skia" },
    { label: "Showcase app", token: "app=showcase" },
  ]
  for check in common_tokens {
    match require_token(text, check.label, check.token) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  let observations : Array[RuntimeObservationCheck] = [
    {
      key: "windowOpened",
      phrase: "MoUI macOS platform window opened passed",
      token: "window-opened",
    },
    {
      key: "resizeRedraw",
      phrase: "MoUI macOS platform resize redraw passed",
      token: "resize-redraw",
    },
    {
      key: "representativeInput",
      phrase: "MoUI macOS platform representative input passed",
      token: "representative-input",
    },
    {
      key: "cleanExit",
      phrase: "MoUI macOS platform clean exit passed",
      token: "clean-exit",
    },
    {
      key: "surface",
      phrase: "MoUI macOS platform surface passed",
      token: "surface",
    },
    {
      key: "redraw",
      phrase: "MoUI macOS platform redraw passed",
      token: "redraw",
    },
    {
      key: "resizeScale",
      phrase: "MoUI macOS platform resize scale passed",
      token: "resize-scale",
    },
    {
      key: "consumerInput",
      phrase: "MoUI macOS platform consumer input passed",
      token: "consumer-input",
    },
    {
      key: "textInput",
      phrase: "MoUI macOS platform text input passed",
      token: "text-input",
    },
    {
      key: "rendererHandle",
      phrase: "MoUI macOS platform renderer handle passed",
      token: "renderer-handle",
    },
    {
      key: "monitorCursor",
      phrase: "MoUI macOS platform monitor cursor passed",
      token: "monitor-cursor",
    },
    {
      key: "cleanShutdown",
      phrase: "MoUI macOS platform clean shutdown passed",
      token: "clean-shutdown",
    },
  ]
  for check in observations {
    if !text.contains(check.phrase) {
      return Err(
        "macOS platform runtime log is missing expected marker for " + check.key,
      )
    }
    match require_token(text, check.key, check.token) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
fn string_set_add(values : Array[String], value : String) -> Unit {
  if value.trim().to_owned() != "" && !values.contains(value) {
    values.push(value)
  }
}

///|
fn existing_artifacts(entry : Map[String, Json]) -> Array[String] {
  json_string_array(optional_array(entry, "artifacts")).filter(artifact => {
    !artifact.has_suffix("/README.md")
  })
}

///|
fn existing_notes(entry : Map[String, Json]) -> Array[String] {
  json_string_array(optional_array(entry, "notes"))
}

///|
fn validate_manifest_ready(entry : Map[String, Json]) -> Result[Unit, String] {
  let skia = match optional_object(entry, "skiaEvidence") {
    Some(value) => value
    None =>
      return Err(
        "macos.skiaEvidence.status must already be passed before promoting macOS platform runtime evidence",
      )
  }
  if optional_string(skia, "status") != "passed" {
    return Err(
      "macos.skiaEvidence.status must already be passed before promoting macOS platform runtime evidence",
    )
  }
  let skia_observations = match optional_object(skia, "observations") {
    Some(value) => value
    None => {}
  }
  for key in skia_observation_keys {
    if optional_string(skia_observations, key) != "yes" {
      return Err(
        "macos.skiaEvidence.observations." + key + " must already be yes",
      )
    }
  }
  let observations = match optional_object(entry, "observations") {
    Some(value) => value
    None => {}
  }
  for key in native_ime_observation_keys {
    if optional_string(observations, key) != "yes" {
      return Err("macos.observations." + key + " must already be yes")
    }
  }
  Ok(())
}

///|
fn json_escape(value : String) -> String {
  let builder = StringBuilder::new()
  for char in value {
    match char {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      _ => builder.write_char(char)
    }
  }
  builder.to_string()
}

///|
fn write_json_string_array(
  builder : StringBuilder,
  values : Array[String],
) -> Unit {
  builder.write_char('[')
  for index in 0..<values.length() {
    if index > 0 {
      builder.write_string(",")
    }
    builder.write_char('"')
    builder.write_string(json_escape(values[index]))
    builder.write_char('"')
  }
  builder.write_char(']')
}

///|
fn write_yes_observations(
  builder : StringBuilder,
  keys : Array[String],
) -> Unit {
  builder.write_char('{')
  for index in 0..<keys.length() {
    if index > 0 {
      builder.write_string(",")
    }
    builder.write_char('"')
    builder.write_string(json_escape(keys[index]))
    builder.write_string("\":\"yes\"")
  }
  builder.write_char('}')
}

///|
fn write_plan_json(
  host : String,
  consumer_command : String,
  window_evidence_command : String,
  artifacts : Array[String],
  notes : Array[String],
  provenance_kind : String,
  provenance_workflow : String,
  provenance_job : String,
  provenance_run_url : String,
  provenance_run_id : String,
  provenance_runner : String,
  provenance_artifacts : Array[String],
  provenance_notes : Array[String],
) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\n")
  builder.write_string("  \"host\": \"" + json_escape(host) + "\",\n")
  builder.write_string(
    "  \"consumerCommand\": \"" + json_escape(consumer_command) + "\",\n",
  )
  builder.write_string(
    "  \"windowEvidenceCommand\": \"" +
    json_escape(window_evidence_command) +
    "\",\n",
  )
  builder.write_string("  \"observations\": ")
  write_yes_observations(builder, platform_observation_keys)
  builder.write_string(",\n")
  builder.write_string("  \"artifacts\": ")
  write_json_string_array(builder, artifacts)
  builder.write_string(",\n  \"notes\": ")
  write_json_string_array(builder, notes)
  builder.write_string(
    ",\n  \"provenanceKind\": \"" + json_escape(provenance_kind) + "\",\n",
  )
  builder.write_string(
    "  \"provenanceWorkflow\": \"" + json_escape(provenance_workflow) + "\",\n",
  )
  builder.write_string(
    "  \"provenanceJob\": \"" + json_escape(provenance_job) + "\",\n",
  )
  builder.write_string(
    "  \"provenanceRunUrl\": \"" + json_escape(provenance_run_url) + "\",\n",
  )
  builder.write_string(
    "  \"provenanceRunId\": \"" + json_escape(provenance_run_id) + "\",\n",
  )
  builder.write_string(
    "  \"provenanceRunner\": \"" + json_escape(provenance_runner) + "\",\n",
  )
  builder.write_string("  \"provenanceArtifacts\": ")
  write_json_string_array(builder, provenance_artifacts)
  builder.write_string(",\n  \"provenanceNotes\": ")
  write_json_string_array(builder, provenance_notes)
  builder.write_string("\n}\n")
  builder.to_string()
}

///|
fn validate_and_plan(options : CliOptions) -> Result[String, String] {
  if !(options.host.contains("macOS") || options.host.contains("Darwin")) {
    return Err("--host must name a matching macOS/Darwin host")
  }
  if options.consumer_command.trim().to_owned() == "" {
    return Err(
      "--consumer-command is required for passed macOS platform evidence",
    )
  }
  if !normalize_slashes(options.consumer_command).contains(
      "examples/showcase/macos_skia",
    ) {
    return Err("--consumer-command must name examples/showcase/macos_skia")
  }
  if options.runtime_logs.is_empty() &&
    (
      options.window_smoke_logs.is_empty() ||
      options.app_runtime_logs.is_empty()
    ) {
    return Err(
      "At least one --runtime-log or both --window-smoke-log and --app-runtime-log are required",
    )
  }
  let text = match
    @tools.read_required_text(options.manifest_path, options.manifest_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let parsed = @json.parse(text) catch {
    _ =>
      return Err(options.manifest_path + ": failed to read JSON: invalid JSON")
  }
  let manifest = match json_object(parsed) {
    Some(value) => value
    None =>
      return Err(options.manifest_path + ": manifest root must be an object")
  }
  let entry = match macos_entry(manifest) {
    Some(value) => value
    None => return Err(options.manifest_path + ": platforms must include macos")
  }
  match validate_manifest_ready(entry) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  let runtime_artifacts = match
    artifacts_for(
      options.repo_root,
      options.runtime_logs,
      "macOS runtime artifact",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let window_artifacts = match
    artifacts_for(
      options.repo_root,
      options.window_smoke_logs,
      "macOS window smoke artifact",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let app_artifacts = match
    artifacts_for(
      options.repo_root,
      options.app_runtime_logs,
      "macOS app runtime artifact",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let explicit_runtime_text = match read_artifacts(runtime_artifacts) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let window_text = match read_artifacts(window_artifacts) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let app_text = match read_artifacts(app_artifacts) {
    Ok(value) => value
    Err(message) => return Err(message)
  }

  let derived : Array[String] = []
  if !window_artifacts.is_empty() {
    match validate_window_smoke(window_text) {
      Ok(lines) =>
        for line in lines {
          derived.push(line)
        }
      Err(message) => return Err(message)
    }
  }
  if !app_artifacts.is_empty() {
    match validate_app_runtime(app_text) {
      Ok(line) => derived.insert(0, line)
      Err(message) => return Err(message)
    }
  }
  let runtime_text = [explicit_runtime_text, derived.join("\n")]
    .filter(part => part.trim().to_owned() != "")
    .join("\n")
  match validate_runtime_text(runtime_text) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  let artifacts = existing_artifacts(entry)
  for artifact in runtime_artifacts {
    string_set_add(artifacts, artifact.relative)
  }
  for artifact in window_artifacts {
    string_set_add(artifacts, artifact.relative)
  }
  for artifact in app_artifacts {
    string_set_add(artifacts, artifact.relative)
  }
  let notes = existing_notes(entry)
  for note in options.notes {
    string_set_add(notes, note)
  }
  string_set_add(
    notes, "macOS platform runtime evidence was marker-validated by record-macos-platform-runtime-evidence.mjs.",
  )
  let provenance_artifacts = artifacts.copy()
  for artifact in options.provenance_artifacts {
    string_set_add(provenance_artifacts, artifact)
  }
  let provenance_notes = options.provenance_notes.copy()

  Ok(
    write_plan_json(
      options.host,
      options.consumer_command,
      options.window_evidence_command,
      artifacts,
      notes,
      options.provenance_kind,
      options.provenance_workflow,
      options.provenance_job,
      options.provenance_run_url,
      options.provenance_run_id,
      options.provenance_runner,
      provenance_artifacts,
      provenance_notes,
    ),
  )
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let plan = match validate_and_plan(options) {
        Ok(value) => value
        Err(message) => {
          println(message)
          return 1
        }
      }
      if options.plan_output != "" {
        match
          @tools.write_text_file(
            options.plan_output,
            plan,
            "macOS platform runtime evidence plan",
          ) {
          Ok(_) => ()
          Err(message) => {
            println(message)
            return 1
          }
        }
      } else {
        println(plan)
      }
      0
    }
    Err(message) => {
      println(message)
      2
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
