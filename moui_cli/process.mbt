///|
priv struct ProcessResult {
  exit_code : Int
  stdout : String
  stderr : String
}

///|
#borrow(argv, env, cwd, stdout_path, stderr_path, exit_code_buf)
extern "C" fn process_exec_native(
  argv : FixedArray[Bytes],
  argc : Int,
  env : FixedArray[Bytes],
  envc : Int,
  cwd : Bytes,
  stdout_path : Bytes,
  stderr_path : Bytes,
  timeout_ms : Int,
  exit_code_buf : Bytes,
) -> Int = "moui_cli_process_exec"

///|
fn read_int32_le_from_bytes(buf : Bytes, offset : Int) -> Int {
  let b0 = buf[offset].to_int()
  let b1 = buf[offset + 1].to_int()
  let b2 = buf[offset + 2].to_int()
  let b3 = buf[offset + 3].to_int()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
fn process_tmp_dir() -> String {
  @env.get_env_var("TMPDIR").unwrap_or_else(() => {
    @env.get_env_var("TEMP").unwrap_or_else(() => {
      @env.get_env_var("TMP").unwrap_or(".")
    })
  })
}

///|
fn process_capture_path(prefix : String) -> String {
  join_path(process_tmp_dir(), prefix + "-" + @env.now().to_string() + ".log")
}

///|
fn process_nul_terminated_or_empty(value : String) -> Bytes {
  if value == "" {
    b"\x00"
  } else {
    nul_terminated(value)
  }
}

///|
fn process_argv_to_bytes(argv : Array[String]) -> FixedArray[Bytes] {
  let result = FixedArray::make(argv.length(), b"")
  for index, item in argv {
    result[index] = nul_terminated(item)
  }
  result
}

///|
fn process_env_to_bytes(env : Array[(String, String)]) -> FixedArray[Bytes] {
  let result = FixedArray::make(env.length(), b"")
  for index, item in env {
    result[index] = nul_terminated(item.0 + "=" + item.1)
  }
  result
}

///|
fn process_exec_argv(
  argv : Array[String],
  cwd? : String = "",
  env? : Array[(String, String)] = [],
  timeout_ms? : Int = 0,
  capture? : Bool = true,
) -> Result[ProcessResult, String] {
  if argv.is_empty() {
    return Err("process_exec_argv: argv must not be empty")
  }
  let argv_bytes = process_argv_to_bytes(argv)
  let env_bytes = process_env_to_bytes(env)
  let cwd_bytes = process_nul_terminated_or_empty(cwd)
  let stdout_path = if capture {
    process_capture_path("moui-process-stdout")
  } else {
    ""
  }
  let stderr_path = if capture {
    process_capture_path("moui-process-stderr")
  } else {
    ""
  }
  let stdout_bytes = process_nul_terminated_or_empty(stdout_path)
  let stderr_bytes = process_nul_terminated_or_empty(stderr_path)
  if capture {
    remove_tree(stdout_path)
    remove_tree(stderr_path)
  }
  let exit_code_buf = Bytes::make(4, b'\x00')
  let status = process_exec_native(
    argv_bytes,
    argv_bytes.length(),
    env_bytes,
    env_bytes.length(),
    cwd_bytes,
    stdout_bytes,
    stderr_bytes,
    timeout_ms,
    exit_code_buf,
  )
  let stdout_content = if capture {
    @fs.read_file_to_string(stdout_path) catch {
      _ => ""
    }
  } else {
    ""
  }
  let stderr_content = if capture {
    @fs.read_file_to_string(stderr_path) catch {
      _ => ""
    }
  } else {
    ""
  }
  if capture {
    remove_tree(stdout_path)
    remove_tree(stderr_path)
  }
  match status {
    0 =>
      Ok({
        exit_code: 0,
        stdout: stdout_content.trim().to_owned(),
        stderr: stderr_content.trim().to_owned(),
      })
    1 =>
      Ok({
        exit_code: read_int32_le_from_bytes(exit_code_buf, 0),
        stdout: stdout_content.trim().to_owned(),
        stderr: stderr_content.trim().to_owned(),
      })
    101 => Err("process setup error: " + argv.join(" "))
    102 => Err("process spawn error: " + argv.join(" "))
    103 =>
      Err(
        "process timeout after " +
        timeout_ms.to_string() +
        "ms: " +
        argv.join(" "),
      )
    _ =>
      Err(
        "process unknown status " + status.to_string() + ": " + argv.join(" "),
      )
  }
}
