///|
struct CliOptions {
  backend : String
  platform : String
  artifact_name : String
  output : String
  logs : Array[String]
  require_passed : Bool
  help : Bool
}

///|
struct ProofConfig {
  key : String
  marker : String
  required : Array[String]
}

///|
struct FontMetadata {
  family : String
  source : String
  text_system : String
  shaper : String
  fallback_script_tag : String?
  fallback_language_tags : Array[String]?
  fallback_language_tag_count : Int?
  fallback_request_language_count : Int?
}

///|
struct GlyphMetadata {
  format : String
  glyph_count : Int
  cluster_count : Int
  high_saturation_pixels : Int
  alpha_pixels : Int
  key : String?
  width : Int?
  height : Int?
  resolved_missing_glyph_count : Int?
  missing_glyph_recovery_ready : Bool?
  fallback_request_character : Int?
}

///|
struct ColorEmojiMetadata {
  font : FontMetadata
  glyph : GlyphMetadata
}

///|
struct Observation {
  key : String
  status : String
  evidence : Array[String]
  artifacts : Array[String]
  metadata : ColorEmojiMetadata?
}

///|
struct RecordResult {
  output : String
  status : String
}

///|
fn usage() -> String {
  "Usage: tools/moui/record_renderer_proof_manifest --backend <wgpu-native|skia-native|webgpu-wasm> --platform <macos|windows|linux|web> --artifact-name <name> --output <path> --log <path> [--log <path> ...] [--require-passed]"
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let backend = Ref("")
  let platform = Ref("")
  let artifact_name = Ref("")
  let output = Ref("")
  let logs : Array[String] = []
  let require_passed = Ref(false)
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--backend" => {
        if index + 1 >= args.length() {
          return Err("missing value for --backend")
        }
        backend.val = args[index + 1]
        index += 2
      }
      "--platform" => {
        if index + 1 >= args.length() {
          return Err("missing value for --platform")
        }
        platform.val = args[index + 1]
        index += 2
      }
      "--artifact-name" => {
        if index + 1 >= args.length() {
          return Err("missing value for --artifact-name")
        }
        artifact_name.val = args[index + 1]
        index += 2
      }
      "--output" => {
        if index + 1 >= args.length() {
          return Err("missing value for --output")
        }
        output.val = args[index + 1]
        index += 2
      }
      "--log" => {
        if index + 1 >= args.length() {
          return Err("missing value for --log")
        }
        logs.push(args[index + 1])
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
  if !help.val &&
    (
      backend.val == "" ||
      platform.val == "" ||
      artifact_name.val == "" ||
      output.val == "" ||
      logs.is_empty()
    ) {
    return Err(usage())
  }
  Ok({
    backend: backend.val,
    platform: platform.val,
    artifact_name: artifact_name.val,
    output: output.val,
    logs,
    require_passed: require_passed.val,
    help: help.val,
  })
}

///|
fn marker_configs(backend : String) -> Array[ProofConfig] {
  [
    {
      key: "radialGradient",
      marker: "MoUI renderer proof radialGradient passed",
      required: ["center-mid-edge-pixels", "shader-payload"],
    },
    {
      key: "transformPixels",
      marker: "MoUI renderer proof transformPixels passed",
      required: ["pixel-markers"],
    },
    {
      key: "colorEmojiPixels",
      marker: "MoUI renderer proof colorEmojiPixels passed",
      required: if backend == "skia-native" {
        [
          "high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata",
          "fallback-request", "emoji-hint", "stable-glyph-key",
        ]
      } else {
        [
          "high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata",
        ]
      },
    },
    {
      key: "zwjGrapheme",
      marker: "MoUI renderer proof zwjGrapheme passed",
      required: ["single-grapheme-cluster", "no-interior-caret"],
    },
    {
      key: "bidiLayout",
      marker: "MoUI renderer proof bidiLayout passed",
      required: if backend == "skia-native" {
        ["engine=skparagraph", "bidi_visual_order_ready=true", "visual-order"]
      } else {
        ["visual-order"]
      },
    },
    {
      key: "paragraphWrapping",
      marker: "MoUI renderer proof paragraphWrapping passed",
      required: if backend == "skia-native" {
        [
          "engine=skparagraph", "native_paragraph_ready=true", "line-metrics", "later-line-pixels",
        ]
      } else {
        ["line-metrics", "later-line-pixels"]
      },
    },
    {
      key: "selectionRects",
      marker: "MoUI renderer proof selectionRects passed",
      required: if backend == "skia-native" {
        [
          "engine=skparagraph", "selection-rects", "line-range", "rect-geometry",
          "hit-test",
        ]
      } else {
        ["selection-rects", "line-range"]
      },
    },
    {
      key: "graphemeEditing",
      marker: "MoUI renderer proof graphemeEditing passed",
      required: ["grapheme-boundaries", "edit-actions"],
    },
    {
      key: "imeCandidateAnchor",
      marker: "MoUI renderer proof imeCandidateAnchor passed",
      required: if backend == "skia-native" {
        [
          "candidate-anchor", "surrounding-text", "grapheme-boundary", "utf8-offsets",
        ]
      } else {
        ["candidate-anchor", "surrounding-text"]
      },
    },
    {
      key: "imeCompositionVisual",
      marker: "MoUI renderer proof imeCompositionVisual passed",
      required: if backend == "skia-native" {
        ["composition-range", "composition-cursor", "preedit-pixels"]
      } else {
        ["composition-range", "preedit-pixels"]
      },
    },
    {
      key: "asyncImageSecondFrame",
      marker: "MoUI renderer proof asyncImageSecondFrame passed",
      required: ["late-completion", "repaint-request", "second-frame-pixels"],
    },
  ]
}

///|
fn is_space(char : UInt16) -> Bool {
  char == ' ' || char == '\n' || char == '\r' || char == '\t'
}

///|
fn whitespace_tokens(text : String) -> Array[String] {
  let tokens : Array[String] = []
  let start = Ref(-1)
  for index in 0..<text.length() {
    if is_space(text[index]) {
      if start.val >= 0 {
        tokens.push(text[start.val:index].to_owned())
        start.val = -1
      }
    } else if start.val < 0 {
      start.val = index
    }
  }
  if start.val >= 0 {
    tokens.push(text[start.val:].to_owned())
  }
  tokens
}

///|
fn index_of_char(text : String, target : UInt16) -> Int {
  for index in 0..<text.length() {
    if text[index] == target {
      return index
    }
  }
  -1
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
fn artifact_path(path : String) -> String {
  let normalized = normalize_separators(path)
  let marker = "/artifacts/"
  let marker_index = find_substring(normalized, marker)
  if marker_index >= 0 {
    normalized[marker_index + 1:].to_owned()
  } else if normalized.has_prefix("artifacts/") {
    normalized
  } else {
    normalized
  }
}

///|
fn read_log(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ =>
      "\nMoUI renderer proof log read failed: " + path + ": could not be read\n"
  }
}

///|
fn join_with_newline(values : Array[String]) -> String {
  let builder = StringBuilder::new()
  for index in 0..<values.length() {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(values[index])
  }
  builder.to_string()
}

///|
fn parse_metadata_fields(log : String, prefix : String) -> Map[String, String]? {
  for line_view in log.split("\n") {
    let mut line = line_view.to_owned()
    if line.has_suffix("\r") {
      line = line[:line.length() - 1].to_owned()
    }
    if line.has_prefix(prefix) {
      let fields : Map[String, String] = {}
      for
        token in whitespace_tokens(
          line[prefix.length():].to_owned().trim().to_owned(),
        ) {
        let separator = index_of_char(token, '=')
        if separator > 0 {
          fields[token[:separator].to_owned()] = token[separator + 1:].to_owned()
        }
      }
      return Some(fields)
    }
  }
  None
}

///|
fn parse_number(value : String) -> Int {
  if value == "" {
    return 0
  }
  let sign = Ref(1)
  let start = Ref(0)
  if value[0] == '-' {
    sign.val = -1
    start.val = 1
  }
  let result = Ref(0)
  let saw_digit = Ref(false)
  for index in start.val..<value.length() {
    let char = value[index]
    if char < '0' || char > '9' {
      return 0
    }
    saw_digit.val = true
    result.val = result.val * 10 + char.to_int() - '0'.to_int()
  }
  if saw_digit.val {
    result.val * sign.val
  } else {
    0
  }
}

///|
fn parse_boolean(value : String) -> Bool {
  value == "true"
}

///|
fn parse_language_tags(value : String) -> Array[String] {
  let tags : Array[String] = []
  if value.trim().to_owned() == "" {
    return tags
  }
  for tag_view in value.split("+") {
    let tag = tag_view.to_owned().trim().to_owned()
    if tag != "" {
      tags.push(tag)
    }
  }
  tags
}

///|
fn field(fields : Map[String, String], name : String) -> String? {
  fields.get(name)
}

///|
fn numeric_field(fields : Map[String, String], name : String) -> Int? {
  match field(fields, name) {
    Some(value) => Some(parse_number(value))
    None => None
  }
}

///|
fn bool_field(fields : Map[String, String], name : String) -> Bool? {
  match field(fields, name) {
    Some(value) => Some(parse_boolean(value))
    None => None
  }
}

///|
fn color_emoji_metadata(log : String) -> ColorEmojiMetadata? {
  let fields = match
    parse_metadata_fields(log, "MoUI renderer proof colorEmojiPixels metadata ") {
    Some(value) => value
    None => return None
  }
  let fallback_language_tags = match field(fields, "fallback_language_tags") {
    Some(value) if value.trim().to_owned() != "" =>
      Some(parse_language_tags(value))
    _ => None
  }
  Some({
    font: {
      family: field(fields, "font_family").unwrap_or("unknown"),
      source: field(fields, "font_source").unwrap_or("unknown"),
      text_system: field(fields, "text_system").unwrap_or("unknown"),
      shaper: field(fields, "shaper").unwrap_or("unknown"),
      fallback_script_tag: field(fields, "fallback_script_tag"),
      fallback_language_tags,
      fallback_language_tag_count: numeric_field(
        fields, "fallback_language_tag_count",
      ),
      fallback_request_language_count: numeric_field(
        fields, "fallback_request_language_count",
      ),
    },
    glyph: {
      format: field(fields, "glyph_format").unwrap_or("unknown"),
      glyph_count: numeric_field(fields, "glyph_count").unwrap_or(0),
      cluster_count: numeric_field(fields, "cluster_count").unwrap_or(0),
      high_saturation_pixels: numeric_field(fields, "high_saturation_pixels").unwrap_or(
        0,
      ),
      alpha_pixels: numeric_field(fields, "alpha_pixels").unwrap_or(0),
      key: field(fields, "glyph_key"),
      width: numeric_field(fields, "glyph_width"),
      height: numeric_field(fields, "glyph_height"),
      resolved_missing_glyph_count: numeric_field(
        fields, "resolved_missing_glyph_count",
      ),
      missing_glyph_recovery_ready: bool_field(
        fields, "missing_glyph_recovery_ready",
      ),
      fallback_request_character: numeric_field(
        fields, "fallback_request_character",
      ),
    },
  })
}

///|
fn string_array_all_non_empty(values : Array[String]) -> Bool {
  for value in values {
    if value.trim().to_owned() == "" {
      return false
    }
  }
  true
}

///|
fn plus_join(values : Array[String]) -> String {
  let builder = StringBuilder::new()
  for index in 0..<values.length() {
    if index > 0 {
      builder.write_char('+')
    }
    builder.write_string(values[index])
  }
  builder.to_string()
}

///|
fn option_string_non_empty(value : String?) -> Bool {
  match value {
    Some(text) => text.trim().to_owned() != ""
    None => false
  }
}

///|
fn option_int_positive(value : Int?) -> Bool {
  match value {
    Some(number) => number > 0
    None => false
  }
}

///|
fn skia_native_color_emoji_metadata_ready(
  metadata : ColorEmojiMetadata,
  backend : String,
) -> Bool {
  if backend != "skia-native" {
    return true
  }
  let font = metadata.font
  let glyph = metadata.glyph
  let fallback_script_tag = match font.fallback_script_tag {
    Some(value) if value.trim().to_owned() != "" => value
    _ => return false
  }
  let fallback_language_tags = match font.fallback_language_tags {
    Some(values) => values
    None => return false
  }
  if fallback_language_tags.length() < 1 ||
    !string_array_all_non_empty(fallback_language_tags) ||
    fallback_language_tags[0] != fallback_script_tag {
    return false
  }
  let fallback_language_tag_count = match font.fallback_language_tag_count {
    Some(value) if value >= 1 => value
    _ => return false
  }
  let fallback_request_language_count = match
    font.fallback_request_language_count {
    Some(value) => value
    None => return false
  }
  let resolved_missing_glyph_count = match glyph.resolved_missing_glyph_count {
    Some(value) if value >= 0 => value
    _ => return false
  }
  ignore(resolved_missing_glyph_count)
  let fallback_request_character = match glyph.fallback_request_character {
    Some(value) if value > 0 => value
    _ => return false
  }
  match glyph.missing_glyph_recovery_ready {
    Some(true) => ()
    _ => return false
  }
  if fallback_language_tags.length() != fallback_language_tag_count ||
    fallback_request_language_count != fallback_language_tag_count {
    return false
  }
  let glyph_key = match glyph.key {
    Some(value) => value
    None => return false
  }
  let expected_parts = [
    font.source,
    font.text_system,
    font.shaper,
    "script=" + fallback_script_tag,
    "langs=" + fallback_request_language_count.to_string(),
    "lang-tags=" + plus_join(fallback_language_tags),
    "emoji-u+" + fallback_request_character.to_string(),
    glyph.format,
  ]
  for part in expected_parts {
    if part == "" || !glyph_key.contains(part) {
      return false
    }
  }
  true
}

///|
fn color_emoji_metadata_ready(
  metadata : ColorEmojiMetadata?,
  backend : String,
) -> Bool {
  let metadata = match metadata {
    Some(value) => value
    None => return false
  }
  let font = metadata.font
  let glyph = metadata.glyph
  option_string_non_empty(Some(font.family)) &&
  font.family != "unknown" &&
  option_string_non_empty(Some(font.source)) &&
  font.source != "unknown" &&
  option_string_non_empty(Some(font.text_system)) &&
  font.text_system != "unknown" &&
  glyph.format == "rgba" &&
  glyph.glyph_count >= 1 &&
  glyph.cluster_count >= 1 &&
  option_string_non_empty(glyph.key) &&
  option_int_positive(glyph.width) &&
  option_int_positive(glyph.height) &&
  glyph.high_saturation_pixels >= 8 &&
  glyph.alpha_pixels > 0 &&
  skia_native_color_emoji_metadata_ready(metadata, backend)
}

///|
fn all_required_tokens_present(log : String, tokens : Array[String]) -> Bool {
  for token in tokens {
    if !log.contains(token) {
      return false
    }
  }
  true
}

///|
fn observation_for(
  config : ProofConfig,
  backend : String,
  combined_log : String,
  artifacts : Array[String],
) -> Observation {
  let has_marker = combined_log.contains(config.marker)
  let has_evidence = all_required_tokens_present(combined_log, config.required)
  let metadata = if config.key == "colorEmojiPixels" {
    color_emoji_metadata(combined_log)
  } else {
    None
  }
  let passed = has_marker &&
    has_evidence &&
    (
      config.key != "colorEmojiPixels" ||
      color_emoji_metadata_ready(metadata, backend)
    )
  {
    key: config.key,
    status: if passed {
      "passed"
    } else {
      "failed"
    },
    evidence: if passed {
      config.required
    } else {
      []
    },
    artifacts,
    metadata,
  }
}

///|
fn all_observations_passed(observations : Array[Observation]) -> Bool {
  for observation in observations {
    if observation.status != "passed" {
      return false
    }
  }
  true
}

///|
fn env_or(name : String, fallback : String) -> String {
  match @env.get_env_var(name) {
    Some(value) if value != "" => value
    _ => fallback
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
fn write_json_string(builder : StringBuilder, value : String) -> Unit {
  builder.write_char('"')
  builder.write_string(json_escape(value))
  builder.write_char('"')
}

///|
fn write_string_array(
  builder : StringBuilder,
  values : Array[String],
  indent : String,
) -> Unit {
  if values.is_empty() {
    builder.write_string("[]")
    return
  }
  builder.write_string("[\n")
  for index in 0..<values.length() {
    if index > 0 {
      builder.write_string(",\n")
    }
    builder.write_string(indent)
    write_json_string(builder, values[index])
  }
  builder.write_string("\n")
  builder.write_string(indent[:indent.length() - 2].to_owned())
  builder.write_char(']')
}

///|
fn write_optional_string_field(
  builder : StringBuilder,
  name : String,
  value : String?,
  comma : Bool,
  indent : String,
) -> Bool {
  match value {
    Some(text) => {
      if comma {
        builder.write_string(",\n")
      }
      builder.write_string(indent)
      write_json_string(builder, name)
      builder.write_string(": ")
      write_json_string(builder, text)
      true
    }
    None => comma
  }
}

///|
fn write_optional_int_field(
  builder : StringBuilder,
  name : String,
  value : Int?,
  comma : Bool,
  indent : String,
) -> Bool {
  match value {
    Some(number) => {
      if comma {
        builder.write_string(",\n")
      }
      builder.write_string(indent)
      write_json_string(builder, name)
      builder.write_string(": ")
      builder.write_string(number.to_string())
      true
    }
    None => comma
  }
}

///|
fn write_optional_bool_field(
  builder : StringBuilder,
  name : String,
  value : Bool?,
  comma : Bool,
  indent : String,
) -> Bool {
  match value {
    Some(value) => {
      if comma {
        builder.write_string(",\n")
      }
      builder.write_string(indent)
      write_json_string(builder, name)
      builder.write_string(": ")
      builder.write_string(if value { "true" } else { "false" })
      true
    }
    None => comma
  }
}

///|
fn write_metadata(
  builder : StringBuilder,
  metadata : ColorEmojiMetadata,
  indent : String,
) -> Unit {
  builder.write_string("{\n")
  builder.write_string(indent + "  \"font\": {\n")
  builder.write_string(indent + "    \"family\": ")
  write_json_string(builder, metadata.font.family)
  builder.write_string(",\n")
  builder.write_string(indent + "    \"source\": ")
  write_json_string(builder, metadata.font.source)
  builder.write_string(",\n")
  builder.write_string(indent + "    \"textSystem\": ")
  write_json_string(builder, metadata.font.text_system)
  builder.write_string(",\n")
  builder.write_string(indent + "    \"shaper\": ")
  write_json_string(builder, metadata.font.shaper)
  let comma = Ref(true)
  comma.val = write_optional_string_field(
    builder,
    "fallbackScriptTag",
    metadata.font.fallback_script_tag,
    comma.val,
    indent + "    ",
  )
  match metadata.font.fallback_language_tags {
    Some(tags) => {
      if comma.val {
        builder.write_string(",\n")
      }
      builder.write_string(indent + "    \"fallbackLanguageTags\": ")
      write_string_array(builder, tags, indent + "      ")
      comma.val = true
    }
    None => ()
  }
  comma.val = write_optional_int_field(
    builder,
    "fallbackLanguageTagCount",
    metadata.font.fallback_language_tag_count,
    comma.val,
    indent + "    ",
  )
  comma.val = write_optional_int_field(
    builder,
    "fallbackRequestLanguageCount",
    metadata.font.fallback_request_language_count,
    comma.val,
    indent + "    ",
  )
  ignore(comma.val)
  builder.write_string("\n")
  builder.write_string(indent + "  },\n")
  builder.write_string(indent + "  \"glyph\": {\n")
  builder.write_string(indent + "    \"format\": ")
  write_json_string(builder, metadata.glyph.format)
  builder.write_string(",\n")
  builder.write_string(indent + "    \"glyphCount\": ")
  builder.write_string(metadata.glyph.glyph_count.to_string())
  builder.write_string(",\n")
  builder.write_string(indent + "    \"clusterCount\": ")
  builder.write_string(metadata.glyph.cluster_count.to_string())
  builder.write_string(",\n")
  builder.write_string(indent + "    \"highSaturationPixels\": ")
  builder.write_string(metadata.glyph.high_saturation_pixels.to_string())
  builder.write_string(",\n")
  builder.write_string(indent + "    \"alphaPixels\": ")
  builder.write_string(metadata.glyph.alpha_pixels.to_string())
  let glyph_comma = Ref(true)
  glyph_comma.val = write_optional_string_field(
    builder,
    "key",
    metadata.glyph.key,
    glyph_comma.val,
    indent + "    ",
  )
  glyph_comma.val = write_optional_int_field(
    builder,
    "width",
    metadata.glyph.width,
    glyph_comma.val,
    indent + "    ",
  )
  glyph_comma.val = write_optional_int_field(
    builder,
    "height",
    metadata.glyph.height,
    glyph_comma.val,
    indent + "    ",
  )
  glyph_comma.val = write_optional_int_field(
    builder,
    "resolvedMissingGlyphCount",
    metadata.glyph.resolved_missing_glyph_count,
    glyph_comma.val,
    indent + "    ",
  )
  glyph_comma.val = write_optional_bool_field(
    builder,
    "missingGlyphRecoveryReady",
    metadata.glyph.missing_glyph_recovery_ready,
    glyph_comma.val,
    indent + "    ",
  )
  glyph_comma.val = write_optional_int_field(
    builder,
    "fallbackRequestCharacter",
    metadata.glyph.fallback_request_character,
    glyph_comma.val,
    indent + "    ",
  )
  ignore(glyph_comma.val)
  builder.write_string("\n")
  builder.write_string(indent + "  }\n")
  builder.write_string(indent + "}")
}

///|
fn write_observation(
  builder : StringBuilder,
  observation : Observation,
  indent : String,
) -> Unit {
  builder.write_string(indent + "{\n")
  builder.write_string(indent + "  \"status\": ")
  write_json_string(builder, observation.status)
  builder.write_string(",\n")
  builder.write_string(indent + "  \"evidence\": ")
  write_string_array(builder, observation.evidence, indent + "    ")
  builder.write_string(",\n")
  builder.write_string(indent + "  \"artifacts\": ")
  write_string_array(builder, observation.artifacts, indent + "    ")
  match observation.metadata {
    Some(metadata) => {
      builder.write_string(",\n")
      builder.write_string(indent + "  \"metadata\": ")
      write_metadata(builder, metadata, indent + "  ")
      builder.write_string("\n")
    }
    None => builder.write_string("\n")
  }
  builder.write_string(indent + "}")
}

///|
fn manifest_text(
  options : CliOptions,
  status : String,
  observations : Array[Observation],
  artifacts : Array[String],
  observations_passed : Bool,
  is_github_actions : Bool,
) -> String {
  let repository = env_or("GITHUB_REPOSITORY", "unknown/unknown")
  let run_id = env_or("GITHUB_RUN_ID", "local")
  let server_url = env_or("GITHUB_SERVER_URL", "https://github.com")
  let runner = env_or("RUNNER_NAME", env_or("RUNNER_OS", "local"))
  let builder = StringBuilder::new()
  builder.write_string("{\n")
  builder.write_string("  \"schemaVersion\": 1,\n")
  builder.write_string("  \"mode\": \"renderer-proof\",\n")
  builder.write_string(
    "  \"generatedBy\": \"scripts/record-renderer-proof-manifest.mjs\",\n",
  )
  builder.write_string("  \"backend\": ")
  write_json_string(builder, options.backend)
  builder.write_string(",\n")
  builder.write_string("  \"platform\": ")
  write_json_string(builder, options.platform)
  builder.write_string(",\n")
  builder.write_string("  \"status\": ")
  write_json_string(builder, status)
  builder.write_string(",\n")
  builder.write_string("  \"provenance\": {\n")
  builder.write_string("    \"kind\": ")
  write_json_string(
    builder,
    if is_github_actions {
      "github-actions"
    } else {
      "matching-host-artifact"
    },
  )
  builder.write_string(",\n")
  builder.write_string("    \"workflow\": ")
  write_json_string(builder, env_or("GITHUB_WORKFLOW", "local"))
  builder.write_string(",\n")
  builder.write_string("    \"job\": ")
  write_json_string(builder, env_or("GITHUB_JOB", "local"))
  builder.write_string(",\n")
  builder.write_string("    \"runId\": ")
  write_json_string(builder, run_id)
  builder.write_string(",\n")
  builder.write_string("    \"runUrl\": ")
  write_json_string(
    builder,
    server_url + "/" + repository + "/actions/runs/" + run_id,
  )
  builder.write_string(",\n")
  builder.write_string("    \"runner\": ")
  write_json_string(builder, runner)
  builder.write_string(",\n")
  builder.write_string("    \"artifactName\": ")
  write_json_string(builder, options.artifact_name)
  builder.write_string("\n")
  builder.write_string("  },\n")
  builder.write_string("  \"artifacts\": ")
  write_string_array(builder, artifacts, "    ")
  builder.write_string(",\n")
  builder.write_string("  \"observations\": {\n")
  for index in 0..<observations.length() {
    if index > 0 {
      builder.write_string(",\n")
    }
    let observation = observations[index]
    builder.write_string("    ")
    write_json_string(builder, observation.key)
    builder.write_string(": ")
    write_observation(builder, observation, "    ")
  }
  builder.write_string("\n")
  builder.write_string("  },\n")
  builder.write_string("  \"notes\": ")
  if observations_passed && !is_github_actions {
    write_string_array(
      builder,
      [
        "All renderer observations passed locally, but renderer-proof manifests require GitHub Actions provenance before status can be passed.",
      ],
      "    ",
    )
  } else {
    builder.write_string("[]")
  }
  builder.write_string("\n")
  builder.write_string("}\n")
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
fn record_renderer_proof_manifest(
  options : CliOptions,
) -> Result[RecordResult, Array[String]] {
  let log_texts : Array[String] = []
  for path in options.logs {
    log_texts.push(read_log(path))
  }
  let combined_log = join_with_newline(log_texts)
  let rel_logs : Array[String] = []
  for path in options.logs {
    rel_logs.push(artifact_path(path))
  }
  let observations : Array[Observation] = []
  for config in marker_configs(options.backend) {
    observations.push(
      observation_for(config, options.backend, combined_log, rel_logs),
    )
  }
  let observations_passed = all_observations_passed(observations)
  let is_github_actions = @env.get_env_var("GITHUB_ACTIONS") == Some("true")
  let status = if observations_passed && is_github_actions {
    "passed"
  } else {
    "failed"
  }
  let artifacts : Array[String] = []
  for path in rel_logs {
    artifacts.push(path)
  }
  artifacts.push(artifact_path(options.output))
  match mkdir_p(parent_dir(options.output)) {
    Ok(_) => ()
    Err(message) => return Err([message])
  }
  match
    @tools.write_text_file(
      options.output,
      manifest_text(
        options, status, observations, artifacts, observations_passed, is_github_actions,
      ),
      "renderer proof manifest",
    ) {
    Ok(_) => ()
    Err(message) => return Err([message])
  }
  if options.require_passed && status != "passed" {
    return Err(["status must be passed"])
  }
  Ok({ output: options.output, status })
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match record_renderer_proof_manifest(options) {
        Ok(result) => {
          println(
            "renderer proof manifest: " +
            result.output +
            " (" +
            result.status +
            ")",
          )
          0
        }
        Err(failures) => {
          for failure in failures {
            println("renderer proof manifest: " + failure)
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
