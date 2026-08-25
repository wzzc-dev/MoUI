///|
struct CliOptions {
  repo_root : String
  status_file : String
  revision_file : String
  provider_lock : String
  status_doc : String
  status_doc_explicit : Bool
  quiet : Bool
  help : Bool
}

///|
struct ProviderLock {
  jetbrains_commit : String
  jetbrains_tag : String
  release_commit : String
  release_tag : String
}

///|
struct PlatformSummary {
  name : String
  accepted : Bool
  accepted_provider : String
  accepted_version : String
  accepted_commit : String
}

///|
struct CiGateContext {
  repo_root : String
  evidence_corpus : String
  evidence_compact : String
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_platform_status [options]
    #|
    #|Checks the platform acceptance, revision, provider lock, and Markdown
    #|matrix contract for skia-platform-status.json.
    #|
    #|Options:
    #|  --repo-root PATH       Repository root used to resolve relative paths. Defaults to cwd.
    #|  --status-file PATH     Platform status JSON file. Defaults to skia-platform-status.json.
    #|  --revision-file PATH   Skia revision file. Defaults to skia-revision.txt.
    #|  --provider-lock PATH   Skia provider lock JSON. Defaults to skia-provider-lock.json.
    #|  --status-doc PATH      Platform status Markdown file. Defaults to SKIA_PLATFORM_STATUS.md.
    #|  --quiet                Suppress success output.
    #|  -h, --help             Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let status_file = Ref("skia-platform-status.json")
  let revision_file = Ref("skia-revision.txt")
  let provider_lock = Ref("skia-provider-lock.json")
  let status_doc = Ref("SKIA_PLATFORM_STATUS.md")
  let status_doc_explicit = Ref(false)
  let quiet = Ref(false)
  let help = Ref(false)
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
      "--status-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --status-file")
        }
        status_file.val = args[index + 1]
        index += 2
      }
      "--revision-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --revision-file")
        }
        revision_file.val = args[index + 1]
        index += 2
      }
      "--provider-lock" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provider-lock")
        }
        provider_lock.val = args[index + 1]
        index += 2
      }
      "--status-doc" => {
        if index + 1 >= args.length() {
          return Err("missing value for --status-doc")
        }
        status_doc.val = args[index + 1]
        status_doc_explicit.val = true
        index += 2
      }
      "--quiet" => {
        quiet.val = true
        index += 1
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({
    repo_root: repo_root.val,
    status_file: status_file.val,
    revision_file: revision_file.val,
    provider_lock: provider_lock.val,
    status_doc: status_doc.val,
    status_doc_explicit: status_doc_explicit.val,
    quiet: quiet.val,
    help: help.val,
  })
}

///|
fn ascii_lower_char(char : Char) -> Char {
  if char >= 'A' && char <= 'Z' {
    Int::unsafe_to_char(char.to_int() + 32)
  } else {
    char
  }
}

///|
fn ascii_lower(value : String) -> String {
  let builder = StringBuilder()
  for char in value {
    builder.write_char(ascii_lower_char(char))
  }
  builder.to_string()
}

///|
fn normalize_slashes(path : String) -> String {
  let builder = StringBuilder()
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
fn basename(path : String) -> String {
  let normalized = normalize_slashes(path)
  let start = Ref(0)
  for index in 0..<normalized.length() {
    if normalized[index] == '/' {
      start.val = index + 1
    }
  }
  normalized[start.val:].to_owned()
}

///|
fn path_is_default_status(options : CliOptions) -> Bool {
  let normalized = normalize_slashes(
    @tools.resolve_path(options.repo_root, options.status_file),
  )
  let default_path = normalize_slashes(
    @tools.resolve_path(options.repo_root, "skia-platform-status.json"),
  )
  normalized == default_path
}

///|
fn json_object(
  value : Json,
  label : String,
) -> Result[Map[String, Json], String] {
  match value {
    Json::Object(fields) => Ok(fields)
    _ => Err(label + " must be an object")
  }
}

///|
fn object_field(
  object : Map[String, Json],
  field : String,
  label : String,
) -> Result[Map[String, Json], String] {
  match object.get(field) {
    Some(Json::Object(fields)) => Ok(fields)
    _ => Err(label + "." + field + " must be an object")
  }
}

///|
fn string_field(
  object : Map[String, Json],
  field : String,
  label : String,
) -> Result[String, String] {
  match object.get(field) {
    Some(Json::String(value)) if value.trim().to_owned() != "" => Ok(value)
    _ => Err(label + "." + field + " must be a non-empty string")
  }
}

///|
fn optional_string_field(object : Map[String, Json], field : String) -> String? {
  match object.get(field) {
    Some(Json::String(value)) => Some(value)
    _ => None
  }
}

///|
fn bool_field(
  object : Map[String, Json],
  field : String,
  label : String,
) -> Result[Bool, String] {
  match object.get(field) {
    Some(Json::True) => Ok(true)
    Some(Json::False) => Ok(false)
    _ => Err(label + "." + field + " must be boolean")
  }
}

///|
fn field_is_present_non_null(
  object : Map[String, Json],
  field : String,
) -> Bool {
  match object.get(field) {
    None | Some(Json::Null) => false
    _ => true
  }
}

///|
fn schema_version(status : Map[String, Json]) -> Result[Int, String] {
  match status.get("schema_version") {
    Some(Json::Number(number, repr=_)) if number == 1.0 => Ok(1)
    Some(Json::Number(number, repr=_)) if number == 2.0 => Ok(2)
    Some(Json::Number(number, repr=_)) if number == 3.0 => Ok(3)
    Some(Json::Number(number, repr=_)) if number == 4.0 => Ok(4)
    _ => Err("unsupported Skia platform status schema_version")
  }
}

///|
fn string_array_field(
  object : Map[String, Json],
  field : String,
) -> Result[Array[String], String] {
  match object.get(field) {
    Some(Json::Array(values)) => {
      let out : Array[String] = []
      for index in 0..<values.length() {
        match values[index] {
          Json::String(value) => out.push(value)
          _ =>
            return Err(
              "platform status " + field + "[\{index}] must be a string",
            )
        }
      }
      Ok(out)
    }
    _ => Err("platform status " + field + " must be a list")
  }
}

///|
fn array_field(
  object : Map[String, Json],
  field : String,
  missing_message : String,
) -> Result[Array[Json], String] {
  match object.get(field) {
    Some(Json::Array(values)) => Ok(values)
    _ => Err(missing_message)
  }
}

///|
fn arrays_equal(left : Array[String], right : Array[String]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
fn put_unique(
  seen : Map[String, Bool],
  value : String,
  duplicate_message : String,
) -> Result[Unit, String] {
  if seen.contains(value) {
    Err(duplicate_message + value)
  } else {
    seen[value] = true
    Ok(())
  }
}

///|
fn sorted_missing(
  required : Array[String],
  seen : Map[String, Bool],
) -> Array[String] {
  let missing : Array[String] = []
  for value in required {
    if !seen.contains(value) {
      missing.push(value)
    }
  }
  missing.sort()
  missing
}

///|
fn compact_whitespace(text : String) -> String {
  let builder = StringBuilder()
  let in_space = Ref(false)
  for char in text {
    let is_space = char == ' ' || char == '\n' || char == '\r' || char == '\t'
    if is_space {
      if !in_space.val {
        builder.write_char(' ')
        in_space.val = true
      }
    } else {
      builder.write_char(char)
      in_space.val = false
    }
  }
  builder.to_string()
}

///|
fn expected_artifact_logs(platform : String) -> Array[String] {
  match platform {
    "linux" =>
      [
        "linux-real-skia-smoke-preflight.log", "linux-real-skia-smoke.log", "linux-native-smoke-output.log",
        "linux-real-skia-acceptance.log",
      ]
    "macos" =>
      [
        "macos-real-skia-smoke-preflight.log", "macos-real-skia-smoke.log", "macos-native-smoke-output.log",
        "macos-real-skia-acceptance.log",
      ]
    "windows" =>
      [
        "windows-real-skia-smoke-preflight.log", "windows-real-skia-smoke.log", "windows-native-smoke-output.log",
        "windows-real-skia-acceptance.log",
      ]
    _ => []
  }
}

///|
fn expected_verifier(platform : String) -> String {
  match platform {
    "linux" =>
      "scripts/verify-real-skia-artifact.sh --platform linux --log-dir logs"
    "macos" =>
      "scripts/verify-real-skia-artifact.sh --platform macos --log-dir logs"
    "windows" =>
      "scripts/verify-real-skia-artifact.ps1 -Platform windows -LogDir logs"
    _ => ""
  }
}

///|
fn provider_lock_from_text(text : String) -> Result[ProviderLock, String] {
  if text == "" {
    return Ok({
      jetbrains_commit: "",
      jetbrains_tag: "",
      release_commit: "",
      release_tag: "",
    })
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("Skia provider lock JSON is invalid")
  }
  let lock = match json_object(parsed, "Skia provider lock JSON root") {
    Ok(value) => value
    Err(_) =>
      return Ok({
        jetbrains_commit: "",
        jetbrains_tag: "",
        release_commit: "",
        release_tag: "",
      })
  }
  let providers = match object_field(lock, "providers", "provider lock") {
    Ok(value) => value
    Err(_) =>
      return Ok({
        jetbrains_commit: "",
        jetbrains_tag: "",
        release_commit: "",
        release_tag: "",
      })
  }
  let jetbrains = match object_field(providers, "jetbrains", "providers") {
    Ok(value) => value
    Err(_) => Map([])
  }
  let release = match object_field(providers, "release", "providers") {
    Ok(value) => value
    Err(_) => Map([])
  }
  Ok({
    jetbrains_commit: ascii_lower(
      optional_string_field(jetbrains, "commit").unwrap_or(""),
    ),
    jetbrains_tag: optional_string_field(jetbrains, "tag").unwrap_or(""),
    release_commit: ascii_lower(
      optional_string_field(release, "commit").unwrap_or(""),
    ),
    release_tag: optional_string_field(release, "tag").unwrap_or(""),
  })
}

///|
fn normalize_repo_relative_path(path : String) -> Result[String, String] {
  let normalized = normalize_slashes(path.trim().to_owned())
  let current = Ref(normalized)
  while current.val.has_prefix("./") {
    current.val = current.val[2:].to_owned()
  }
  if current.val == "" {
    return Err("CI gate evidence file is missing path")
  }
  if current.val.has_prefix("/") ||
    current.val.split("/").any(part => part == "..") {
    return Err("CI gate evidence file must be repo-relative: " + path)
  }
  Ok(current.val)
}

///|
fn resolve_ci_gate_evidence_text(
  repo_root : String,
  evidence_path : String,
) -> Result[String, String] {
  let primary = @tools.join_path(repo_root, evidence_path)
  if @tools.file_exists(primary) {
    return @tools.read_required_text(primary, "CI gate evidence file")
  }
  if evidence_path.has_prefix(".github/workflows/") {
    let workspace_path = @tools.join_path(
      @tools.join_path(repo_root, ".."),
      evidence_path,
    )
    if @tools.file_exists(workspace_path) {
      return @tools.read_required_text(workspace_path, "CI gate evidence file")
    }
  }
  Err("CI gate evidence file is missing: " + evidence_path)
}

///|
fn build_ci_gate_context(
  status_text : String,
  repo_root : String,
) -> Result[CiGateContext?, String] {
  let parsed = @json.parse(status_text) catch {
    _ => return Err("Skia platform status JSON is invalid")
  }
  let status = match json_object(parsed, "Skia platform status JSON root") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let schema = match schema_version(status) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if schema < 4 {
    return Ok(None)
  }
  let evidence_values = match
    array_field(
      status, "ci_gate_evidence_files", "schema v4 platform status is missing ci_gate_evidence_files list",
    ) {
    Ok(values) if !values.is_empty() => values
    _ =>
      return Err(
        "schema v4 platform status is missing ci_gate_evidence_files list",
      )
  }
  let seen : Map[String, Bool] = Map([])
  let parts : Array[String] = []
  for value in evidence_values {
    let raw = match value {
      Json::String(text) => text
      _ => return Err("CI gate evidence file is missing path")
    }
    let evidence_path = match normalize_repo_relative_path(raw) {
      Ok(path) => path
      Err(message) => return Err(message)
    }
    match put_unique(seen, evidence_path, "duplicate CI gate evidence file: ") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    let text = match resolve_ci_gate_evidence_text(repo_root, evidence_path) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    parts.push(text)
  }
  let missing = sorted_missing(required_ci_gate_evidence_files(), seen)
  if !missing.is_empty() {
    return Err(
      "CI gate evidence is missing files: " + @tools.comma_join(missing),
    )
  }
  let builder = StringBuilder()
  for index in 0..<parts.length() {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(parts[index])
  }
  let corpus = normalize_slashes(builder.to_string())
  Ok(
    Some({
      repo_root,
      evidence_corpus: corpus,
      evidence_compact: compact_whitespace(corpus),
    }),
  )
}

///|
fn strip_token_quotes(token : String) -> String {
  let trimmed = token.trim().to_owned()
  let start = if trimmed.length() > 0 &&
    (trimmed[0] == '\'' || trimmed[0] == '"') {
    1
  } else {
    0
  }
  let end = if trimmed.length() > start &&
    (
      trimmed[trimmed.length() - 1] == '\'' ||
      trimmed[trimmed.length() - 1] == '"'
    ) {
    trimmed.length() - 1
  } else {
    trimmed.length()
  }
  trimmed[start:end].to_owned()
}

///|
fn strip_leading_dot_slash(value : String) -> String {
  let current = Ref(value)
  while current.val.has_prefix("./") {
    current.val = current.val[2:].to_owned()
  }
  current.val
}

///|
fn split_command_tokens(command : String) -> Array[String] {
  let tokens : Array[String] = []
  let builder = StringBuilder()
  let flush = fn() {
    let token = builder.to_string().trim().to_owned()
    if token != "" {
      tokens.push(token)
    }
    builder.reset()
  }
  for char in normalize_slashes(command) {
    if char == ' ' ||
      char == '\n' ||
      char == '\r' ||
      char == '\t' ||
      char == ';' ||
      char == '&' ||
      char == '|' {
      flush()
    } else {
      builder.write_char(char)
    }
  }
  flush()
  tokens
}

///|
fn ci_gate_script_paths(command : String) -> Array[String] {
  let paths : Array[String] = []
  for token in split_command_tokens(command) {
    let path = strip_leading_dot_slash(strip_token_quotes(token))
    if path.has_prefix("scripts/") &&
      (path.has_suffix(".sh") || path.has_suffix(".ps1")) {
      paths.push(path)
    }
  }
  paths
}

///|
fn split_command_parts(command : String) -> Array[String] {
  let parts : Array[String] = []
  let builder = StringBuilder()
  let flush = fn() {
    let part = compact_whitespace(builder.to_string()).trim().to_owned()
    if part != "" {
      parts.push(part)
    }
    builder.reset()
  }
  for char in normalize_slashes(command) {
    if char == '\n' || char == ';' || char == '&' || char == '|' {
      flush()
    } else {
      builder.write_char(char)
    }
  }
  flush()
  parts
}

///|
fn ci_gate_evidence_terms(command : String) -> Array[String] {
  let script_paths = ci_gate_script_paths(command)
  if !script_paths.is_empty() {
    let terms : Array[String] = []
    for path in script_paths {
      terms.push(path)
    }
    for token in split_command_tokens(command) {
      let option = strip_token_quotes(token)
      if option.has_prefix("-") && option != "-n" {
        terms.push(option)
      }
    }
    return terms
  }
  split_command_parts(command)
}

///|
fn verify_ci_gate_contract(
  status : Map[String, Json],
  context : CiGateContext,
) -> Result[Unit, String] {
  let gates = match
    array_field(
      status, "ci_gates", "schema v4 platform status is missing ci_gates list",
    ) {
    Ok(values) if !values.is_empty() => values
    _ => return Err("schema v4 platform status is missing ci_gates list")
  }
  let seen_gate_ids : Map[String, Bool] = Map([])
  let seen_gate_commands : Map[String, Bool] = Map([])
  let seen_gate_areas : Map[String, Bool] = Map([])
  for gate_json in gates {
    let gate = match json_object(gate_json, "ci_gates entries") {
      Ok(value) => value
      Err(_) => return Err("ci_gates entries must be objects")
    }
    let gate_id = optional_string_field(gate, "id")
      .unwrap_or("")
      .trim()
      .to_owned()
    let area = optional_string_field(gate, "area")
      .unwrap_or("")
      .trim()
      .to_owned()
    let unix_command = optional_string_field(gate, "unix_command")
      .unwrap_or("")
      .trim()
      .to_owned()
    let powershell_command = optional_string_field(gate, "powershell_command")
      .unwrap_or("")
      .trim()
      .to_owned()
    if gate_id == "" {
      return Err("CI gate is missing id")
    }
    if area == "" {
      return Err("CI gate is missing area: " + gate_id)
    }
    if unix_command == "" && powershell_command == "" {
      return Err("CI gate is missing verifier command: " + gate_id)
    }
    match put_unique(seen_gate_ids, gate_id, "duplicate CI gate id: ") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    seen_gate_areas[area] = true
    for command in [unix_command, powershell_command] {
      if command == "" {
        continue
      }
      let command_key = area + "\n" + command
      match
        put_unique(
          seen_gate_commands, command_key, "duplicate CI gate command: ",
        ) {
        Ok(_) => ()
        Err(_) => return Err("duplicate CI gate command: " + command)
      }
      for script_path in ci_gate_script_paths(command) {
        if !@tools.file_exists(@tools.join_path(context.repo_root, script_path)) {
          return Err(
            "CI gate references missing verifier script: " +
            gate_id +
            ": " +
            script_path,
          )
        }
      }
      for term in ci_gate_evidence_terms(command) {
        if !context.evidence_corpus.contains(term) &&
          !context.evidence_compact.contains(term) {
          return Err(
            "CI gate evidence is missing command wiring: " +
            gate_id +
            ": " +
            term,
          )
        }
      }
    }
  }
  let missing_ids = sorted_missing(required_ci_gate_ids(), seen_gate_ids)
  if !missing_ids.is_empty() {
    return Err(
      "CI gate coverage is missing ids: " + @tools.comma_join(missing_ids),
    )
  }
  let missing_areas = sorted_missing(
    ["MoonBit", "NativeSmoke", "FFI", "PlatformStatus", "Artifact"],
    seen_gate_areas,
  )
  if !missing_areas.is_empty() {
    return Err(
      "CI gate coverage is missing areas: " + @tools.comma_join(missing_areas),
    )
  }
  Ok(())
}

///|
fn verify_native_smoke_contract(
  status : Map[String, Json],
  schema : Int,
) -> Result[Unit, String] {
  if schema < 3 {
    return Ok(())
  }
  let capabilities = match
    array_field(
      status, "native_smoke_capabilities", "schema v3 platform status is missing native_smoke_capabilities list",
    ) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  let seen_ids : Map[String, Bool] = Map([])
  let seen_markers : Map[String, Bool] = Map([])
  let seen_areas : Map[String, Bool] = Map([])
  for capability_json in capabilities {
    let capability = match
      json_object(capability_json, "native_smoke_capabilities entries") {
      Ok(value) => value
      Err(_) => return Err("native_smoke_capabilities entries must be objects")
    }
    let capability_id = optional_string_field(capability, "id")
      .unwrap_or("")
      .trim()
      .to_owned()
    let area = optional_string_field(capability, "area")
      .unwrap_or("")
      .trim()
      .to_owned()
    let marker = optional_string_field(capability, "marker")
      .unwrap_or("")
      .trim()
      .to_owned()
    if capability_id == "" {
      return Err("native smoke capability is missing id")
    }
    if area == "" {
      return Err("native smoke capability is missing area: " + capability_id)
    }
    if marker == "" {
      return Err("native smoke capability is missing marker: " + capability_id)
    }
    match
      put_unique(
        seen_ids, capability_id, "duplicate native smoke capability id: ",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    match
      put_unique(
        seen_markers, marker, "duplicate native smoke capability marker: ",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    seen_areas[area] = true
  }
  let missing_ids = sorted_missing(
    required_native_smoke_capability_ids(),
    seen_ids,
  )
  if !missing_ids.is_empty() {
    return Err(
      "native smoke capability coverage is missing ids: " +
      @tools.comma_join(missing_ids),
    )
  }
  let missing_areas = sorted_missing(required_native_smoke_areas(), seen_areas)
  if !missing_areas.is_empty() {
    return Err(
      "native smoke capability coverage is missing areas: " +
      @tools.comma_join(missing_areas),
    )
  }
  if schema < 4 {
    return Ok(())
  }
  let conditional_capabilities = match
    array_field(
      status, "native_smoke_conditional_capabilities", "schema v4 platform status is missing native_smoke_conditional_capabilities list",
    ) {
    Ok(values) if !values.is_empty() => values
    _ =>
      return Err(
        "schema v4 platform status is missing native_smoke_conditional_capabilities list",
      )
  }
  let seen_conditional_ids : Map[String, Bool] = Map([])
  let seen_conditional_markers : Map[String, Bool] = Map([])
  for conditional_json in conditional_capabilities {
    let conditional = match
      json_object(
        conditional_json, "native_smoke_conditional_capabilities entries",
      ) {
      Ok(value) => value
      Err(_) =>
        return Err(
          "native_smoke_conditional_capabilities entries must be objects",
        )
    }
    let conditional_id = optional_string_field(conditional, "id")
      .unwrap_or("")
      .trim()
      .to_owned()
    let area = optional_string_field(conditional, "area")
      .unwrap_or("")
      .trim()
      .to_owned()
    let marker = optional_string_field(conditional, "marker")
      .unwrap_or("")
      .trim()
      .to_owned()
    let when_marker = optional_string_field(conditional, "when_marker")
      .unwrap_or("")
      .trim()
      .to_owned()
    let when_value = optional_string_field(conditional, "when_value")
      .unwrap_or("")
      .trim()
      .to_owned()
    if conditional_id == "" {
      return Err("native smoke conditional capability is missing id")
    }
    if area == "" {
      return Err(
        "native smoke conditional capability is missing area: " + conditional_id,
      )
    }
    if marker == "" {
      return Err(
        "native smoke conditional capability is missing marker: " +
        conditional_id,
      )
    }
    if when_marker == "" {
      return Err(
        "native smoke conditional capability is missing when_marker: " +
        conditional_id,
      )
    }
    if when_value == "" {
      return Err(
        "native smoke conditional capability is missing when_value: " +
        conditional_id,
      )
    }
    match
      put_unique(
        seen_conditional_ids, conditional_id, "duplicate native smoke conditional capability id: ",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    if seen_markers.contains(marker) ||
      seen_conditional_markers.contains(marker) {
      return Err(
        "duplicate native smoke conditional capability marker: " + marker,
      )
    }
    seen_conditional_markers[marker] = true
    if !seen_markers.contains(when_marker) {
      return Err(
        "native smoke conditional capability references unknown condition marker: " +
        conditional_id +
        ": " +
        when_marker,
      )
    }
    for required in required_native_smoke_conditionals() {
      if required.id == conditional_id {
        if area != required.area {
          return Err(
            "native smoke conditional capability mismatch: " +
            conditional_id +
            ": area",
          )
        }
        if marker != required.marker {
          return Err(
            "native smoke conditional capability mismatch: " +
            conditional_id +
            ": marker",
          )
        }
        if when_marker != required.when_marker {
          return Err(
            "native smoke conditional capability mismatch: " +
            conditional_id +
            ": when_marker",
          )
        }
        if when_value != required.when_value {
          return Err(
            "native smoke conditional capability mismatch: " +
            conditional_id +
            ": when_value",
          )
        }
      }
    }
  }
  let required_conditional_seen : Map[String, Bool] = Map([])
  for required in required_native_smoke_conditionals() {
    if seen_conditional_ids.contains(required.id) {
      required_conditional_seen[required.id] = true
    }
  }
  let missing_conditional_ids = sorted_missing(
    required_native_smoke_conditionals().map(item => item.id),
    required_conditional_seen,
  )
  if !missing_conditional_ids.is_empty() {
    return Err(
      "native smoke conditional capability coverage is missing ids: " +
      @tools.comma_join(missing_conditional_ids),
    )
  }
  let expected_values = match
    array_field(
      status, "native_smoke_expected_values", "schema v4 platform status is missing native_smoke_expected_values list",
    ) {
    Ok(values) if !values.is_empty() => values
    _ =>
      return Err(
        "schema v4 platform status is missing native_smoke_expected_values list",
      )
  }
  let seen_expected_markers : Map[String, String] = Map([])
  for expected_json in expected_values {
    let expected = match
      json_object(expected_json, "native_smoke_expected_values entries") {
      Ok(value) => value
      Err(_) =>
        return Err("native_smoke_expected_values entries must be objects")
    }
    let expected_id = optional_string_field(expected, "id")
      .unwrap_or("")
      .trim()
      .to_owned()
    let marker = optional_string_field(expected, "marker")
      .unwrap_or("")
      .trim()
      .to_owned()
    let value = optional_string_field(expected, "value")
      .unwrap_or("")
      .trim()
      .to_owned()
    if expected_id == "" {
      return Err("native smoke expected value is missing id")
    }
    if !seen_ids.contains(expected_id) {
      return Err(
        "native smoke expected value references unknown capability id: " +
        expected_id,
      )
    }
    if marker == "" {
      return Err(
        "native smoke expected value is missing marker: " + expected_id,
      )
    }
    if !seen_markers.contains(marker) {
      return Err(
        "native smoke expected value references unknown marker: " + marker,
      )
    }
    if value == "" {
      return Err("native smoke expected value is missing value: " + marker)
    }
    if seen_expected_markers.contains(marker) {
      return Err("duplicate native smoke expected value marker: " + marker)
    }
    seen_expected_markers[marker] = value
  }
  for required in required_native_smoke_expected_values() {
    match seen_expected_markers.get(required.marker) {
      None =>
        return Err(
          "native smoke expected value coverage is missing marker: " +
          required.marker,
        )
      Some(actual) =>
        if actual != required.value {
          return Err(
            "native smoke expected value mismatch: " +
            required.marker +
            ": expected " +
            required.value,
          )
        }
    }
  }
  Ok(())
}

///|
fn verify_platform_entry(
  platform : String,
  entry : Map[String, Json],
  schema : Int,
  revision : String,
) -> Result[PlatformSummary, String] {
  let accepted = match
    bool_field(entry, "accepted", "platform status." + platform) {
    Ok(value) => value
    Err(_) => return Err("platform accepted flag must be boolean: " + platform)
  }
  match string_field(entry, "state", "platform status." + platform) {
    Ok(_) => ()
    Err(_) => return Err("platform status is missing state: " + platform)
  }
  let required_artifact_logs = match
    string_array_field(entry, "required_artifact_logs") {
    Ok(value) => value
    Err(_) =>
      return Err(
        "platform status required_artifact_logs do not match expected contract: " +
        platform,
      )
  }
  if !arrays_equal(required_artifact_logs, expected_artifact_logs(platform)) {
    return Err(
      "platform status required_artifact_logs do not match expected contract: " +
      platform,
    )
  }
  let verifier = optional_string_field(entry, "required_verifier").unwrap_or("")
  if verifier != expected_verifier(platform) {
    return Err(
      "platform status required_verifier does not match expected verifier: " +
      platform,
    )
  }
  match string_field(entry, "next_step", "platform status." + platform) {
    Ok(_) => ()
    Err(_) => return Err("platform status is missing next step: " + platform)
  }

  if accepted {
    match
      string_field(entry, "accepted_artifact", "platform status." + platform) {
      Ok(_) => ()
      Err(_) =>
        return Err(
          "accepted platform is missing accepted_artifact: " + platform,
        )
    }
    let accepted_commit = match
      string_field(entry, "accepted_commit", "platform status." + platform) {
      Ok(value) => value
      Err(_) =>
        return Err("accepted platform is missing accepted_commit: " + platform)
    }
    if !@skia_acceptance.full_hex_hash(accepted_commit) {
      return Err("accepted platform is missing accepted_commit: " + platform)
    }
    let accepted_provider = if schema >= 2 {
      optional_string_field(entry, "accepted_provider").unwrap_or("")
    } else {
      "source"
    }
    let accepted_version = if schema >= 2 {
      optional_string_field(entry, "accepted_version").unwrap_or("")
    } else {
      revision
    }
    if accepted_provider != "source" &&
      accepted_provider != "jetbrains" &&
      accepted_provider != "release" {
      return Err(
        "accepted platform has unsupported accepted_provider: " + platform,
      )
    }
    if accepted_version == "" {
      return Err("accepted platform is missing accepted_version: " + platform)
    }
    Ok({
      name: platform,
      accepted,
      accepted_provider,
      accepted_version,
      accepted_commit: ascii_lower(accepted_commit),
    })
  } else {
    if field_is_present_non_null(entry, "accepted_artifact") {
      return Err(
        "unaccepted platform must not record accepted_artifact: " + platform,
      )
    }
    if field_is_present_non_null(entry, "accepted_commit") {
      return Err(
        "unaccepted platform must not record accepted_commit: " + platform,
      )
    }
    if schema >= 2 && field_is_present_non_null(entry, "accepted_provider") {
      return Err(
        "unaccepted platform must not record accepted_provider: " + platform,
      )
    }
    if schema >= 2 && field_is_present_non_null(entry, "accepted_version") {
      return Err(
        "unaccepted platform must not record accepted_version: " + platform,
      )
    }
    Ok({
      name: platform,
      accepted,
      accepted_provider: "",
      accepted_version: "",
      accepted_commit: "",
    })
  }
}

///|
fn platform_summary(
  summaries : Array[PlatformSummary],
  platform : String,
) -> PlatformSummary? {
  for summary in summaries {
    if summary.name == platform {
      return Some(summary)
    }
  }
  None
}

///|
fn platform_display_name(platform : String) -> String {
  match platform {
    "linux" => "Linux"
    "macos" => "macOS"
    "windows" => "Windows"
    _ => platform
  }
}

///|
fn verify_provider_alignment(
  summaries : Array[PlatformSummary],
  revision : String,
  provider_lock : ProviderLock,
) -> Result[Unit, String] {
  let source_accepted : Array[String] = []
  for summary in summaries {
    if summary.accepted && summary.accepted_provider == "source" {
      source_accepted.push(summary.name)
    }
  }
  if revision == "main" && !source_accepted.is_empty() {
    return Err(
      "source platforms cannot be accepted while skia-revision.txt is still main: " +
      @tools.comma_join(source_accepted),
    )
  }
  if revision != "main" && !@skia_acceptance.full_hex_hash(revision) {
    return Err(
      "Skia revision must be main or a full 40-character commit: " + revision,
    )
  }
  for summary in summaries {
    if !summary.accepted {
      continue
    }
    match summary.accepted_provider {
      "source" => {
        if summary.accepted_commit != ascii_lower(revision) {
          return Err(
            "accepted platform commit does not match pinned revision: platform=" +
            summary.name +
            " accepted_commit=" +
            summary.accepted_commit +
            " revision=" +
            revision,
          )
        }
        if summary.accepted_version != revision {
          return Err(
            "accepted source platform version does not match pinned revision: platform=" +
            summary.name +
            " accepted_version=" +
            summary.accepted_version +
            " revision=" +
            revision,
          )
        }
      }
      "jetbrains" => {
        if provider_lock.jetbrains_commit == "" ||
          provider_lock.jetbrains_tag == "" {
          return Err("JetBrains provider lock is missing tag or commit")
        }
        if summary.accepted_commit != provider_lock.jetbrains_commit {
          return Err(
            "accepted JetBrains platform commit does not match provider lock: platform=" +
            summary.name +
            " accepted_commit=" +
            summary.accepted_commit +
            " jetbrains_commit=" +
            provider_lock.jetbrains_commit,
          )
        }
        if summary.accepted_version != provider_lock.jetbrains_tag {
          return Err(
            "accepted JetBrains platform version does not match provider lock tag: platform=" +
            summary.name +
            " accepted_version=" +
            summary.accepted_version +
            " jetbrains_tag=" +
            provider_lock.jetbrains_tag,
          )
        }
      }
      "release" => {
        if provider_lock.release_commit == "" || provider_lock.release_tag == "" {
          return Err("release provider lock is missing tag or commit")
        }
        if summary.accepted_commit != provider_lock.release_commit {
          return Err(
            "accepted release platform commit does not match provider lock: platform=" +
            summary.name +
            " accepted_commit=" +
            summary.accepted_commit +
            " release_commit=" +
            provider_lock.release_commit,
          )
        }
        if summary.accepted_version != provider_lock.release_tag {
          return Err(
            "accepted release platform version does not match provider lock tag: platform=" +
            summary.name +
            " accepted_version=" +
            summary.accepted_version +
            " release_tag=" +
            provider_lock.release_tag,
          )
        }
      }
      _ => ()
    }
  }
  Ok(())
}

///|
fn trim_outer_pipe(line : String) -> String {
  let trimmed = line.trim().to_owned()
  let start = if trimmed.length() > 0 && trimmed[0] == '|' { 1 } else { 0 }
  let end = if trimmed.length() > start && trimmed[trimmed.length() - 1] == '|' {
    trimmed.length() - 1
  } else {
    trimmed.length()
  }
  trimmed[start:end].to_owned()
}

///|
fn markdown_cells(line : String) -> Array[String] {
  let cells : Array[String] = []
  for cell in trim_outer_pipe(line).split("|") {
    cells.push(cell.trim().to_owned())
  }
  cells
}

///|
fn verify_status_doc(
  status_doc_text : String,
  summaries : Array[PlatformSummary],
) -> Result[Unit, String] {
  let rows : Map[String, Array[String]] = Map([])
  let in_current_matrix = Ref(false)
  for line in status_doc_text.split("\n") {
    let stripped = line.trim().to_owned()
    if stripped == "## Current Matrix" {
      in_current_matrix.val = true
      continue
    }
    if in_current_matrix.val && stripped.has_prefix("## ") {
      break
    }
    if !in_current_matrix.val || !stripped.has_prefix("|") {
      continue
    }
    let cells = markdown_cells(stripped)
    if cells.length() >= 4 {
      match cells[0] {
        "Linux" => rows["linux"] = cells
        "macOS" => rows["macos"] = cells
        "Windows" => rows["windows"] = cells
        _ => ()
      }
    }
  }
  for platform in ["linux", "macos", "windows"] {
    let display_name = platform_display_name(platform)
    let cells = match rows.get(platform) {
      Some(value) => value
      None =>
        return Err(
          "platform status Markdown matrix is missing row: " + display_name,
        )
    }
    let summary = match platform_summary(summaries, platform) {
      Some(value) => value
      None => continue
    }
    let row_text_builder = StringBuilder()
    for index in 1..<cells.length() {
      if index > 1 {
        row_text_builder.write_char(' ')
      }
      row_text_builder.write_string(cells[index])
    }
    let row_text = ascii_lower(row_text_builder.to_string())
    let state_cell = ascii_lower(cells[1])
    if summary.accepted {
      if !state_cell.contains("accepted") || state_cell.contains("not accepted") {
        return Err(
          "platform status Markdown matrix does not mark accepted platform: " +
          display_name,
        )
      }
      if summary.accepted_provider != "" &&
        !row_text.contains(ascii_lower(summary.accepted_provider)) {
        return Err(
          "platform status Markdown matrix is missing accepted provider: " +
          display_name +
          ": " +
          summary.accepted_provider,
        )
      }
      if summary.accepted_version != "" &&
        !row_text.contains(ascii_lower(summary.accepted_version)) {
        return Err(
          "platform status Markdown matrix is missing accepted version: " +
          display_name +
          ": " +
          summary.accepted_version,
        )
      }
    } else if !state_cell.contains("not accepted") {
      return Err(
        "platform status Markdown matrix does not mark unaccepted platform: " +
        display_name,
      )
    }
  }
  Ok(())
}

///|
fn verify_platform_status_texts(
  status_text : String,
  revision_text : String,
  provider_lock_text : String,
  status_doc_text : String?,
  status_file_name : String,
  revision_file_name : String,
  check_status_doc : Bool,
  ci_gate_context : CiGateContext?,
) -> Result[String, String] {
  let parsed_status = @json.parse(status_text) catch {
    _ => return Err("Skia platform status JSON is invalid")
  }
  let status = match
    json_object(parsed_status, "Skia platform status JSON root") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let schema = match schema_version(status) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match verify_native_smoke_contract(status, schema) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  if schema >= 4 {
    match ci_gate_context {
      Some(context) =>
        match verify_ci_gate_contract(status, context) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      None => ()
    }
  }
  let revision_file = optional_string_field(status, "revision_file").unwrap_or(
    "",
  )
  if revision_file != revision_file_name {
    return Err(
      "status revision_file does not match requested revision file: status=" +
      revision_file +
      " revision=" +
      revision_file_name,
    )
  }
  let revision = @skia_acceptance.first_pinned_revision(revision_text)
  if revision == "" {
    return Err("Skia revision file does not contain a revision")
  }
  let provider_lock = match provider_lock_from_text(provider_lock_text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let platform_entries = match
    object_field(status, "platforms", "platform status") {
    Ok(value) => value
    Err(_) => return Err("platform status is missing platforms object")
  }
  let summaries : Array[PlatformSummary] = []
  for platform in ["linux", "macos", "windows"] {
    let entry_json = match platform_entries.get(platform) {
      Some(value) => value
      None =>
        return Err("platform status is missing required platform: " + platform)
    }
    let entry = match json_object(entry_json, "platform status entry") {
      Ok(value) => value
      Err(_) =>
        return Err("platform status entry is not an object: " + platform)
    }
    match verify_platform_entry(platform, entry, schema, revision) {
      Ok(summary) => summaries.push(summary)
      Err(message) => return Err(message)
    }
  }
  match verify_provider_alignment(summaries, revision, provider_lock) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let linux_entry = match
    object_field(platform_entries, "linux", "platform status") {
    Ok(value) => value
    Err(_) => return Err("platform status entry is not an object: linux")
  }
  let windows_entry = match
    object_field(platform_entries, "windows", "platform status") {
    Ok(value) => value
    Err(_) => return Err("platform status entry is not an object: windows")
  }
  match linux_entry.get("first_acceptance_platform") {
    Some(Json::True) => ()
    _ =>
      return Err(
        "Linux must remain the first acceptance platform until the initial source-built pin is established",
      )
  }
  match linux_entry.get("source_build") {
    Some(Json::True) => ()
    _ =>
      return Err(
        "Linux status must keep source_build=true for first acceptance",
      )
  }
  match windows_entry.get("source_build") {
    Some(Json::True) =>
      return Err(
        "Windows status must not claim source_build=true until a repeatable Windows Skia build path exists",
      )
    _ => ()
  }
  if check_status_doc {
    match status_doc_text {
      Some(text) =>
        match verify_status_doc(text, summaries) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      None =>
        return Err(
          "Skia platform status Markdown file is missing: " + status_file_name,
        )
    }
  }
  Ok(revision)
}

///|
fn read_optional_text(path : String) -> Result[String, String] {
  if !@tools.file_exists(path) {
    return Ok("")
  }
  @tools.read_required_text(path, "optional file")
}

///|
fn verify_platform_status(options : CliOptions) -> Result[String, String] {
  let status_path = @tools.resolve_path(options.repo_root, options.status_file)
  let revision_path = @tools.resolve_path(
    options.repo_root,
    options.revision_file,
  )
  let provider_lock_path = @tools.resolve_path(
    options.repo_root,
    options.provider_lock,
  )
  let status_doc_path = @tools.resolve_path(
    options.repo_root,
    options.status_doc,
  )
  let status_text = match
    @tools.read_required_text(status_path, "Skia platform status file") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let revision_text = match
    @tools.read_required_text(revision_path, "Skia revision file") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let provider_lock_text = match read_optional_text(provider_lock_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let should_check_status_doc = options.status_doc_explicit ||
    path_is_default_status(options)
  let ci_gate_context = match
    build_ci_gate_context(status_text, options.repo_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let status_doc_text = if should_check_status_doc {
    match
      @tools.read_required_text(
        status_doc_path, "Skia platform status Markdown file",
      ) {
      Ok(value) => Some(value)
      Err(message) => return Err(message)
    }
  } else {
    None
  }
  let revision = match
    verify_platform_status_texts(
      status_text,
      revision_text,
      provider_lock_text,
      status_doc_text,
      status_path,
      basename(revision_path),
      should_check_status_doc,
      ci_gate_context,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(
    "Verified Skia platform status in " +
    status_path +
    " with revision " +
    revision +
    ".",
  )
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match verify_platform_status(options) {
        Ok(message) => {
          if !options.quiet {
            println(message)
          }
          0
        }
        Err(message) => {
          println(message)
          1
        }
      }
    Err(message) => {
      println(message)
      println(usage())
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
