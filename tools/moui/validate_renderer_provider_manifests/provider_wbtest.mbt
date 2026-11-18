// White-box tests for the renderer provider manifest gate: rule table shape
// and forbidden-token scan messages.

///|
fn parsed_cli(args : Array[String]) -> CliOptions {
  match parse_cli(args) {
    Ok(options) => options
    Err(_) => { repo_root: "<error>", help: false, }
  }
}

///|
test "provider rules cover every platform backend and renderer package" {
  let rules = provider_rules()
  assert_eq(rules.length(), 13)
  assert_eq(rules[0].path, "moui/backend/macos/moon.pkg")
  assert_eq(rules[7].path, "moui/backend/wechat/moon.pkg")
  assert_true(rules[0].forbidden.contains("wzzc-dev/moui_skia_renderer"))
  let paths = rules.map(rule => rule.path)
  assert_true(paths.contains("moui_skia_renderer/moon.pkg"))
  assert_true(paths.contains("moui_wgpu_renderer/moon.pkg"))
  assert_true(paths.contains("moui_web_renderer/canvas2d/moon.pkg"))
  assert_true(paths.contains("moui_web_renderer/moon.pkg"))
  // Backend packages must never depend on a concrete renderer.
  for
    renderer in [
      "wzzc-dev/moui_sun_renderer", "wzzc-dev/moui_metal_renderer", "wzzc-dev/moui_web_renderer",
    ] {
    assert_true(rules[3].forbidden.contains(renderer))
  }
}

///|
test "validate_provider_text reports one message per forbidden token" {
  let forbidden = ["wzzc-dev/moui_skia", "wzzc-dev/moui_sun"]
  assert_eq(
    validate_provider_text(
      "pkg/moon.pkg", "import { \"moui/core\" }", forbidden,
    ).length(),
    0,
  )
  let failures = validate_provider_text(
    "pkg/moon.pkg", "import { \"wzzc-dev/moui_skia\" }", forbidden,
  )
  assert_eq(failures.length(), 1)
  assert_eq(
    failures[0],
    "pkg/moon.pkg: forbidden import/dependency token 'wzzc-dev/moui_skia'",
  )
  let both = validate_provider_text(
    "pkg/moon.pkg", "import { \"wzzc-dev/moui_skia\" \"wzzc-dev/moui_sun\" }", forbidden,
  )
  assert_eq(both.length(), 2)
  assert_true(
    both[1].contains("forbidden import/dependency token 'wzzc-dev/moui_sun'"),
  )
}

///|
test "parse_cli resolves repo root and help" {
  assert_eq(parsed_cli(["--repo-root", "/repo"]).repo_root, "/repo")
  let help = parsed_cli(["--help"])
  assert_true(help.help)
  assert_eq(help.repo_root, parsed_cli(["-h"]).repo_root)
  match parse_cli(["--repo-root"]) {
    Err(message) => assert_eq(message, "missing value for --repo-root")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["stray"]) {
    Err(message) => assert_eq(message, "unknown argument: stray")
    Ok(_) => assert_true(false)
  }
}
