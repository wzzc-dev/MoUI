///|
struct ProvenanceOptions {
  kind : String
  kind_set : Bool
  host : String
  host_set : Bool
  workflow : String
  workflow_set : Bool
  job : String
  job_set : Bool
  run_url : String
  run_url_set : Bool
  run_id : String
  run_id_set : Bool
  runner : String
  runner_set : Bool
  artifacts : Array[String]
  notes : Array[String]
}

///|
struct CliOptions {
  repo_root : String
  manifest_path : String
  platform : String
  output_path : String
  status : String
  status_set : Bool
  host : String
  host_set : Bool
  window_evidence_command : String
  window_evidence_command_set : Bool
  consumer_command : String
  consumer_command_set : Bool
  observations : Map[String, String]
  artifacts : Array[String]
  notes : Array[String]
  provenance : ProvenanceOptions
  web_presentation_manifest : String
  web_presentation_manifest_set : Bool
  skia_status : String
  skia_status_set : Bool
  skia_boundary : String
  skia_boundary_set : Bool
  skia_observations : Map[String, String]
  skia_provider_commands : Array[String]
  skia_runtime_smoke_commands : Array[String]
  skia_artifacts : Array[String]
  skia_notes : Array[String]
  skia_provenance : ProvenanceOptions
  help : Bool
}

///|
fn empty_provenance() -> ProvenanceOptions {
  {
    kind: "",
    kind_set: false,
    host: "",
    host_set: false,
    workflow: "",
    workflow_set: false,
    job: "",
    job_set: false,
    run_url: "",
    run_url_set: false,
    run_id: "",
    run_id_set: false,
    runner: "",
    runner_set: false,
    artifacts: [],
    notes: [],
  }
}

///|
fn provenance_replace(
  value : ProvenanceOptions,
  field : String,
  text : String,
) -> ProvenanceOptions {
  let kind = Ref(value.kind)
  let kind_set = Ref(value.kind_set)
  let host = Ref(value.host)
  let host_set = Ref(value.host_set)
  let workflow = Ref(value.workflow)
  let workflow_set = Ref(value.workflow_set)
  let job = Ref(value.job)
  let job_set = Ref(value.job_set)
  let run_url = Ref(value.run_url)
  let run_url_set = Ref(value.run_url_set)
  let run_id = Ref(value.run_id)
  let run_id_set = Ref(value.run_id_set)
  let runner = Ref(value.runner)
  let runner_set = Ref(value.runner_set)
  match field {
    "kind" => {
      kind.val = text
      kind_set.val = true
    }
    "host" => {
      host.val = text
      host_set.val = true
    }
    "workflow" => {
      workflow.val = text
      workflow_set.val = true
    }
    "job" => {
      job.val = text
      job_set.val = true
    }
    "run_url" => {
      run_url.val = text
      run_url_set.val = true
    }
    "run_id" => {
      run_id.val = text
      run_id_set.val = true
    }
    "runner" => {
      runner.val = text
      runner_set.val = true
    }
    _ => ()
  }
  {
    kind: kind.val,
    kind_set: kind_set.val,
    host: host.val,
    host_set: host_set.val,
    workflow: workflow.val,
    workflow_set: workflow_set.val,
    job: job.val,
    job_set: job_set.val,
    run_url: run_url.val,
    run_url_set: run_url_set.val,
    run_id: run_id.val,
    run_id_set: run_id_set.val,
    runner: runner.val,
    runner_set: runner_set.val,
    artifacts: value.artifacts,
    notes: value.notes,
  }
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/record_platform_evidence_manifest <manifest.json> <platform> [options]
    #|
    #|Platforms:
    #|  web | macos | windows | linux
    #|
    #|Writes an updated platform runtime evidence manifest to --output for the
    #|compatibility Node wrapper to validate and install.
    #|
  text
}

///|
fn platform_names() -> Array[String] {
  ["web", "macos", "windows", "linux"]
}

///|
fn native_skia_platforms() -> Array[String] {
  ["macos", "windows", "linux"]
}

///|
fn statuses() -> Array[String] {
  ["passed", "failed", "pending"]
}

///|
fn provenance_kinds() -> Array[String] {
  ["github-actions", "matching-host-artifact"]
}

///|
fn native_ime_observation_keys() -> Array[String] {
  [
    "imeCandidateAnchor", "imeSurroundingText", "imeCompositionVisual", "imeCommitDelete",
    "imeCursorUpdate", "imeScrollAnchor", "imeScaleDprAnchor", "imeResizeAnchor",
  ]
}

///|
fn legacy_native_ime_observation_keys() -> Array[String] {
  ["imeMarkdownEditor"]
}

///|
fn observation_keys() -> Array[String] {
  [
    "windowOpened", "resizeRedraw", "representativeInput", "cleanExit", "surface",
    "redraw", "resizeScale", "consumerInput", "textInput", "rendererHandle", "monitorCursor",
    "cleanShutdown", "imeCandidateAnchor", "imeSurroundingText", "imeCompositionVisual",
    "imeCommitDelete", "imeCursorUpdate", "imeScrollAnchor", "imeScaleDprAnchor",
    "imeResizeAnchor",
  ]
}

///|
fn skia_observation_keys() -> Array[String] {
  [
    "providerPreflight", "fallbackUnavailable", "realRendererSmoke", "asyncImageSecondFrame",
    "showcaseFirstFrame",
  ]
}

///|
fn legacy_skia_observation_keys() -> Array[String] {
  ["markdownFirstFrame"]
}

///|
fn observation_values() -> Array[String] {
  ["yes", "no", "pending"]
}

///|
fn string_array_contains(values : Array[String], expected : String) -> Bool {
  values.contains(expected)
}

///|
fn parse_assignment(
  assignment : String,
  allowed_keys : Array[String],
  invalid_prefix : String,
  unknown_prefix : String,
  value_prefix : String,
) -> Result[(String, String), String] {
  let separator = Ref(-1)
  for index in 0..<assignment.length() {
    if assignment[index] == '=' {
      separator.val = index
      break
    }
  }
  if separator.val <= 0 {
    return Err(invalid_prefix + assignment)
  }
  let key = assignment[:separator.val].to_owned()
  let value = assignment[separator.val + 1:].to_owned()
  if !string_array_contains(allowed_keys, key) {
    return Err(unknown_prefix + key)
  }
  if !string_array_contains(observation_values(), value) {
    return Err(
      value_prefix + key + " must be yes, no, or pending; got " + value,
    )
  }
  Ok((key, value))
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let manifest_path = Ref("")
  let platform = Ref("")
  let output_path = Ref("")
  let status = Ref("")
  let status_set = Ref(false)
  let host = Ref("")
  let host_set = Ref(false)
  let window_evidence_command = Ref("")
  let window_evidence_command_set = Ref(false)
  let consumer_command = Ref("")
  let consumer_command_set = Ref(false)
  let observations : Map[String, String] = {}
  let artifacts : Array[String] = []
  let notes : Array[String] = []
  let provenance = Ref(empty_provenance())
  let web_presentation_manifest = Ref("")
  let web_presentation_manifest_set = Ref(false)
  let skia_status = Ref("")
  let skia_status_set = Ref(false)
  let skia_boundary = Ref("")
  let skia_boundary_set = Ref(false)
  let skia_observations : Map[String, String] = {}
  let skia_provider_commands : Array[String] = []
  let skia_runtime_smoke_commands : Array[String] = []
  let skia_artifacts : Array[String] = []
  let skia_notes : Array[String] = []
  let skia_provenance = Ref(empty_provenance())
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
      "--output" => {
        if index + 1 >= args.length() {
          return Err("missing value for --output")
        }
        output_path.val = args[index + 1]
        index += 2
      }
      "--status" => {
        if index + 1 >= args.length() {
          return Err("missing value for --status")
        }
        status.val = args[index + 1]
        status_set.val = true
        index += 2
      }
      "--host" => {
        if index + 1 >= args.length() {
          return Err("missing value for --host")
        }
        host.val = args[index + 1]
        host_set.val = true
        index += 2
      }
      "--window-evidence-command" => {
        if index + 1 >= args.length() {
          return Err("missing value for --window-evidence-command")
        }
        window_evidence_command.val = args[index + 1]
        window_evidence_command_set.val = true
        index += 2
      }
      "--consumer-command" => {
        if index + 1 >= args.length() {
          return Err("missing value for --consumer-command")
        }
        consumer_command.val = args[index + 1]
        consumer_command_set.val = true
        index += 2
      }
      "--set" => {
        if index + 1 >= args.length() {
          return Err("missing value for --set")
        }
        match
          parse_assignment(
            args[index + 1],
            observation_keys(),
            "Invalid --set value: ",
            "Unknown observation key: ",
            "Observation ",
          ) {
          Ok((key, value)) => observations[key] = value
          Err(message) => return Err(message)
        }
        index += 2
      }
      "--artifact" => {
        if index + 1 >= args.length() {
          return Err("missing value for --artifact")
        }
        artifacts.push(args[index + 1])
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
        provenance.val = provenance_replace(
          provenance.val,
          "kind",
          args[index + 1],
        )
        index += 2
      }
      "--provenance-host" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-host")
        }
        provenance.val = provenance_replace(
          provenance.val,
          "host",
          args[index + 1],
        )
        index += 2
      }
      "--provenance-workflow" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-workflow")
        }
        provenance.val = provenance_replace(
          provenance.val,
          "workflow",
          args[index + 1],
        )
        index += 2
      }
      "--provenance-job" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-job")
        }
        provenance.val = provenance_replace(
          provenance.val,
          "job",
          args[index + 1],
        )
        index += 2
      }
      "--provenance-run-url" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-run-url")
        }
        provenance.val = provenance_replace(
          provenance.val,
          "run_url",
          args[index + 1],
        )
        index += 2
      }
      "--provenance-run-id" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-run-id")
        }
        provenance.val = provenance_replace(
          provenance.val,
          "run_id",
          args[index + 1],
        )
        index += 2
      }
      "--provenance-runner" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-runner")
        }
        provenance.val = provenance_replace(
          provenance.val,
          "runner",
          args[index + 1],
        )
        index += 2
      }
      "--provenance-artifact" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-artifact")
        }
        provenance.val.artifacts.push(args[index + 1])
        index += 2
      }
      "--provenance-note" => {
        if index + 1 >= args.length() {
          return Err("missing value for --provenance-note")
        }
        provenance.val.notes.push(args[index + 1])
        index += 2
      }
      "--web-presentation-manifest" => {
        if index + 1 >= args.length() {
          return Err("missing value for --web-presentation-manifest")
        }
        web_presentation_manifest.val = args[index + 1]
        web_presentation_manifest_set.val = true
        index += 2
      }
      "--skia-status" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-status")
        }
        skia_status.val = args[index + 1]
        skia_status_set.val = true
        index += 2
      }
      "--skia-set" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-set")
        }
        match
          parse_assignment(
            args[index + 1],
            skia_observation_keys(),
            "Invalid --skia-set value: ",
            "Unknown Skia observation key: ",
            "Skia observation ",
          ) {
          Ok((key, value)) => skia_observations[key] = value
          Err(message) => return Err(message)
        }
        index += 2
      }
      "--skia-boundary" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-boundary")
        }
        skia_boundary.val = args[index + 1]
        skia_boundary_set.val = true
        index += 2
      }
      "--skia-provider-command" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-provider-command")
        }
        skia_provider_commands.push(args[index + 1])
        index += 2
      }
      "--skia-runtime-smoke-command" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-runtime-smoke-command")
        }
        skia_runtime_smoke_commands.push(args[index + 1])
        index += 2
      }
      "--skia-artifact" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-artifact")
        }
        skia_artifacts.push(args[index + 1])
        index += 2
      }
      "--skia-note" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-note")
        }
        skia_notes.push(args[index + 1])
        index += 2
      }
      "--skia-provenance-kind" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-provenance-kind")
        }
        skia_provenance.val = provenance_replace(
          skia_provenance.val,
          "kind",
          args[index + 1],
        )
        index += 2
      }
      "--skia-provenance-host" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-provenance-host")
        }
        skia_provenance.val = provenance_replace(
          skia_provenance.val,
          "host",
          args[index + 1],
        )
        index += 2
      }
      "--skia-provenance-workflow" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-provenance-workflow")
        }
        skia_provenance.val = provenance_replace(
          skia_provenance.val,
          "workflow",
          args[index + 1],
        )
        index += 2
      }
      "--skia-provenance-job" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-provenance-job")
        }
        skia_provenance.val = provenance_replace(
          skia_provenance.val,
          "job",
          args[index + 1],
        )
        index += 2
      }
      "--skia-provenance-run-url" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-provenance-run-url")
        }
        skia_provenance.val = provenance_replace(
          skia_provenance.val,
          "run_url",
          args[index + 1],
        )
        index += 2
      }
      "--skia-provenance-run-id" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-provenance-run-id")
        }
        skia_provenance.val = provenance_replace(
          skia_provenance.val,
          "run_id",
          args[index + 1],
        )
        index += 2
      }
      "--skia-provenance-runner" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-provenance-runner")
        }
        skia_provenance.val = provenance_replace(
          skia_provenance.val,
          "runner",
          args[index + 1],
        )
        index += 2
      }
      "--skia-provenance-artifact" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-provenance-artifact")
        }
        skia_provenance.val.artifacts.push(args[index + 1])
        index += 2
      }
      "--skia-provenance-note" => {
        if index + 1 >= args.length() {
          return Err("missing value for --skia-provenance-note")
        }
        skia_provenance.val.notes.push(args[index + 1])
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
    if output_path.val == "" {
      return Err("missing value for --output")
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
    output_path: output_path.val,
    status: status.val,
    status_set: status_set.val,
    host: host.val,
    host_set: host_set.val,
    window_evidence_command: window_evidence_command.val,
    window_evidence_command_set: window_evidence_command_set.val,
    consumer_command: consumer_command.val,
    consumer_command_set: consumer_command_set.val,
    observations,
    artifacts,
    notes,
    provenance: provenance.val,
    web_presentation_manifest: web_presentation_manifest.val,
    web_presentation_manifest_set: web_presentation_manifest_set.val,
    skia_status: skia_status.val,
    skia_status_set: skia_status_set.val,
    skia_boundary: skia_boundary.val,
    skia_boundary_set: skia_boundary_set.val,
    skia_observations,
    skia_provider_commands,
    skia_runtime_smoke_commands,
    skia_artifacts,
    skia_notes,
    skia_provenance: skia_provenance.val,
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
fn string_json(value : String) -> Json {
  Json::string(value)
}

///|
fn number_json(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn string_array_json(values : Array[String]) -> Json {
  let array : Array[Json] = []
  for value in values {
    array.push(string_json(value))
  }
  Json::array(array)
}

///|
fn pending_observations(keys : Array[String]) -> Map[String, Json] {
  let values : Map[String, Json] = {}
  for key in keys {
    values[key] = string_json("pending")
  }
  values
}

///|
fn pending_skia_observations() -> Map[String, Json] {
  pending_observations(skia_observation_keys())
}

///|
fn default_skia_evidence(platform : String) -> Json? {
  let fields : Map[String, Json] = {}
  fields["status"] = string_json("pending")
  fields["observations"] = Json::object(pending_skia_observations())
  match platform {
    "macos" => {
      fields["boundary"] = string_json(
        "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named macOS host and does not reuse moui_skia dependency evidence.",
      )
      fields["providerCommands"] = string_array_json([
        "moon test moui/render/skia --target native", "moon test moui/backend/macos/skia --target native",
      ])
      fields["runtimeSmokeCommands"] = string_array_json([
        "scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --smoke-log artifacts/platform-evidence/macos/skia-renderer-smoke.log --showcase-log artifacts/platform-evidence/macos/showcase-macos-skia-first-frame.log --record-platform-evidence artifacts/conformance/platform-runtime-evidence.json",
      ])
      fields["artifacts"] = string_array_json([
        "artifacts/platform-evidence/macos/README.md",
      ])
      fields["notes"] = string_array_json([
        "macOS Skia runtime evidence is pending until the real-Skia renderer smoke and Showcase first-frame Skia entrypoint log are recorded as artifacts.",
      ])
      Some(Json::object(fields))
    }
    "windows" => {
      fields["boundary"] = string_json(
        "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named Windows/MSVC host and does not reuse moui_skia dependency evidence.",
      )
      fields["providerCommands"] = string_array_json([
        "moon test moui/render/skia --target native", "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon test moui/backend/windows/skia --target native }\"",
        "powershell -ExecutionPolicy Bypass -File scripts/windows/build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly",
      ])
      fields["runtimeSmokeCommands"] = string_array_json([
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; $env:MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT='1'; moon run examples/showcase/windows_skia --target native }\"",
      ])
      fields["artifacts"] = string_array_json([
        "artifacts/platform-evidence/windows/README.md",
      ])
      fields["notes"] = string_array_json([
        "Windows Skia runtime evidence remains matching-host pending until the MSVC first-frame Showcase log is recorded.",
      ])
      Some(Json::object(fields))
    }
    "linux" => {
      fields["boundary"] = string_json(
        "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named Linux Wayland host and does not reuse moui_skia dependency evidence.",
      )
      fields["providerCommands"] = string_array_json([
        "moon test moui/render/skia --target native", "moon test moui/backend/linux/skia --target native",
        "moon build examples/showcase/linux_skia --target native",
      ])
      fields["runtimeSmokeCommands"] = string_array_json([
        "MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/linux_skia --target native",
      ])
      fields["artifacts"] = string_array_json([
        "artifacts/platform-evidence/linux/README.md",
      ])
      fields["notes"] = string_array_json([
        "Linux Skia runtime evidence remains matching-host pending until the Wayland first-frame Showcase log is recorded with configured real Skia link flags.",
      ])
      Some(Json::object(fields))
    }
    _ => None
  }
}

///|
fn has_provenance_update(data : ProvenanceOptions) -> Bool {
  data.kind_set ||
  data.host_set ||
  data.workflow_set ||
  data.job_set ||
  data.run_url_set ||
  data.run_id_set ||
  data.runner_set ||
  !data.artifacts.is_empty() ||
  !data.notes.is_empty()
}

///|
fn non_empty(value : String, label : String) -> Result[Unit, String] {
  if value.trim().to_owned() == "" {
    Err(label + " must be a non-empty string")
  } else {
    Ok(())
  }
}

///|
fn validate_provenance_input(
  data : ProvenanceOptions,
  label : String,
) -> Result[Unit, String] {
  if !has_provenance_update(data) {
    return Ok(())
  }
  match non_empty(data.kind, label + "-kind") {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  match non_empty(data.host, label + "-host") {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  for index in 0..<data.artifacts.length() {
    match
      non_empty(
        data.artifacts[index],
        label + "-artifact " + (index + 1).to_string(),
      ) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  for index in 0..<data.notes.length() {
    match
      non_empty(data.notes[index], label + "-note " + (index + 1).to_string()) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  if data.artifacts.is_empty() {
    return Err(label + "-artifact is required when provenance is recorded")
  }
  if data.notes.is_empty() {
    return Err(label + "-note is required when provenance is recorded")
  }
  if data.kind == "github-actions" {
    match non_empty(data.workflow, label + "-workflow") {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
    match non_empty(data.job, label + "-job") {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
    match non_empty(data.run_url, label + "-run-url") {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
    match non_empty(data.runner, label + "-runner") {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
    if !data.run_url.has_prefix("https://github.com/") ||
      !data.run_url.contains("/actions/runs/") {
      return Err(label + "-run-url must be a GitHub Actions run URL")
    }
    if data.run_id_set {
      match non_empty(data.run_id, label + "-run-id") {
        Err(message) => return Err(message)
        Ok(_) => ()
      }
    }
  }
  Ok(())
}

///|
fn build_provenance(data : ProvenanceOptions) -> Json? {
  if !has_provenance_update(data) {
    return None
  }
  let fields : Map[String, Json] = {}
  fields["kind"] = string_json(data.kind)
  fields["host"] = string_json(data.host)
  fields["artifacts"] = string_array_json(data.artifacts)
  fields["notes"] = string_array_json(data.notes)
  if data.workflow_set {
    fields["workflow"] = string_json(data.workflow)
  }
  if data.job_set {
    fields["job"] = string_json(data.job)
  }
  if data.run_url_set {
    fields["runUrl"] = string_json(data.run_url)
  }
  if data.run_id_set {
    fields["runId"] = string_json(data.run_id)
  }
  if data.runner_set {
    fields["runner"] = string_json(data.runner)
  }
  Some(Json::object(fields))
}

///|
fn has_skia_update(options : CliOptions) -> Bool {
  options.skia_status_set ||
  options.skia_boundary_set ||
  options.skia_observations.length() > 0 ||
  !options.skia_provider_commands.is_empty() ||
  !options.skia_runtime_smoke_commands.is_empty() ||
  !options.skia_artifacts.is_empty() ||
  !options.skia_notes.is_empty() ||
  has_provenance_update(options.skia_provenance)
}

///|
fn validate_options(options : CliOptions) -> Result[Unit, String] {
  if !string_array_contains(platform_names(), options.platform) {
    return Err("Unknown platform: " + options.platform)
  }
  if options.status_set && !string_array_contains(statuses(), options.status) {
    return Err(
      "--status must be passed, failed, or pending; got " + options.status,
    )
  }
  if options.skia_status_set &&
    !string_array_contains(statuses(), options.skia_status) {
    return Err(
      "--skia-status must be passed, failed, or pending; got " +
      options.skia_status,
    )
  }
  if options.provenance.kind_set &&
    !string_array_contains(provenance_kinds(), options.provenance.kind) {
    return Err(
      "--provenance-kind must be github-actions or matching-host-artifact; got " +
      options.provenance.kind,
    )
  }
  if options.skia_provenance.kind_set &&
    !string_array_contains(provenance_kinds(), options.skia_provenance.kind) {
    return Err(
      "--skia-provenance-kind must be github-actions or matching-host-artifact; got " +
      options.skia_provenance.kind,
    )
  }
  if has_skia_update(options) &&
    !string_array_contains(native_skia_platforms(), options.platform) {
    return Err(
      "Skia evidence options can only update native Skia platform entries: macos, windows, or linux",
    )
  }
  if options.host_set {
    match non_empty(options.host, "--host") {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  if options.window_evidence_command_set {
    match
      non_empty(options.window_evidence_command, "--window-evidence-command") {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  if options.consumer_command_set {
    match non_empty(options.consumer_command, "--consumer-command") {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  for index in 0..<options.artifacts.length() {
    match
      non_empty(
        options.artifacts[index],
        "--artifact " + (index + 1).to_string(),
      ) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  for index in 0..<options.notes.length() {
    match non_empty(options.notes[index], "--note " + (index + 1).to_string()) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  match validate_provenance_input(options.provenance, "--provenance") {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  if options.skia_boundary_set {
    match non_empty(options.skia_boundary, "--skia-boundary") {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  for index in 0..<options.skia_provider_commands.length() {
    match
      non_empty(
        options.skia_provider_commands[index],
        "--skia-provider-command " + (index + 1).to_string(),
      ) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  for index in 0..<options.skia_runtime_smoke_commands.length() {
    match
      non_empty(
        options.skia_runtime_smoke_commands[index],
        "--skia-runtime-smoke-command " + (index + 1).to_string(),
      ) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  for index in 0..<options.skia_artifacts.length() {
    match
      non_empty(
        options.skia_artifacts[index],
        "--skia-artifact " + (index + 1).to_string(),
      ) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  for index in 0..<options.skia_notes.length() {
    match
      non_empty(
        options.skia_notes[index],
        "--skia-note " + (index + 1).to_string(),
      ) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
  }
  match
    validate_provenance_input(options.skia_provenance, "--skia-provenance") {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  if options.web_presentation_manifest_set {
    match
      non_empty(
        options.web_presentation_manifest,
        "--web-presentation-manifest",
      ) {
      Err(message) => return Err(message)
      Ok(_) => ()
    }
    if options.platform != "web" {
      return Err(
        "--web-presentation-manifest can only update the web platform entry",
      )
    }
    if options.status_set ||
      options.host_set ||
      options.window_evidence_command_set ||
      options.consumer_command_set ||
      options.observations.length() > 0 ||
      !options.artifacts.is_empty() ||
      has_provenance_update(options.provenance) ||
      has_skia_update(options) {
      return Err(
        "--web-presentation-manifest derives status, host, consumer command, observations, and artifacts; do not combine it with --status, --host, --window-evidence-command, --consumer-command, --set, --artifact, or Skia evidence options",
      )
    }
  }
  Ok(())
}

///|
fn all_targets_observed(web_manifest : Map[String, Json], key : String) -> Bool {
  let targets = optional_array(web_manifest, "targets")
  if targets.is_empty() {
    return false
  }
  for target in targets {
    match target {
      Json::Object(fields) => {
        let observations = match optional_object(fields, "observations") {
          Some(value) => value
          None => return false
        }
        if optional_string(observations, key) != "yes" {
          return false
        }
      }
      _ => return false
    }
  }
  true
}

///|
fn bool_observation(value : Bool) -> Json {
  string_json(if value { "yes" } else { "no" })
}

///|
fn web_platform_observations(
  web_manifest : Map[String, Json],
) -> Map[String, Json] {
  match optional_object(web_manifest, "platformObservations") {
    Some(value) => return value
    None => ()
  }
  let observations : Map[String, Json] = {}
  observations["windowOpened"] = bool_observation(
    all_targets_observed(web_manifest, "pageLoaded"),
  )
  observations["resizeRedraw"] = string_json("pending")
  observations["representativeInput"] = string_json("pending")
  observations["cleanExit"] = string_json("pending")
  observations["surface"] = bool_observation(
    all_targets_observed(web_manifest, "webGpuAvailable") &&
    all_targets_observed(web_manifest, "deviceRequested") &&
    all_targets_observed(web_manifest, "canvasCreated") &&
    all_targets_observed(web_manifest, "canvasSized"),
  )
  observations["redraw"] = bool_observation(
    all_targets_observed(web_manifest, "statusRunning") &&
    all_targets_observed(web_manifest, "nonblankScreenshot") &&
    all_targets_observed(web_manifest, "cleanConsole"),
  )
  observations["resizeScale"] = string_json("pending")
  observations["consumerInput"] = string_json("pending")
  observations["textInput"] = string_json("pending")
  observations["rendererHandle"] = bool_observation(
    all_targets_observed(web_manifest, "deviceRequested") &&
    all_targets_observed(web_manifest, "wasmStarted") &&
    all_targets_observed(web_manifest, "cleanConsole"),
  )
  observations["monitorCursor"] = string_json("pending")
  observations["cleanShutdown"] = string_json("pending")
  observations
}

///|
fn basename(path : String) -> String {
  let normalized = normalize_separators(path)
  let last = Ref(-1)
  for index in 0..<normalized.length() {
    if normalized[index] == '/' {
      last.val = index
    }
  }
  if last.val < 0 {
    normalized
  } else {
    normalized[last.val + 1:].to_owned()
  }
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
fn copy_file(source : String, target : String) -> Result[Unit, String] {
  let bytes = @fs.read_file_to_bytes(source) catch {
    _ => return Err("could not read artifact: " + source)
  }
  @fs.write_bytes_to_file(target, bytes) catch {
    _ => return Err("could not write artifact: " + target)
  }
  Ok(())
}

///|
fn copy_web_presentation_artifacts(
  repo_root : String,
  web_manifest : Map[String, Json],
  source_path : String,
) -> Result[Array[String], String] {
  ignore(source_path)
  let target_relative_dir = "artifacts/platform-evidence/web"
  let target_dir = @tools.join_path(repo_root, target_relative_dir)
  match mkdir_p(target_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let manifest_relative = target_relative_dir + "/web-runtime-presentation.json"
  let manifest_artifact = @tools.join_path(repo_root, manifest_relative)
  let manifest_text = Json::object(web_manifest).stringify(indent=2) + "\n"
  match
    @tools.write_text_file(
      manifest_artifact, manifest_text, "web runtime presentation platform artifact",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let copied : Array[String] = [manifest_relative]
  for target in optional_array(web_manifest, "targets") {
    match target {
      Json::Object(fields) => {
        let screenshot = match optional_object(fields, "screenshot") {
          Some(value) => value
          None => continue
        }
        let source = optional_string(screenshot, "artifact")
        if source.trim().to_owned() == "" {
          continue
        }
        let source_absolute = @tools.resolve_path(repo_root, source)
        if !@tools.file_exists(source_absolute) {
          continue
        }
        let output_relative = target_relative_dir + "/" + basename(source)
        let output_absolute = @tools.join_path(repo_root, output_relative)
        match copy_file(source_absolute, output_absolute) {
          Ok(_) => copied.push(output_relative)
          Err(message) => return Err(message)
        }
      }
      _ => ()
    }
  }
  Ok(copied)
}

///|
fn env_or_empty(name : String) -> String {
  @env.get_env_var(name).unwrap_or("")
}

///|
fn github_actions_provenance_for_web(
  entry : Map[String, Json],
  artifacts : Array[String],
) -> Json? {
  if env_or_empty("GITHUB_ACTIONS") != "true" {
    return None
  }
  let server_url = if env_or_empty("GITHUB_SERVER_URL") == "" {
    "https://github.com"
  } else {
    env_or_empty("GITHUB_SERVER_URL")
  }
  let repository = env_or_empty("GITHUB_REPOSITORY")
  let run_id = env_or_empty("GITHUB_RUN_ID")
  let workflow = env_or_empty("GITHUB_WORKFLOW")
  let job = env_or_empty("GITHUB_JOB")
  let runner = if env_or_empty("RUNNER_NAME") != "" {
    env_or_empty("RUNNER_NAME")
  } else if env_or_empty("RUNNER_OS") != "" {
    env_or_empty("RUNNER_OS")
  } else {
    env_or_empty("RUNNER_ARCH")
  }
  if repository == "" ||
    run_id == "" ||
    workflow == "" ||
    job == "" ||
    runner == "" {
    return None
  }
  let fields : Map[String, Json] = {}
  fields["kind"] = string_json("github-actions")
  fields["host"] = string_json(optional_string(entry, "host"))
  fields["workflow"] = string_json(workflow)
  fields["job"] = string_json(job)
  fields["runUrl"] = string_json(
    server_url + "/" + repository + "/actions/runs/" + run_id,
  )
  fields["runId"] = string_json(run_id)
  fields["runner"] = string_json(runner)
  fields["artifacts"] = string_array_json(artifacts)
  fields["notes"] = string_array_json([
    "Web platform evidence was derived from a browser presentation manifest produced by GitHub Actions.",
    "GitHub Actions job " + job + " in workflow " + workflow + ".",
  ])
  Some(Json::object(fields))
}

///|
fn matching_host_web_provenance(
  entry : Map[String, Json],
  path : String,
) -> Json {
  let fields : Map[String, Json] = {}
  fields["kind"] = string_json("matching-host-artifact")
  fields["host"] = string_json(optional_string(entry, "host"))
  fields["artifacts"] = entry.get("artifacts").unwrap_or(Json::array([]))
  fields["notes"] = string_array_json([
    "Web platform evidence was derived from the browser presentation manifest artifact.",
    "Source manifest: " + path,
  ])
  Json::object(fields)
}

///|
fn apply_web_presentation_evidence(
  entry : Map[String, Json],
  repo_root : String,
  path : String,
) -> Result[Unit, String] {
  let text = match @tools.read_required_text(path, path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err(path + ": failed to read JSON: invalid JSON")
  }
  let web_manifest = match json_object(parsed) {
    Some(value) => value
    None =>
      return Err(path + ": web presentation manifest root must be an object")
  }
  let platform_observations = web_platform_observations(web_manifest)
  let all_passed = optional_string(web_manifest, "overallStatus") == "passed"
  let browser_observable_passed = Ref(true)
  for key in observation_keys() {
    if key == "monitorCursor" {
      continue
    }
    match platform_observations.get(key) {
      Some(Json::String("yes")) => ()
      Some(_) => browser_observable_passed.val = false
      None => ()
    }
  }
  let web_evidence_passed = all_passed && browser_observable_passed.val
  entry["status"] = string_json(
    if web_evidence_passed {
      "passed"
    } else {
      "failed"
    },
  )
  let browser = match optional_object(web_manifest, "browser") {
    Some(value) => value
    None => {}
  }
  let product = if optional_string(browser, "product") == "" {
    "unknown browser"
  } else {
    optional_string(browser, "product")
  }
  entry["host"] = string_json("Web wasm-gc browser host (" + product + ")")
  let require_passed_flag = if all_passed { " --require-passed" } else { "" }
  let command = "node scripts/record-web-runtime-presentation.mjs --base-url " +
    optional_string(web_manifest, "baseUrl") +
    " --cdp-url " +
    optional_string(web_manifest, "cdpUrl") +
    " --manifest " +
    path +
    require_passed_flag
  entry["consumerCommand"] = string_json(command)
  let observations = ensure_object_field(entry, "observations")
  for key in observation_keys() {
    match platform_observations.get(key) {
      Some(value) => observations[key] = value
      None => ()
    }
  }
  let artifacts = match
    copy_web_presentation_artifacts(repo_root, web_manifest, path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  entry["artifacts"] = string_array_json(artifacts)
  entry["evidenceProvenance"] = match
    github_actions_provenance_for_web(entry, artifacts) {
    Some(value) => value
    None => matching_host_web_provenance(entry, path)
  }
  let boundary = optional_string(web_manifest, "evidenceBoundary")
  entry["notes"] = string_array_json([
    if web_evidence_passed {
      "Web browser presentation manifest passed with resize, input, text-input, and clean-shutdown observations; monitor/cursor remains pending because CDP evidence is browser-local."
    } else {
      "Web browser presentation manifest failed; do not claim passed Web runtime evidence from this browser session."
    },
    "Web presentation manifest: " + path,
    "Browser evidence boundary: " + boundary,
  ])
  Ok(())
}

///|
fn ensure_object_field(
  object : Map[String, Json],
  field : String,
) -> Map[String, Json] {
  match object.get(field) {
    Some(Json::Object(fields)) => fields
    _ => {
      let fields : Map[String, Json] = {}
      object[field] = Json::object(fields)
      fields
    }
  }
}

///|
fn ensure_skia_evidence(
  entry : Map[String, Json],
  platform : String,
) -> Map[String, Json] {
  match entry.get("skiaEvidence") {
    Some(Json::Object(fields)) => fields
    _ => {
      let value = default_skia_evidence(platform).unwrap_or(Json::object({}))
      entry["skiaEvidence"] = value
      match value {
        Json::Object(fields) => fields
        _ => {}
      }
    }
  }
}

///|
fn migrate_manifest(manifest : Map[String, Json]) -> Result[Unit, String] {
  let platforms = match manifest.get("platforms") {
    Some(Json::Array(values)) => values
    _ => return Err("field 'platforms' must be an array")
  }
  match manifest.get("schemaVersion") {
    Some(Json::Number(number, repr=_)) if number == 1.0 || number == 2.0 => ()
    _ => return Err("schemaVersion must be 1 or 2")
  }
  manifest["schemaVersion"] = number_json(2)
  for value in platforms {
    match value {
      Json::Object(entry) => {
        let observations = ensure_object_field(entry, "observations")
        if observations.get("monitorCursor") == None {
          observations["monitorCursor"] = string_json("pending")
        }
        for key in legacy_native_ime_observation_keys() {
          observations.remove(key)
        }
        for key in native_ime_observation_keys() {
          if observations.get(key) == None {
            observations[key] = string_json("pending")
          }
        }
        let name = optional_string(entry, "name")
        if string_array_contains(native_skia_platforms(), name) {
          let skia = ensure_skia_evidence(entry, name)
          let skia_observations = ensure_object_field(skia, "observations")
          for key in legacy_skia_observation_keys() {
            skia_observations.remove(key)
          }
          for key in skia_observation_keys() {
            if skia_observations.get(key) == None {
              skia_observations[key] = string_json("pending")
            }
          }
        }
      }
      _ => ()
    }
  }
  Ok(())
}

///|
fn find_platform_entry(
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
fn json_string_array_to_strings(value : Json?) -> Array[String] {
  match value {
    Some(Json::Array(values)) => {
      let strings : Array[String] = []
      for item in values {
        match item {
          Json::String(text) => strings.push(text)
          _ => ()
        }
      }
      strings
    }
    _ => []
  }
}

///|
fn apply_updates(
  options : CliOptions,
  manifest : Map[String, Json],
) -> Result[Unit, String] {
  let entry = match find_platform_entry(manifest, options.platform) {
    Some(value) => value
    None =>
      return Err(
        options.manifest_path +
        ": platforms must include '" +
        options.platform +
        "'",
      )
  }
  if options.status_set {
    entry["status"] = string_json(options.status)
  }
  if options.host_set {
    entry["host"] = string_json(options.host)
  }
  if options.window_evidence_command_set {
    entry["windowEvidenceCommand"] = string_json(
      options.window_evidence_command,
    )
  }
  if options.consumer_command_set {
    entry["consumerCommand"] = string_json(options.consumer_command)
  }
  match build_provenance(options.provenance) {
    Some(value) => entry["evidenceProvenance"] = value
    None => ()
  }
  ignore(ensure_object_field(entry, "observations"))
  if options.web_presentation_manifest_set {
    match
      apply_web_presentation_evidence(
        entry,
        options.repo_root,
        options.web_presentation_manifest,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  let observations = ensure_object_field(entry, "observations")
  for item in options.observations {
    observations[item.0] = string_json(item.1)
  }
  if string_array_contains(native_skia_platforms(), options.platform) {
    let skia = ensure_skia_evidence(entry, options.platform)
    let skia_observations = ensure_object_field(skia, "observations")
    for key in legacy_skia_observation_keys() {
      skia_observations.remove(key)
    }
    for key in skia_observation_keys() {
      if skia_observations.get(key) == None {
        skia_observations[key] = string_json("pending")
      }
    }
    if options.skia_status_set {
      skia["status"] = string_json(options.skia_status)
    }
    if options.skia_boundary_set {
      skia["boundary"] = string_json(options.skia_boundary)
    }
    if !options.skia_provider_commands.is_empty() {
      skia["providerCommands"] = string_array_json(
        options.skia_provider_commands,
      )
    }
    if !options.skia_runtime_smoke_commands.is_empty() {
      skia["runtimeSmokeCommands"] = string_array_json(
        options.skia_runtime_smoke_commands,
      )
    }
    for item in options.skia_observations {
      skia_observations[item.0] = string_json(item.1)
    }
    if !options.skia_artifacts.is_empty() {
      skia["artifacts"] = string_array_json(options.skia_artifacts)
    }
    if !options.skia_notes.is_empty() {
      skia["notes"] = string_array_json(options.skia_notes)
    }
    match build_provenance(options.skia_provenance) {
      Some(value) => skia["evidenceProvenance"] = value
      None => ()
    }
  }
  if !options.artifacts.is_empty() {
    entry["artifacts"] = string_array_json(options.artifacts)
  }
  if !options.notes.is_empty() {
    if options.web_presentation_manifest_set {
      let merged = json_string_array_to_strings(entry.get("notes"))
      for note in options.notes {
        merged.push(note)
      }
      entry["notes"] = string_array_json(merged)
    } else {
      entry["notes"] = string_array_json(options.notes)
    }
  }
  Ok(())
}

///|
fn record_manifest(options : CliOptions) -> Result[Unit, String] {
  match validate_options(options) {
    Ok(_) => ()
    Err(message) => return Err(message)
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
  match migrate_manifest(manifest) {
    Ok(_) => ()
    Err(message) => return Err(options.manifest_path + ": " + message)
  }
  match apply_updates(options, manifest) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let output_text = Json::object(manifest).stringify(indent=2) + "\n"
  match
    @tools.write_text_file(
      options.output_path,
      output_text,
      "updated platform evidence manifest",
    ) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
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
      match record_manifest(options) {
        Ok(_) => 0
        Err(message) => {
          println(message)
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
