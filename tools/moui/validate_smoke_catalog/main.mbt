///|
struct CliOptions {
  repo_root : String
  manifest : String
  mode : String
  tier : String?
  gate_plan : Bool
  gate_mode : String
  suites : Array[String]
  platform : String?
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: node scripts/smoke-check.mjs [options]
    #|       moon run tools/moui/validate_smoke_catalog --target native -- [options]
    #|
    #|Validates the checked-in MoUI smoke gate catalog and prints smoke plans.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root used to resolve paths. Defaults to cwd.
    #|  --manifest PATH    Smoke gate catalog path. Default: smoke/gates.json
    #|  --check            Validate only. This is the default.
    #|  --list             Print a human-readable suite list.
    #|  --json             Print a normalized JSON plan.
    #|  --tier TIER        Filter suites to daily, nightly, or release.
    #|  --gate-plan        Print a smoke-gate dry-run/run plan.
    #|  --suite ID         Select a suite id for --gate-plan. Repeatable.
    #|  --platform NAME    Replace <macos|web|windows|linux> placeholders.
    #|  --dry-run          Set --gate-plan mode to dry-run. This is the default.
    #|  --run              Set --gate-plan mode to run.
    #|  -h, --help         Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let manifest = Ref("smoke/gates.json")
  let mode = Ref("check")
  let tier : Ref[String?] = Ref(None)
  let gate_plan = Ref(false)
  let gate_mode = Ref("dry-run")
  let suites : Array[String] = []
  let platform : Ref[String?] = Ref(None)
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
      "--manifest" => {
        if index + 1 >= args.length() {
          return Err("missing value for --manifest")
        }
        manifest.val = args[index + 1]
        index += 2
      }
      "--check" => {
        mode.val = "check"
        index += 1
      }
      "--list" => {
        mode.val = "list"
        index += 1
      }
      "--json" => {
        mode.val = "json"
        index += 1
      }
      "--tier" => {
        if index + 1 >= args.length() {
          return Err("missing value for --tier")
        }
        tier.val = Some(args[index + 1])
        index += 2
      }
      "--gate-plan" => {
        gate_plan.val = true
        index += 1
      }
      "--suite" => {
        if index + 1 >= args.length() {
          return Err("missing value for --suite")
        }
        suites.push(args[index + 1])
        index += 2
      }
      "--platform" => {
        if index + 1 >= args.length() {
          return Err("missing value for --platform")
        }
        platform.val = Some(args[index + 1])
        index += 2
      }
      "--dry-run" => {
        gate_mode.val = "dry-run"
        index += 1
      }
      "--run" => {
        gate_mode.val = "run"
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
    manifest: manifest.val,
    mode: mode.val,
    tier: tier.val,
    gate_plan: gate_plan.val,
    gate_mode: gate_mode.val,
    suites,
    platform: platform.val,
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
fn json_object_field(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn json_array_field(value : Json?) -> Array[Json] {
  match value {
    Some(Json::Array(values)) => values
    _ => []
  }
}

///|
fn json_string(value : Json?) -> String? {
  match value {
    Some(Json::String(text)) => Some(text)
    _ => None
  }
}

///|
fn json_non_empty_string(value : Json?) -> String? {
  match value {
    Some(Json::String(text)) if text.trim().to_owned() != "" => Some(text)
    _ => None
  }
}

///|
fn json_bool(value : Json?) -> Bool? {
  match value {
    Some(Json::True) => Some(true)
    Some(Json::False) => Some(false)
    _ => None
  }
}

///|
fn json_number_is_one(value : Json?) -> Bool {
  match value {
    Some(Json::Number(number, repr=_)) => number == 1.0
    _ => false
  }
}

///|
fn array_contains(values : Array[String], needle : String) -> Bool {
  values.any(value => value == needle)
}

///|
fn repo_path_exists(repo_root : String, path : String) -> Bool {
  let resolved = @tools.resolve_path(repo_root, path)
  @tools.file_exists(resolved) || @tools.directory_exists(resolved)
}

///|
fn looks_like_repo_path(value : String) -> Bool {
  value.has_prefix("scripts/") ||
  value.has_prefix("docs/") ||
  value.has_prefix("smoke/") ||
  value.has_prefix(".github/") ||
  value.has_prefix("artifacts/")
}

///|
fn valid_id_start(char : Char) -> Bool {
  ('a' <= char && char <= 'z') || ('0' <= char && char <= '9')
}

///|
fn valid_id_char(char : Char) -> Bool {
  valid_id_start(char) || char == '.' || char == '-'
}

///|
fn valid_suite_id(value : String) -> Bool {
  let count = Ref(0)
  let first_ok = Ref(false)
  for char in value {
    if count.val == 0 {
      first_ok.val = valid_id_start(char)
    }
    if !valid_id_char(char) {
      return false
    }
    count.val += 1
  }
  first_ok.val && count.val >= 2
}

///|
fn push(failures : Array[String], message : String) -> Unit {
  failures.push(message)
}

///|
fn string_array_from_json(values : Array[Json]) -> Array[String] {
  let strings : Array[String] = []
  for value in values {
    match value {
      Json::String(text) => strings.push(text)
      _ => ()
    }
  }
  strings
}

///|
fn command_label(suite : Map[String, Json], command_index : Int) -> String {
  let id = json_string(suite.get("id")).unwrap_or("")
  id + ".commands[\{command_index}]"
}

///|
fn validate_command(
  repo_root : String,
  suite : Map[String, Json],
  command : Json,
  command_index : Int,
  failures : Array[String],
) -> Unit {
  let label = command_label(suite, command_index)
  let command_object = match json_object(command) {
    Some(fields) => fields
    None => {
      push(failures, label + " must be an object")
      return
    }
  }
  match json_string(command_object.get("mode")) {
    Some("run") | Some("manual") => ()
    _ => push(failures, label + ".mode must be run or manual")
  }
  let argv = json_array_field(command_object.get("argv"))
  if argv.is_empty() {
    push(failures, label + ".argv must be a non-empty string array")
    return
  }
  let arg_strings : Array[String] = []
  for arg in argv {
    match arg {
      Json::String(text) if text != "" => arg_strings.push(text)
      _ => {
        push(failures, label + ".argv must be a non-empty string array")
        return
      }
    }
  }
  for arg in arg_strings {
    if looks_like_repo_path(arg) &&
      !arg.has_prefix("artifacts/") &&
      !arg.contains("<") &&
      !arg.contains("*") &&
      !repo_path_exists(repo_root, arg) {
      push(failures, label + ".argv references missing repo path: " + arg)
    }
  }
}

///|
fn validate_result(
  repo_root : String,
  suite : Map[String, Json],
  result : Json?,
  failures : Array[String],
) -> Unit {
  let suite_id = json_string(suite.get("id")).unwrap_or("")
  let result_object = match json_object_field(result) {
    Some(fields) => fields
    None => {
      push(failures, suite_id + ".result must be an object")
      return
    }
  }
  let result_type = json_string(result_object.get("type")).unwrap_or("")
  if !(result_type == "exit-code" ||
    result_type == "manifest" ||
    result_type == "log-marker") {
    push(
      failures,
      suite_id + ".result.type must be exit-code, manifest, or log-marker",
    )
  }
  if result_type == "manifest" {
    match json_non_empty_string(result_object.get("path")) {
      Some(path) if path.has_prefix("artifacts/") => ()
      _ =>
        push(
          failures,
          suite_id + ".result.path must be an artifacts/ manifest path",
        )
    }
    let validator = json_array_field(result_object.get("validator"))
    if validator.length() < 2 {
      push(failures, suite_id + ".result.validator must be a command array")
    } else {
      let validator_args : Array[String] = []
      for arg in validator {
        match arg {
          Json::String(text) if text != "" => validator_args.push(text)
          _ => {
            push(
              failures,
              suite_id + ".result.validator must be a command array",
            )
            return
          }
        }
      }
      for arg in validator_args {
        if looks_like_repo_path(arg) &&
          !arg.has_prefix("artifacts/") &&
          !repo_path_exists(repo_root, arg) {
          push(
            failures,
            suite_id + ".result.validator references missing repo path: " + arg,
          )
        }
      }
    }
  }
  if result_type == "log-marker" {
    let markers = json_array_field(result_object.get("markers"))
    if markers.is_empty() {
      push(
        failures,
        suite_id + ".result.markers must be a non-empty string array",
      )
    } else {
      for marker in markers {
        match marker {
          Json::String(text) if text != "" => ()
          _ => {
            push(
              failures,
              suite_id + ".result.markers must be a non-empty string array",
            )
            return
          }
        }
      }
    }
  }
}

///|
fn validate_docs(
  repo_root : String,
  suite_id : String,
  suite : Map[String, Json],
  failures : Array[String],
) -> Unit {
  let docs = json_array_field(suite.get("docs"))
  if docs.is_empty() {
    push(failures, suite_id + ".docs must be non-empty")
    return
  }
  for doc in docs {
    match doc {
      Json::String(path) if path != "" && repo_path_exists(repo_root, path) =>
        ()
      Json::String(path) =>
        push(failures, suite_id + ".docs references missing repo path: " + path)
      _ => push(failures, suite_id + ".docs references missing repo path: ")
    }
  }
}

///|
fn validate_artifacts(
  suite_id : String,
  suite : Map[String, Json],
  failures : Array[String],
) -> Unit {
  for artifact in json_array_field(suite.get("artifacts")) {
    match artifact {
      Json::String(path) if path != "" && path.has_prefix("artifacts/") => ()
      _ =>
        push(failures, suite_id + ".artifacts entries must be artifacts/ paths")
    }
  }
}

///|
fn validate_ci(
  repo_root : String,
  suite_id : String,
  suite : Map[String, Json],
  failures : Array[String],
) -> Unit {
  let ci = json_object_field(suite.get("ci"))
  match ci {
    Some(fields) =>
      match json_non_empty_string(fields.get("workflow")) {
        Some(workflow) if repo_path_exists(repo_root, workflow) => ()
        _ =>
          push(
            failures,
            suite_id + ".ci.workflow must reference a checked-in workflow",
          )
      }
    None =>
      push(
        failures,
        suite_id + ".ci.workflow must reference a checked-in workflow",
      )
  }
  match ci {
    Some(fields) =>
      match json_non_empty_string(fields.get("gate")) {
        Some(_) => ()
        None => push(failures, suite_id + ".ci.gate is required")
      }
    None => push(failures, suite_id + ".ci.gate is required")
  }
}

///|
fn validate_catalog_fields(
  repo_root : String,
  catalog : Map[String, Json],
) -> Array[String] {
  let failures : Array[String] = []
  if !json_number_is_one(catalog.get("schemaVersion")) {
    push(failures, "schemaVersion must be 1")
  }
  match json_non_empty_string(catalog.get("description")) {
    Some(_) => ()
    None => push(failures, "description is required")
  }
  let tiers = string_array_from_json(json_array_field(catalog.get("tiers")))
  for tier in ["daily", "nightly", "release"] {
    if !array_contains(tiers, tier) {
      push(failures, "tiers must include " + tier)
    }
  }
  let suites = json_array_field(catalog.get("suites"))
  if suites.is_empty() {
    push(failures, "suites must be non-empty")
  }
  let ids : Map[String, Bool] = Map([])
  let tier_counts : Map[String, Int] = Map([])
  let default_daily_check_count = Ref(0)
  for suite_json in suites {
    let suite = match json_object(suite_json) {
      Some(fields) => fields
      None => {
        push(failures, "suite entries must be objects")
        continue
      }
    }
    let suite_id = json_string(suite.get("id")).unwrap_or("")
    if !valid_suite_id(suite_id) {
      push(failures, "suite.id must use lowercase dot/dash notation")
    } else if ids.contains(suite_id) {
      push(failures, "duplicate suite id: " + suite_id)
    } else {
      ids[suite_id] = true
    }
    let tier = json_string(suite.get("tier")).unwrap_or("")
    if !array_contains(tiers, tier) {
      push(failures, suite_id + ".tier is not declared in tiers")
    } else {
      tier_counts[tier] = tier_counts.get(tier).unwrap_or(0) + 1
    }
    for field in ["kind", "host", "purpose"] {
      match json_non_empty_string(suite.get(field)) {
        Some(_) => ()
        None => push(failures, suite_id + "." + field + " is required")
      }
    }
    match json_bool(suite.get("defaultDevCheck")) {
      Some(value) =>
        if value {
          default_daily_check_count.val += 1
          if tier != "daily" {
            push(
              failures,
              suite_id +
              " cannot run in default daily check outside the daily tier",
            )
          }
        }
      None => push(failures, suite_id + ".defaultDevCheck must be boolean")
    }
    let commands = json_array_field(suite.get("commands"))
    if commands.is_empty() {
      push(failures, suite_id + ".commands must be non-empty")
    }
    for index, command in commands {
      validate_command(repo_root, suite, command, index, failures)
    }
    validate_result(repo_root, suite, suite.get("result"), failures)
    validate_ci(repo_root, suite_id, suite, failures)
    validate_docs(repo_root, suite_id, suite, failures)
    validate_artifacts(suite_id, suite, failures)
  }
  for tier in ["daily", "nightly", "release"] {
    if tier_counts.get(tier).unwrap_or(0) == 0 {
      push(failures, "missing suite for tier: " + tier)
    }
  }
  if default_daily_check_count.val == 0 {
    push(
      failures, "at least one daily suite must describe the default daily check",
    )
  }
  failures
}

///|
fn parse_catalog_text(
  text : String,
) -> Result[Map[String, Json], Array[String]] {
  let parsed = @json.parse(text) catch {
    _ => return Err(["failed to read JSON: invalid JSON"])
  }
  match json_object(parsed) {
    Some(fields) => Ok(fields)
    None => Err(["catalog must be a JSON object"])
  }
}

///|
fn validate_catalog_text(
  repo_root : String,
  text : String,
) -> Result[Map[String, Json], Array[String]] {
  match parse_catalog_text(text) {
    Ok(catalog) => {
      let failures = validate_catalog_fields(repo_root, catalog)
      if failures.is_empty() {
        Ok(catalog)
      } else {
        Err(failures)
      }
    }
    Err(failures) => Err(failures)
  }
}

///|
fn load_catalog(
  options : CliOptions,
) -> Result[Map[String, Json], Array[String]] {
  let manifest_path = @tools.resolve_path(options.repo_root, options.manifest)
  let text = match
    @tools.read_required_text(manifest_path, "smoke gate catalog") {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  validate_catalog_text(options.repo_root, text)
}

///|
fn suite_matches_tier(suite : Map[String, Json], tier : String?) -> Bool {
  match tier {
    Some(value) => json_string(suite.get("tier")).unwrap_or("") == value
    None => true
  }
}

///|
fn catalog_tiers(catalog : Map[String, Json]) -> Array[String] {
  string_array_from_json(json_array_field(catalog.get("tiers")))
}

///|
fn catalog_suites(catalog : Map[String, Json]) -> Array[Map[String, Json]] {
  let suites : Array[Map[String, Json]] = []
  for suite in json_array_field(catalog.get("suites")) {
    match json_object(suite) {
      Some(fields) => suites.push(fields)
      None => ()
    }
  }
  suites
}

///|
fn command_argv_strings(command : Map[String, Json]) -> Array[String] {
  string_array_from_json(json_array_field(command.get("argv")))
}

///|
fn command_string_for_check(command : Map[String, Json]) -> String {
  command_argv_strings(command).join(" ")
}

///|
fn suite_check_plan_json(suite : Map[String, Json]) -> Json {
  let object : Map[String, Json] = Map([])
  object["id"] = Json::string(json_string(suite.get("id")).unwrap_or(""))
  object["tier"] = Json::string(json_string(suite.get("tier")).unwrap_or(""))
  object["kind"] = Json::string(json_string(suite.get("kind")).unwrap_or(""))
  object["host"] = Json::string(json_string(suite.get("host")).unwrap_or(""))
  object["defaultDevCheck"] = Json::boolean(
    json_bool(suite.get("defaultDevCheck")).unwrap_or(false),
  )
  let commands : Array[Json] = []
  for command_json in json_array_field(suite.get("commands")) {
    match json_object(command_json) {
      Some(command) =>
        commands.push(Json::string(command_string_for_check(command)))
      None => ()
    }
  }
  object["commands"] = Json::array(commands)
  object["result"] = suite.get("result").unwrap_or(Json::empty_object())
  object["ci"] = suite.get("ci").unwrap_or(Json::empty_object())
  match suite.get("artifacts") {
    Some(value) => object["artifacts"] = value
    None => ()
  }
  Json::object(object)
}

///|
fn normalized_check_plan(catalog : Map[String, Json], tier : String?) -> Json {
  let suites : Array[Json] = []
  for suite in catalog_suites(catalog) {
    if suite_matches_tier(suite, tier) {
      suites.push(suite_check_plan_json(suite))
    }
  }
  let object : Map[String, Json] = Map([])
  object["schemaVersion"] = catalog
    .get("schemaVersion")
    .unwrap_or(Json::number(1.0, repr="1"))
  object["tier"] = match tier {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  object["suiteCount"] = Json::number(
    suites.length().to_double(),
    repr=suites.length().to_string(),
  )
  object["suites"] = Json::array(suites)
  Json::object(object)
}

///|
fn smoke_check_list(plan : Json) -> Array[String] {
  let lines : Array[String] = []
  match json_object(plan) {
    Some(fields) =>
      for suite_json in json_array_field(fields.get("suites")) {
        match json_object(suite_json) {
          Some(suite) => {
            let tier = json_string(suite.get("tier")).unwrap_or("")
            let id = json_string(suite.get("id")).unwrap_or("")
            let kind = json_string(suite.get("kind")).unwrap_or("")
            let host = json_string(suite.get("host")).unwrap_or("")
            lines.push("\{tier}: \{id} [\{kind}] host=\{host}")
            for
              command in string_array_from_json(
                json_array_field(suite.get("commands")),
              ) {
              lines.push("  " + command)
            }
          }
          None => ()
        }
      }
    None => ()
  }
  lines
}

///|
fn valid_platform(value : String) -> Bool {
  value == "macos" || value == "web" || value == "windows" || value == "linux"
}

///|
fn substitute_arg(
  arg : String,
  gate_mode : String,
  platform : String?,
) -> Result[String, String] {
  let has_placeholder = arg.contains("<macos|web|windows|linux>") ||
    arg.contains("<platform>")
  if !has_placeholder {
    return Ok(arg)
  }
  match platform {
    None =>
      if gate_mode == "dry-run" {
        Ok(arg)
      } else {
        Err("--platform is required for placeholder argument: " + arg)
      }
    Some(value) =>
      if !valid_platform(value) {
        Err("unknown platform: " + value)
      } else {
        Ok(
          arg
          .replace_all(old="<macos|web|windows|linux>", new=value)
          .replace_all(old="<platform>", new=value),
        )
      }
  }
}

///|
fn substitute_argv(
  argv : Array[String],
  gate_mode : String,
  platform : String?,
) -> Result[Array[String], String] {
  let values : Array[String] = []
  for arg in argv {
    match substitute_arg(arg, gate_mode, platform) {
      Ok(value) => values.push(value)
      Err(message) => return Err(message)
    }
  }
  Ok(values)
}

///|
fn command_gate_json(
  command : Map[String, Json],
  gate_mode : String,
  platform : String?,
) -> Result[Json, String] {
  let argv = match
    substitute_argv(command_argv_strings(command), gate_mode, platform) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let argv_json : Array[Json] = []
  for arg in argv {
    argv_json.push(Json::string(arg))
  }
  let object : Map[String, Json] = Map([])
  object["mode"] = Json::string(json_string(command.get("mode")).unwrap_or(""))
  object["argv"] = Json::array(argv_json)
  Ok(Json::object(object))
}

///|
fn result_gate_json(
  result : Json,
  gate_mode : String,
  platform : String?,
) -> Result[Json, String] {
  if gate_mode == "dry-run" {
    return Ok(result)
  }
  let fields = match json_object(result) {
    Some(value) => value
    None => return Ok(result)
  }
  if json_string(fields.get("type")).unwrap_or("") != "manifest" {
    return Ok(result)
  }
  let output : Map[String, Json] = Map([])
  for key, value in fields {
    output[key] = value
  }
  let validator = string_array_from_json(
    json_array_field(fields.get("validator")),
  )
  let substituted = match substitute_argv(validator, gate_mode, platform) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let validator_json : Array[Json] = []
  for arg in substituted {
    validator_json.push(Json::string(arg))
  }
  output["validator"] = Json::array(validator_json)
  Ok(Json::object(output))
}

///|
fn suite_gate_plan_json(
  suite : Map[String, Json],
  gate_mode : String,
  platform : String?,
) -> Result[Json, String] {
  let object : Map[String, Json] = Map([])
  object["id"] = Json::string(json_string(suite.get("id")).unwrap_or(""))
  object["tier"] = Json::string(json_string(suite.get("tier")).unwrap_or(""))
  object["kind"] = Json::string(json_string(suite.get("kind")).unwrap_or(""))
  object["host"] = Json::string(json_string(suite.get("host")).unwrap_or(""))
  let commands : Array[Json] = []
  for command_json in json_array_field(suite.get("commands")) {
    match json_object(command_json) {
      Some(command) =>
        match command_gate_json(command, gate_mode, platform) {
          Ok(value) => commands.push(value)
          Err(message) => return Err(message)
        }
      None => ()
    }
  }
  object["commands"] = Json::array(commands)
  let result = suite.get("result").unwrap_or(Json::empty_object())
  match result_gate_json(result, gate_mode, platform) {
    Ok(value) => object["result"] = value
    Err(message) => return Err(message)
  }
  let artifacts : Array[Json] = []
  for
    artifact in string_array_from_json(json_array_field(suite.get("artifacts"))) {
    match substitute_arg(artifact, gate_mode, platform) {
      Ok(value) => artifacts.push(Json::string(value))
      Err(message) => return Err(message)
    }
  }
  object["artifacts"] = Json::array(artifacts)
  Ok(Json::object(object))
}

///|
fn suite_requested(
  suite : Map[String, Json],
  requested : Map[String, Bool],
) -> Bool {
  requested.is_empty() ||
  requested.contains(json_string(suite.get("id")).unwrap_or(""))
}

///|
fn select_gate_suites(
  catalog : Map[String, Json],
  options : CliOptions,
) -> Result[Array[Map[String, Json]], String] {
  let tiers = catalog_tiers(catalog)
  match options.tier {
    Some(value) =>
      if !array_contains(tiers, value) {
        return Err("unknown tier: " + value)
      }
    None => ()
  }
  let requested : Map[String, Bool] = Map([])
  for suite in options.suites {
    requested[suite] = true
  }
  let selected : Array[Map[String, Json]] = []
  let all_suites = catalog_suites(catalog)
  for suite in all_suites {
    if suite_matches_tier(suite, options.tier) &&
      suite_requested(suite, requested) {
      selected.push(suite)
    }
  }
  for suite_id in options.suites {
    if !all_suites.any(suite => {
        json_string(suite.get("id")).unwrap_or("") == suite_id
      }) {
      return Err("unknown suite: " + suite_id)
    }
  }
  if selected.is_empty() {
    return Err("no smoke suites selected")
  }
  Ok(selected)
}

///|
fn gate_plan_json(
  catalog : Map[String, Json],
  options : CliOptions,
) -> Result[Json, String] {
  let suites = match select_gate_suites(catalog, options) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let suite_json : Array[Json] = []
  for suite in suites {
    match suite_gate_plan_json(suite, options.gate_mode, options.platform) {
      Ok(value) => suite_json.push(value)
      Err(message) => return Err(message)
    }
  }
  let object : Map[String, Json] = Map([])
  object["mode"] = Json::string(options.gate_mode)
  object["tier"] = match options.tier {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  object["suiteCount"] = Json::number(
    suite_json.length().to_double(),
    repr=suite_json.length().to_string(),
  )
  object["suites"] = Json::array(suite_json)
  Ok(Json::object(object))
}

///|
fn shell_quote(arg : String) -> String {
  if arg == "" {
    return "\"\""
  }
  for char in arg {
    let safe = ('A' <= char && char <= 'Z') ||
      ('a' <= char && char <= 'z') ||
      ('0' <= char && char <= '9') ||
      char == '_' ||
      char == '.' ||
      char == '/' ||
      char == ':' ||
      char == '=' ||
      char == '@' ||
      char == '+' ||
      char == '-'
    if !safe {
      return Json::string(arg).stringify()
    }
  }
  arg
}

///|
fn command_to_string(argv : Array[String]) -> String {
  let parts : Array[String] = []
  for arg in argv {
    parts.push(shell_quote(arg))
  }
  parts.join(" ")
}

///|
fn gate_plan_list(plan : Json) -> Array[String] {
  let lines : Array[String] = []
  match json_object(plan) {
    Some(fields) =>
      for suite_json in json_array_field(fields.get("suites")) {
        match json_object(suite_json) {
          Some(suite) => {
            let tier = json_string(suite.get("tier")).unwrap_or("")
            let id = json_string(suite.get("id")).unwrap_or("")
            let kind = json_string(suite.get("kind")).unwrap_or("")
            let host = json_string(suite.get("host")).unwrap_or("")
            lines.push("\{tier}: \{id} [\{kind}] host=\{host}")
            for command_json in json_array_field(suite.get("commands")) {
              match json_object(command_json) {
                Some(command) => {
                  let mode = json_string(command.get("mode")).unwrap_or("")
                  let argv = string_array_from_json(
                    json_array_field(command.get("argv")),
                  )
                  lines.push("  \{mode}: " + command_to_string(argv))
                }
                None => ()
              }
            }
          }
          None => ()
        }
      }
    None => ()
  }
  lines
}

///|
fn print_failures(failures : Array[String]) -> Unit {
  println("smoke gate catalog failed:")
  for failure in failures {
    println("- " + failure)
  }
}

///|
fn run_check_mode(options : CliOptions, catalog : Map[String, Json]) -> Int {
  if options.tier is Some(tier) && !array_contains(catalog_tiers(catalog), tier) {
    print_failures(["unknown tier: " + tier])
    return 1
  }
  let plan = normalized_check_plan(catalog, options.tier)
  match options.mode {
    "json" => {
      println(plan.stringify(indent=2))
      0
    }
    "list" => {
      for line in smoke_check_list(plan) {
        println(line)
      }
      0
    }
    _ => {
      println(
        "smoke gate catalog: ok (" +
        catalog_suites(catalog).length().to_string() +
        " suites)",
      )
      0
    }
  }
}

///|
fn run_gate_mode(options : CliOptions, catalog : Map[String, Json]) -> Int {
  match gate_plan_json(catalog, options) {
    Ok(plan) => {
      if options.mode == "json" {
        println(plan.stringify(indent=2))
      } else {
        for line in gate_plan_list(plan) {
          println(line)
        }
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
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match load_catalog(options) {
        Ok(catalog) =>
          if options.gate_plan {
            run_gate_mode(options, catalog)
          } else {
            run_check_mode(options, catalog)
          }
        Err(failures) => {
          print_failures(failures)
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
