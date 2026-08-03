///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
struct ProviderRule {
  path : String
  forbidden : Array[String]
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_renderer_provider_manifests [options]
    #|
    #|Checks platform host and renderer package manifests for forbidden
    #|cross-layer dependencies.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root used to resolve package paths. Defaults to cwd.
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
fn provider_rules() -> Array[ProviderRule] {
  let rules : Array[ProviderRule] = []
  for
    platform in [
      "macos", "windows", "linux", "android", "ios", "harmonyos", "web", "wechat",
    ] {
    rules.push({
      path: "moui/backend/" + platform + "/moon.pkg",
      forbidden: [
        "wzzc-dev/moui/render/skia", "wzzc-dev/moui/render/sun", "wzzc-dev/moui/render/wgpu",
        "wzzc-dev/moui/render/canvas2d", "wzzc-dev/moui/render/webgpu_adapter", "Milky2018/wgpu_mbt",
        "wzzc-dev/moui_skia", "wzzc-dev/moui_sun",
      ],
    })
  }
  let renderer_forbidden : Array[(String, Array[String])] = [
    (
      "skia",
      ["wzzc-dev/moui/backend/", "Milky2018/wgpu_mbt", "wzzc-dev/moui_sun"],
    ),
    (
      "sun",
      ["wzzc-dev/moui/backend/", "wzzc-dev/moui_skia", "Milky2018/wgpu_mbt"],
    ),
    (
      "wgpu",
      ["wzzc-dev/moui/backend/", "wzzc-dev/moui_skia", "wzzc-dev/moui_sun"],
    ),
    (
      "canvas2d",
      ["wzzc-dev/moui/backend/", "wzzc-dev/moui_skia", "Milky2018/wgpu_mbt"],
    ),
    (
      "webgpu_adapter",
      ["wzzc-dev/moui/backend/", "wzzc-dev/moui_skia", "Milky2018/wgpu_mbt"],
    ),
  ]
  for item in renderer_forbidden {
    let (renderer, forbidden) = item
    rules.push({ path: "moui/render/" + renderer + "/moon.pkg", forbidden })
  }
  rules
}

///|
fn validate_provider_text(
  path : String,
  text : String,
  forbidden : Array[String],
) -> Array[String] {
  let failures : Array[String] = []
  for token in forbidden {
    if text.contains(token) {
      failures.push(
        path + ": forbidden import/dependency token '" + token + "'",
      )
    }
  }
  failures
}

///|
fn validate_provider_rule(
  repo_root : String,
  rule : ProviderRule,
) -> Array[String] {
  let resolved_path = @tools.resolve_path(repo_root, rule.path)
  let text = match
    @tools.read_required_text(resolved_path, "provider package manifest") {
    Ok(value) => value
    Err(message) => return [message]
  }
  validate_provider_text(rule.path, text, rule.forbidden)
}

///|
fn validate_renderer_provider_manifests(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  for rule in provider_rules() {
    for failure in validate_provider_rule(repo_root, rule) {
      failures.push(failure)
    }
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
      let failures = validate_renderer_provider_manifests(options.repo_root)
      if failures.is_empty() {
        println("renderer provider manifest guard: ok")
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
