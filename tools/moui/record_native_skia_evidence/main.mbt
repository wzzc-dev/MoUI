///|
struct CliOptions {
  repo_root : String
  manifest_path : String
  platform : String
  host : String
  provider_preflight_log : String
  fallback_unavailable_log : String
  renderer_smoke_log : String
  async_image_log : String
  showcase_log : String
  gpu_renderer_smoke_logs : Array[String]
  gpu_showcase_logs : Array[String]
  notes : Array[String]
  plan_output : String
  help : Bool
}

///|
struct PlatformSpec {
  name : String
  host_tokens : Array[String]
  first_frame_marker : String
  provider_tokens : Array[String]
  provider_pass_tokens : Array[String]
  fallback_tokens : Array[String]
}

///|
struct LogOption {
  observation : String
  label : String
  marker_description : String
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
let skia_observation_keys : Array[String] = [
  "providerPreflight", "fallbackUnavailable", "realRendererSmoke", "asyncImageSecondFrame",
  "showcaseFirstFrame",
]

///|
let showcase_first_frame_title = "MoUI Showcase"

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/record_native_skia_evidence <manifest.json> <macos|windows|linux> [options]
    #|
    #|Validates native Skia evidence logs and writes a JSON plan for the
    #|compatibility Node wrapper to pass to record-platform-evidence-manifest.mjs.
    #|
    #|Options:
    #|  --repo-root PATH
    #|  --host TEXT
    #|  --provider-preflight-log PATH
    #|  --fallback-unavailable-log PATH
    #|  --renderer-smoke-log PATH
    #|  --gpu-renderer-smoke-log PATH
    #|  --async-image-log PATH
    #|  --showcase-log PATH
    #|  --gpu-showcase-log PATH
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
  let provider_preflight_log = Ref("")
  let fallback_unavailable_log = Ref("")
  let renderer_smoke_log = Ref("")
  let async_image_log = Ref("")
  let showcase_log = Ref("")
  let gpu_renderer_smoke_logs : Array[String] = []
  let gpu_showcase_logs : Array[String] = []
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
      "--provider-preflight-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provider-preflight-log")
        }
        provider_preflight_log.val = args[index + 1]
        index += 2
      }
      "--fallback-unavailable-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --fallback-unavailable-log")
        }
        fallback_unavailable_log.val = args[index + 1]
        index += 2
      }
      "--renderer-smoke-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --renderer-smoke-log")
        }
        renderer_smoke_log.val = args[index + 1]
        index += 2
      }
      "--async-image-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --async-image-log")
        }
        async_image_log.val = args[index + 1]
        index += 2
      }
      "--showcase-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --showcase-log")
        }
        showcase_log.val = args[index + 1]
        index += 2
      }
      "--gpu-renderer-smoke-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --gpu-renderer-smoke-log")
        }
        gpu_renderer_smoke_logs.push(args[index + 1])
        index += 2
      }
      "--gpu-showcase-log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --gpu-showcase-log")
        }
        gpu_showcase_logs.push(args[index + 1])
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
    provider_preflight_log: provider_preflight_log.val,
    fallback_unavailable_log: fallback_unavailable_log.val,
    renderer_smoke_log: renderer_smoke_log.val,
    async_image_log: async_image_log.val,
    showcase_log: showcase_log.val,
    gpu_renderer_smoke_logs,
    gpu_showcase_logs,
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
        first_frame_marker: "macOS renderer presented first frame; exiting by request",
        provider_tokens: [
          "macOS Skia provider preflight", "moui/backend/macos/skia", "backend/macos/skia",
        ],
        provider_pass_tokens: [
          "failed: 0", "build succeeded", "build finished", "Finished", "renderer=ready",
          "can_render=true",
        ],
        fallback_tokens: [
          "macOS Skia renderer selected, but moui_skia/native is unavailable", "moui_skia/native is unavailable",
        ],
      })
    "windows" =>
      Some({
        name,
        host_tokens: ["Windows", "MSVC"],
        first_frame_marker: "Windows renderer presented first frame; exiting by request",
        provider_tokens: [
          "Windows Skia provider preflight", "moui/backend/windows/skia", "backend/windows/skia",
          "build_windows_msvc.ps1",
        ],
        provider_pass_tokens: [
          "failed: 0", "build succeeded", "build finished", "Finished", "renderer=ready",
          "can_render=true",
        ],
        fallback_tokens: [
          "Windows Skia renderer selected, but moui_skia/native is unavailable",
          "moui_skia/native is unavailable",
        ],
      })
    "linux" =>
      Some({
        name,
        host_tokens: ["Linux", "Wayland"],
        first_frame_marker: "Linux renderer presented first frame; exiting by request",
        provider_tokens: [
          "Linux Skia provider preflight", "moui/backend/linux/skia", "backend/linux/skia",
        ],
        provider_pass_tokens: [
          "failed: 0", "build succeeded", "build finished", "Finished", "renderer=ready",
          "can_render=true",
        ],
        fallback_tokens: [
          "Linux Skia renderer selected, but moui_skia/native is unavailable", "moui_skia/native is unavailable",
        ],
      })
    _ => None
  }
}

///|
fn log_option(option : String) -> LogOption {
  match option {
    "--provider-preflight-log" =>
      {
        observation: "providerPreflight",
        label: "provider preflight log",
        marker_description: "a platform Skia provider identity plus a preflight/test/build pass marker",
      }
    "--fallback-unavailable-log" =>
      {
        observation: "fallbackUnavailable",
        label: "fallback unavailable log",
        marker_description: "the explicit moui_skia/native unavailable diagnostic",
      }
    "--renderer-smoke-log" =>
      {
        observation: "realRendererSmoke",
        label: "renderer smoke log",
        marker_description: "MoUI Skia renderer smoke passed",
      }
    "--async-image-log" =>
      {
        observation: "asyncImageSecondFrame",
        label: "async image second-frame log",
        marker_description: "MoUI Skia async image second-frame smoke passed",
      }
    _ =>
      {
        observation: "showcaseFirstFrame",
        label: "Showcase first-frame log",
        marker_description: "the platform first-frame marker with title=" +
        showcase_first_frame_title,
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
fn first_frame_marker(spec : PlatformSpec, title : String) -> String {
  spec.first_frame_marker + "; title=" + title
}

///|
fn marker_ok(text : String, spec : PlatformSpec, option : String) -> Bool {
  match option {
    "--provider-preflight-log" =>
      any_contains(text, spec.provider_tokens) &&
      any_contains(text, spec.provider_pass_tokens)
    "--fallback-unavailable-log" => any_contains(text, spec.fallback_tokens)
    "--renderer-smoke-log" => text.contains("MoUI Skia renderer smoke passed")
    "--async-image-log" =>
      text.contains("MoUI Skia async image second-frame smoke passed")
    "--showcase-log" =>
      text.contains(first_frame_marker(spec, showcase_first_frame_title))
    _ => false
  }
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
  if !marker_ok(text, spec, option) {
    return Err(
      config.label + " is missing expected marker: " + config.marker_description,
    )
  }
  Ok((config.observation, artifact.relative))
}

///|
fn validate_gpu_renderer_log(
  repo_root : String,
  spec : PlatformSpec,
  raw_path : String,
) -> Result[String, String] {
  if raw_path.trim().to_owned() == "" {
    return Err("--gpu-renderer-smoke-log requires a non-empty path")
  }
  let artifact = match artifact_path(repo_root, spec.name, raw_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let text = match
    @tools.read_required_text(artifact.absolute, "GPU renderer smoke log") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if text.trim().to_owned() == "" {
    return Err("GPU renderer smoke log is empty: " + raw_path)
  }
  let required = [
    "MoUI Skia GPU Metal renderer smoke passed", "route=metal-gpu", "surface_gpu=true",
    "present_count=1", "pixel-markers",
  ]
  if !required.all(token => text.contains(token)) {
    return Err(
      "GPU renderer smoke log is missing expected marker: MoUI Skia GPU Metal renderer smoke passed with route=metal-gpu, surface_gpu=true, present_count=1, and pixel-markers",
    )
  }
  Ok(artifact.relative)
}

///|
fn validate_gpu_showcase_log(
  repo_root : String,
  spec : PlatformSpec,
  raw_path : String,
) -> Result[String, String] {
  if raw_path.trim().to_owned() == "" {
    return Err("GPU Showcase first-frame log requires a non-empty path")
  }
  let artifact = match artifact_path(repo_root, spec.name, raw_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let text = match
    @tools.read_required_text(artifact.absolute, "GPU Showcase first-frame log") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if text.trim().to_owned() == "" {
    return Err("GPU Showcase first-frame log is empty: " + raw_path)
  }
  if !text.contains(first_frame_marker(spec, showcase_first_frame_title)) {
    return Err(
      "GPU Showcase first-frame log is missing expected marker: the platform first-frame marker with title=" +
      showcase_first_frame_title,
    )
  }
  if !text.contains(
      "macOS Skia renderer route diagnostics: surface_route=metal-gpu; surface_gpu=true",
    ) {
    return Err(
      "GPU Showcase first-frame log is missing expected marker: macOS Skia renderer route diagnostics with surface_route=metal-gpu and surface_gpu=true",
    )
  }
  Ok(artifact.relative)
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
fn parse_existing_skia_observations(
  entry : Map[String, Json],
) -> Map[String, String] {
  let observations : Map[String, String] = {}
  let skia = match optional_object(entry, "skiaEvidence") {
    Some(value) => value
    None => {}
  }
  let existing = match optional_object(skia, "observations") {
    Some(value) => value
    None => {}
  }
  for key in skia_observation_keys {
    let value = match existing.get(key) {
      Some(Json::String(text)) => text
      _ => "pending"
    }
    observations[key] = value
  }
  observations
}

///|
fn existing_skia_artifacts(entry : Map[String, Json]) -> Array[String] {
  let skia = match optional_object(entry, "skiaEvidence") {
    Some(value) => value
    None => return []
  }
  json_string_array(optional_array(skia, "artifacts")).filter(artifact => {
    !artifact.has_suffix("/README.md")
  })
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
  notes : Array[String],
  status : String,
  host : String,
  platform : String,
) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\n")
  builder.write_string("  \"platform\": \"" + json_escape(platform) + "\",\n")
  builder.write_string("  \"status\": \"" + json_escape(status) + "\",\n")
  builder.write_string("  \"host\": \"" + json_escape(host) + "\",\n")
  builder.write_string("  \"observations\": {\n")
  for index in 0..<skia_observation_keys.length() {
    let key = skia_observation_keys[index]
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
  builder.write_string("  \"notes\": ")
  write_json_string_array(builder, notes)
  builder.write_string("\n}\n")
  builder.to_string()
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
fn validate_and_plan(options : CliOptions) -> Result[String, String] {
  let spec = match platform_spec(options.platform) {
    Some(value) => value
    None => return Err("Unknown native Skia platform: " + options.platform)
  }
  if options.host.trim().to_owned() == "" {
    return Err(
      "--host is required so Skia route evidence names its matching host",
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
  let has_log = options.provider_preflight_log != "" ||
    options.fallback_unavailable_log != "" ||
    options.renderer_smoke_log != "" ||
    options.async_image_log != "" ||
    options.showcase_log != "" ||
    !options.gpu_renderer_smoke_logs.is_empty() ||
    !options.gpu_showcase_logs.is_empty()
  if !has_log {
    return Err("At least one Skia evidence log option is required")
  }
  if options.platform != "macos" &&
    (
      !options.gpu_renderer_smoke_logs.is_empty() ||
      !options.gpu_showcase_logs.is_empty()
    ) {
    return Err(
      "Skia GPU route log options currently require the macos platform",
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
  let observations = parse_existing_skia_observations(entry)
  let artifacts = existing_skia_artifacts(entry)
  let notes : Array[String] = []

  let regular_options = [
    { option: "--provider-preflight-log", path: options.provider_preflight_log },
    {
      option: "--fallback-unavailable-log",
      path: options.fallback_unavailable_log,
    },
    { option: "--renderer-smoke-log", path: options.renderer_smoke_log },
    { option: "--async-image-log", path: options.async_image_log },
    { option: "--showcase-log", path: options.showcase_log },
  ]
  for supplied in regular_options {
    if supplied.path != "" {
      let (observation, artifact) = match
        validate_log_option(
          options.repo_root,
          spec,
          supplied.option,
          supplied.path,
        ) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      set_observation(observations, observation, "yes")
      string_set_add(artifacts, artifact)
    }
  }
  for path in options.gpu_renderer_smoke_logs {
    let artifact = match
      validate_gpu_renderer_log(options.repo_root, spec, path) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    string_set_add(artifacts, artifact)
    string_set_add(
      notes, "macOS Metal GPU route smoke proved route=metal-gpu, surface_gpu=true, frame presentation, and pixel markers.",
    )
  }
  for path in options.gpu_showcase_logs {
    let artifact = match
      validate_gpu_showcase_log(options.repo_root, spec, path) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    string_set_add(artifacts, artifact)
    string_set_add(
      notes, "macOS Showcase first-frame smoke proved route=metal-gpu and surface_gpu=true before presentation.",
    )
  }
  let status = if skia_observation_keys.all(key => {
      map_string_or(observations, key, "pending") == "yes"
    }) {
    "passed"
  } else {
    "pending"
  }
  let default_note = if status == "passed" {
    options.platform +
    " native Skia route evidence passed on " +
    options.host +
    "; this records provider/fallback/renderer/first-frame Skia evidence only, not full platform-service runtime evidence."
  } else {
    options.platform +
    " native Skia route evidence is partially recorded on " +
    options.host +
    "; omitted Skia observations remain pending and do not prove full platform runtime readiness."
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
      notes,
      status,
      options.host,
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
            "native Skia evidence plan",
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
