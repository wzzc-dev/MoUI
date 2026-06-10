///|
struct CliOptions {
  web_presentation_manifest : String
  output : String
  require_passed : Bool
  help : Bool
}

///|
struct ProofRequirement {
  key : String
  evidence : Array[String]
}

///|
struct RecordResult {
  summary : String
}

///|
fn usage() -> String {
  "Usage: tools/moui/record_web_renderer_proof_manifest --web-presentation-manifest <web-runtime-presentation.json> --output <renderer-proof.json> [--require-passed]"
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let web_presentation_manifest = Ref("")
  let output = Ref("artifacts/conformance/renderer-proof/webgpu-wasm-web.json")
  let require_passed = Ref(false)
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--web-presentation-manifest" => {
        if index + 1 >= args.length() {
          return Err("missing value for --web-presentation-manifest")
        }
        web_presentation_manifest.val = args[index + 1]
        index += 2
      }
      "--output" => {
        if index + 1 >= args.length() {
          return Err("missing value for --output")
        }
        output.val = args[index + 1]
        index += 2
      }
      "--require-passed" => {
        require_passed.val = true
        index += 1
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      _ => return Err("unknown argument: " + args[index])
    }
  }
  if !help.val && web_presentation_manifest.val == "" {
    return Err(usage())
  }
  Ok({
    web_presentation_manifest: web_presentation_manifest.val,
    output: output.val,
    require_passed: require_passed.val,
    help: help.val,
  })
}

///|
fn proof_keys() -> Array[String] {
  [
    "radialGradient", "transformPixels", "colorEmojiPixels", "zwjGrapheme", "bidiLayout",
    "paragraphWrapping", "selectionRects", "graphemeEditing", "imeCandidateAnchor",
    "imeCompositionVisual", "asyncImageSecondFrame",
  ]
}

///|
fn proof_evidence_requirements() -> Array[ProofRequirement] {
  [
    {
      key: "radialGradient",
      evidence: ["center-mid-edge-pixels", "shader-payload"],
    },
    {
      key: "colorEmojiPixels",
      evidence: [
        "high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata",
      ],
    },
    {
      key: "zwjGrapheme",
      evidence: ["single-grapheme-cluster", "no-interior-caret"],
    },
    { key: "bidiLayout", evidence: ["visual-order"] },
    {
      key: "paragraphWrapping",
      evidence: ["line-metrics", "later-line-pixels"],
    },
    { key: "selectionRects", evidence: ["selection-rects", "line-range"] },
    {
      key: "graphemeEditing",
      evidence: ["grapheme-boundaries", "edit-actions"],
    },
    {
      key: "imeCandidateAnchor",
      evidence: ["candidate-anchor", "surrounding-text"],
    },
    {
      key: "imeCompositionVisual",
      evidence: ["composition-range", "preedit-pixels"],
    },
    {
      key: "asyncImageSecondFrame",
      evidence: ["late-completion", "repaint-request", "second-frame-pixels"],
    },
  ]
}

///|
fn evidence_for(key : String) -> Array[String] {
  for requirement in proof_evidence_requirements() {
    if requirement.key == key {
      return requirement.evidence
    }
  }
  []
}

///|
fn json_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn optional_object(object : Map[String, Json], field : String) -> Map[String, Json]? {
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
fn optional_bool(object : Map[String, Json], field : String) -> Bool {
  match object.get(field) {
    Some(Json::True) => true
    _ => false
  }
}

///|
fn optional_number(object : Map[String, Json], field : String) -> Double? {
  match object.get(field) {
    Some(Json::Number(number, repr=_)) => Some(number)
    _ => None
  }
}

///|
fn number_or(object : Map[String, Json], field : String, fallback : Double) -> Double {
  match optional_number(object, field) {
    Some(number) => number
    None => fallback
  }
}

///|
fn json_string_array_contains(values : Array[Json], expected : String) -> Bool {
  for value in values {
    match value {
      Json::String(text) if text == expected => return true
      _ => ()
    }
  }
  false
}

///|
fn observations_value(observations : Map[String, Json]?, key : String) -> String {
  match observations {
    Some(fields) => optional_string(fields, key)
    None => ""
  }
}

///|
fn find_showcase_target(manifest : Map[String, Json]) -> Map[String, Json]? {
  for target_json in optional_array(manifest, "targets") {
    match target_json {
      Json::Object(target) if optional_string(target, "name") == "showcase-web-wasm" =>
        return Some(target)
      _ => ()
    }
  }
  None
}

///|
fn proof_ready(showcase : Map[String, Json]?, key : String) -> Bool {
  let showcase = match showcase {
    Some(value) => value
    None => return false
  }
  let observations = optional_object(showcase, "observations")
  if observations_value(observations, key) != "yes" {
    return false
  }
  let screenshot = match optional_object(showcase, "screenshot") {
    Some(value) => value
    None => return false
  }
  let proof = match optional_object(screenshot, key) {
    Some(value) => value
    None => return false
  }
  if !optional_bool(proof, "passed") {
    return false
  }
  let evidence = optional_array(proof, "evidence")
  for token in evidence_for(key) {
    if !json_string_array_contains(evidence, token) {
      return false
    }
  }
  true
}

///|
fn string_non_empty(value : String) -> Bool {
  value.trim().to_owned() != ""
}

///|
fn positive_number(value : Double?) -> Bool {
  match value {
    Some(number) => number > 0.0
    None => false
  }
}

///|
fn at_least_number(value : Double?, minimum : Double) -> Bool {
  match value {
    Some(number) => number >= minimum
    None => false
  }
}

///|
fn color_emoji_metadata_ready(showcase : Map[String, Json]?) -> Bool {
  let showcase = match showcase {
    Some(value) => value
    None => return false
  }
  let screenshot = match optional_object(showcase, "screenshot") {
    Some(value) => value
    None => return false
  }
  let color_emoji = match optional_object(screenshot, "colorEmojiPixels") {
    Some(value) => value
    None => return false
  }
  if !optional_bool(color_emoji, "passed") {
    return false
  }
  let metadata = match optional_object(color_emoji, "metadata") {
    Some(value) => value
    None => return false
  }
  let font = match optional_object(metadata, "font") {
    Some(value) => value
    None => return false
  }
  let glyph = match optional_object(metadata, "glyph") {
    Some(value) => value
    None => return false
  }
  string_non_empty(optional_string(font, "family")) &&
  string_non_empty(optional_string(font, "source")) &&
  string_non_empty(optional_string(font, "textSystem")) &&
  optional_string(glyph, "format") == "rgba" &&
  at_least_number(optional_number(glyph, "glyphCount"), 1.0) &&
  at_least_number(optional_number(glyph, "clusterCount"), 1.0) &&
  at_least_number(optional_number(glyph, "highSaturationPixels"), 8.0) &&
  number_or(
    glyph,
    "alphaPixels",
    number_or(color_emoji, "glyphAlphaPixels", 0.0),
  ) >
  0.0 &&
  string_non_empty(optional_string(glyph, "key")) &&
  positive_number(optional_number(glyph, "width")) &&
  positive_number(optional_number(glyph, "height"))
}

///|
fn is_whitespace(char : Char) -> Bool {
  char == ' ' || char == '\n' || char == '\r' || char == '\t'
}

///|
fn metadata_token_value(value : String) -> String {
  let builder = StringBuilder::new()
  let in_whitespace = Ref(false)
  for char in value {
    if is_whitespace(char) {
      if !in_whitespace.val {
        builder.write_char('_')
      }
      in_whitespace.val = true
    } else {
      builder.write_char(char)
      in_whitespace.val = false
    }
  }
  builder.to_string()
}

///|
fn number_token(number : Double) -> String {
  number.to_int().to_string()
}

///|
fn color_emoji_metadata_line(showcase : Map[String, Json]?) -> String {
  let showcase = match showcase {
    Some(value) => value
    None => return ""
  }
  let screenshot = match optional_object(showcase, "screenshot") {
    Some(value) => value
    None => return ""
  }
  let color_emoji = match optional_object(screenshot, "colorEmojiPixels") {
    Some(value) => value
    None => return ""
  }
  let metadata = match optional_object(color_emoji, "metadata") {
    Some(value) => value
    None => return ""
  }
  let font = match optional_object(metadata, "font") {
    Some(value) => value
    None => return ""
  }
  let glyph = match optional_object(metadata, "glyph") {
    Some(value) => value
    None => return ""
  }
  [
    "MoUI renderer proof colorEmojiPixels metadata",
    "font_family=" + metadata_token_value(optional_string(font, "family")),
    "font_source=" + metadata_token_value(optional_string(font, "source")),
    "text_system=" + metadata_token_value(optional_string(font, "textSystem")),
    "shaper=" +
    metadata_token_value(
      if optional_string(font, "shaper") == "" {
        "browser-canvas"
      } else {
        optional_string(font, "shaper")
      },
    ),
    "glyph_format=" + metadata_token_value(optional_string(glyph, "format")),
    "glyph_count=" + number_token(number_or(glyph, "glyphCount", 0.0)),
    "cluster_count=" + number_token(number_or(glyph, "clusterCount", 0.0)),
    "high_saturation_pixels=" +
    number_token(number_or(glyph, "highSaturationPixels", 0.0)),
    "alpha_pixels=" +
    number_token(
      number_or(
        glyph,
        "alphaPixels",
        number_or(color_emoji, "glyphAlphaPixels", 0.0),
      ),
    ),
    "glyph_key=" + metadata_token_value(optional_string(glyph, "key")),
    "glyph_width=" + number_token(number_or(glyph, "width", 0.0)),
    "glyph_height=" + number_token(number_or(glyph, "height", 0.0)),
  ].join(" ")
}

///|
fn marker_lines(showcase : Map[String, Json]?) -> Array[String] {
  let lines : Array[String] = []
  if proof_ready(showcase, "radialGradient") {
    lines.push(
      "MoUI renderer proof radialGradient passed center-mid-edge-pixels shader-payload",
    )
  }
  match showcase {
    Some(target) =>
      if observations_value(optional_object(target, "observations"), "transformPixels") ==
        "yes" {
        lines.push("MoUI renderer proof transformPixels passed pixel-markers")
      }
    None => ()
  }
  if proof_ready(showcase, "colorEmojiPixels") &&
    color_emoji_metadata_ready(showcase) {
    lines.push(
      "MoUI renderer proof colorEmojiPixels passed high-saturation-pixels glyph-or-raster font-metadata glyph-metadata",
    )
    lines.push(color_emoji_metadata_line(showcase))
  }
  if proof_ready(showcase, "zwjGrapheme") {
    lines.push(
      "MoUI renderer proof zwjGrapheme passed single-grapheme-cluster no-interior-caret",
    )
  }
  if proof_ready(showcase, "bidiLayout") {
    lines.push("MoUI renderer proof bidiLayout passed visual-order")
  }
  if proof_ready(showcase, "paragraphWrapping") {
    lines.push(
      "MoUI renderer proof paragraphWrapping passed line-metrics later-line-pixels",
    )
  }
  if proof_ready(showcase, "selectionRects") {
    lines.push(
      "MoUI renderer proof selectionRects passed selection-rects line-range",
    )
  }
  if proof_ready(showcase, "graphemeEditing") {
    lines.push(
      "MoUI renderer proof graphemeEditing passed grapheme-boundaries edit-actions",
    )
  }
  if proof_ready(showcase, "imeCandidateAnchor") {
    lines.push(
      "MoUI renderer proof imeCandidateAnchor passed candidate-anchor surrounding-text",
    )
  }
  if proof_ready(showcase, "imeCompositionVisual") {
    lines.push(
      "MoUI renderer proof imeCompositionVisual passed composition-range preedit-pixels",
    )
  }
  if proof_ready(showcase, "asyncImageSecondFrame") {
    lines.push(
      "MoUI renderer proof asyncImageSecondFrame passed late-completion repaint-request second-frame-pixels",
    )
  }
  lines
}

///|
fn missing_proofs(showcase : Map[String, Json]?) -> Array[String] {
  let missing : Array[String] = []
  for key in proof_keys() {
    let observed = match showcase {
      Some(target) => observations_value(optional_object(target, "observations"), key)
      None => ""
    }
    let ready = if key == "transformPixels" {
      true
    } else {
      proof_ready(showcase, key)
    }
    let metadata_ready = key != "colorEmojiPixels" || color_emoji_metadata_ready(showcase)
    if observed != "yes" || !ready || !metadata_ready {
      missing.push(key)
    }
  }
  missing
}

///|
fn non_empty_or(value : String, fallback : String) -> String {
  if value == "" {
    fallback
  } else {
    value
  }
}

///|
fn showcase_status(showcase : Map[String, Json]?) -> String {
  match showcase {
    Some(target) => non_empty_or(optional_string(target, "status"), "missing")
    None => "missing"
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
fn observations_json_text(showcase : Map[String, Json]?) -> String {
  let observations = match showcase {
    Some(target) => optional_object(target, "observations")
    None => None
  }
  let observations = match observations {
    Some(value) => value
    None => return "{}"
  }
  let builder = StringBuilder::new()
  builder.write_char('{')
  let first = Ref(true)
  for key in proof_keys() {
    let value = optional_string(observations, key)
    if value != "" {
      if !first.val {
        builder.write_char(',')
      }
      first.val = false
      builder.write_char('"')
      builder.write_string(json_escape(key))
      builder.write_string("\":\"")
      builder.write_string(json_escape(value))
      builder.write_char('"')
    }
  }
  builder.write_char('}')
  builder.to_string()
}

///|
fn join_lines(lines : Array[String]) -> String {
  let builder = StringBuilder::new()
  for line in lines {
    builder.write_string(line)
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
fn normalize_separators(path : String) -> String {
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
fn parent_dir(path : String) -> String {
  let normalized = normalize_separators(path)
  let slash = Ref(-1)
  for index in 0..<normalized.length() {
    if normalized[index] == '/' {
      slash.val = index
    }
  }
  if slash.val < 0 {
    ""
  } else if slash.val == 0 {
    "/"
  } else {
    normalized[:slash.val].to_owned()
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
  let normalized = normalize_separators(path)
  let current = Ref(if normalized.has_prefix("/") { "/" } else { "" })
  for part_view in normalized.split("/") {
    let part = part_view.to_owned()
    if part == "" {
      continue
    }
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
fn record_web_renderer_proof_manifest(
  options : CliOptions,
) -> Result[RecordResult, Array[String]] {
  let text = match @tools.read_required_text(
    options.web_presentation_manifest,
    options.web_presentation_manifest,
  ) {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  let parsed = @json.parse(text) catch {
    _ => return Err(["failed to read JSON: invalid JSON"])
  }
  let manifest = match json_object(Some(parsed)) {
    Some(value) => value
    None => return Err(["manifest root must be an object"])
  }
  let showcase = find_showcase_target(manifest)
  let artifact_dir = parent_dir(options.output)
  let log_path = if artifact_dir == "" {
    "webgpu-wasm-web.log"
  } else {
    artifact_dir + "/webgpu-wasm-web.log"
  }
  match mkdir_p(artifact_dir) {
    Ok(_) => ()
    Err(message) => return Err([message])
  }
  let web_presentation_status = match manifest.get("overallStatus") {
    Some(Json::String(value)) => value
    _ => "unknown"
  }
  let target_status = showcase_status(showcase)
  let notes = [
    "webPresentationManifest=" + options.web_presentation_manifest,
    "webPresentationStatus=" + web_presentation_status,
    "showcaseStatus=" + target_status,
    "showcaseObservations=" + observations_json_text(showcase),
  ]
  let log_text = join_lines(notes + marker_lines(showcase))
  match @tools.write_text_file(log_path, log_text, "web renderer proof log") {
    Ok(_) => ()
    Err(message) => return Err([message])
  }
  let missing = missing_proofs(showcase)
  let overall_status = match manifest.get("overallStatus") {
    Some(Json::String(value)) => value
    _ => "failed"
  }
  let missing_text = if missing.is_empty() { "(none)" } else { missing.join(",") }
  let summary = if overall_status != "passed" || !missing.is_empty() {
    [
      "web renderer proof failed summary:",
      "  webPresentationStatus=" + overall_status,
      "  showcaseStatus=" + target_status,
      "  missingProofs=" + missing_text,
      "  log=" + log_path,
    ].join("\n") + "\n"
  } else {
    ""
  }
  ignore(options.require_passed)
  Ok({ summary, })
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match record_web_renderer_proof_manifest(options) {
        Ok(result) => {
          if result.summary != "" {
            println(result.summary)
          }
          0
        }
        Err(failures) => {
          for failure in failures {
            println("web renderer proof manifest: " + failure)
          }
          1
        }
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
