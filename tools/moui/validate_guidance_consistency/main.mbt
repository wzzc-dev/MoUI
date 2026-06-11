///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
struct TextRule {
  path : String
  token : String
}

///|
struct SymlinkRule {
  path : String
  target : String
}

///|
#borrow(path)
extern "C" fn readlink_bytes(path : Bytes, path_len : Int) -> Bytes = "moui_tools_guidance_readlink"

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_guidance_consistency [options]
    #|
    #|Checks that repository guidance, docs, skills, workflows, and validation
    #|scripts stay synchronized around the current MoUI development contracts.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root used to resolve paths. Defaults to cwd.
    #|  -h, --help         Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
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
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({ repo_root: repo_root.val, help: help.val })
}

///|
fn read_repo_text(repo_root : String, path : String) -> Result[String, String] {
  @tools.read_required_text(@tools.resolve_path(repo_root, path), path)
}

///|
fn include_failure(path : String, text : String, token : String) -> String? {
  if text.contains(token) {
    None
  } else {
    Some(path + ": expected to include '" + token + "'")
  }
}

///|
fn absent_failure(path : String, text : String, token : String) -> String? {
  if text.contains(token) {
    Some(path + ": stale guidance token '" + token + "'")
  } else {
    None
  }
}

///|
fn push_include_check(
  repo_root : String,
  path : String,
  token : String,
  failures : Array[String],
) -> Unit {
  match read_repo_text(repo_root, path) {
    Ok(text) =>
      match include_failure(path, text, token) {
        Some(message) => failures.push(message)
        None => ()
      }
    Err(message) => failures.push(message)
  }
}

///|
fn push_absent_check(
  repo_root : String,
  path : String,
  token : String,
  failures : Array[String],
) -> Unit {
  match read_repo_text(repo_root, path) {
    Ok(text) =>
      match absent_failure(path, text, token) {
        Some(message) => failures.push(message)
        None => ()
      }
    Err(message) => failures.push(message)
  }
}

///|
fn quoted_strings(text : String) -> Array[String] {
  let values : Array[String] = []
  let mut index = 0
  while index < text.length() {
    if text[index] == '"' {
      let builder = StringBuilder::new()
      index += 1
      while index < text.length() && text[index] != '"' {
        builder.write_char(Int::unsafe_to_char(text[index].to_int()))
        index += 1
      }
      if index < text.length() {
        values.push(builder.to_string())
      }
    }
    index += 1
  }
  values
}

///|
fn push_moon_work_member_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  match read_repo_text(repo_root, "moon.work") {
    Ok(text) =>
      for workspace_member in quoted_strings(text) {
        push_include_check(
          repo_root, "docs/development.md", workspace_member, failures,
        )
        if workspace_member.has_prefix("./examples/") {
          let package_name = workspace_member["./examples/".length():].to_owned()
          push_include_check(
            repo_root,
            "docs/examples.md",
            "examples/" + package_name + "/app/",
            failures,
          )
        }
      }
    Err(message) => failures.push(message)
  }
}

///|
fn daily_quality_gate_tokens() -> Array[String] {
  [
    "node scripts/validate-guidance-consistency.mjs", "node --check scripts/validate-api-surface.mjs",
    "node scripts/validate-api-surface.mjs", "node scripts/validate-renderer-provider-manifests.mjs",
    "node scripts/validate-skia-entrypoints.mjs", "node scripts/test-validate-skia-entrypoints.mjs",
    "node scripts/test-validate-renderer-proof-manifest.mjs", "node scripts/test-record-web-runtime-presentation.mjs",
    "node scripts/test-validate-web-runtime-presentation-manifest.mjs", "node --check scripts/validate-checked-conformance-artifacts.mjs",
    "node scripts/validate-conformance-capture-manifest.mjs artifacts/conformance/showcase-golden-capture.json",
    "node scripts/validate-conformance-capture-manifest.mjs artifacts/conformance/showcase-benchmark-capture.json",
    "node scripts/validate-web-runtime-handoff-manifest.mjs artifacts/conformance/web-runtime-handoff.json",
    "node scripts/validate-web-runtime-presentation-manifest.mjs artifacts/conformance/web-runtime-presentation.json",
    "node scripts/validate-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json",
    "node scripts/validate-renderer-proof-manifest.mjs artifacts/conformance/renderer-proof/webgpu-wasm-web.json",
    "node scripts/validate-renderer-proof-manifest.mjs artifacts/conformance/renderer-proof/skia-native-macos.json",
    "node scripts/validate-renderer-proof-manifest.mjs artifacts/conformance/renderer-proof/wgpu-native-macos.json",
    "node scripts/validate-checked-conformance-artifacts.mjs", "moon check",
    "moon test moui/core --target native", "moon test moui/views --target native",
    "moon test moui/render/skia --target native", "moon test moui/backend/host --target native",
    "moon test moui/backend/web --target wasm-gc", "moon test examples/showcase/app --target native",
    "moon test examples/markdown_editor/app --target native", "moon test examples/design_systems/app --target native",
    "moon build examples/showcase/web_wasm --target wasm-gc", "moon build examples/markdown_editor/web_wasm --target wasm-gc",
    "moon build examples/design_systems/web_wasm --target wasm-gc", "node scripts/validate-web-runtime-handoff.mjs",
  ]
}

///|
fn push_daily_quality_gate_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for token in daily_quality_gate_tokens() {
    push_include_check(repo_root, "scripts/dev-check.sh", token, failures)
    push_include_check(repo_root, "docs/testing.md", token, failures)
  }
}

///|
fn release_readiness_quality_tokens() -> Array[String] {
  [
    "node scripts/validate-api-surface.mjs",
    "checked conformance artifact guard",
    "dedicated checked-artifact validators",
    "examples/design_systems/app",
    "examples/design_systems/web_wasm",
  ]
}

///|
fn push_release_readiness_quality_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for token in release_readiness_quality_tokens() {
    push_include_check(repo_root, "docs/release-readiness.md", token, failures)
  }
}

///|
fn agent_quality_gate_tokens() -> Array[String] {
  [
    "node scripts/validate-api-surface.mjs",
    "node scripts/validate-checked-conformance-artifacts.mjs",
    "moon build examples/design_systems/web_wasm --target wasm-gc",
    "dedicated checked-artifact validators",
  ]
}

///|
fn push_agent_quality_gate_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for token in agent_quality_gate_tokens() {
    push_include_check(repo_root, "AGENTS.md", token, failures)
  }
}

///|
fn push_file_exists_check(
  repo_root : String,
  path : String,
  failures : Array[String],
) -> Unit {
  if !@tools.file_exists(@tools.resolve_path(repo_root, path)) {
    failures.push(path + ": expected file to exist")
  }
}

///|
fn push_no_workflow_files_check(
  repo_root : String,
  path : String,
  failures : Array[String],
) -> Unit {
  let absolute = @tools.resolve_path(repo_root, path)
  if !@tools.directory_exists(absolute) {
    return
  }
  let entries : Array[String] = []
  match @tools.file_names_with_suffix(absolute, ".yml") {
    Ok(values) =>
      for value in values {
        entries.push(value)
      }
    Err(message) => {
      failures.push(message)
      return
    }
  }
  match @tools.file_names_with_suffix(absolute, ".yaml") {
    Ok(values) =>
      for value in values {
        entries.push(value)
      }
    Err(message) => {
      failures.push(message)
      return
    }
  }
  entries.sort()
  if !entries.is_empty() {
    failures.push(
      path +
      ": workflow files must live in root .github/workflows: " +
      @tools.comma_join(entries),
    )
  }
}

///|
fn native_readlink(path : String) -> String? {
  let bytes = @utf8.encode(path, bom=false)
  let target = readlink_bytes(bytes, bytes.length())
  if target.length() == 0 {
    None
  } else {
    Some(@utf8.decode_lossy(target[:], ignore_bom=false))
  }
}

///|
fn push_symlink_target_check(
  repo_root : String,
  rule : SymlinkRule,
  failures : Array[String],
) -> Unit {
  let resolved = @tools.resolve_path(repo_root, rule.path)
  match native_readlink(resolved) {
    Some(actual) =>
      if actual != rule.target {
        failures.push(
          rule.path +
          ": expected symlink target '" +
          rule.target +
          "', got '" +
          actual +
          "'",
        )
      }
    None =>
      match read_repo_text(repo_root, rule.path) {
        Ok(text) =>
          if text.trim().to_owned() != rule.target {
            failures.push(
              rule.path + ": expected to be a symlink to " + rule.target,
            )
          }
        Err(message) => failures.push(message)
      }
  }
}

///|
fn validate_guidance_consistency(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  push_moon_work_member_checks(repo_root, failures)
  push_daily_quality_gate_checks(repo_root, failures)
  push_release_readiness_quality_checks(repo_root, failures)
  push_agent_quality_gate_checks(repo_root, failures)
  for rule in guidance_include_rules() {
    push_include_check(repo_root, rule.path, rule.token, failures)
  }
  for rule in guidance_absent_rules() {
    push_absent_check(repo_root, rule.path, rule.token, failures)
  }
  for path in guidance_file_exists_rules() {
    push_file_exists_check(repo_root, path, failures)
  }
  for path in guidance_no_workflow_file_rules() {
    push_no_workflow_files_check(repo_root, path, failures)
  }
  for rule in guidance_symlink_rules() {
    push_symlink_target_check(repo_root, rule, failures)
  }
  failures
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) => {
      let failures = validate_guidance_consistency(options.repo_root)
      if failures.is_empty() {
        println("guidance consistency guard: ok")
        0
      } else {
        for failure in failures {
          println(failure)
        }
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
