///|
struct CliOptions {
  repo_root : String
  help : Bool
}

///|
struct PackageBudget {
  label : String
  path : String
  package_token : String
  max_lines : Int
  max_pub_lines : Int
  max_pub_all_lines : Int
  required_tokens : Array[String]
  forbidden_tokens : Array[String]
}

///|
struct ViewReturnRule {
  name : String
  signature_prefix : String
  return_token : String
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_api_surface [--repo-root PATH]
    #|
    #|Audits generated pkg.generated.mbti files for MoUI API-surface guardrails:
    #|package size budgets, root facade boundaries, and app-facing view return
    #|types. Run moon info before this check when public API may have changed.
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
fn package_budgets() -> Array[PackageBudget] {
  [
    {
      label: "root facade",
      path: "moui/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui\"",
      max_lines: 120,
      max_pub_lines: 55,
      max_pub_all_lines: 0,
      required_tokens: [
        "\"wzzc-dev/moui/core\"", "pub using @core {type View}", "pub using @core {type Program}",
        "pub using @core {type Effect}", "pub using @core {type Subscription}", "pub using @core {type Theme}",
        "pub using @core {type AppRuntime}", "pub using @core {type Binding}",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui/backend", "\"wzzc-dev/moui/render", "moui_theme", "HostWindowRenderer",
        "RendererBackendKind", "SkiaRasterRenderer", "RuntimeState", "ViewNode",
        "ViewSpec",
      ],
    },
    {
      label: "core",
      path: "moui/core/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/core\"",
      max_lines: 2600,
      max_pub_lines: 700,
      max_pub_all_lines: 230,
      required_tokens: [
        "pub struct View[Msg]", "View::map", "pub(all) struct Theme", "pub(all) struct Program",
        "pub(all) struct Effect", "pub(all) struct Subscription", "pub(all) struct DrawFrame",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui_theme", "\"wzzc-dev/moui/render/skia\"", "SkiaRasterRenderer",
      ],
    },
    {
      label: "views facade",
      path: "moui/views/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/views\"",
      max_lines: 750,
      max_pub_lines: 240,
      max_pub_all_lines: 60,
      required_tokens: [
        "\"wzzc-dev/moui/core\"", "pub fn[Msg] button(", "pub fn[Msg] column(", "pub fn[Msg] markdown_editor(",
      ],
      forbidden_tokens: [
        "ViewSpec", "ViewNode", "RuntimeState", "HostWindowRenderer", "SkiaRasterRenderer",
      ],
    },
    {
      label: "host contracts",
      path: "moui/backend/host/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/backend/host\"",
      max_lines: 1100,
      max_pub_lines: 390,
      max_pub_all_lines: 100,
      required_tokens: [
        "HostWindowRenderer", "HostAsyncImageLoader", "HostRouteSource",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui/render/skia\"", "\"wzzc-dev/moui/render/wgpu\"", "SkiaRasterRenderer",
      ],
    },
    {
      label: "renderer facade",
      path: "moui/render/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/render\"",
      max_lines: 380,
      max_pub_lines: 80,
      max_pub_all_lines: 45,
      required_tokens: [
        "RendererBackendKind", "RendererDescriptor", "RenderFrameResult",
      ],
      forbidden_tokens: [
        "\"wzzc-dev/moui/backend/host\"", "HostWindowRenderer", "SkiaRasterRenderer",
      ],
    },
    {
      label: "skia renderer",
      path: "moui/render/skia/pkg.generated.mbti",
      package_token: "package \"wzzc-dev/moui/render/skia\"",
      max_lines: 220,
      max_pub_lines: 50,
      max_pub_all_lines: 8,
      required_tokens: [
        "SkiaRasterRenderer", "skia_available", "skia_image_load_completion",
      ],
      forbidden_tokens: ["\"wzzc-dev/moui/backend/host\"", "HostWindowRenderer"],
    },
  ]
}

///|
fn view_return_rules() -> Array[ViewReturnRule] {
  [
    {
      name: "button",
      signature_prefix: "pub fn[Msg] button(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "column",
      signature_prefix: "pub fn[Msg] column(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "row",
      signature_prefix: "pub fn[Msg] row(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "text",
      signature_prefix: "pub fn[Msg] text(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "text_field",
      signature_prefix: "pub fn[Msg] text_field(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "markdown_editor",
      signature_prefix: "pub fn[Msg] markdown_editor(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "navigation_stack",
      signature_prefix: "pub fn[Msg] navigation_stack(",
      return_token: "-> @core.View[Msg]",
    },
    {
      name: "web_view",
      signature_prefix: "pub fn[Msg] web_view(",
      return_token: "-> @core.View[Msg]",
    },
  ]
}

///|
fn line_count(text : String) -> Int {
  let mut count = 0
  for index in 0..<text.length() {
    if text[index] == '\n' {
      count += 1
    }
  }
  if text != "" && !text.has_suffix("\n") {
    count += 1
  }
  count
}

///|
fn count_lines_with_prefix(text : String, prefix : String) -> Int {
  let mut count = 0
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if line.has_prefix(prefix) {
      count += 1
    }
  }
  count
}

///|
fn read_repo_text(repo_root : String, path : String) -> Result[String, String] {
  @tools.read_required_text(@tools.resolve_path(repo_root, path), path)
}

///|
fn push_max_check(
  failures : Array[String],
  label : String,
  actual : Int,
  max : Int,
) -> Unit {
  if actual > max {
    failures.push(label + " is \{actual}, above budget \{max}")
  }
}

///|
fn push_required_token_checks(
  failures : Array[String],
  path : String,
  text : String,
  tokens : Array[String],
) -> Unit {
  for token in tokens {
    if !text.contains(token) {
      failures.push(path + ": expected token '" + token + "'")
    }
  }
}

///|
fn push_forbidden_token_checks(
  failures : Array[String],
  path : String,
  text : String,
  tokens : Array[String],
) -> Unit {
  for token in tokens {
    if text.contains(token) {
      failures.push(path + ": forbidden token '" + token + "'")
    }
  }
}

///|
fn validate_package_budget(
  repo_root : String,
  budget : PackageBudget,
  failures : Array[String],
) -> Unit {
  let text = match read_repo_text(repo_root, budget.path) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  let lines = line_count(text)
  let pub_lines = count_lines_with_prefix(text, "pub ")
  let pub_all_lines = count_lines_with_prefix(text, "pub(all)")
  println(
    "api surface: " +
    budget.label +
    " lines=\{lines} pub=\{pub_lines} pub(all)=\{pub_all_lines}",
  )
  if !text.has_prefix("// Generated using `moon info`, DON'T EDIT IT") {
    failures.push(budget.path + ": expected moon info generated header")
  }
  if !text.contains(budget.package_token) {
    failures.push(
      budget.path + ": expected package token " + budget.package_token,
    )
  }
  push_max_check(failures, budget.path + " line count", lines, budget.max_lines)
  push_max_check(
    failures,
    budget.path + " public declaration count",
    pub_lines,
    budget.max_pub_lines,
  )
  push_max_check(
    failures,
    budget.path + " pub(all) declaration count",
    pub_all_lines,
    budget.max_pub_all_lines,
  )
  push_required_token_checks(
    failures,
    budget.path,
    text,
    budget.required_tokens,
  )
  push_forbidden_token_checks(
    failures,
    budget.path,
    text,
    budget.forbidden_tokens,
  )
}

///|
fn matching_signature_line(text : String, prefix : String) -> String? {
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if line.has_prefix(prefix) {
      return Some(line)
    }
  }
  None
}

///|
fn validate_views_return_types(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let path = "moui/views/pkg.generated.mbti"
  let text = match read_repo_text(repo_root, path) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  for rule in view_return_rules() {
    match matching_signature_line(text, rule.signature_prefix) {
      Some(line) =>
        if !line.contains(rule.return_token) {
          failures.push(
            path + ": " + rule.name + " must return " + rule.return_token,
          )
        }
      None =>
        failures.push(
          path + ": missing app-facing constructor " + rule.signature_prefix,
        )
    }
  }
}

///|
fn validate_root_facade_shape(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let path = "moui/pkg.generated.mbti"
  let text = match read_repo_text(repo_root, path) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  if count_lines_with_prefix(text, "import {") != 1 {
    failures.push(path + ": root facade should keep a single import block")
  }
  if count_lines_with_prefix(text, "pub using @core {type ") < 30 {
    failures.push(
      path + ": root facade should continue re-exporting core app types",
    )
  }
}

///|
fn run_checks(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  for budget in package_budgets() {
    validate_package_budget(repo_root, budget, failures)
  }
  validate_root_facade_shape(repo_root, failures)
  validate_views_return_types(repo_root, failures)
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
      let failures = run_checks(options.repo_root)
      if failures.is_empty() {
        println("api surface guardrails: ok")
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
