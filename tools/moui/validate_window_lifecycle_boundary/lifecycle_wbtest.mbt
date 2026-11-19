// White-box tests for the window lifecycle boundary gate's CLI contract.
// The repository checks themselves are filesystem-backed; these tests pin the
// argument parsing that decides which root is validated.

///|
test "parse_cli resolves the repository root and help flag" {
  match parse_cli(["--repo-root", "/repo"]) {
    Ok(options) => {
      assert_eq(options.repo_root, "/repo")
      assert_true(!options.help)
    }
    Err(_) => assert_true(false)
  }
  match parse_cli(["--help"]) {
    Ok(options) => assert_true(options.help)
    Err(_) => assert_true(false)
  }
  match parse_cli(["-h"]) {
    Ok(options) => assert_true(options.help)
    Err(_) => assert_true(false)
  }
}

///|
test "parse_cli rejects missing values and unknown flags" {
  match parse_cli(["--repo-root"]) {
    Err(message) => assert_eq(message, "missing value for --repo-root")
    Ok(_) => assert_true(false)
  }
  match parse_cli(["--wat"]) {
    Err(message) => assert_eq(message, "unknown argument: --wat")
    Ok(_) => assert_true(false)
  }
  // Trailing positional arguments are rejected, not silently ignored.
  match parse_cli(["extra"]) {
    Err(message) => assert_eq(message, "unknown argument: extra")
    Ok(_) => assert_true(false)
  }
}
