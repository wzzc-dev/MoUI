///|
test "parse_cli accepts --repo-root" {
  match parse_cli(["--repo-root", "/tmp/repo"]) {
    Ok(options) => assert_eq(options.repo_root, "/tmp/repo")
    Err(message) => fail(message)
  }
}

///|
test "parse_cli rejects a missing path value" {
  match parse_cli(["--repo-root"]) {
    Err(message) => assert_eq(message, "missing value for --repo-root")
    Ok(_) => fail("missing value must be rejected")
  }
}

///|
test "json_int_field reads numbers and rejects other types" {
  let fields : Map[String, Json] = Map([])
  fields["n"] = Json::number(3.0, repr="3")
  fields["s"] = Json::string("x")
  assert_eq(json_int_field(fields, "n", 0), Ok(3))
  assert_eq(json_int_field(fields, "missing", 7), Ok(7))
  match json_int_field(fields, "s", 0) {
    Err(message) => assert_eq(message, "s must be a number")
    Ok(_) => fail("string must not be read as a number")
  }
}

///|
test "json_string_field reads strings with fallback" {
  let fields : Map[String, Json] = Map([])
  fields["root"] = Json::string("tools/moui")
  fields["n"] = Json::number(1.0, repr="1")
  assert_eq(json_string_field(fields, "root", "x"), Ok("tools/moui"))
  assert_eq(json_string_field(fields, "missing", "x"), Ok("x"))
  match json_string_field(fields, "n", "x") {
    Err(message) => assert_eq(message, "n must be a string")
    Ok(_) => fail("number must not be read as a string")
  }
}
