///|
fn smoke_fixture() -> String {
  let text =
    #|{
    #|  "schemaVersion": 1,
    #|  "description": "test catalog",
    #|  "tiers": ["daily", "nightly", "release"],
    #|  "suites": [
    #|    {
    #|      "id": "daily.dev-check",
    #|      "tier": "daily",
    #|      "kind": "package-baseline",
    #|      "host": "any",
    #|      "purpose": "test daily",
    #|      "defaultDevCheck": true,
    #|      "commands": [{ "argv": ["sh", "scripts/dev-check.sh"], "mode": "run" }],
    #|      "result": { "type": "exit-code" },
    #|      "ci": { "workflow": ".github/workflows/ci.yml", "gate": "pull_request" },
    #|      "docs": ["docs/testing.md"],
    #|      "artifacts": []
    #|    },
    #|    {
    #|      "id": "web.runtime-presentation",
    #|      "tier": "nightly",
    #|      "kind": "browser-runtime-smoke",
    #|      "host": "macos-14",
    #|      "purpose": "test nightly",
    #|      "defaultDevCheck": false,
    #|      "commands": [{ "argv": ["sh", "scripts/ci-web-runtime-presentation.sh"], "mode": "run" }],
    #|      "result": {
    #|        "type": "manifest",
    #|        "path": "artifacts/smoke/web-runtime-presentation/presentation-smoke.json",
    #|        "validator": [
    #|          "node",
    #|          "scripts/validate-web-runtime-presentation-manifest.mjs",
    #|          "artifacts/smoke/web-runtime-presentation/presentation-smoke.json"
    #|        ]
    #|      },
    #|      "ci": { "workflow": ".github/workflows/ci.yml", "gate": "nightly" },
    #|      "docs": ["docs/testing.md"],
    #|      "artifacts": ["artifacts/smoke/web-runtime-presentation/presentation-smoke.json"]
    #|    },
    #|    {
    #|      "id": "window-package.matching-host",
    #|      "tier": "release",
    #|      "kind": "dependency-matching-host-smoke",
    #|      "host": "matching-host",
    #|      "purpose": "test release",
    #|      "defaultDevCheck": false,
    #|      "commands": [
    #|        {
    #|          "argv": ["scripts/run-window-package-smoke.sh", "<macos|web|windows|linux>", "--run"],
    #|          "mode": "manual"
    #|        }
    #|      ],
    #|      "result": { "type": "exit-code" },
    #|      "ci": { "workflow": ".github/workflows/ci.yml", "gate": "release-manual" },
    #|      "docs": ["docs/release-readiness.md"],
    #|      "artifacts": ["artifacts/window-package-smoke/<platform>.log"]
    #|    }
    #|  ]
    #|}
  text
}

///|
fn test_repo_root() -> String {
  let cwd = @env.current_dir().unwrap_or(".")
  if @tools.file_exists(@tools.join_path(cwd, "scripts/dev-check.sh")) {
    cwd
  } else {
    @tools.resolve_path(cwd, "..")
  }
}

///|
fn parse_fixture() -> Map[String, Json] raise {
  match validate_catalog_text(test_repo_root(), smoke_fixture()) {
    Ok(catalog) => catalog
    Err(failures) => fail("fixture should be valid: " + failures.join(", "))
  }
}

///|
test "validates catalog and filters normalized JSON plans" {
  let catalog = parse_fixture()
  let plan = normalized_check_plan(catalog, Some("nightly"))
  let text = plan.stringify(indent=2)
  inspect(text.contains("\"tier\": \"nightly\""), content="true")
  inspect(text.contains("\"suiteCount\": 1"), content="true")
  inspect(text.contains("web.runtime-presentation"), content="true")
  inspect(text.contains("daily.dev-check"), content="false")
}

///|
test "reports catalog validation failures" {
  let bad = smoke_fixture().replace_all(
    old="\"schemaVersion\": 1",
    new="\"schemaVersion\": 2",
  )
  match validate_catalog_text(test_repo_root(), bad) {
    Ok(_) => fail("bad schema should fail")
    Err(failures) =>
      inspect(failures.contains("schemaVersion must be 1"), content="true")
  }
}

///|
test "builds smoke gate plan with platform substitution" {
  let catalog = parse_fixture()
  let options : CliOptions = {
    repo_root: ".",
    manifest: "smoke/gates.json",
    mode: "json",
    tier: None,
    gate_plan: true,
    gate_mode: "run",
    suites: ["window-package.matching-host"],
    platform: Some("linux"),
    help: false,
  }
  match gate_plan_json(catalog, options) {
    Ok(plan) => {
      let text = plan.stringify(indent=2)
      inspect(text.contains("\"mode\": \"run\""), content="true")
      inspect(text.contains("\"linux\""), content="true")
      inspect(text.contains("<platform>"), content="false")
    }
    Err(message) => fail(message)
  }
}

///|
test "requires platform for run plans with placeholders" {
  let catalog = parse_fixture()
  let options : CliOptions = {
    repo_root: ".",
    manifest: "smoke/gates.json",
    mode: "json",
    tier: None,
    gate_plan: true,
    gate_mode: "run",
    suites: ["window-package.matching-host"],
    platform: None,
    help: false,
  }
  match gate_plan_json(catalog, options) {
    Ok(_) => fail("run plan should require --platform")
    Err(message) =>
      inspect(
        message,
        content=(
          #|--platform is required for placeholder argument: <macos|web|windows|linux>
        ),
      )
  }
}

///|
test "dry-run list preserves placeholders and command quoting" {
  let catalog = parse_fixture()
  let options : CliOptions = {
    repo_root: ".",
    manifest: "smoke/gates.json",
    mode: "list",
    tier: None,
    gate_plan: true,
    gate_mode: "dry-run",
    suites: ["window-package.matching-host"],
    platform: None,
    help: false,
  }
  match gate_plan_json(catalog, options) {
    Ok(plan) => {
      let lines = gate_plan_list(plan)
      inspect(
        lines.join("\n").contains("<macos|web|windows|linux>"),
        content="true",
      )
    }
    Err(message) => fail(message)
  }
}
