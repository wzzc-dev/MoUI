///|
struct CliOptions {
  repo_root : String
  manifest_path : String
  platform : String
  host : String
  consumer_command : String
  candidate_anchor_log : String
  surrounding_text_log : String
  composition_visual_log : String
  commit_delete_log : String
  cursor_update_log : String
  scroll_anchor_log : String
  scale_dpr_anchor_log : String
  resize_anchor_log : String
  notes : Array[String]
  plan_output : String
  help : Bool
}

///|
struct PlatformSpec {
  name : String
  host_tokens : Array[String]
  protocol_tokens : Array[String]
  protocol_description : String
}

///|
struct LogOption {
  observation : String
  label : String
  required_tokens : Array[String]
  marker_description : String
  macos_required_tokens : Array[String]
  macos_marker_description : String
}

///|
struct ArtifactPath {
  absolute : String
  relative : String
}

///|
struct SuppliedLog {
  option : String
  path : String
}

///|
let ime_observation_keys : Array[String] = [
  "imeCandidateAnchor", "imeSurroundingText", "imeCompositionVisual", "imeCommitDelete",
  "imeCursorUpdate", "imeScrollAnchor", "imeScaleDprAnchor", "imeResizeAnchor",
]

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/record_native_ime_evidence <manifest.json> <macos|windows|linux> [options]
    #|
    #|Validates native IME evidence logs and writes a JSON plan for the
    #|compatibility Node wrapper to pass to record-platform-evidence-manifest.mjs.
    #|
    #|Options:
    #|  --repo-root PATH
    #|  --host TEXT
    #|  --consumer-command TEXT
    #|  --candidate-anchor-log PATH
    #|  --surrounding-text-log PATH
    #|  --composition-visual-log PATH
    #|  --commit-delete-log PATH
    #|  --cursor-update-log PATH
    #|  --scroll-anchor-log PATH
    #|  --scale-dpr-anchor-log PATH
    #|  --resize-anchor-log PATH
    #|  --note TEXT
    #|  --plan-output PATH
    #|  -h, --help
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let manifest_path = Ref("")
  let platform = Ref("")
  let host = Ref("")
  let consumer_command = Ref("")
  let candidate_anchor_log = Ref("")
  let surrounding_text_log = Ref("")
  let composition_visual_log = Ref("")
  let commit_delete_log = Ref("")
  let cursor_update_log = Ref("")
  let scroll_anchor_log = Ref("")
  let scale_dpr_anchor_log = Ref("")
  let resize_anchor_log = Ref("")
  let notes : Array[String] = []
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
      "--candidate-anchor-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --candidate-anchor-log")
        }
        candidate_anchor_log.val = args[index + 1]
        index += 2
      }
      "--surrounding-text-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --surrounding-text-log")
        }
        surrounding_text_log.val = args[index + 1]
        index += 2
      }
      "--composition-visual-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --composition-visual-log")
        }
        composition_visual_log.val = args[index + 1]
        index += 2
      }
      "--commit-delete-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --commit-delete-log")
        }
        commit_delete_log.val = args[index + 1]
        index += 2
      }
      "--cursor-update-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --cursor-update-log")
        }
        cursor_update_log.val = args[index + 1]
        index += 2
      }
      "--scroll-anchor-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --scroll-anchor-log")
        }
        scroll_anchor_log.val = args[index + 1]
        index += 2
      }
      "--scale-dpr-anchor-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --scale-dpr-anchor-log")
        }
        scale_dpr_anchor_log.val = args[index + 1]
        index += 2
      }
      "--resize-anchor-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --resize-anchor-log")
        }
        resize_anchor_log.val = args[index + 1]
        index += 2
      }
      "--note" => {
        if index + 1 >= args.length() {
          return Err("missing value for --note")
        }
        notes.push(args[index + 1])
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
    if positionals.length() < 2 {
      return Err(usage())
    }
    if positionals.length() > 2 {
      return Err("unexpected argument: " + positionals[2])
    }
  }
  if positionals.length() >= 1 {
    manifest_path.val = positionals[0]
  }
  if positionals.length() >= 2 {
    platform.val = positionals[1]
  }
  Ok({
    repo_root: repo_root.val,
    manifest_path: manifest_path.val,
    platform: platform.val,
    host: host.val,
    consumer_command: consumer_command.val,
    candidate_anchor_log: candidate_anchor_log.val,
    surrounding_text_log: surrounding_text_log.val,
    composition_visual_log: composition_visual_log.val,
    commit_delete_log: commit_delete_log.val,
    cursor_update_log: cursor_update_log.val,
    scroll_anchor_log: scroll_anchor_log.val,
    scale_dpr_anchor_log: scale_dpr_anchor_log.val,
    resize_anchor_log: resize_anchor_log.val,
    notes,
    plan_output: plan_output.val,
    help: help.val,
  })
}

///|
fn platform_spec(name : String) -> PlatformSpec? {
  match name {
    "macos" =>
      Some({
        name,
        host_tokens: ["macOS", "Darwin"],
        protocol_tokens: [
          "platform-protocol=macos-marked-text", "platform-protocol=marked-text",
          "platform-protocol=NSTextInputClient",
        ],
        protocol_description: "platform-protocol=macos-marked-text, platform-protocol=marked-text, or platform-protocol=NSTextInputClient",
      })
    "windows" =>
      Some({
        name,
        host_tokens: ["Windows", "MSVC"],
        protocol_tokens: [
          "platform-protocol=windows-ime", "platform-protocol=imm", "platform-protocol=tsf",
        ],
        protocol_description: "platform-protocol=windows-ime, platform-protocol=imm, or platform-protocol=tsf",
      })
    "linux" =>
      Some({
        name,
        host_tokens: ["Linux", "Wayland"],
        protocol_tokens: [
          "platform-protocol=wayland-text-input", "platform-protocol=wayland-ime",
        ],
        protocol_description: "platform-protocol=wayland-text-input or platform-protocol=wayland-ime",
      })
    _ => None
  }
}

///|
fn log_option(option : String) -> LogOption {
  match option {
    "--candidate-anchor-log" =>
      {
        observation: "imeCandidateAnchor",
        label: "candidate anchor log",
        required_tokens: [
          "MoUI native IME candidate anchor passed", "candidate-anchor", "candidate-window",
          "caret-rect", "surrounding-text",
        ],
        marker_description: "MoUI native IME candidate anchor passed with candidate-anchor, candidate-window, caret-rect, and surrounding-text markers",
        macos_required_tokens: [
          "NSTextInputClient", "appkit-setMarkedText", "appkit-firstRectForCharacterRange",
        ],
        macos_marker_description: "NSTextInputClient, appkit-setMarkedText, and appkit-firstRectForCharacterRange markers",
      }
    "--surrounding-text-log" =>
      {
        observation: "imeSurroundingText",
        label: "surrounding text log",
        required_tokens: [
          "MoUI native IME surrounding text passed", "surrounding-text", "selection-anchor",
          "grapheme",
        ],
        marker_description: "MoUI native IME surrounding text passed with surrounding-text, selection-anchor, UTF-8 offsets, and grapheme markers",
        macos_required_tokens: [
          "NSTextInputClient", "appkit-setMarkedText", "appkit-firstRectForCharacterRange",
        ],
        macos_marker_description: "NSTextInputClient, appkit-setMarkedText, and appkit-firstRectForCharacterRange markers",
      }
    "--composition-visual-log" =>
      {
        observation: "imeCompositionVisual",
        label: "composition visual log",
        required_tokens: [
          "MoUI native IME composition visual passed", "composition-range", "composition-cursor",
          "preedit-underline", "preedit-pixels", "selection-highlight",
        ],
        marker_description: "MoUI native IME composition visual passed with composition-range, composition-cursor, preedit-underline, preedit-pixels, and selection-highlight markers",
        macos_required_tokens: [
          "NSTextInputClient", "appkit-setMarkedText", "appkit-firstRectForCharacterRange",
        ],
        macos_marker_description: "NSTextInputClient, appkit-setMarkedText, and appkit-firstRectForCharacterRange markers",
      }
    "--commit-delete-log" =>
      {
        observation: "imeCommitDelete",
        label: "commit/delete log",
        required_tokens: [
          "MoUI native IME commit delete passed", "commit", "delete", "selection-replacement",
        ],
        marker_description: "MoUI native IME commit delete passed with commit, delete, and selection-replacement markers",
        macos_required_tokens: ["NSTextInputClient", "appkit-insertText"],
        macos_marker_description: "NSTextInputClient and appkit-insertText markers",
      }
    "--cursor-update-log" =>
      {
        observation: "imeCursorUpdate",
        label: "cursor update log",
        required_tokens: [
          "MoUI native IME cursor update passed", "cursor-area", "cursor-update",
          "caret-rect",
        ],
        marker_description: "MoUI native IME cursor update passed with cursor-area, cursor-update, and caret-rect markers",
        macos_required_tokens: ["NSTextInputClient", "appkit-insertText"],
        macos_marker_description: "NSTextInputClient and appkit-insertText markers",
      }
    "--scroll-anchor-log" =>
      {
        observation: "imeScrollAnchor",
        label: "scroll anchor log",
        required_tokens: [
          "MoUI native IME scroll anchor passed", "scroll", "candidate-anchor", "candidate-window",
        ],
        marker_description: "MoUI native IME scroll anchor passed with scroll, candidate-anchor, and candidate-window markers",
        macos_required_tokens: ["NSTextInputClient", "appkit-insertText"],
        macos_marker_description: "NSTextInputClient and appkit-insertText markers",
      }
    "--scale-dpr-anchor-log" =>
      {
        observation: "imeScaleDprAnchor",
        label: "scale/DPR anchor log",
        required_tokens: [
          "MoUI native IME scale DPR anchor passed", "scale", "dpr", "candidate-anchor",
          "candidate-window",
        ],
        marker_description: "MoUI native IME scale DPR anchor passed with scale, DPR, candidate-anchor, and candidate-window markers",
        macos_required_tokens: ["NSTextInputClient", "appkit-insertText"],
        macos_marker_description: "NSTextInputClient and appkit-insertText markers",
      }
    _ =>
      {
        observation: "imeResizeAnchor",
        label: "resize anchor log",
        required_tokens: [
          "MoUI native IME resize anchor passed", "resize", "candidate-anchor", "candidate-window",
        ],
        marker_description: "MoUI native IME resize anchor passed with resize, candidate-anchor, and candidate-window markers",
        macos_required_tokens: ["NSTextInputClient", "appkit-insertText"],
        macos_marker_description: "NSTextInputClient and appkit-insertText markers",
      }
  }
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
fn platform_entry(
  manifest : Map[String, Json],
  platform : String,
) -> Map[String, Json]? {
  for value in optional_array(manifest, "platforms") {
    match value {
      Json::Object(entry) if optional_string(entry, "name") == platform =>
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
  platform : String,
  raw_path : String,
) -> Result[ArtifactPath, String] {
  let absolute = collapse_path(@tools.resolve_path(repo_root, raw_path))
  let root = collapse_path(repo_root)
  let prefix = if root.has_suffix("/") { root } else { root + "/" }
  let relative = if absolute == root {
    ""
  } else if absolute.has_prefix(prefix) {
    absolute[prefix.length():].to_owned()
  } else {
    return Err("artifact log must be inside the repository: " + raw_path)
  }
  let expected_prefix = "artifacts/platform-evidence/" + platform + "/"
  if !relative.has_prefix(expected_prefix) {
    return Err(
      "artifact log must stay under " + expected_prefix + ": " + raw_path,
    )
  }
  if relative.contains("../") || relative == ".." {
    return Err("artifact log must be inside the repository: " + raw_path)
  }
  if !@tools.file_exists(absolute) {
    return Err("artifact log does not exist: " + raw_path)
  }
  Ok({ absolute, relative })
}

///|
fn any_contains(text : String, tokens : Array[String]) -> Bool {
  tokens.any(token => text.contains(token))
}

///|
fn all_contains(text : String, tokens : Array[String]) -> Bool {
  tokens.all(token => text.contains(token))
}

///|
fn is_ascii_whitespace_uint16(char : UInt16) -> Bool {
  char == ' ' || char == '\n' || char == '\r' || char == '\t'
}

///|
fn has_whitespace_delimited_token(text : String, token : String) -> Bool {
  if token == "" {
    return false
  }
  let start = Ref(-1)
  for index in 0..<text.length() {
    if is_ascii_whitespace_uint16(text[index]) {
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
fn any_token(text : String, tokens : Array[String]) -> Bool {
  tokens.any(token => has_whitespace_delimited_token(text, token))
}

///|
fn has_utf8_offsets(text : String) -> Bool {
  text.contains("utf8-offsets") ||
  text.contains("utf-8-offsets") ||
  text.contains("UTF-8 offsets")
}

///|
fn validate_runtime_markers(
  text : String,
  spec : PlatformSpec,
  label : String,
) -> Result[Unit, String] {
  if !text.contains("MoUI native IME runtime") ||
    !has_whitespace_delimited_token(text, "matching-host") ||
    !has_whitespace_delimited_token(text, "native-app") ||
    !has_whitespace_delimited_token(text, "renderer=skia") ||
    !has_whitespace_delimited_token(text, "app=showcase") ||
    !any_token(text, spec.protocol_tokens) {
    return Err(
      label +
      " is missing expected marker: MoUI native IME runtime, matching-host, native-app, renderer=skia, app=showcase, and " +
      spec.protocol_description +
      " markers",
    )
  }
  Ok(())
}

///|
fn validate_log_option(
  repo_root : String,
  spec : PlatformSpec,
  option : String,
  raw_path : String,
) -> Result[(String, String), String] {
  let config = log_option(option)
  if raw_path.trim().to_owned() == "" {
    return Err(option + " requires a non-empty path")
  }
  let artifact = match artifact_path(repo_root, spec.name, raw_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let text = match @tools.read_required_text(artifact.absolute, config.label) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if text.trim().to_owned() == "" {
    return Err(config.label + " is empty: " + raw_path)
  }
  match validate_runtime_markers(text, spec, config.label) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  if !all_contains(text, config.required_tokens) ||
    (option == "--surrounding-text-log" && !has_utf8_offsets(text)) {
    return Err(
      config.label + " is missing expected marker: " + config.marker_description,
    )
  }
  if spec.name == "macos" && !all_contains(text, config.macos_required_tokens) {
    return Err(
      config.label +
      " is missing expected marker: " +
      config.macos_marker_description,
    )
  }
  Ok((config.observation, artifact.relative))
}

///|
fn set_observation(
  observations : Map[String, String],
  key : String,
  value : String,
) -> Unit {
  observations[key] = value
}

///|
fn string_set_add(values : Array[String], value : String) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
fn parse_existing_observations(
  entry : Map[String, Json],
) -> Map[String, String] {
  let observations : Map[String, String] = {}
  let existing = match optional_object(entry, "observations") {
    Some(value) => value
    None => {}
  }
  for key in ime_observation_keys {
    let value = match existing.get(key) {
      Some(Json::String(text)) => text
      _ => "pending"
    }
    observations[key] = value
  }
  observations
}

///|
fn existing_artifacts(entry : Map[String, Json]) -> Array[String] {
  json_string_array(optional_array(entry, "artifacts"))
}

///|
fn map_string_or(
  map : Map[String, String],
  key : String,
  fallback : String,
) -> String {
  match map.get(key) {
    Some(value) => value
    None => fallback
  }
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
fn write_plan_json(
  observations : Map[String, String],
  artifacts : Array[String],
  provenance_artifacts : Array[String],
  notes : Array[String],
  status : String,
  host : String,
  consumer_command : String,
  platform : String,
) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\n")
  builder.write_string("  \"platform\": \"" + json_escape(platform) + "\",\n")
  builder.write_string("  \"status\": \"" + json_escape(status) + "\",\n")
  builder.write_string("  \"host\": \"" + json_escape(host) + "\",\n")
  builder.write_string(
    "  \"consumerCommand\": \"" + json_escape(consumer_command) + "\",\n",
  )
  builder.write_string("  \"observations\": {\n")
  for index in 0..<ime_observation_keys.length() {
    let key = ime_observation_keys[index]
    if index > 0 {
      builder.write_string(",\n")
    }
    builder.write_string(
      "    \"" +
      json_escape(key) +
      "\": \"" +
      json_escape(map_string_or(observations, key, "pending")) +
      "\"",
    )
  }
  builder.write_string("\n  },\n")
  builder.write_string("  \"artifacts\": ")
  write_json_string_array(builder, artifacts)
  builder.write_string(",\n")
  builder.write_string("  \"provenanceArtifacts\": ")
  write_json_string_array(builder, provenance_artifacts)
  builder.write_string(",\n")
  builder.write_string("  \"notes\": ")
  write_json_string_array(builder, notes)
  builder.write_string("\n}\n")
  builder.to_string()
}

///|
fn validate_and_plan(options : CliOptions) -> Result[String, String] {
  let spec = match platform_spec(options.platform) {
    Some(value) => value
    None => return Err("Unknown native IME platform: " + options.platform)
  }
  if options.host.trim().to_owned() == "" {
    return Err(
      "--host is required so IME runtime evidence names its matching host",
    )
  }
  if !any_contains(options.host, spec.host_tokens) {
    return Err(
      "--host must name a matching " +
      options.platform +
      " host; got '" +
      options.host +
      "'",
    )
  }
  if options.consumer_command.trim().to_owned() == "" {
    return Err(
      "--consumer-command is required so IME observations name the native app run",
    )
  }
  let normalized_command = normalize_slashes(options.consumer_command)
  let showcase_target = "examples/showcase/" + options.platform + "_skia"
  if !normalized_command.contains(showcase_target) {
    return Err(
      "--consumer-command must name " +
      showcase_target +
      "; got '" +
      options.consumer_command +
      "'",
    )
  }
  let supplied = [
    { option: "--candidate-anchor-log", path: options.candidate_anchor_log },
    { option: "--surrounding-text-log", path: options.surrounding_text_log },
    { option: "--composition-visual-log", path: options.composition_visual_log },
    { option: "--commit-delete-log", path: options.commit_delete_log },
    { option: "--cursor-update-log", path: options.cursor_update_log },
    { option: "--scroll-anchor-log", path: options.scroll_anchor_log },
    { option: "--scale-dpr-anchor-log", path: options.scale_dpr_anchor_log },
    { option: "--resize-anchor-log", path: options.resize_anchor_log },
  ]
  if supplied.all(item => item.path == "") {
    return Err("At least one native IME evidence log option is required")
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
  let entry = match platform_entry(manifest, options.platform) {
    Some(value) => value
    None =>
      return Err(
        options.manifest_path +
        ": platforms must include '" +
        options.platform +
        "'",
      )
  }
  let observations = parse_existing_observations(entry)
  let artifacts = existing_artifacts(entry)
  let provenance_artifacts : Array[String] = []
  for item in supplied {
    if item.path != "" {
      let (observation, artifact) = match
        validate_log_option(options.repo_root, spec, item.option, item.path) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      set_observation(observations, observation, "yes")
      string_set_add(artifacts, artifact)
      string_set_add(provenance_artifacts, artifact)
    }
  }
  let status = if ime_observation_keys.all(key => {
      map_string_or(observations, key, "pending") == "yes"
    }) {
    "complete"
  } else {
    "partial"
  }
  let notes : Array[String] = []
  let default_note = if status == "complete" {
    options.platform +
    " native IME runtime evidence is fully recorded on " +
    options.host +
    "; this still does not prove full platform readiness without the other platform observations and Skia route evidence."
  } else {
    options.platform +
    " native IME runtime evidence is partially recorded on " +
    options.host +
    "; omitted IME observations remain pending and do not prove native IME readiness."
  }
  string_set_add(notes, default_note)
  for note in options.notes {
    if note.trim().to_owned() != "" {
      string_set_add(notes, note)
    }
  }
  Ok(
    write_plan_json(
      observations,
      artifacts,
      provenance_artifacts,
      notes,
      status,
      options.host,
      options.consumer_command,
      options.platform,
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
            "native IME evidence plan",
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
