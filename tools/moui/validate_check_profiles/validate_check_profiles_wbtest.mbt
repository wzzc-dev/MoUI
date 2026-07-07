///|
test "validates minimal check profile catalog" {
  let text =
    #|{
    #|  "schemaVersion": 1,
    #|  "description": "test",
    #|  "profiles": {
    #|    "pr": { "description": "pr", "steps": [{ "name": "one", "argv": ["node", "--version"] }] },
    #|    "daily": { "description": "daily", "includes": ["pr"], "steps": [{ "name": "two", "argv": ["moon", "check"] }] },
    #|    "platform": { "description": "platform", "steps": [{ "name": "three", "host": "linux", "argv": ["moon", "check"] }] },
    #|    "theme": { "description": "theme", "steps": [{ "name": "four", "argv": ["moon", "check"] }] },
    #|    "full": { "description": "full", "includes": ["daily", "platform", "theme"], "steps": [{ "name": "five", "argv": ["moon", "check"] }] }
    #|  }
    #|}
  let result = validate_catalog_text(@env.current_dir().unwrap_or("."), text)
  assert_true(result is Ok(_))
}

///|
test "rejects deleted entrypoint references" {
  let text =
    #|{
    #|  "schemaVersion": 1,
    #|  "description": "test",
    #|  "profiles": {
    #|    "pr": { "description": "pr", "steps": [{ "name": "bad", "argv": ["sh", "scripts/dev-check.sh"] }] },
    #|    "daily": { "description": "daily", "steps": [{ "name": "two", "argv": ["moon", "check"] }] },
    #|    "platform": { "description": "platform", "steps": [{ "name": "three", "argv": ["moon", "check"] }] },
    #|    "theme": { "description": "theme", "steps": [{ "name": "four", "argv": ["moon", "check"] }] },
    #|    "full": { "description": "full", "steps": [{ "name": "five", "argv": ["moon", "check"] }] }
    #|  }
    #|}
  match validate_catalog_text(@env.current_dir().unwrap_or("."), text) {
    Ok(_) => fail("expected deleted entrypoint failure")
    Err(failures) =>
      assert_true(
        failures.any(failure => failure.contains("deleted entrypoint")),
      )
  }
}
