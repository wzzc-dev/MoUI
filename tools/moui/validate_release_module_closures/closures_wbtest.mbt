// White-box tests for the release-module closure gate: catalog parsing,
// duplicate detection, manifest scanning, and stage ordering.

///|
fn catalog_error(text : String) -> String {
  match parse_catalog(text) {
    Err(failures) => failures[0]
    Ok(_) => "<ok>"
  }
}

///|
fn catalog_error_count(text : String) -> Int32 {
  match parse_catalog(text) {
    Err(failures) => failures.length()
    Ok(_) => 0
  }
}

///|
fn parsed_cli(args : Array[String]) -> CliOptions {
  match parse_cli(args) {
    Ok(options) => options
    Err(_) => { repo_root: "<error>", help: false, }
  }
}

///|
test "duplicate_values reports repeated names once, preserving order" {
  assert_eq(duplicate_values(["a", "b", "a", "a", "b", "c"]), ["a", "b"])
  assert_eq(duplicate_values(["a", "b", "c"]), [])
  assert_eq(duplicate_values([]), [])
}

///|
test "module manifests resolve name, version, and @-aliased imports" {
  let text =
    #|name = "wzzc-dev/moui"
    #|version = "0.1.0"
    #|import {
    #|  "wzzc-dev/moui/core@core"
    #|  "wzzc-dev/moui_skia_renderer@skia"
    #|}
    #|  "unrelated" @outside
  let manifest = parse_module_manifest(text)
  assert_eq(manifest.name, "wzzc-dev/moui")
  assert_eq(manifest.version, "0.1.0")
  assert_eq(manifest.imports, [
    ("wzzc-dev/moui/core", "core"),
    ("wzzc-dev/moui_skia_renderer", "skia"),
  ])
  // Imports outside the `import { }` block are ignored.
  assert_eq(manifest.imports.length(), 2)
  match first_quoted("no quoted value") {
    None => assert_true(true)
    Some(_) => assert_true(false)
  }
}

///|
test "parse_catalog reports structural and per-module diagnostics" {
  assert_eq(catalog_error("{"), "checks/release-modules.json: invalid JSON")
  assert_eq(
    catalog_error("[]"),
    "checks/release-modules.json must be an object",
  )
  assert_eq(catalog_error_count("{}"), 3)
  assert_eq(
    catalog_error("{}"),
    "checks/release-modules.json.schemaVersion must be 1",
  )
  let valid = "{\"schemaVersion\":1,\"releaseStages\":[\"r1\",\"r2\"],\"modules\":[{\"name\":\"wzzc-dev/moui\",\"directory\":\"moui\",\"publication\":\"public\",\"role\":\"runtime\",\"releaseStage\":\"r2\"}]}"
  match parse_catalog(valid) {
    Ok(catalog) => {
      assert_eq(catalog.release_stages, ["r1", "r2"])
      assert_eq(release_stage_index(catalog, "r2"), 1)
      assert_eq(release_stage_index(catalog, "missing"), -1)
      assert_true(catalog_module(catalog, "wzzc-dev/moui") is Some(_))
      assert_true(catalog_module(catalog, "missing") is None)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse_cli and base closure tokens stay stable" {
  assert_eq(parsed_cli(["--repo-root", "/repo"]).repo_root, "/repo")
  assert_true(parsed_cli(["--help"]).help)
  let tokens = base_forbidden_tokens()
  assert_eq(tokens.length(), 12)
  assert_true(tokens.contains("wzzc-dev/moui_skia_renderer"))
  match parse_cli(["--wat"]) {
    Err(message) => assert_eq(message, "unknown argument: --wat")
    Ok(_) => assert_true(false)
  }
}
