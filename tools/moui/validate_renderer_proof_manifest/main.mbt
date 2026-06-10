///|
struct CliOptions {
  manifest_path : String
  display_path : String
  require_passed : Bool
  artifact_root : String
  help : Bool
}

///|
struct ArtifactContext {
  root : String
  files : Array[String]
}

///|
fn usage() -> String {
  "Usage: tools/moui/validate_renderer_proof_manifest <renderer-proof.json> [--require-passed] [--artifact-root <dir>]"
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let manifest_path = Ref("")
  let display_path = Ref("")
  let require_passed = Ref(false)
  let artifact_root = Ref("")
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--require-passed" => {
        require_passed.val = true
        index += 1
      }
      "--artifact-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --artifact-root")
        }
        artifact_root.val = args[index + 1]
        index += 2
      }
      "--display-path" => {
        if index + 1 >= args.length() {
          return Err("missing value for --display-path")
        }
        display_path.val = args[index + 1]
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
        if manifest_path.val != "" {
          return Err("unexpected argument: " + value)
        }
        manifest_path.val = value
        index += 1
      }
    }
  }
  if !help.val && manifest_path.val == "" {
    return Err("missing renderer-proof.json path")
  }
  let display = if display_path.val == "" {
    manifest_path.val
  } else {
    display_path.val
  }
  Ok({
    manifest_path: manifest_path.val,
    display_path: display,
    require_passed: require_passed.val,
    artifact_root: artifact_root.val,
    help: help.val,
  })
}

///|
fn allowed_backends() -> Array[String] {
  ["wgpu-native", "skia-native", "webgpu-wasm"]
}

///|
fn allowed_platforms() -> Array[String] {
  ["macos", "windows", "linux", "web"]
}

///|
fn allowed_status() -> Array[String] {
  ["passed", "failed", "pending"]
}

///|
fn base_observation_keys() -> Array[String] {
  [
    "radialGradient", "transformPixels", "colorEmojiPixels", "zwjGrapheme", "bidiLayout",
    "paragraphWrapping", "selectionRects", "graphemeEditing", "imeCandidateAnchor",
    "imeCompositionVisual", "asyncImageSecondFrame",
  ]
}

///|
fn required_observation_evidence(
  backend : String,
  key : String,
) -> Array[String] {
  if backend == "skia-native" {
    match key {
      "colorEmojiPixels" =>
        [
          "high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata",
          "fallback-request", "emoji-hint", "stable-glyph-key",
        ]
      "bidiLayout" =>
        ["engine=skparagraph", "bidi_visual_order_ready=true", "visual-order"]
      "paragraphWrapping" =>
        [
          "engine=skparagraph", "native_paragraph_ready=true", "line-metrics", "later-line-pixels",
        ]
      "selectionRects" =>
        [
          "engine=skparagraph", "selection-rects", "line-range", "rect-geometry",
          "hit-test",
        ]
      "imeCandidateAnchor" =>
        [
          "candidate-anchor", "surrounding-text", "grapheme-boundary", "utf8-offsets",
        ]
      "imeCompositionVisual" =>
        ["composition-range", "composition-cursor", "preedit-pixels"]
      _ => required_observation_evidence("webgpu-wasm", key)
    }
  } else {
    match key {
      "radialGradient" => ["center-mid-edge-pixels", "shader-payload"]
      "transformPixels" => ["pixel-markers"]
      "colorEmojiPixels" =>
        [
          "high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata",
        ]
      "zwjGrapheme" => ["single-grapheme-cluster", "no-interior-caret"]
      "bidiLayout" => ["visual-order"]
      "paragraphWrapping" => ["line-metrics", "later-line-pixels"]
      "selectionRects" => ["selection-rects", "line-range"]
      "graphemeEditing" => ["grapheme-boundaries", "edit-actions"]
      "imeCandidateAnchor" => ["candidate-anchor", "surrounding-text"]
      "imeCompositionVisual" => ["composition-range", "preedit-pixels"]
      "asyncImageSecondFrame" =>
        ["late-completion", "repaint-request", "second-frame-pixels"]
      _ => []
    }
  }
}

///|
fn json_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn json_object_value(
  value : Json,
  label : String,
  failures : Array[String],
) -> Map[String, Json] {
  match value {
    Json::Object(fields) => fields
    _ => {
      failures.push(label + " must be an object")
      {}
    }
  }
}

///|
fn require_object(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> Map[String, Json] {
  match object.get(field) {
    Some(Json::Object(fields)) => fields
    _ => {
      failures.push(label + " must be an object")
      {}
    }
  }
}

///|
fn require_string(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> String {
  match object.get(field) {
    Some(Json::String(value)) if value.trim().to_owned() != "" => value
    _ => {
      failures.push(label + "." + field + " must be a non-empty string")
      ""
    }
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
fn require_number(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> Double {
  match object.get(field) {
    Some(Json::Number(number, repr=_)) => number
    _ => {
      failures.push(label + "." + field + " must be a finite number")
      0.0
    }
  }
}

///|
fn require_array(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> Array[Json] {
  match object.get(field) {
    Some(Json::Array(values)) => values
    _ => {
      failures.push(label + "." + field + " must be an array")
      []
    }
  }
}

///|
fn require_string_array(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> Array[String] {
  let values = require_array(object, field, label, failures)
  let strings : Array[String] = []
  for index in 0..<values.length() {
    match values[index] {
      Json::String(value) if value.trim().to_owned() != "" =>
        strings.push(value)
      _ =>
        failures.push(
          label + "." + field + "[\{index}] must be a non-empty string",
        )
    }
  }
  strings
}

///|
fn json_string_array_contains(values : Array[Json], expected : String) -> Bool {
  values.any(value => {
    match value {
      Json::String(text) => text == expected
      _ => false
    }
  })
}

///|
fn string_array_contains(values : Array[String], expected : String) -> Bool {
  values.any(value => value == expected)
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
fn normalize_slashes(path : String) -> String {
  path.replace(old="\\", new="/")
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
fn collect_files(
  root : String,
  directory : String,
  out : Array[String],
) -> Result[Unit, String] {
  let entries : Array[String] = @fs.read_dir(directory) catch {
    _ => return Err("artifact root could not be read: " + root)
  }
  for entry in entries {
    let path = @tools.join_path(directory, entry)
    if @tools.directory_exists(path) {
      match collect_files(root, path, out) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    } else if @tools.file_exists(path) {
      out.push(normalize_slashes(path))
    }
  }
  Ok(())
}

///|
fn artifact_context(root : String) -> Result[ArtifactContext?, String] {
  if root == "" {
    return Ok(None)
  }
  if !@tools.directory_exists(root) {
    return Err("artifact root does not exist: " + root)
  }
  let files : Array[String] = []
  match collect_files(root, root, files) {
    Ok(_) => Ok(Some({ root, files }))
    Err(message) => Err(message)
  }
}

///|
fn artifact_exists(context : ArtifactContext?, artifact : String) -> Bool {
  match context {
    None => true
    Some(ctx) => {
      let normalized = normalize_slashes(artifact)
      if @tools.file_exists(@tools.join_path(ctx.root, normalized)) {
        return true
      }
      let suffix = "/" + normalized
      let base = basename(normalized)
      ctx.files.any(path => path.has_suffix(suffix) || basename(path) == base)
    }
  }
}

///|
fn require_artifact_paths(
  paths : Array[Json],
  label : String,
  failures : Array[String],
) -> Unit {
  if paths.is_empty() {
    failures.push(label + " must include at least one artifact path")
  }
  for index in 0..<paths.length() {
    match paths[index] {
      Json::String(artifact) if artifact.trim().to_owned() != "" =>
        if !artifact.has_prefix("artifacts/") {
          failures.push(label + "[\{index}] must stay under artifacts/")
        }
      _ => failures.push(label + "[\{index}] must be a non-empty string")
    }
  }
}

///|
fn require_artifact_files_exist(
  paths : Array[Json],
  label : String,
  context : ArtifactContext?,
  failures : Array[String],
) -> Unit {
  if context is None {
    return
  }
  for artifact in paths {
    match artifact {
      Json::String(path) if path.trim().to_owned() != "" =>
        if !artifact_exists(context, path) {
          failures.push(label + " missing uploaded artifact file: " + path)
        }
      _ => ()
    }
  }
}

///|
fn validate_schema_and_header(
  manifest : Map[String, Json],
  require_passed : Bool,
  failures : Array[String],
) -> (String, String, String) {
  match manifest.get("schemaVersion") {
    Some(Json::Number(number, repr=_)) if number == 1.0 => ()
    _ => failures.push("schemaVersion must be 1")
  }
  match manifest.get("mode") {
    Some(Json::String("renderer-proof")) => ()
    _ => failures.push("mode must be 'renderer-proof'")
  }
  let backend = require_string(manifest, "backend", "manifest", failures)
  if backend != "" && !string_array_contains(allowed_backends(), backend) {
    failures.push("backend '" + backend + "' is not recognized")
  }
  let platform = require_string(manifest, "platform", "manifest", failures)
  if platform != "" && !string_array_contains(allowed_platforms(), platform) {
    failures.push("platform '" + platform + "' is not recognized")
  }
  if backend == "webgpu-wasm" && platform != "web" {
    failures.push("webgpu-wasm renderer proof must use platform 'web'")
  }
  if backend != "" && backend != "webgpu-wasm" && platform == "web" {
    failures.push(backend + " renderer proof must use a native platform")
  }
  let status = require_string(manifest, "status", "manifest", failures)
  if status != "" && !string_array_contains(allowed_status(), status) {
    failures.push("status '" + status + "' is not recognized")
  }
  if require_passed && status != "passed" {
    failures.push("status must be passed when --require-passed is set")
  }
  (backend, platform, status)
}

///|
fn validate_provenance(
  manifest : Map[String, Json],
  status : String,
  failures : Array[String],
) -> Unit {
  let provenance = require_object(
    manifest, "provenance", "provenance", failures,
  )
  let provenance_kind = require_string(
    provenance, "kind", "provenance", failures,
  )
  if status == "passed" && provenance_kind != "github-actions" {
    failures.push("passed renderer proof requires github-actions provenance")
  }
  for key in ["workflow", "job", "runId", "runUrl", "runner", "artifactName"] {
    ignore(require_string(provenance, key, "provenance", failures))
  }
  let run_url = optional_string(provenance, "runUrl")
  if run_url != "" && !run_url.has_prefix("https://github.com/") {
    failures.push("provenance.runUrl must be a GitHub Actions URL")
  }
}

///|
fn validate_evidence_items(
  evidence : Array[Json],
  label : String,
  failures : Array[String],
) -> Unit {
  for index in 0..<evidence.length() {
    match evidence[index] {
      Json::String(item) if item.trim().to_owned() != "" =>
        if item.contains("caret-only") ||
          item.contains("coverage-only") ||
          item.contains("package-only") ||
          item.contains("preflight-only") ||
          item.contains("heuristic") {
          failures.push(
            label +
            ".evidence must not use caret-only, coverage-only, package-only, preflight-only, or heuristic proof",
          )
        }
      _ =>
        failures.push(label + ".evidence[\{index}] must be a non-empty string")
    }
  }
}

///|
fn validate_basic_color_emoji_metadata(
  observation : Map[String, Json],
  failures : Array[String],
) -> (Map[String, Json], Map[String, Json], String) {
  let metadata = require_object(
    observation, "metadata", "observations.colorEmojiPixels.metadata", failures,
  )
  let font = require_object(
    metadata, "font", "observations.colorEmojiPixels.metadata.font", failures,
  )
  ignore(
    require_string(
      font, "family", "observations.colorEmojiPixels.metadata.font", failures,
    ),
  )
  ignore(
    require_string(
      font, "source", "observations.colorEmojiPixels.metadata.font", failures,
    ),
  )
  ignore(
    require_string(
      font, "textSystem", "observations.colorEmojiPixels.metadata.font", failures,
    ),
  )
  let glyph = require_object(
    metadata, "glyph", "observations.colorEmojiPixels.metadata.glyph", failures,
  )
  let glyph_format = require_string(
    glyph, "format", "observations.colorEmojiPixels.metadata.glyph", failures,
  )
  if glyph_format != "" && glyph_format != "rgba" {
    failures.push(
      "observations.colorEmojiPixels.metadata.glyph.format must be rgba",
    )
  }
  if require_number(
      glyph, "glyphCount", "observations.colorEmojiPixels.metadata.glyph", failures,
    ) <
    1.0 {
    failures.push(
      "observations.colorEmojiPixels.metadata.glyph.glyphCount must be at least 1",
    )
  }
  if require_number(
      glyph, "clusterCount", "observations.colorEmojiPixels.metadata.glyph", failures,
    ) <
    1.0 {
    failures.push(
      "observations.colorEmojiPixels.metadata.glyph.clusterCount must be at least 1",
    )
  }
  ignore(
    require_string(
      glyph, "key", "observations.colorEmojiPixels.metadata.glyph", failures,
    ),
  )
  if require_number(
      glyph, "width", "observations.colorEmojiPixels.metadata.glyph", failures,
    ) <=
    0.0 {
    failures.push(
      "observations.colorEmojiPixels.metadata.glyph.width must be greater than 0",
    )
  }
  if require_number(
      glyph, "height", "observations.colorEmojiPixels.metadata.glyph", failures,
    ) <=
    0.0 {
    failures.push(
      "observations.colorEmojiPixels.metadata.glyph.height must be greater than 0",
    )
  }
  if require_number(
      glyph, "highSaturationPixels", "observations.colorEmojiPixels.metadata.glyph",
      failures,
    ) <
    8.0 {
    failures.push(
      "observations.colorEmojiPixels.metadata.glyph.highSaturationPixels must be at least 8",
    )
  }
  ignore(
    require_number(
      glyph, "alphaPixels", "observations.colorEmojiPixels.metadata.glyph", failures,
    ),
  )
  (font, glyph, glyph_format)
}

///|
fn validate_skia_color_emoji_metadata(
  font : Map[String, Json],
  glyph : Map[String, Json],
  glyph_format : String,
  failures : Array[String],
) -> Unit {
  let fallback_script_tag = require_string(
    font, "fallbackScriptTag", "observations.colorEmojiPixels.metadata.font", failures,
  )
  let fallback_language_tag_count = require_number(
    font, "fallbackLanguageTagCount", "observations.colorEmojiPixels.metadata.font",
    failures,
  )
  if fallback_language_tag_count < 1.0 {
    failures.push(
      "observations.colorEmojiPixels.metadata.font.fallbackLanguageTagCount must be at least 1",
    )
  }
  let fallback_language_tags = require_string_array(
    font, "fallbackLanguageTags", "observations.colorEmojiPixels.metadata.font",
    failures,
  )
  if fallback_language_tags.length() < 1 {
    failures.push(
      "observations.colorEmojiPixels.metadata.font.fallbackLanguageTags must include at least one tag",
    )
  }
  if fallback_language_tags.length() >= 1 &&
    fallback_language_tags[0] != fallback_script_tag {
    failures.push(
      "observations.colorEmojiPixels.metadata.font.fallbackLanguageTags[0] must match fallbackScriptTag",
    )
  }
  if fallback_language_tags.length().to_double() != fallback_language_tag_count {
    failures.push(
      "observations.colorEmojiPixels.metadata.font.fallbackLanguageTags length must match fallbackLanguageTagCount",
    )
  }
  let fallback_request_language_count = require_number(
    font, "fallbackRequestLanguageCount", "observations.colorEmojiPixels.metadata.font",
    failures,
  )
  if fallback_request_language_count != fallback_language_tag_count {
    failures.push(
      "observations.colorEmojiPixels.metadata.font.fallbackRequestLanguageCount must match fallbackLanguageTagCount",
    )
  }
  if require_number(
      glyph, "resolvedMissingGlyphCount", "observations.colorEmojiPixels.metadata.glyph",
      failures,
    ) <
    0.0 {
    failures.push(
      "observations.colorEmojiPixels.metadata.glyph.resolvedMissingGlyphCount must be non-negative",
    )
  }
  match glyph.get("missingGlyphRecoveryReady") {
    Some(Json::True) => ()
    _ =>
      failures.push(
        "observations.colorEmojiPixels.metadata.glyph.missingGlyphRecoveryReady must be true",
      )
  }
  let fallback_request_character = require_number(
    glyph, "fallbackRequestCharacter", "observations.colorEmojiPixels.metadata.glyph",
    failures,
  )
  if fallback_request_character <= 0.0 {
    failures.push(
      "observations.colorEmojiPixels.metadata.glyph.fallbackRequestCharacter must be greater than 0",
    )
  }
  let glyph_key = optional_string(glyph, "key")
  let expected_parts = [
    optional_string(font, "source"),
    optional_string(font, "textSystem"),
    require_string(
      font, "shaper", "observations.colorEmojiPixels.metadata.font", failures,
    ),
    "script=" + fallback_script_tag,
    "langs=\{fallback_request_language_count.to_int()}",
    "lang-tags=" + plus_join(fallback_language_tags),
    "emoji-u+\{fallback_request_character.to_int()}",
    glyph_format,
  ]
  for part in expected_parts {
    if part != "" && !glyph_key.contains(part) {
      failures.push(
        "observations.colorEmojiPixels.metadata.glyph.key must include '" +
        part +
        "'",
      )
    }
  }
}

///|
fn validate_color_emoji_metadata(
  observation : Map[String, Json],
  backend : String,
  failures : Array[String],
) -> Unit {
  let (font, glyph, glyph_format) = validate_basic_color_emoji_metadata(
    observation, failures,
  )
  if backend == "skia-native" {
    validate_skia_color_emoji_metadata(font, glyph, glyph_format, failures)
  }
}

///|
fn validate_observation(
  key : String,
  observation_json : Json?,
  backend : String,
  manifest_status : String,
  context : ArtifactContext?,
  failures : Array[String],
) -> Unit {
  let label = "observations." + key
  let observation = match observation_json {
    Some(value) => json_object_value(value, label, failures)
    None => {
      failures.push(label + " must be an object")
      {}
    }
  }
  let observation_status = require_string(
    observation, "status", label, failures,
  )
  if observation_status != "" &&
    !string_array_contains(allowed_status(), observation_status) {
    failures.push(
      label + ".status '" + observation_status + "' is not recognized",
    )
  }
  let evidence = require_array(observation, "evidence", label, failures)
  let observation_artifacts = require_array(
    observation, "artifacts", label, failures,
  )
  require_artifact_paths(observation_artifacts, label + ".artifacts", failures)
  if manifest_status == "passed" || observation_status == "passed" {
    require_artifact_files_exist(
      observation_artifacts,
      label + ".artifacts",
      context,
      failures,
    )
  }
  validate_evidence_items(evidence, label, failures)
  if manifest_status == "passed" || observation_status == "passed" {
    if observation_status != "passed" {
      failures.push(label + ".status must be passed for passed renderer proof")
    }
    for required in required_observation_evidence(backend, key) {
      if !json_string_array_contains(evidence, required) {
        failures.push(label + ".evidence must include '" + required + "'")
      }
    }
    if key == "colorEmojiPixels" {
      validate_color_emoji_metadata(observation, backend, failures)
    }
  }
}

///|
fn validate_observations(
  manifest : Map[String, Json],
  backend : String,
  manifest_status : String,
  context : ArtifactContext?,
  failures : Array[String],
) -> Unit {
  let observations = require_object(
    manifest, "observations", "observations", failures,
  )
  let actual_keys : Array[String] = observations.keys().collect()
  actual_keys.sort()
  let expected_keys = base_observation_keys()
  expected_keys.sort()
  if !arrays_equal(actual_keys, expected_keys) {
    failures.push(
      "observations must contain exactly: " + @tools.comma_join(expected_keys),
    )
  }
  for key in expected_keys {
    validate_observation(
      key,
      observations.get(key),
      backend,
      manifest_status,
      context,
      failures,
    )
  }
}

///|
fn validate_manifest_json(
  manifest : Json,
  require_passed : Bool,
  artifact_root : String,
) -> Array[String] {
  let failures : Array[String] = []
  let context = match artifact_context(artifact_root) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      None
    }
  }
  let fields = match json_object(Some(manifest)) {
    Some(value) => value
    None => {
      failures.push("manifest must be an object")
      return failures
    }
  }
  let (backend, _, status) = validate_schema_and_header(
    fields, require_passed, failures,
  )
  validate_provenance(fields, status, failures)
  let artifacts = require_array(fields, "artifacts", "manifest", failures)
  require_artifact_paths(artifacts, "manifest.artifacts", failures)
  if status == "passed" {
    require_artifact_files_exist(
      artifacts, "manifest.artifacts", context, failures,
    )
  }
  validate_observations(fields, backend, status, context, failures)
  failures
}

///|
fn validate_manifest_text(
  text : String,
  require_passed : Bool,
  artifact_root : String,
) -> Array[String] {
  let parsed = @json.parse(text) catch {
    _ => return ["failed to read JSON: invalid JSON"]
  }
  validate_manifest_json(parsed, require_passed, artifact_root)
}

///|
fn validate_renderer_proof_manifest(
  options : CliOptions,
) -> Result[String, Array[String]] {
  let text = match
    @tools.read_required_text(options.manifest_path, "renderer proof manifest") {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  let failures = validate_manifest_text(
    text,
    options.require_passed,
    options.artifact_root,
  )
  if failures.is_empty() {
    Ok(options.display_path + ": ok (renderer proof manifest)")
  } else {
    Err(failures)
  }
}

///|
fn print_prefixed_failures(path : String, failures : Array[String]) -> Unit {
  for failure in failures {
    println(path + ": " + failure)
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
      match validate_renderer_proof_manifest(options) {
        Ok(message) => {
          println(message)
          0
        }
        Err(failures) => {
          print_prefixed_failures(options.display_path, failures)
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
