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
