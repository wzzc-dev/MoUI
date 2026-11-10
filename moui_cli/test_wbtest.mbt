///|
test "test parser defaults to native and the app package" {
  let parsed = match parse_test_args([], "/tmp/project") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(parsed.target, content="native")
  inspect(parsed.package_path is None, content="true")
  inspect(parsed.project_root, content="/tmp/project")
}

///|
test "test parser accepts package, target, and project root" {
  let parsed = match
    parse_test_args(
      ["--package", "app", "--target", "wasm-gc", "--project-root", "proj"],
      "/tmp",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(parsed.package_path.unwrap(), content="app")
  inspect(parsed.target, content="wasm-gc")
  inspect(parsed.project_root, content="/tmp/proj")
}

///|
test "test parser rejects duplicate package paths" {
  let result = parse_test_args(["app", "--package", "other"], "/tmp")
  match result {
    Ok(_) => fail("expected duplicate package paths to be rejected")
    Err(message) => assert_true(message.contains("at most one package path"))
  }
}
