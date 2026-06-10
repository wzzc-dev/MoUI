///|
struct CliOptions {
  manifest_path : String
  display_path : String
  expected_platform : String
  help : Bool
}

///|
struct PlatformSpec {
  example_targets : Array[String]
  routine_tokens : Array[String]
  runtime_tokens : Array[String]
}

///|
struct NativeSkiaSpec {
  provider_tokens : Array[String]
  runtime_tokens : Array[String]
}

///|
fn usage() -> String {
  "Usage: tools/moui/validate_platform_evidence_manifest <manifest.json> [--platform web|macos|windows|linux]"
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let manifest_path = Ref("")
  let display_path = Ref("")
  let expected_platform = Ref("")
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--platform" => {
        if index + 1 >= args.length() {
          return Err("missing value for --platform")
        }
        expected_platform.val = args[index + 1]
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
    return Err("missing manifest.json path")
  }
  let display = if display_path.val == "" {
    manifest_path.val
  } else {
    display_path.val
  }
  Ok({
    manifest_path: manifest_path.val,
    display_path: display,
    expected_platform: expected_platform.val,
    help: help.val,
  })
}

///|
fn platform_names() -> Array[String] {
  ["web", "macos", "windows", "linux"]
}

///|
fn platform_spec(name : String) -> PlatformSpec? {
  match name {
    "web" =>
      Some({
        example_targets: [
          "examples/showcase/web_wasm", "examples/markdown_editor/web_wasm",
        ],
        routine_tokens: [
          "moon test moui/backend/web --target wasm-gc", "moon build examples/showcase/web_wasm --target wasm-gc",
          "moon build examples/markdown_editor/web_wasm --target wasm-gc",
        ],
        runtime_tokens: [
          "record-web-runtime-presentation.mjs", "examples/showcase/web_wasm", "examples/markdown_editor/web_wasm",
          "--web-presentation-manifest",
        ],
      })
    "macos" =>
      Some({
        example_targets: [
          "examples/showcase/macos_skia", "examples/markdown_editor/macos_skia",
        ],
        routine_tokens: [
          "sh scripts/dev-check.sh --platform-examples-test", "moon build examples/showcase/macos_skia --target native",
          "moon build examples/markdown_editor/macos_skia --target native",
        ],
        runtime_tokens: [
          "moon run examples/showcase/macos_skia --target native", "moon run examples/markdown_editor/macos_skia --target native",
        ],
      })
    "windows" =>
      Some({
        example_targets: [
          "examples/showcase/windows_skia", "examples/markdown_editor/windows_skia",
        ],
        routine_tokens: [
          "moon test moui/backend/windows --target native", "build_windows_msvc.ps1",
          "package_windows_app_msvc.ps1", "examples/showcase/windows_skia", "examples/markdown_editor/windows_skia",
        ],
        runtime_tokens: [
          "moon run examples/showcase/windows_skia --target native", "moon run examples/markdown_editor/windows_skia --target native",
        ],
      })
    "linux" =>
      Some({
        example_targets: [
          "examples/showcase/linux_skia", "examples/markdown_editor/linux_skia",
        ],
        routine_tokens: [
          "sh scripts/dev-check.sh --platform-examples-test", "moon build examples/showcase/linux_skia --target native",
          "moon build examples/markdown_editor/linux_skia --target native",
        ],
        runtime_tokens: [
          "moon run examples/showcase/linux_skia --target native", "moon run examples/markdown_editor/linux_skia --target native",
        ],
      })
    _ => None
  }
}

///|
fn native_skia_spec(name : String) -> NativeSkiaSpec? {
  match name {
    "macos" =>
      Some({
        provider_tokens: [
          "moon test moui/render/skia --target native", "moon test moui/backend/macos/skia --target native",
        ],
        runtime_tokens: [
          "scripts/macos-skia-renderer-smoke.sh", "--run-showcase-smoke", "--run-markdown-smoke",
        ],
      })
    "windows" =>
      Some({
        provider_tokens: [
          "moon test moui/render/skia --target native", "moon test moui/backend/windows/skia --target native",
          "build_windows_msvc.ps1", "examples/showcase/windows_skia", "examples/markdown_editor/windows_skia",
        ],
        runtime_tokens: [
          "MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT", "MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT",
          "examples/showcase/windows_skia", "examples/markdown_editor/windows_skia",
        ],
      })
    "linux" =>
      Some({
        provider_tokens: [
          "moon test moui/render/skia --target native", "moon test moui/backend/linux/skia --target native",
          "examples/showcase/linux_skia", "examples/markdown_editor/linux_skia",
        ],
        runtime_tokens: [
          "MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT", "MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT",
          "examples/showcase/linux_skia", "examples/markdown_editor/linux_skia",
        ],
      })
    _ => None
  }
}

///|
fn native_ime_observation_keys() -> Array[String] {
  [
    "imeCandidateAnchor", "imeSurroundingText", "imeCompositionVisual", "imeCommitDelete",
    "imeCursorUpdate", "imeScrollAnchor", "imeScaleDprAnchor", "imeResizeAnchor",
    "imeMarkdownEditor",
  ]
}

///|
fn observation_keys() -> Array[String] {
  [
    "windowOpened", "resizeRedraw", "representativeInput", "cleanExit", "surface",
    "redraw", "resizeScale", "consumerInput", "textInput", "rendererHandle", "monitorCursor",
    "cleanShutdown", "imeCandidateAnchor", "imeSurroundingText", "imeCompositionVisual",
    "imeCommitDelete", "imeCursorUpdate", "imeScrollAnchor", "imeScaleDprAnchor",
    "imeResizeAnchor", "imeMarkdownEditor",
  ]
}

///|
fn consumer_observation_keys() -> Array[String] {
  [
    "surface", "redraw", "resizeScale", "consumerInput", "textInput", "rendererHandle",
    "monitorCursor", "cleanShutdown", "imeCandidateAnchor", "imeSurroundingText",
    "imeCompositionVisual", "imeCommitDelete", "imeCursorUpdate", "imeScrollAnchor",
    "imeScaleDprAnchor", "imeResizeAnchor", "imeMarkdownEditor",
  ]
}

///|
fn skia_observation_keys() -> Array[String] {
  [
    "providerPreflight", "fallbackUnavailable", "realRendererSmoke", "asyncImageSecondFrame",
    "showcaseFirstFrame", "markdownFirstFrame",
  ]
}

///|
fn allowed_status(value : String) -> Bool {
  value == "passed" || value == "failed" || value == "pending"
}

///|
fn valid_observation_value(value : String) -> Bool {
  value == "yes" || value == "no" || value == "pending"
}

///|
fn platform_host_matches(name : String, host : String) -> Bool {
  match name {
    "web" => {
      let lowered = host.to_lower()
      lowered.contains("web") ||
      lowered.contains("browser") ||
      lowered.contains("wasm-gc")
    }
    "macos" => host.contains("macOS") || host.contains("Darwin")
    "windows" => host.contains("Windows") || host.contains("MSVC")
    "linux" => host.contains("Linux") || host.contains("Wayland")
    _ => false
  }
}

///|
fn json_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn json_object_value(value : Json) -> Map[String, Json]? {
  match value {
    Object(fields) => Some(fields)
    _ => None
  }
}

///|
fn json_number_is(value : Json?, expected : Double) -> Bool {
  match value {
    Some(Number(number, repr=_)) => number == expected
    _ => false
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
    Some(String(value)) if value.trim().to_owned() != "" => value
    _ => {
      failures.push("missing non-empty string field '" + label + "'")
      ""
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
    Some(Array(values)) => values
    _ => {
      failures.push("field '" + label + "' must be an array")
      []
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
      String(value) if value.trim().to_owned() != "" => ()
      _ => failures.push(label + "[\{index}] must be a non-empty string")
    }
  }
}

///|
fn json_string_array_contains(values : Array[Json], expected : String) -> Bool {
  values.any(value => {
    match value {
      String(text) => text == expected
      _ => false
    }
  })
}

///|
fn assert_includes_all(
  values : Array[Json],
  expected : Array[String],
  label : String,
  failures : Array[String],
) -> Unit {
  for value in expected {
    if !json_string_array_contains(values, value) {
      failures.push(label + " must include '" + value + "'")
    }
  }
}

///|
fn json_string_array_contains_token(
  values : Array[Json],
  token : String,
) -> Bool {
  values.any(value => {
    match value {
      String(text) => text.contains(token)
      _ => false
    }
  })
}

///|
fn assert_contains_tokens(
  values : Array[Json],
  tokens : Array[String],
  label : String,
  failures : Array[String],
) -> Unit {
  for token in tokens {
    if !json_string_array_contains_token(values, token) {
      failures.push(label + " must contain an entry mentioning '" + token + "'")
    }
  }
}

///|
fn json_string_array_has_no(values : Array[String]) -> Bool {
  values.any(value => value == "no")
}

///|
fn artifact_is_readme_placeholder(artifact : String) -> Bool {
  artifact.to_lower().has_suffix("/readme.md")
}

///|
fn assert_no_placeholder_passed_artifacts(
  artifacts : Array[Json],
  label : String,
  status : String,
  failures : Array[String],
) -> Unit {
  if status != "passed" {
    return
  }
  for index in 0..<artifacts.length() {
    match artifacts[index] {
      String(artifact) if artifact_is_readme_placeholder(artifact) =>
        failures.push(
          label +
          "[\{index}] must reference runtime evidence, not README.md placeholder documentation, when status is passed",
        )
      _ => ()
    }
  }
}

///|
fn artifact_starts_platform_root(artifact : String, name : String) -> Bool {
  !artifact.has_prefix("artifacts/platform-evidence/") ||
  artifact.has_prefix("artifacts/platform-evidence/" + name + "/")
}

///|
fn assert_artifacts_under_platform(
  artifacts : Array[Json],
  label : String,
  name : String,
  failures : Array[String],
) -> Unit {
  for index in 0..<artifacts.length() {
    match artifacts[index] {
      String(artifact) =>
        if !artifact_starts_platform_root(artifact, name) {
          failures.push(
            label +
            "[\{index}] must stay under artifacts/platform-evidence/" +
            name +
            "/",
          )
        }
      _ => ()
    }
  }
}

///|
fn github_actions_run_url(url : String) -> Bool {
  url.has_prefix("https://github.com/") && url.contains("/actions/runs/")
}

///|
fn validate_evidence_provenance(
  provenance_value : Json?,
  label : String,
  name : String,
  status : String,
  failures : Array[String],
) -> Unit {
  let provenance = match provenance_value {
    None => {
      if status == "passed" {
        failures.push(
          label + ".evidenceProvenance must be recorded when status is passed",
        )
      }
      return
    }
    Some(Object(fields)) => fields
    _ => {
      failures.push(label + ".evidenceProvenance must be an object")
      return
    }
  }
  let kind = require_string(
    provenance,
    "kind",
    label + ".evidenceProvenance.kind",
    failures,
  )
  if kind != "github-actions" && kind != "matching-host-artifact" {
    failures.push(
      label +
      ".evidenceProvenance.kind must be github-actions or matching-host-artifact",
    )
  }
  let host = require_string(
    provenance,
    "host",
    label + ".evidenceProvenance.host",
    failures,
  )
  if status == "passed" && !platform_host_matches(name, host) {
    failures.push(
      label +
      ".evidenceProvenance.host must name a matching " +
      name +
      " host when status is passed",
    )
  }
  let artifacts = require_array(
    provenance,
    "artifacts",
    label + ".evidenceProvenance.artifacts",
    failures,
  )
  let notes = require_array(
    provenance,
    "notes",
    label + ".evidenceProvenance.notes",
    failures,
  )
  assert_string_array(
    artifacts,
    label + ".evidenceProvenance.artifacts",
    failures,
  )
  assert_string_array(notes, label + ".evidenceProvenance.notes", failures)
  assert_no_placeholder_passed_artifacts(
    artifacts,
    label + ".evidenceProvenance.artifacts",
    status,
    failures,
  )
  if artifacts.is_empty() {
    failures.push(
      label +
      ".evidenceProvenance.artifacts must include at least one artifact reference",
    )
  }
  if notes.is_empty() {
    failures.push(
      label + ".evidenceProvenance.notes must include at least one note",
    )
  }
  assert_artifacts_under_platform(
    artifacts,
    label + ".evidenceProvenance.artifacts",
    name,
    failures,
  )
  if kind == "github-actions" {
    ignore(
      require_string(
        provenance,
        "workflow",
        label + ".evidenceProvenance.workflow",
        failures,
      ),
    )
    ignore(
      require_string(
        provenance,
        "job",
        label + ".evidenceProvenance.job",
        failures,
      ),
    )
    ignore(
      require_string(
        provenance,
        "runner",
        label + ".evidenceProvenance.runner",
        failures,
      ),
    )
    let run_url = require_string(
      provenance,
      "runUrl",
      label + ".evidenceProvenance.runUrl",
      failures,
    )
    if !github_actions_run_url(run_url) {
      failures.push(
        label + ".evidenceProvenance.runUrl must be a GitHub Actions run URL",
      )
    }
    if provenance.contains("runId") {
      ignore(
        require_string(
          provenance,
          "runId",
          label + ".evidenceProvenance.runId",
          failures,
        ),
      )
    }
  }
}

///|
fn validate_skia_evidence(
  entry : Map[String, Json],
  label : String,
  name : String,
  platform_status : String,
  failures : Array[String],
) -> Unit {
  let expected = match native_skia_spec(name) {
    Some(value) => value
    None => {
      if entry.contains("skiaEvidence") {
        failures.push(
          label + ".skiaEvidence is only supported for native Skia platforms",
        )
      }
      return
    }
  }
  let skia_evidence = match entry.get("skiaEvidence") {
    Some(Object(fields)) => fields
    _ => {
      failures.push(
        label + ".skiaEvidence must be an object for native Skia evidence",
      )
      return
    }
  }
  let status = require_string(
    skia_evidence,
    "status",
    label + ".skiaEvidence.status",
    failures,
  )
  if !allowed_status(status) {
    failures.push(
      label + ".skiaEvidence.status must be passed, failed, or pending",
    )
  }
  let boundary = require_string(
    skia_evidence,
    "boundary",
    label + ".skiaEvidence.boundary",
    failures,
  )
  let boundary_lower = boundary.to_lower()
  if !boundary_lower.contains("provider") || !boundary_lower.contains("runtime") {
    failures.push(
      label +
      ".skiaEvidence.boundary must describe provider and runtime evidence boundaries",
    )
  }
  let provider_commands = require_array(
    skia_evidence,
    "providerCommands",
    label + ".skiaEvidence.providerCommands",
    failures,
  )
  let runtime_smoke_commands = require_array(
    skia_evidence,
    "runtimeSmokeCommands",
    label + ".skiaEvidence.runtimeSmokeCommands",
    failures,
  )
  let artifacts = require_array(
    skia_evidence,
    "artifacts",
    label + ".skiaEvidence.artifacts",
    failures,
  )
  let notes = require_array(
    skia_evidence,
    "notes",
    label + ".skiaEvidence.notes",
    failures,
  )
  assert_string_array(
    provider_commands,
    label + ".skiaEvidence.providerCommands",
    failures,
  )
  assert_string_array(
    runtime_smoke_commands,
    label + ".skiaEvidence.runtimeSmokeCommands",
    failures,
  )
  assert_string_array(artifacts, label + ".skiaEvidence.artifacts", failures)
  assert_string_array(notes, label + ".skiaEvidence.notes", failures)
  assert_no_placeholder_passed_artifacts(
    artifacts,
    label + ".skiaEvidence.artifacts",
    status,
    failures,
  )
  if notes.is_empty() {
    failures.push(label + ".skiaEvidence.notes must include at least one note")
  }
  assert_contains_tokens(
    provider_commands,
    expected.provider_tokens,
    label + ".skiaEvidence.providerCommands",
    failures,
  )
  assert_contains_tokens(
    runtime_smoke_commands,
    expected.runtime_tokens,
    label + ".skiaEvidence.runtimeSmokeCommands",
    failures,
  )
  let observations = match skia_evidence.get("observations") {
    Some(Object(fields)) => fields
    _ => {
      failures.push(label + ".skiaEvidence.observations must be an object")
      return
    }
  }
  let observed_values : Array[String] = []
  for key in skia_observation_keys() {
    let value = match observations.get(key) {
      Some(String(text)) => text
      _ => ""
    }
    if !valid_observation_value(value) {
      failures.push(
        label +
        ".skiaEvidence.observations." +
        key +
        " must be yes, no, or pending",
      )
    }
    observed_values.push(value)
  }
  for key in observations.keys() {
    if !skia_observation_keys().contains(key) {
      failures.push(
        label + ".skiaEvidence.observations contains unknown key '" + key + "'",
      )
    }
  }
  if status == "passed" {
    for key in skia_observation_keys() {
      match observations.get(key) {
        Some(String("yes")) => ()
        _ => {
          failures.push(
            label +
            ".skiaEvidence.observations." +
            key +
            " must be yes when skiaEvidence.status is passed",
          )
          break
        }
      }
    }
  }
  validate_evidence_provenance(
    skia_evidence.get("evidenceProvenance"),
    label + ".skiaEvidence",
    name,
    status,
    failures,
  )
  if status == "failed" && !json_string_array_has_no(observed_values) {
    failures.push(
      label +
      ".skiaEvidence.observations must include at least one no when skiaEvidence.status is failed",
    )
  }
  if platform_status == "passed" && status != "passed" {
    failures.push(
      label +
      ".skiaEvidence.status must be passed when native platform status is passed",
    )
  }
  assert_artifacts_under_platform(
    artifacts,
    label + ".skiaEvidence.artifacts",
    name,
    failures,
  )
}

///|
fn web_passed_observation_required(key : String) -> Bool {
  key != "monitorCursor" && !native_ime_observation_keys().contains(key)
}

///|
fn validate_platform_entry(
  entry_json : Json,
  index : Int,
  seen : Map[String, Bool],
) -> Array[String] {
  let failures : Array[String] = []
  let entry = match json_object_value(entry_json) {
    Some(fields) => fields
    None => {
      failures.push("platforms[\{index}] must be an object")
      return failures
    }
  }
  let label = "platforms[\{index}]"
  let name = require_string(entry, "name", label + ".name", failures)
  if seen.contains(name) {
    failures.push("duplicate platform '" + name + "'")
  }
  seen[name] = true
  let expected = match platform_spec(name) {
    Some(value) => value
    None => {
      failures.push(label + ".name must be one of web, macos, windows, linux")
      return failures
    }
  }
  let status = require_string(entry, "status", label + ".status", failures)
  if !allowed_status(status) {
    failures.push(label + ".status must be passed, failed, or pending")
  }
  let host = require_string(entry, "host", label + ".host", failures)
  if status == "passed" && !platform_host_matches(name, host) {
    failures.push(
      label +
      ".host must name a matching " +
      name +
      " host when status is passed",
    )
  }
  let routine_commands = require_array(
    entry,
    "routineCommands",
    label + ".routineCommands",
    failures,
  )
  let runtime_evidence_commands = require_array(
    entry,
    "runtimeEvidenceCommands",
    label + ".runtimeEvidenceCommands",
    failures,
  )
  let example_targets = require_array(
    entry,
    "exampleTargets",
    label + ".exampleTargets",
    failures,
  )
  let artifacts = require_array(
    entry,
    "artifacts",
    label + ".artifacts",
    failures,
  )
  let notes = require_array(entry, "notes", label + ".notes", failures)
  assert_string_array(routine_commands, label + ".routineCommands", failures)
  assert_string_array(
    runtime_evidence_commands,
    label + ".runtimeEvidenceCommands",
    failures,
  )
  assert_string_array(example_targets, label + ".exampleTargets", failures)
  assert_string_array(artifacts, label + ".artifacts", failures)
  assert_string_array(notes, label + ".notes", failures)
  assert_no_placeholder_passed_artifacts(
    artifacts,
    label + ".artifacts",
    status,
    failures,
  )
  if notes.is_empty() {
    failures.push(label + ".notes must include at least one note")
  }
  assert_includes_all(
    example_targets,
    expected.example_targets,
    label + ".exampleTargets",
    failures,
  )
  assert_contains_tokens(
    routine_commands,
    expected.routine_tokens,
    label + ".routineCommands",
    failures,
  )
  assert_contains_tokens(
    runtime_evidence_commands,
    expected.runtime_tokens,
    label + ".runtimeEvidenceCommands",
    failures,
  )
  let window_evidence_command = require_string(
    entry,
    "windowEvidenceCommand",
    label + ".windowEvidenceCommand",
    failures,
  )
  if !window_evidence_command.contains(
      ".local_repos/window/scripts/record_moui_evidence.sh " + name,
    ) {
    failures.push(
      label +
      ".windowEvidenceCommand must use the window fork recorder for " +
      name,
    )
  }
  let observations = match entry.get("observations") {
    Some(Object(fields)) => fields
    _ => {
      failures.push(label + ".observations must be an object")
      return failures
    }
  }
  let observed_values : Array[String] = []
  for key in observation_keys() {
    let value = match observations.get(key) {
      Some(String(text)) => text
      _ => ""
    }
    if !valid_observation_value(value) {
      failures.push(
        label + ".observations." + key + " must be yes, no, or pending",
      )
    }
    observed_values.push(value)
  }
  for key in observations.keys() {
    if !observation_keys().contains(key) {
      failures.push(label + ".observations contains unknown key '" + key + "'")
    }
  }
  let consumer_command = require_string(
    entry,
    "consumerCommand",
    label + ".consumerCommand",
    failures,
  )
  let has_consumer_observation = consumer_observation_keys().any(key => {
    match observations.get(key) {
      Some(String("pending")) => false
      Some(String(_)) => true
      _ => false
    }
  })
  if has_consumer_observation && consumer_command == "pending" {
    failures.push(
      label +
      ".consumerCommand must name the MoUI consumer run when consumer observations are recorded",
    )
  }
  if status == "passed" {
    for key in observation_keys() {
      if name == "web" && !web_passed_observation_required(key) {
        continue
      }
      match observations.get(key) {
        Some(String("yes")) => ()
        _ => {
          failures.push(
            label +
            ".observations." +
            key +
            " must be yes when status is passed",
          )
          break
        }
      }
    }
    if consumer_command == "pending" {
      failures.push(
        label + ".consumerCommand must not be pending when status is passed",
      )
    }
  }
  validate_evidence_provenance(
    entry.get("evidenceProvenance"),
    label,
    name,
    status,
    failures,
  )
  if status == "failed" && !json_string_array_has_no(observed_values) {
    failures.push(
      label + ".observations must include at least one no when status is failed",
    )
  }
  validate_skia_evidence(entry, label, name, status, failures)
  assert_artifacts_under_platform(
    artifacts,
    label + ".artifacts",
    name,
    failures,
  )
  failures
}

///|
fn validate_manifest_fields(
  manifest : Map[String, Json],
  expected_platform : String,
) -> Array[String] {
  let failures : Array[String] = []
  if !json_number_is(manifest.get("schemaVersion"), 2.0) {
    failures.push("schemaVersion must be 2")
  }
  let mode = require_string(manifest, "mode", "mode", failures)
  if mode != "platform-runtime-evidence" {
    failures.push("mode must be 'platform-runtime-evidence'")
  }
  ignore(require_string(manifest, "generatedBy", "generatedBy", failures))
  let window_evidence_source = require_string(
    manifest, "windowEvidenceSource", "windowEvidenceSource", failures,
  )
  if window_evidence_source !=
    ".local_repos/window/scripts/record_moui_evidence.sh" {
    failures.push(
      "windowEvidenceSource must point at .local_repos/window/scripts/record_moui_evidence.sh",
    )
  }
  let entries = require_array(manifest, "platforms", "platforms", failures)
  let seen : Map[String, Bool] = {}
  for index in 0..<entries.length() {
    for failure in validate_platform_entry(entries[index], index, seen) {
      failures.push(failure)
    }
  }
  let required = if expected_platform == "" {
    platform_names()
  } else {
    [expected_platform]
  }
  for name in required {
    if !seen.contains(name) {
      failures.push("platforms must include '" + name + "'")
    }
  }
  failures
}

///|
fn validate_manifest_text(
  text : String,
  expected_platform? : String = "",
) -> Array[String] {
  let parsed = @json.parse(text) catch {
    _ => return ["failed to read JSON: invalid JSON"]
  }
  let manifest = match json_object(Some(parsed)) {
    Some(fields) => fields
    None => return ["manifest root must be an object"]
  }
  validate_manifest_fields(manifest, expected_platform)
}

///|
fn validate_platform_evidence_manifest(
  options : CliOptions,
) -> Result[String, Array[String]] {
  if options.expected_platform != "" &&
    !platform_names().contains(options.expected_platform) {
    return Err(["Unknown platform: " + options.expected_platform])
  }
  let text = match
    @tools.read_required_text(
      options.manifest_path,
      "platform evidence manifest",
    ) {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  let failures = validate_manifest_text(
    text,
    expected_platform=options.expected_platform,
  )
  if failures.is_empty() {
    Ok(options.display_path + ": ok (platform runtime evidence manifest)")
  } else {
    Err(failures)
  }
}

///|
fn print_prefixed_failures(path : String, failures : Array[String]) -> Unit {
  for failure in failures {
    if failure.has_prefix("Unknown platform: ") {
      println(failure)
    } else {
      println(path + ": " + failure)
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
      match validate_platform_evidence_manifest(options) {
        Ok(message) => {
          println(message)
          0
        }
        Err(failures) => {
          print_prefixed_failures(options.display_path, failures)
          if failures.length() == 1 &&
            failures[0].has_prefix("Unknown platform: ") {
            println(usage())
            2
          } else {
            1
          }
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
