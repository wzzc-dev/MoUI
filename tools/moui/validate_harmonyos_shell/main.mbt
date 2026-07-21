///|
/// ADR 0015: HarmonyOS product path is window HostCmd, not moui_shell.
struct M5Finding {
  rule : String
  ok : Bool
  path : String
  hint : String
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_harmonyos_shell [--repo-root PATH] [--json]
    #|
    #|Validates HarmonyOS window-hosted path (ADR 0015 / invariants M5).
    #|
  )
}

///|
fn required_paths() -> Array[String] {
  [
    "window/harmonyos/native_harmonyos_host.c", "window/harmonyos/native_harmonyos_host.h",
    "window/harmonyos/template/entry/src/main/cpp/window_hosted_napi.cpp", "moui/backend/harmonyos/window_hosted.mbt",
    "examples/counter/harmonyos_window_hosted/main.mbt", "scripts/build-window-hosted-harmonyos-hap.sh",
  ]
}

///|
fn forbidden_paths() -> Array[String] {
  ["moui_shell"]
}

///|
fn validate_repo(repo_root : String) -> Array[M5Finding] {
  let findings : Array[M5Finding] = []
  for path in required_paths() {
    let absolute = @tools.resolve_path(repo_root, path)
    if @tools.file_exists(absolute) || @tools.directory_exists(absolute) {
      findings.push({ rule: "M5", ok: true, path, hint: "" })
    } else {
      findings.push({
        rule: "M5",
        ok: false,
        path,
        hint: "missing window-hosted HarmonyOS artifact. Fix: restore window HostCmd path. See docs/invariants.md#M5 and ADR 0015",
      })
    }
  }
  for path in forbidden_paths() {
    let absolute = @tools.resolve_path(repo_root, path)
    if @tools.file_exists(absolute) || @tools.directory_exists(absolute) {
      findings.push({
        rule: "M5",
        ok: false,
        path,
        hint: "moui_shell must not remain in tree (ADR 0015).",
      })
    } else {
      findings.push({ rule: "M5", ok: true, path: path + " (absent)", hint: "" })
    }
  }
  let host_path = "window/harmonyos/native_harmonyos_host.c"
  match
    @tools.read_required_text(
      @tools.resolve_path(repo_root, host_path),
      host_path,
    ) {
    Ok(body) =>
      if body.contains("mbw_harmonyos_host_on_surface_init") &&
        body.contains("mbw_harmonyos_host_on_pointer") {
        findings.push({
          rule: "M5",
          ok: true,
          path: host_path + " HostCmd",
          hint: "",
        })
      } else {
        findings.push({
          rule: "M5",
          ok: false,
          path: host_path,
          hint: "HostCmd surface/pointer hooks missing. See window/docs/mobile-hosted-backend.md",
        })
      }
    Err(message) =>
      findings.push({ rule: "M5", ok: false, path: host_path, hint: message })
  }
  findings
}

///|
struct CliOptions {
  repo_root : String
  json : Bool
  help : Bool
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut repo_root = @env.current_dir().unwrap_or("")
  let mut json = false
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help = true
        index += 1
      }
      "--json" => {
        json = true
        index += 1
      }
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root = args[index + 1]
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  Ok({ repo_root, json, help })
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Err(message) => {
      println(message)
      println(usage())
      2
    }
    Ok(options) => {
      if options.help {
        println(usage())
        return 0
      }
      let results = validate_repo(options.repo_root)
      let failures = results.filter(item => !item.ok)
      if options.json {
        println("{\"ok\":" + failures.is_empty().to_string() + "}")
      } else if failures.is_empty() {
        println(
          "validate-harmonyos-shell: OK (window-hosted M5; ADR 0015; " +
          results.length().to_string() +
          " checks)",
        )
      } else {
        println("validate-harmonyos-shell: FAIL")
        for item in failures {
          println("")
          println("[" + item.rule + "] " + item.path)
          println("  " + item.hint)
        }
      }
      if failures.is_empty() {
        0
      } else {
        1
      }
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
