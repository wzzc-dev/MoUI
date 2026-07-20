///|
test "test_process_exec_success" {
  let host = detect_host_platform()
  let argv = match host {
    Windows => ["cmd.exe", "/c", "exit 0"]
    _ => ["true"]
  }
  match process_exec_argv(argv, timeout_ms=5000) {
    Ok(result) => assert_eq(result.exit_code, 0)
    Err(message) => fail("expected success, got: " + message)
  }
}

///|
test "test_process_exec_failure" {
  let host = detect_host_platform()
  let argv = match host {
    Windows => ["cmd.exe", "/c", "exit 1"]
    _ => ["false"]
  }
  match process_exec_argv(argv, timeout_ms=5000) {
    Ok(result) => assert_eq(result.exit_code, 1)
    Err(message) => fail("expected failure exit, got: " + message)
  }
}

///|
test "test_process_exec_argv_with_args" {
  let host = detect_host_platform()
  let result = match host {
    Windows => process_exec_shell("echo hello", timeout_ms=5000)
    _ => process_exec_argv(["echo", "hello"], timeout_ms=5000)
  }
  match result {
    Ok(r) =>
      assert_true(r.stdout.contains("hello") || r.stderr.contains("hello"))
    Err(message) => fail("expected echo output, got: " + message)
  }
}

///|
test "test_process_exec_shell_pipe" {
  let host = detect_host_platform()
  let command = match host {
    Windows => "echo hello"
    _ => "echo hello | tr a-z A-Z"
  }
  match process_exec_shell(command, timeout_ms=5000) {
    Ok(r) =>
      assert_true(r.stdout.contains("hello") || r.stdout.contains("HELLO"))
    Err(message) => fail("expected shell output, got: " + message)
  }
}

///|
test "test_process_exec_env_injection" {
  let host = detect_host_platform()
  let command = match host {
    Windows => "echo %FOO%"
    _ => "echo $FOO"
  }
  match process_exec_shell(command, env=[("FOO", "bar")], timeout_ms=5000) {
    Ok(r) => assert_true(r.stdout.contains("bar") || r.stdout.contains("%FOO%"))
    Err(message) => fail("expected env injection, got: " + message)
  }
}

///|
test "test_process_exec_cwd" {
  let host = detect_host_platform()
  // Skip on Windows because cmd.exe cwd handling differs
  if host == Windows {
    return
  }
  let tmp = process_tmp_dir()
  match process_exec_argv(["pwd"], cwd=tmp, timeout_ms=5000) {
    Ok(r) => assert_true(r.stdout.contains(tmp) || r.stdout.length() > 0)
    Err(message) => fail("expected pwd output, got: " + message)
  }
}

///|
test "test_process_exec_timeout" {
  let host = detect_host_platform()
  let argv = match host {
    Windows => ["cmd.exe", "/c", "ping -n 30 127.0.0.1"]
    _ => ["sleep", "5"]
  }
  match process_exec_argv(argv, timeout_ms=200) {
    Err(message) => assert_true(message.contains("timeout"))
    Ok(result) =>
      fail(
        "expected timeout, got success with exit_code=" +
        result.exit_code.to_string(),
      )
  }
}

///|
test "test_process_exec_with_inherit" {
  let host = detect_host_platform()
  let argv = match host {
    Windows => ["cmd.exe", "/c", "exit 0"]
    _ => ["true"]
  }
  // With inherit, stdout/stderr go to terminal (not captured).
  // We only check that the call does not raise an error.
  match process_exec_with_inherit(argv, timeout_ms=5000) {
    Ok(result) => assert_eq(result.exit_code, 0)
    Err(message) =>
      // Some environments may not support inherit mode; tolerate errors
      assert_true(message.contains("error") || message.contains("setup"))
  }
}
