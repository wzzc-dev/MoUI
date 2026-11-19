// White-box tests for tools/moui/validate_check_profiles.
// They pin host/path predicates, JSON accessors, step and profile rules, and
// the whole-catalog schema checks.

///|
test "host and repo-path predicates are exact" {
  assert_true(valid_host("any"))
  assert_true(valid_host("darwin"))
  assert_true(valid_host("non-windows"))
  assert_false(valid_host("macos"))
  assert_false(valid_host(""))
  assert_true(looks_like_repo_path("scripts/check.sh"))
  assert_true(looks_like_repo_path("checks/profiles.json"))
  assert_true(looks_like_repo_path(".github/workflows/ci.yml"))
  assert_true(looks_like_repo_path("docs/testing.md"))
  assert_true(looks_like_repo_path("smoke/gates.json"))
  assert_false(looks_like_repo_path("moon test"))
  assert_false(looks_like_repo_path("artifacts/report.json"))
}

///|
test "old entrypoint tokens are detected" {
  assert_true(old_entrypoint_token("scripts/dev-check.sh --profile pr"))
  assert_true(old_entrypoint_token("dev_check.ps1"))
  assert_true(old_entrypoint_token("conformance-check.sh"))
  assert_false(old_entrypoint_token("scripts/check.sh --profile pr"))
}

///|
test "JSON accessors distinguish missing, blank, and present values" {
  assert_eq(json_non_empty_string(Some(Json::string("  "))), None)
  assert_eq(json_non_empty_string(Some(Json::string("value"))), Some("value"))
  assert_eq(json_non_empty_string(None), None)
  assert_eq(json_string(Some(Json::number(1.0, repr="1"))), None)
  assert_eq(json_array_field(None), [])
  assert_eq(json_object_field(Some(Json::array([]))), None)
  assert_true(json_number_is_one(Some(Json::number(1.0, repr="1"))))
  assert_false(json_number_is_one(Some(Json::number(2.0, repr="2"))))
  assert_false(json_number_is_one(None))
}

///|
test "validate_step checks name, host, argv, and deleted entrypoints" {
  let valid : Map[String, Json] = Map([])
  valid["name"] = Json::string("test")
  valid["host"] = Json::string("linux")
  valid["argv"] = Json::array([Json::string("moon"), Json::string("test")])
  let failures : Array[String] = []
  validate_step("", "pr", Json::object(valid), 0, failures)
  assert_eq(failures.length(), 0)
  let bad_host : Map[String, Json] = Map([])
  bad_host["name"] = Json::string("test")
  bad_host["host"] = Json::string("macos")
  bad_host["argv"] = Json::array([Json::string("moon")])
  let host_failures : Array[String] = []
  validate_step("", "pr", Json::object(bad_host), 0, host_failures)
  assert_eq(host_failures.length(), 1)
  assert_eq(
    host_failures[0],
    "pr.steps[0].host must be any, darwin, linux, windows, or non-windows",
  )
  let empty_argv : Map[String, Json] = Map([])
  empty_argv["name"] = Json::string("test")
  empty_argv["argv"] = Json::array([])
  let argv_failures : Array[String] = []
  validate_step("", "pr", Json::object(empty_argv), 0, argv_failures)
  assert_eq(argv_failures.length(), 1)
  assert_eq(
    argv_failures[0],
    "pr.steps[0].argv must be a non-empty string array",
  )
  let deleted : Map[String, Json] = Map([])
  deleted["name"] = Json::string("legacy")
  deleted["argv"] = Json::array([Json::string("scripts/dev-check.sh")])
  let deleted_failures : Array[String] = []
  validate_step("", "pr", Json::object(deleted), 2, deleted_failures)
  assert_true(
    deleted_failures.any(message => {
      message ==
      "pr.steps[2].argv references deleted entrypoint: scripts/dev-check.sh"
    }),
  )
}

///|
test "validate_profile requires a description and a real step source" {
  let profiles : Map[String, Json] = Map([])
  let empty_profile : Map[String, Json] = Map([])
  let failures : Array[String] = []
  validate_profile("", profiles, "pr", Json::object(empty_profile), failures)
  assert_true(failures.any(message => message == "pr.description is required"))
  assert_true(
    failures.any(message => {
      message ==
      "pr.steps must be non-empty unless includes delegates every step"
    }),
  )
  let includes : Map[String, Json] = Map([])
  includes["description"] = Json::string("composite")
  includes["includes"] = Json::array([
    Json::string("daily"),
    Json::string("nope"),
  ])
  let include_failures : Array[String] = []
  validate_profile(
    "",
    profiles,
    "daily",
    Json::object(includes),
    include_failures,
  )
  assert_true(
    include_failures.any(message => {
      message == "daily.includes cannot include itself"
    }),
  )
  assert_true(
    include_failures.any(message => {
      message == "daily.includes references unknown profile: nope"
    }),
  )
  let known_profiles : Map[String, Json] = Map([])
  known_profiles["pr"] = Json::object(Map([]))
  let ok_includes : Map[String, Json] = Map([])
  ok_includes["description"] = Json::string("composite")
  ok_includes["includes"] = Json::array([Json::string("pr")])
  let ok_failures : Array[String] = []
  validate_profile(
    "",
    known_profiles,
    "daily",
    Json::object(ok_includes),
    ok_failures,
  )
  assert_eq(ok_failures.length(), 0)
}

///|
test "validate_catalog_text requires the five standard profiles" {
  match validate_catalog_text("", "{}") {
    Ok(_) => fail("empty catalog must be rejected")
    Err(failures) => {
      assert_eq(failures.length(), 8)
      assert_true(failures.any(message => message == "schemaVersion must be 1"))
      assert_true(failures.any(message => message == "description is required"))
      assert_true(
        failures.any(message => message == "profiles must be an object"),
      )
      assert_true(
        failures.any(message => message == "profiles must include pr"),
      )
      assert_true(
        failures.any(message => message == "profiles must include full"),
      )
    }
  }
  let valid =
    #|{"schemaVersion":1,"description":"catalog","profiles":{
    #|"pr":{"description":"p","steps":[{"name":"test","host":"any","argv":["moon","test"]}]},
    #|"daily":{"description":"d","includes":["pr"]},
    #|"platform":{"description":"p","includes":["pr"]},
    #|"theme":{"description":"t","includes":["pr"]},
    #|"full":{"description":"f","includes":["daily","platform","theme"]}}}
  match validate_catalog_text("", valid) {
    Ok(catalog) => {
      assert_eq(catalog.length(), 3)
      match json_object_field(catalog.get("profiles")) {
        Some(profiles) => assert_eq(profiles.length(), 5)
        None => fail("profiles must be an object")
      }
    }
    Err(failures) => fail(failures.join("; "))
  }
  let self_include =
    #|{"schemaVersion":1,"description":"catalog","profiles":{
    #|"pr":{"description":"p","includes":["pr"]},
    #|"daily":{"description":"d","includes":["pr"]},
    #|"platform":{"description":"p","includes":["pr"]},
    #|"theme":{"description":"t","includes":["pr"]},
    #|"full":{"description":"f","includes":["pr"]}}}
  match validate_catalog_text("", self_include) {
    Ok(_) => fail("self include must be rejected")
    Err(failures) =>
      assert_true(
        failures.any(message => message == "pr.includes cannot include itself"),
      )
  }
}
