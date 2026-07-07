///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_openseek_workbench [options]
    #|
    #|Checks the Mo Workbench OpenSeek local workspace requirements.
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
fn moon_work_lists_openseek(work : String) -> Bool {
  for line in work.split("\n") {
    if line.trim().to_owned() == "\"./openseek\"," {
      return true
    }
  }
  false
}

///|
fn validate_openseek_workbench_inputs(
  moon_work : String?,
  transport_pkg_exists : Bool,
  openseek_mod_exists : Bool,
) -> Array[String] {
  let errors : Array[String] = []
  if !transport_pkg_exists {
    errors.push(
      "missing examples/mo_workbench/openseek_native_transport/moon.pkg",
    )
  }
  if !openseek_mod_exists {
    errors.push(
      "openseek submodule not initialized (run: git submodule update --init --recursive openseek)",
    )
  }
  match moon_work {
    Some(work) =>
      if !moon_work_lists_openseek(work) {
        errors.push(
          "moon.work must list \"./openseek\" until bobzhang/openseek is published on mooncakes.io.\n" +
          "  Run: sh scripts/openseek-dev-mode.sh on",
        )
      }
    None => errors.push("moon.work is missing or could not be read")
  }
  errors
}

///|
fn validate_openseek_workbench(repo_root : String) -> Array[String] {
  let moon_work = match
    @tools.read_required_text(
      @tools.resolve_path(repo_root, "moon.work"),
      "moon.work",
    ) {
    Ok(value) => Some(value)
    Err(_) => None
  }
  validate_openseek_workbench_inputs(
    moon_work,
    @tools.file_exists(
      @tools.resolve_path(
        repo_root, "examples/mo_workbench/openseek_native_transport/moon.pkg",
      ),
    ),
    @tools.file_exists(@tools.resolve_path(repo_root, "openseek/moon.mod")),
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
      let errors = validate_openseek_workbench(options.repo_root)
      if errors.is_empty() {
        println("validate-openseek-workbench: ok")
        0
      } else {
        println("validate-openseek-workbench failed:\n")
        for error in errors {
          println("  - " + error)
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
