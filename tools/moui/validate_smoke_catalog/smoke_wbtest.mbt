// White-box tests for the smoke catalog gate: suite-id rules, tier filtering,
// placeholder substitution, CLI parsing, and normalized check plans.

///|
fn arg_ok(result : Result[String, String]) -> String {
  match result {
    Ok(value) => value
    Err(_) => "<err>"
  }
}

///|
fn argv_ok(result : Result[Array[String], String]) -> Array[String] {
  match result {
    Ok(values) => values
    Err(_) => []
  }
}

///|
fn parsed_cli(args : Array[String]) -> CliOptions {
  match parse_cli(args) {
    Ok(options) => options
    Err(_) =>
      {
        repo_root: "<error>",
        manifest: "<error>",
        mode: "<error>",
        tier: None,
        gate_plan: false,
        gate_mode: "<error>",
        suites: [],
        platform: None,
        help: false,
      }
  }
}

///|
fn demo_catalog() -> Map[String, Json] {
  let command : Map[String, Json] = Map([
    (
      "argv",
      Json::array([Json::string("node"), Json::string("scripts/smoke.mjs")]),
    ),
  ])
  let suite : Map[String, Json] = Map([
    ("id", Json::string("web-runtime")),
    ("tier", Json::string("daily")),
    ("kind", Json::string("browser")),
    ("host", Json::string("linux")),
    ("commands", Json::array([Json::object(command)])),
  ])
  Map([
    ("schemaVersion", Json::number(1.0, repr="1")),
    ("tiers", Json::array([Json::string("daily"), Json::string("nightly")])),
    ("suites", Json::array([Json::object(suite)])),
  ])
}

///|
test "suite ids accept lowercase dotted/dashed identifiers only" {
  assert_true(valid_suite_id("pr"))
  assert_true(valid_suite_id("macos-skia"))
  assert_true(valid_suite_id("web.runtime-2"))
  assert_true(valid_suite_id("0smoke"))
  assert_true(!valid_suite_id("x"))
  assert_true(!valid_suite_id(""))
  assert_true(!valid_suite_id("Macos"))
  assert_true(!valid_suite_id("-lead"))
  assert_true(!valid_suite_id("has space"))
  assert_true(looks_like_repo_path("scripts/check.sh"))
  assert_true(looks_like_repo_path(".github/workflows/pr.yml"))
  assert_true(!looks_like_repo_path("moui/core"))
  assert_true(!looks_like_repo_path("scripts"))
  assert_true(valid_platform("web"))
  assert_true(!valid_platform("android"))
}

///|
test "placeholder substitution requires a platform only for real runs" {
  assert_eq(arg_ok(substitute_arg("--check", "dry-run", None)), "--check")
  assert_eq(
    arg_ok(
      substitute_arg("--target <macos|web|windows|linux>", "dry-run", None),
    ),
    "--target <macos|web|windows|linux>",
  )
  match substitute_arg("--target <platform>", "run", None) {
    Err(message) =>
      assert_eq(
        message, "--platform is required for placeholder argument: --target <platform>",
      )
    Ok(_) => assert_true(false)
  }
  match substitute_arg("--target <platform>", "run", Some("plan9")) {
    Err(message) => assert_eq(message, "unknown platform: plan9")
    Ok(_) => assert_true(false)
  }
  assert_eq(
    arg_ok(
      substitute_arg("--target <macos|web|windows|linux>", "run", Some("web")),
    ),
    "--target web",
  )
  assert_eq(
    argv_ok(
      substitute_argv(
        ["--check", "--target", "<platform>"],
        "run",
        Some("windows"),
      ),
    ),
    ["--check", "--target", "windows"],
  )
}

///|
test "parse_cli captures modes, tiers, suites, and gate plan flags" {
  let defaults = parsed_cli([])
  assert_eq(defaults.manifest, "smoke/gates.json")
  assert_eq(defaults.mode, "check")
  assert_eq(defaults.gate_mode, "dry-run")
  assert_true(defaults.tier is None)
  assert_true(!defaults.gate_plan)
  assert_eq(defaults.suites.length(), 0)
  let full = parsed_cli([
    "--manifest", "smoke/other.json", "--json", "--tier", "nightly", "--suite", "a",
    "--suite", "b", "--gate-plan", "--run", "--platform", "linux",
  ])
  assert_eq(full.manifest, "smoke/other.json")
  assert_eq(full.mode, "json")
  assert_eq(full.tier, Some("nightly"))
  assert_eq(full.suites, ["a", "b"])
  assert_true(full.gate_plan)
  assert_eq(full.gate_mode, "run")
  assert_eq(full.platform, Some("linux"))
  let help = parsed_cli(["--help"])
  assert_true(help.help)
  match parse_cli(["--tier"]) {
    Err(message) => assert_eq(message, "missing value for --tier")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--suite"]) {
    Err(message) => assert_eq(message, "missing value for --suite")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--wat"]) {
    Err(message) => assert_eq(message, "unknown argument: --wat")
    Ok(_) => assert_true(false)
  }
}

///|
test "catalog plans filter by tier and render suite check lines" {
  let catalog = demo_catalog()
  assert_eq(catalog_tiers(catalog), ["daily", "nightly"])
  let suites = catalog_suites(catalog)
  assert_eq(suites.length(), 1)
  assert_true(suite_matches_tier(suites[0], Some("daily")))
  assert_true(!suite_matches_tier(suites[0], Some("nightly")))
  assert_true(suite_matches_tier(suites[0], None))
  let command : Map[String, Json] = Map([
    (
      "argv",
      Json::array([Json::string("node"), Json::string("scripts/smoke.mjs")]),
    ),
  ])
  assert_eq(command_string_for_check(command), "node scripts/smoke.mjs")
  assert_eq(smoke_check_list(normalized_check_plan(catalog, Some("daily"))), [
    "daily: web-runtime [browser] host=linux", "  node scripts/smoke.mjs",
  ])
  assert_eq(
    smoke_check_list(normalized_check_plan(catalog, Some("nightly"))).length(),
    0,
  )
  assert_eq(smoke_check_list(normalized_check_plan(catalog, None)).length(), 2)
}
