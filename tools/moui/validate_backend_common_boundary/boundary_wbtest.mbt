// White-box tests for tools/moui/validate_backend_common_boundary.
// They pin default-import detection, ownership config parsing, and JSON field
// error reporting.

///|
test "has_default_import only accepts non-test import blocks" {
  let text =
    #|import {
    #|  "wzzc-dev/moui/backend/common"
    #|}
  assert_true(has_default_import(text, "wzzc-dev/moui/backend/common"))
  assert_false(has_default_import(text, "wzzc-dev/moui/backend/common/extra"))
  let test_only =
    #|import {
    #|  "wzzc-dev/moui/backend/common",
    #|} for "test"
  assert_false(has_default_import(test_only, "wzzc-dev/moui/backend/common"))
  let wbtest_only =
    #|import {
    #|  "wzzc-dev/moui/backend/common",
    #|} for "wbtest"
  assert_false(has_default_import(wbtest_only, "wzzc-dev/moui/backend/common"))
  assert_false(
    has_default_import(
      "// \"wzzc-dev/moui/backend/common\"", "wzzc-dev/moui/backend/common",
    ),
  )
}

///|
test "json_string_array reports missing arrays and invalid items" {
  let failures : Array[String] = []
  let fields : Map[String, Json] = Map([])
  assert_eq(
    json_string_array(fields, "requiredSources", "rules[0]", true, failures),
    [],
  )
  assert_eq(failures.length(), 1)
  assert_eq(failures[0], "rules[0].requiredSources must be an array")
  let optional_failures : Array[String] = []
  assert_eq(
    json_string_array(
      fields, "forbiddenImports", "rules[0]", false, optional_failures,
    ),
    [],
  )
  assert_eq(optional_failures.length(), 0)
  let mixed : Map[String, Json] = Map([])
  mixed["requiredImports"] = Json::array([Json::string("a"), Json::string("  ")])
  let item_failures : Array[String] = []
  let values = json_string_array(
    mixed, "requiredImports", "rules[0]", true, item_failures,
  )
  assert_eq(values, ["a"])
  assert_eq(item_failures.length(), 1)
  assert_eq(
    item_failures[0],
    "rules[0].requiredImports[1] must be a non-empty string",
  )
}

///|
test "json_required_string reports blank or missing strings" {
  let fields : Map[String, Json] = Map([])
  let failures : Array[String] = []
  assert_eq(json_required_string(fields, "path", "rules[0]", failures), "")
  assert_eq(failures[0], "rules[0].path must be a non-empty string")
  let blank : Map[String, Json] = Map([])
  blank["name"] = Json::string("   ")
  let blank_failures : Array[String] = []
  assert_eq(
    json_required_string(blank, "name", "rendererModules[0]", blank_failures),
    "",
  )
  assert_eq(
    blank_failures[0],
    "rendererModules[0].name must be a non-empty string",
  )
}

///|
test "parse_ownership_config requires the full schema" {
  match parse_ownership_config("{") {
    Ok(_) => fail("invalid JSON must be rejected")
    Err(failures) =>
      assert_eq(failures, ["checks/backend-common-ownership.json: invalid JSON"])
  }
  match parse_ownership_config("[]") {
    Ok(_) => fail("array root must be rejected")
    Err(failures) =>
      assert_eq(failures, [
        "checks/backend-common-ownership.json must be an object",
      ])
  }
  match parse_ownership_config("{}") {
    Ok(_) => fail("missing schema fields must be rejected")
    Err(failures) => {
      assert_true(
        failures.any(message => {
          message ==
          "checks/backend-common-ownership.json.schemaVersion must be 1"
        }),
      )
      assert_true(
        failures.any(message => {
          message ==
          "checks/backend-common-ownership.json.packageRules must be an array"
        }),
      )
      assert_true(
        failures.any(message => {
          message ==
          "checks/backend-common-ownership.json.rendererModules must be an array"
        }),
      )
      assert_true(
        failures.any(message => {
          message ==
          "checks/backend-common-ownership.json.forbiddenPackageManifests must be an array"
        }),
      )
    }
  }
  let valid =
    #|{"schemaVersion":1,"packageRules":[],"rendererModules":[],
    #|"forbiddenPackageManifests":[],"legacySymbols":[],"sourceRoots":[],
    #|"rootRenderForbiddenTokens":[]}
  match parse_ownership_config(valid) {
    Ok(config) => {
      assert_eq(config.package_rules.length(), 0)
      assert_eq(config.renderer_modules.length(), 0)
      assert_eq(config.legacy_symbols.length(), 0)
    }
    Err(failures) => fail(failures.join("; "))
  }
}

///|
test "parse_ownership_config parses package and renderer rules" {
  let text =
    #|{"schemaVersion":1,
    #|"packageRules":[{"path":"moui/backend/common","requiredImports":["wzzc-dev/moui/core"],"forbiddenImports":["wzzc-dev/moui/backend"]}],
    #|"rendererModules":[{"name":"moui_skia","path":"moui_skia"}],
    #|"forbiddenPackageManifests":["moui/backend/old"],"legacySymbols":["Legacy"],
    #|"sourceRoots":["moui/backend"],"rootRenderForbiddenTokens":["Skia"]}
  match parse_ownership_config(text) {
    Ok(config) => {
      assert_eq(config.package_rules.length(), 1)
      assert_eq(config.package_rules[0].path, "moui/backend/common")
      assert_eq(config.package_rules[0].required_imports, ["wzzc-dev/moui/core"])
      assert_eq(config.package_rules[0].forbidden_imports, [
        "wzzc-dev/moui/backend",
      ])
      assert_eq(config.renderer_modules.length(), 1)
      assert_eq(config.renderer_modules[0].name, "moui_skia")
      assert_eq(config.root_render_forbidden_tokens, ["Skia"])
    }
    Err(failures) => fail(failures.join("; "))
  }
}

///|
test "parse_cli accepts the repo root and rejects unknown options" {
  match parse_cli(["--repo-root", "/repo"]) {
    Ok(options) => {
      assert_eq(options.repo_root, "/repo")
      assert_false(options.help)
    }
    Err(message) => fail(message)
  }
  match parse_cli(["--help"]) {
    Ok(options) => assert_true(options.help)
    Err(message) => fail(message)
  }
  match parse_cli(["--repo-root"]) {
    Err(message) => assert_eq(message, "missing value for --repo-root")
    Ok(_) => fail("missing --repo-root value must be rejected")
  }
  match parse_cli(["--wat"]) {
    Err(message) => assert_eq(message, "unknown argument: --wat")
    Ok(_) => fail("unknown option must be rejected")
  }
}
