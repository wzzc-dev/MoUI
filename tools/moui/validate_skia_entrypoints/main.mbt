///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_skia_entrypoints [root]
    #|
    #|Checks that native Skia renderer selection stays in render/skia.
    #|Composition roots are discovered and validated from
    #|checks/platform-matrix.json by validate-harness-invariants.
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(".")
  let help = Ref(false)
  let seen_root = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      value => {
        if value.has_prefix("-") {
          return Err("unknown argument: " + value)
        }
        if seen_root.val {
          return Err("unexpected argument: " + value)
        }
        repo_root.val = value
        seen_root.val = true
        index += 1
      }
    }
  }
  Ok({ repo_root: repo_root.val, help: help.val })
}

///|
fn require_token(
  text : String,
  token : String,
  path : String,
  failures : Array[String],
) -> Unit {
  if token != "" && !text.contains(token) {
    failures.push(path + ": missing '" + token + "'")
  }
}

///|
fn validate_renderer_policy(repo_root : String) -> Array[String] {
  let path = "moui/render/skia/binding_factory.mbt"
  let source = match
    @tools.read_required_text(
      @tools.resolve_path(repo_root, path),
      "Skia renderer factory",
    ) {
    Ok(value) => value
    Err(message) => return [message]
  }
  let failures : Array[String] = []
  for
    token in [
      "pub fn raster(", "pub fn gpu(", "pub fn from_env()", "MOUI_SKIA_RENDERER",
      "NativeRendererMode::parse", "[gpu(), raster()]",
    ] {
    require_token(source, token, path, failures)
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
      let failures = validate_renderer_policy(options.repo_root)
      if failures.is_empty() {
        println("native Skia renderer policy validation: ok")
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
