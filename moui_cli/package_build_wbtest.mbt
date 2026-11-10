///|
test "package parser defaults to release and accepts linux" {
  let parsed = match parse_package_build_args(["linux", "app"], ".") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(parsed.platform, content="linux")
  inspect(parsed.options.release, content="true")
  inspect(parsed.options.allow_cross, content="false")
  inspect(parsed.options.no_build, content="false")
}

///|
test "package parser honors debug, release, and allow-cross flags" {
  let debug = match parse_package_build_args(["macos", "app", "--debug"], ".") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(debug.options.release, content="false")
  let release = match
    parse_package_build_args(["macos", "app", "--debug", "--release"], ".") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(release.options.release, content="true")
  let cross = match
    parse_package_build_args(["linux", "app", "--allow-cross"], ".") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(cross.options.allow_cross, content="true")
}

///|
test "package parser still rejects mobile targets" {
  let result = parse_package_build_args(["android", "app"], ".")
  match result {
    Ok(_) => fail("mobile targets must be rejected by moui package")
    Err(message) =>
      assert_true(
        message.contains("mobile artifacts are produced by `moui build"),
      )
  }
}
