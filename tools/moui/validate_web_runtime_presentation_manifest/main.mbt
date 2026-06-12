///|
struct CliOptions {
  manifest_path : String
  display_path : String
  require_passed : Bool
  help : Bool
}

///|
struct ExpectedTarget {
  name : String
  package_path : String
  path : String
}

///|
fn usage() -> String {
  "Usage: tools/moui/validate_web_runtime_presentation_manifest <presentation-smoke.json> [--require-passed]"
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let manifest_path = Ref("")
  let display_path = Ref("")
  let require_passed = Ref(false)
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--require-passed" => {
        require_passed.val = true
        index += 1
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
    return Err("missing presentation smoke manifest path")
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
    help: help.val,
  })
}

///|
fn expected_targets() -> Array[ExpectedTarget] {
  [
    {
      name: "showcase-web-wasm",
      package_path: "examples/showcase/web_wasm",
      path: "examples/showcase/web_wasm/index.html",
    },
  ]
}

///|
fn expected_target(name : String) -> ExpectedTarget? {
  for target in expected_targets() {
    if target.name == name {
      return Some(target)
    }
  }
  None
}

///|
fn expected_target_names() -> String {
  let names : Array[String] = []
  for target in expected_targets() {
    names.push(target.name)
  }
  @tools.comma_join(names)
}

///|
fn observation_keys() -> Array[String] {
  [
    "pageLoaded", "webGpuAvailable", "adapterRequested", "deviceRequested", "wasmStarted",
    "statusRunning", "canvasCreated", "canvasSized", "nonblankScreenshot", "cleanConsole",
    "resizeEvent", "resizedCanvas", "pointerInput", "keyboardInput", "textInput",
    "radialGradient", "transformPixels", "colorEmojiPixels", "zwjGrapheme", "bidiLayout",
    "paragraphWrapping", "selectionRects", "graphemeEditing", "imeCandidateAnchor",
    "imeCompositionVisual", "asyncImageSecondFrame", "targetClosed",
  ]
}

///|
fn platform_observation_keys() -> Array[String] {
  [
    "windowOpened", "resizeRedraw", "representativeInput", "cleanExit", "surface",
    "redraw", "resizeScale", "consumerInput", "textInput", "rendererHandle", "cleanShutdown",
  ]
}

///|
fn renderer_smoke_keys() -> Array[String] {
  [
    "radialGradient", "colorEmojiPixels", "zwjGrapheme", "bidiLayout", "paragraphWrapping",
    "selectionRects", "graphemeEditing", "imeCandidateAnchor", "imeCompositionVisual",
    "asyncImageSecondFrame",
  ]
}

///|
fn renderer_smoke_marker_requirements(key : String) -> Array[String] {
  match key {
    "radialGradient" => ["center-mid-edge-pixels", "shader-payload"]
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

///|
fn renderer_smoke_observation_key(key : String) -> Bool {
  renderer_smoke_keys().any(value => value == key)
}

///|
fn json_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn json_object_value(value : Json) -> Map[String, Json]? {
  match value {
    Json::Object(fields) => Some(fields)
    _ => None
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
      failures.push("missing non-empty string field '" + label + "'")
      ""
    }
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
      failures.push("missing finite number field '" + label + "'")
      0.0
    }
  }
}

///|
fn require_boolean(
  object : Map[String, Json],
  field : String,
  label : String,
  failures : Array[String],
) -> Bool {
  match object.get(field) {
    Some(Json::True) => true
    Some(Json::False) => false
    _ => {
      failures.push("missing boolean field '" + label + "'")
      false
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
      failures.push("field '" + label + "' must be an array")
      []
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
      failures.push("field '" + label + "' must be an object")
      {}
    }
  }
}

///|
fn assert_string_array(
  values : Array[Json],
  label : String,
  failures : Array[String],
) -> Unit {
  for index in 0..<values.length() {
    match values[index] {
      Json::String(value) if value.trim().to_owned() != "" => ()
      _ => failures.push(label + "[\{index}] must be a non-empty string")
    }
  }
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
fn json_yes_no_value(object : Map[String, Json], field : String) -> String {
  match object.get(field) {
    Some(Json::String("yes")) => "yes"
    Some(Json::String("no")) => "no"
    _ => ""
  }
}

///|
fn local_http_url(url : String) -> Bool {
  let prefix = if url.has_prefix("http://127.0.0.1:") {
    "http://127.0.0.1:"
  } else if url.has_prefix("http://localhost:") {
    "http://localhost:"
  } else {
    return false
  }
  let rest = url[prefix.length():].to_owned()
  if rest == "" {
    return false
  }
  let mut index = 0
  while index < rest.length() && rest[index] != '/' {
    if rest[index] < '0' || rest[index] > '9' {
      return false
    }
    index += 1
  }
  index > 0
}

///|
fn validate_target_expected_field(
  target : Map[String, Json],
  field : String,
  expected_value : String,
  name : String,
  label : String,
  failures : Array[String],
) -> Unit {
  let value = require_string(target, field, label + "." + field, failures)
  if value != expected_value {
    failures.push(
      label +
      "." +
      field +
      " must be '" +
      expected_value +
      "' for '" +
      name +
      "'",
    )
  }
}

///|
fn validate_renderer_smoke(
  screenshot : Map[String, Json],
  smoke_key : String,
  label : String,
  target_name : String,
  smoke_passed : Map[String, Bool],
  failures : Array[String],
) -> Unit {
  let smoke = require_object(
    screenshot,
    smoke_key,
    label + ".screenshot." + smoke_key,
    failures,
  )
  let required = require_boolean(
    smoke,
    "required",
    label + ".screenshot." + smoke_key + ".required",
    failures,
  )
  let passed = require_boolean(
    smoke,
    "passed",
    label + ".screenshot." + smoke_key + ".passed",
    failures,
  )
  smoke_passed[smoke_key] = passed
  let smoke_markers = require_array(
    smoke,
    "markers",
    label + ".screenshot." + smoke_key + ".markers",
    failures,
  )
  assert_string_array(
    smoke_markers,
    label + ".screenshot." + smoke_key + ".markers",
    failures,
  )
  let matched_markers = require_number(
    smoke,
    "matchedMarkers",
    label + ".screenshot." + smoke_key + ".matchedMarkers",
    failures,
  )
  if target_name == "showcase-web-wasm" && required != true {
    failures.push(
      label + ".screenshot." + smoke_key + ".required must be true for Showcase",
    )
  }
  if target_name != "showcase-web-wasm" && required != false {
    failures.push(
      label +
      ".screenshot." +
      smoke_key +
      ".required must be false for non-Showcase targets",
    )
  }
  if passed && smoke_markers.is_empty() {
    failures.push(
      label + ".screenshot." + smoke_key + ".passed requires marker tokens",
    )
  }
  if passed {
    for required_token in renderer_smoke_marker_requirements(smoke_key) {
      if !json_string_array_contains(smoke_markers, required_token) {
        failures.push(
          label +
          ".screenshot." +
          smoke_key +
          ".markers must include '" +
          required_token +
          "'",
        )
      }
    }
  }
  if matched_markers < 0.0 {
    failures.push(
      label + ".screenshot." + smoke_key + ".matchedMarkers must be nonnegative",
    )
  }
}

///|
fn json_string_arrays_same_order(
  left : Array[Json],
  right : Array[Json],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    match (left[index], right[index]) {
      (Json::String(left_text), Json::String(right_text)) =>
        if left_text != right_text {
          return false
        }
      _ => return false
    }
  }
  true
}

///|
fn validate_showcase_color_emoji_smoke(
  screenshot : Map[String, Json],
  label : String,
  failures : Array[String],
) -> Unit {
  let color_emoji = require_object(
    screenshot,
    "colorEmojiPixels",
    label + ".screenshot.colorEmojiPixels",
    failures,
  )
  let glyph_high_saturation_pixels = require_number(
    color_emoji,
    "glyphHighSaturationPixels",
    label + ".screenshot.colorEmojiPixels.glyphHighSaturationPixels",
    failures,
  )
  if glyph_high_saturation_pixels < 8.0 {
    failures.push(
      label + " passed color emoji smoke requires high-saturation glyph pixels",
    )
  }
  let color_emoji_metadata = require_object(
    color_emoji,
    "metadata",
    label + ".screenshot.colorEmojiPixels.metadata",
    failures,
  )
  let color_emoji_font = require_object(
    color_emoji_metadata,
    "font",
    label + ".screenshot.colorEmojiPixels.metadata.font",
    failures,
  )
  ignore(
    require_string(
      color_emoji_font,
      "family",
      label + ".screenshot.colorEmojiPixels.metadata.font",
      failures,
    ),
  )
  ignore(
    require_string(
      color_emoji_font,
      "source",
      label + ".screenshot.colorEmojiPixels.metadata.font",
      failures,
    ),
  )
  ignore(
    require_string(
      color_emoji_font,
      "textSystem",
      label + ".screenshot.colorEmojiPixels.metadata.font",
      failures,
    ),
  )
  let color_emoji_glyph = require_object(
    color_emoji_metadata,
    "glyph",
    label + ".screenshot.colorEmojiPixels.metadata.glyph",
    failures,
  )
  let glyph_format = require_string(
    color_emoji_glyph,
    "format",
    label + ".screenshot.colorEmojiPixels.metadata.glyph",
    failures,
  )
  if glyph_format != "rgba" {
    failures.push(
      label + " passed color emoji smoke requires RGBA glyph metadata",
    )
  }
  let metadata_glyph_pixels = require_number(
    color_emoji_glyph,
    "highSaturationPixels",
    label + ".screenshot.colorEmojiPixels.metadata.glyph",
    failures,
  )
  if metadata_glyph_pixels < 8.0 {
    failures.push(
      label +
      " passed color emoji metadata requires high-saturation glyph pixels",
    )
  }
  let metadata_glyph_count = require_number(
    color_emoji_glyph,
    "glyphCount",
    label + ".screenshot.colorEmojiPixels.metadata.glyph",
    failures,
  )
  if metadata_glyph_count < 1.0 {
    failures.push(
      label + " passed color emoji metadata requires at least one glyph",
    )
  }
  let metadata_cluster_count = require_number(
    color_emoji_glyph,
    "clusterCount",
    label + ".screenshot.colorEmojiPixels.metadata.glyph",
    failures,
  )
  if metadata_cluster_count < 1.0 {
    failures.push(
      label + " passed color emoji metadata requires at least one cluster",
    )
  }
  let metadata_alpha_pixels = require_number(
    color_emoji_glyph,
    "alphaPixels",
    label + ".screenshot.colorEmojiPixels.metadata.glyph",
    failures,
  )
  if metadata_alpha_pixels < 1.0 {
    failures.push(
      label + " passed color emoji metadata requires alpha glyph pixels",
    )
  }
  ignore(
    require_string(
      color_emoji_glyph,
      "key",
      label + ".screenshot.colorEmojiPixels.metadata.glyph",
      failures,
    ),
  )
  let metadata_glyph_width = require_number(
    color_emoji_glyph,
    "width",
    label + ".screenshot.colorEmojiPixels.metadata.glyph",
    failures,
  )
  if metadata_glyph_width <= 0.0 {
    failures.push(
      label + " passed color emoji metadata requires positive glyph width",
    )
  }
  let metadata_glyph_height = require_number(
    color_emoji_glyph,
    "height",
    label + ".screenshot.colorEmojiPixels.metadata.glyph",
    failures,
  )
  if metadata_glyph_height <= 0.0 {
    failures.push(
      label + " passed color emoji metadata requires positive glyph height",
    )
  }
}

///|
fn validate_showcase_text_and_image_smokes(
  screenshot : Map[String, Json],
  label : String,
  failures : Array[String],
) -> Unit {
  let zwj_grapheme = require_object(
    screenshot,
    "zwjGrapheme",
    label + ".screenshot.zwjGrapheme",
    failures,
  )
  let logical_clusters = require_number(
    zwj_grapheme,
    "logicalClusters",
    label + ".screenshot.zwjGrapheme.logicalClusters",
    failures,
  )
  let visual_clusters = require_number(
    zwj_grapheme,
    "visualClusters",
    label + ".screenshot.zwjGrapheme.visualClusters",
    failures,
  )
  if logical_clusters != 1.0 || visual_clusters != 1.0 {
    failures.push(
      label +
      " passed ZWJ smoke requires one logical and visual grapheme cluster",
    )
  }
  let bidi_layout = require_object(
    screenshot,
    "bidiLayout",
    label + ".screenshot.bidiLayout",
    failures,
  )
  let logical_bidi = require_array(
    bidi_layout,
    "logicalClusters",
    label + ".screenshot.bidiLayout.logicalClusters",
    failures,
  )
  let visual_bidi = require_array(
    bidi_layout,
    "visualClusters",
    label + ".screenshot.bidiLayout.visualClusters",
    failures,
  )
  if logical_bidi.is_empty() ||
    visual_bidi.is_empty() ||
    json_string_arrays_same_order(logical_bidi, visual_bidi) {
    failures.push(
      label +
      " passed bidi smoke requires differing logical and visual cluster order",
    )
  }
  let paragraph = require_object(
    screenshot,
    "paragraphWrapping",
    label + ".screenshot.paragraphWrapping",
    failures,
  )
  let paragraph_line_count = require_number(
    paragraph,
    "paragraphLineCount",
    label + ".screenshot.paragraphWrapping.paragraphLineCount",
    failures,
  )
  let paragraph_rows = require_number(
    paragraph,
    "paragraphRows",
    label + ".screenshot.paragraphWrapping.paragraphRows",
    failures,
  )
  if paragraph_line_count < 3.0 || paragraph_rows < 3.0 {
    failures.push(
      label + " passed paragraph smoke requires multiple line metrics",
    )
  }
  let async_image = require_object(
    screenshot,
    "asyncImageSecondFrame",
    label + ".screenshot.asyncImageSecondFrame",
    failures,
  )
  let event_order = require_object(
    async_image,
    "eventIndexes",
    label + ".screenshot.asyncImageSecondFrame.eventIndexes",
    failures,
  )
  let placeholder_index = require_number(
    event_order,
    "placeholder",
    label + ".screenshot.asyncImageSecondFrame.eventIndexes.placeholder",
    failures,
  )
  let load_index = require_number(
    event_order,
    "load",
    label + ".screenshot.asyncImageSecondFrame.eventIndexes.load",
    failures,
  )
  let repaint_index = require_number(
    event_order,
    "repaint",
    label + ".screenshot.asyncImageSecondFrame.eventIndexes.repaint",
    failures,
  )
  let change_index = require_number(
    event_order,
    "change",
    label + ".screenshot.asyncImageSecondFrame.eventIndexes.change",
    failures,
  )
  let ready_index = require_number(
    event_order,
    "ready",
    label + ".screenshot.asyncImageSecondFrame.eventIndexes.ready",
    failures,
  )
  let present_indexes = require_array(
    event_order,
    "present",
    label + ".screenshot.asyncImageSecondFrame.eventIndexes.present",
    failures,
  )
  let latest_load_signal = if change_index > repaint_index {
    change_index
  } else {
    repaint_index
  }
  if !(placeholder_index >= 0.0 &&
    load_index > placeholder_index &&
    change_index > load_index &&
    repaint_index > load_index &&
    ready_index > latest_load_signal) ||
    present_indexes.length() < 2 {
    failures.push(
      label +
      " passed async image smoke requires placeholder, late load, repaint, ready second-frame order",
    )
  }
}

///|
fn observation_required_for_passed_target(key : String, name : String) -> Bool {
  if key == "transformPixels" && name != "showcase-web-wasm" {
    return false
  }
  if renderer_smoke_observation_key(key) && name != "showcase-web-wasm" {
    return false
  }
  true
}

///|
fn validate_target(
  target_json : Json,
  index : Int,
  seen : Map[String, Bool],
  passed_count : Ref[Int],
) -> Array[String] {
  let failures : Array[String] = []
  let target = match json_object_value(target_json) {
    Some(fields) => fields
    None => {
      failures.push("targets[\{index}] must be an object")
      return failures
    }
  }
  let label = "targets[\{index}]"
  let name = require_string(target, "name", label + ".name", failures)
  if seen.contains(name) {
    failures.push("duplicate target '" + name + "'")
  }
  seen[name] = true
  let expected = match expected_target(name) {
    Some(value) => value
    None => {
      failures.push(label + ".name must be one of " + expected_target_names())
      return failures
    }
  }
  validate_target_expected_field(
    target,
    "packagePath",
    expected.package_path,
    name,
    label,
    failures,
  )
  validate_target_expected_field(
    target,
    "path",
    expected.path,
    name,
    label,
    failures,
  )
  let url = require_string(target, "url", label + ".url", failures)
  if !local_http_url(url) {
    failures.push(label + ".url must be a local HTTP URL")
  }
  let status = require_string(target, "status", label + ".status", failures)
  if status != "passed" && status != "failed" {
    failures.push(label + ".status must be passed or failed")
  }
  if status == "passed" {
    passed_count.val += 1
  }
  let title = require_string(target, "title", label + ".title", failures)
  ignore(title)
  let status_text = require_string(
    target,
    "statusText",
    label + ".statusText",
    failures,
  )
  let body_failed = require_boolean(
    target,
    "bodyFailed",
    label + ".bodyFailed",
    failures,
  )
  let navigator_gpu = require_boolean(
    target,
    "navigatorGpu",
    label + ".navigatorGpu",
    failures,
  )
  let canvas = require_object(target, "canvas", label + ".canvas", failures)
  let canvas_count = require_number(
    canvas,
    "count",
    label + ".canvas.count",
    failures,
  )
  let host_width = require_number(
    canvas,
    "hostWidth",
    label + ".canvas.hostWidth",
    failures,
  )
  let host_height = require_number(
    canvas,
    "hostHeight",
    label + ".canvas.hostHeight",
    failures,
  )
  let canvas_width = require_number(
    canvas,
    "canvasWidth",
    label + ".canvas.canvasWidth",
    failures,
  )
  let canvas_height = require_number(
    canvas,
    "canvasHeight",
    label + ".canvas.canvasHeight",
    failures,
  )
  let runtime_signals = require_object(
    target,
    "runtimeSignals",
    label + ".runtimeSignals",
    failures,
  )
  for key in ["adapterRequested", "deviceRequested", "wasmStarted", "running"] {
    ignore(
      require_boolean(
        runtime_signals,
        key,
        label + ".runtimeSignals." + key,
        failures,
      ),
    )
  }
  let observation_events = require_array(
    target,
    "observationEvents",
    label + ".observationEvents",
    failures,
  )
  for event_index in 0..<observation_events.length() {
    let event = match json_object_value(observation_events[event_index]) {
      Some(fields) => fields
      None => {
        failures.push(
          label + ".observationEvents[\{event_index}] must be an object",
        )
        continue
      }
    }
    ignore(
      require_number(
        event,
        "kind",
        label + ".observationEvents[\{event_index}].kind",
        failures,
      ),
    )
    ignore(
      require_string(
        event,
        "name",
        label + ".observationEvents[\{event_index}].name",
        failures,
      ),
    )
  }
  let screenshot = require_object(
    target,
    "screenshot",
    label + ".screenshot",
    failures,
  )
  let artifact = require_string(
    screenshot,
    "artifact",
    label + ".screenshot.artifact",
    failures,
  )
  if !artifact.has_suffix(".png") {
    failures.push(label + ".screenshot.artifact must end with .png")
  }
  let screenshot_width = require_number(
    screenshot,
    "width",
    label + ".screenshot.width",
    failures,
  )
  let screenshot_height = require_number(
    screenshot,
    "height",
    label + ".screenshot.height",
    failures,
  )
  let total_pixels = require_number(
    screenshot,
    "totalPixels",
    label + ".screenshot.totalPixels",
    failures,
  )
  let content_pixels = require_number(
    screenshot,
    "contentPixels",
    label + ".screenshot.contentPixels",
    failures,
  )
  let distinct_color_buckets = require_number(
    screenshot,
    "distinctColorBuckets",
    label + ".screenshot.distinctColorBuckets",
    failures,
  )
  let transform_pixels = require_object(
    screenshot,
    "transformPixels",
    label + ".screenshot.transformPixels",
    failures,
  )
  let transform_pixels_required = require_boolean(
    transform_pixels,
    "required",
    label + ".screenshot.transformPixels.required",
    failures,
  )
  let transform_pixels_passed = require_boolean(
    transform_pixels,
    "passed",
    label + ".screenshot.transformPixels.passed",
    failures,
  )
  let hot_pink_pixels = require_number(
    transform_pixels,
    "hotPinkPixels",
    label + ".screenshot.transformPixels.hotPinkPixels",
    failures,
  )
  let cyan_pixels = require_number(
    transform_pixels,
    "cyanPixels",
    label + ".screenshot.transformPixels.cyanPixels",
    failures,
  )
  let gold_pixels = require_number(
    transform_pixels,
    "goldPixels",
    label + ".screenshot.transformPixels.goldPixels",
    failures,
  )
  let matched_markers = require_number(
    transform_pixels,
    "matchedMarkers",
    label + ".screenshot.transformPixels.matchedMarkers",
    failures,
  )
  if name == "showcase-web-wasm" && transform_pixels_required != true {
    failures.push(
      label + ".screenshot.transformPixels.required must be true for Showcase",
    )
  }
  if name != "showcase-web-wasm" && transform_pixels_required != false {
    failures.push(
      label +
      ".screenshot.transformPixels.required must be false for non-Showcase targets",
    )
  }
  if transform_pixels_passed && matched_markers < 3.0 {
    failures.push(
      label +
      ".screenshot.transformPixels.passed requires three matched markers",
    )
  }
  if hot_pink_pixels < 0.0 ||
    cyan_pixels < 0.0 ||
    gold_pixels < 0.0 ||
    matched_markers < 0.0 {
    failures.push(
      label + ".screenshot.transformPixels counts must be nonnegative",
    )
  }
  let smoke_passed : Map[String, Bool] = {}
  for smoke_key in renderer_smoke_keys() {
    validate_renderer_smoke(
      screenshot, smoke_key, label, name, smoke_passed, failures,
    )
  }
  let observations = require_object(
    target,
    "observations",
    label + ".observations",
    failures,
  )
  for key in observation_keys() {
    let value = json_yes_no_value(observations, key)
    if value != "yes" && value != "no" {
      failures.push(label + ".observations." + key + " must be yes or no")
    }
  }
  let console_errors = require_array(
    target,
    "consoleErrors",
    label + ".consoleErrors",
    failures,
  )
  assert_string_array(console_errors, label + ".consoleErrors", failures)
  let notes = require_array(target, "notes", label + ".notes", failures)
  assert_string_array(notes, label + ".notes", failures)
  if status == "passed" {
    if status_text != "Running" {
      failures.push(label + ".statusText must be Running for passed observation")
    }
    if body_failed != false || navigator_gpu != true {
      failures.push(
        label +
        " passed observation requires bodyFailed=false and navigatorGpu=true",
      )
    }
    if canvas_count < 1.0 ||
      host_width <= 0.0 ||
      host_height <= 0.0 ||
      canvas_width <= 0.0 ||
      canvas_height <= 0.0 {
      failures.push(label + " passed observation requires a sized canvas")
    }
    if screenshot_width <= 0.0 ||
      screenshot_height <= 0.0 ||
      total_pixels <= 0.0 {
      failures.push(label + " passed observation requires a non-empty screenshot")
    }
    if content_pixels < 500.0 || distinct_color_buckets < 6.0 {
      failures.push(label + " passed observation requires a nonblank screenshot")
    }
    if !console_errors.is_empty() {
      failures.push(label + " passed observation must not contain console errors")
    }
    for key in observation_keys() {
      if observation_required_for_passed_target(key, name) &&
        json_yes_no_value(observations, key) != "yes" {
        failures.push(
          label + ".observations." + key + " must be yes for passed observation",
        )
      }
    }
    if name == "showcase-web-wasm" && transform_pixels_passed != true {
      failures.push(
        label + " passed observation requires Showcase transform pixel markers",
      )
    }
    if name == "showcase-web-wasm" {
      for smoke_key in renderer_smoke_keys() {
        match smoke_passed.get(smoke_key) {
          Some(true) => ()
          _ =>
            failures.push(
              label +
              " passed observation requires Showcase " +
              smoke_key +
              " smoke markers",
            )
        }
      }
      validate_showcase_color_emoji_smoke(screenshot, label, failures)
      validate_showcase_text_and_image_smokes(screenshot, label, failures)
    }
  } else {
    let any_no = observation_keys().any(key => {
      json_yes_no_value(observations, key) == "no"
    })
    if !any_no {
      failures.push(
        label + " failed observation must include at least one no observation",
      )
    }
  }
  failures
}

///|
fn validate_header(
  manifest : Map[String, Json],
  require_passed : Bool,
  failures : Array[String],
) -> String {
  match manifest.get("schemaVersion") {
    Some(Json::Number(number, repr=_)) if number == 1.0 => ()
    _ => failures.push("schemaVersion must be 1")
  }
  let mode = require_string(manifest, "mode", "mode", failures)
  if mode != "web-runtime-presentation" {
    failures.push("mode must be 'web-runtime-presentation'")
  }
  let generated_by = require_string(
    manifest, "generatedBy", "generatedBy", failures,
  )
  if generated_by != "scripts/record-web-runtime-presentation.mjs" {
    failures.push(
      "generatedBy must be scripts/record-web-runtime-presentation.mjs",
    )
  }
  let overall_status = require_string(
    manifest, "overallStatus", "overallStatus", failures,
  )
  if overall_status != "passed" && overall_status != "failed" {
    failures.push("overallStatus must be passed or failed")
  }
  if require_passed && overall_status != "passed" {
    failures.push("overallStatus must be passed when --require-passed is used")
  }
  let base_url = require_string(manifest, "baseUrl", "baseUrl", failures)
  if !local_http_url(base_url) {
    failures.push("baseUrl must be a local HTTP URL")
  }
  let cdp_url = require_string(manifest, "cdpUrl", "cdpUrl", failures)
  if !local_http_url(cdp_url) {
    failures.push("cdpUrl must be a local HTTP URL")
  }
  let observation_boundary = require_string(
    manifest, "observationBoundary", "observationBoundary", failures,
  )
  for
    token in [
      "WebGPU", "wasm app startup", "resize/input", "target close", "screenshot",
      "not claim cross-browser",
    ] {
    if !observation_boundary.contains(token) {
      failures.push("observationBoundary must include '" + token + "'")
    }
  }
  let browser = require_object(manifest, "browser", "browser", failures)
  ignore(require_string(browser, "product", "browser.product", failures))
  ignore(require_string(browser, "userAgent", "browser.userAgent", failures))
  ignore(
    require_string(
      browser, "protocolVersion", "browser.protocolVersion", failures,
    ),
  )
  overall_status
}

///|
fn validate_platform_observations(
  manifest : Map[String, Json],
  overall_status : String,
  passed_count : Int,
  failures : Array[String],
) -> Unit {
  let platform_observations = require_object(
    manifest, "platformObservations", "platformObservations", failures,
  )
  for key in platform_observation_keys() {
    let value = json_yes_no_value(platform_observations, key)
    if value != "yes" && value != "no" {
      failures.push("platformObservations." + key + " must be yes or no")
    }
  }
  let allowed_keys = platform_observation_keys()
  let keys : Array[String] = platform_observations.keys().collect()
  for key in keys {
    if !string_array_contains(allowed_keys, key) {
      failures.push("platformObservations contains unknown key '" + key + "'")
    }
  }
  if overall_status == "passed" {
    if passed_count != expected_targets().length() {
      failures.push("overallStatus passed requires all target entries to pass")
    }
    for key in platform_observation_keys() {
      if json_yes_no_value(platform_observations, key) != "yes" {
        failures.push(
          "platformObservations." +
          key +
          " must be yes when overallStatus is passed",
        )
      }
    }
  }
  if overall_status == "failed" && passed_count == expected_targets().length() {
    let has_platform_failure = platform_observation_keys().any(key => {
      json_yes_no_value(platform_observations, key) == "no"
    })
    if !has_platform_failure {
      failures.push(
        "overallStatus failed requires at least one failed target entry or platform observation",
      )
    }
  }
}

///|
fn validate_manifest_fields(
  manifest : Map[String, Json],
  require_passed : Bool,
) -> Array[String] {
  let failures : Array[String] = []
  let overall_status = validate_header(manifest, require_passed, failures)
  let targets = require_array(manifest, "targets", "targets", failures)
  let seen_targets : Map[String, Bool] = {}
  let passed_count = Ref(0)
  for index in 0..<targets.length() {
    for
      failure in validate_target(
        targets[index],
        index,
        seen_targets,
        passed_count,
      ) {
      failures.push(failure)
    }
  }
  for target in expected_targets() {
    if !seen_targets.contains(target.name) {
      failures.push("targets must include '" + target.name + "'")
    }
  }
  if targets.length() != expected_targets().length() {
    failures.push(
      "targets must contain exactly \{expected_targets().length()} entries",
    )
  }
  validate_platform_observations(
    manifest,
    overall_status,
    passed_count.val,
    failures,
  )
  failures
}

///|
fn validate_manifest_text_with_options(
  text : String,
  require_passed : Bool,
) -> Array[String] {
  let parsed = @json.parse(text) catch {
    _ => return ["failed to read JSON: invalid JSON"]
  }
  let manifest = match json_object(Some(parsed)) {
    Some(fields) => fields
    None => return ["manifest root must be an object"]
  }
  validate_manifest_fields(manifest, require_passed)
}

///|
fn validate_manifest_text(text : String) -> Array[String] {
  validate_manifest_text_with_options(text, false)
}

///|
fn validate_web_runtime_presentation_manifest(
  options : CliOptions,
) -> Result[String, Array[String]] {
  let text = match
    @tools.read_required_text(
      options.manifest_path,
      "web runtime presentation manifest",
    ) {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  let failures = if options.require_passed {
    validate_manifest_text_with_options(text, true)
  } else {
    validate_manifest_text(text)
  }
  if failures.is_empty() {
    Ok(options.display_path + ": ok (web runtime presentation manifest)")
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
      match validate_web_runtime_presentation_manifest(options) {
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
