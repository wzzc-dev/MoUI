// White-box tests for window dependency discovery: version extraction,
// de-duplication, and print-mode CLI parsing.

///|
test "extract_window_versions finds every wzzc-dev/window pin" {
  let text =
    #|deps = [
    #|  "wzzc-dev/window@0.4.1",
    #|  "wzzc-dev/other@1.0.0",
    #|  "wzzc-dev/window@0.4.2",
    #|]
  assert_eq(extract_window_versions(text), ["0.4.1", "0.4.2"])
  assert_eq(extract_window_versions("no dependency here"), [])
  // An unterminated pin is dropped rather than looping forever.
  assert_eq(extract_window_versions("\"wzzc-dev/window@0.5.0"), [])
}

///|
test "unique_strings preserves first-seen order" {
  assert_eq(unique_strings(["b", "a", "b", "c", "a"]), ["b", "a", "c"])
  assert_eq(unique_strings([]), [])
  assert_eq(unique_strings(["only"]), ["only"])
}

///|
test "parse_cli selects the print mode and path overrides" {
  match parse_cli(["--print-version", "--repo-root", "/repo"]) {
    Ok((mode, repo_root, _home)) => {
      assert_eq(mode, "version")
      assert_eq(repo_root, "/repo")
    }
    Err(_) => assert_true(false)
  }
  match parse_cli(["--print-package"]) {
    Ok((mode, _, _home)) => assert_eq(mode, "package")
    Err(_) => assert_true(false)
  }
  match parse_cli(["--print-cache-zip", "--home", "/tmp/home"]) {
    Ok((mode, _, home)) => {
      assert_eq(mode, "cache-zip")
      assert_eq(home, "/tmp/home")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse_cli rejects a missing mode and malformed arguments" {
  match parse_cli([]) {
    Err(message) => assert_eq(message, "missing print mode")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--help"]) {
    Err(message) => assert_eq(message, "help")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--print-version", "--repo-root"]) {
    Err(message) => assert_eq(message, "missing value for --repo-root")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--print-version", "--home"]) {
    Err(message) => assert_eq(message, "missing value for --home")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--wat"]) {
    Err(message) => assert_eq(message, "Unknown argument: --wat")
    Ok(_) => assert_true(false)
  }
}
