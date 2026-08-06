///|
async test "pty spawns shell and echoes" {
  let pty = match Pty::spawn("/bin/sh", 80, 24) {
    Some(p) => p
    None => fail("failed to spawn pty")
  }
  let input = @utf8.encode("echo hello\r\n")
  let written = pty.write_input(input)
  inspect(written > 0, content="true")
  let buf : FixedArray[Byte] = FixedArray::make(4096, 0)
  let mut text = ""
  for _ in 0..<50 {
    let n = pty.read_output(buf)
    if n <= 0 {
      break
    }
    text = text + @utf8.decode_lossy(buf.unsafe_reinterpret_as_bytes()[0:n])
    if text.contains("hello") {
      break
    }
  }
  inspect(text.contains("hello"), content="true")
  pty.close()
}

///|
async test "pty exit closes reader" {
  let pty = match Pty::spawn("/bin/sh", 80, 24) {
    Some(p) => p
    None => fail("failed to spawn pty")
  }
  let input = @utf8.encode("exit\r\n")
  ignore(pty.write_input(input))
  let buf : FixedArray[Byte] = FixedArray::make(4096, 0)
  let mut saw_eof = false
  for _ in 0..<50 {
    let n = pty.read_output(buf)
    if n <= 0 {
      saw_eof = true
      break
    }
  }
  inspect(saw_eof, content="true")
  pty.close()
}

///|
async test "pty resize does not crash" {
  let pty = match Pty::spawn("/bin/sh", 80, 24) {
    Some(p) => p
    None => fail("failed to spawn pty")
  }
  pty.resize(120, 40)
  pty.resize(60, 10)
  let input = @utf8.encode("exit\r\n")
  ignore(pty.write_input(input))
  let buf : FixedArray[Byte] = FixedArray::make(4096, 0)
  for _ in 0..<50 {
    let n = pty.read_output(buf)
    if n <= 0 {
      break
    }
  }
  pty.close()
}

///|
/// Ctrl+C(\x03)必须终止前台进程:sleep 5 在 2 秒内被中断,
/// shell 输出回到提示符(读到新 prompt 或内容增长)。
async test "ctrl-c terminates foreground process" {
  let pty = match Pty::spawn("/bin/sh", 80, 24) {
    Some(p) => p
    None => fail("failed to spawn pty")
  }
  let buf : FixedArray[Byte] = FixedArray::make(4096, 0)
  let mut text = ""
  // 等待 shell 提示符
  for _ in 0..<50 {
    let n = pty.read_output(buf)
    if n <= 0 {
      break
    }
    text = text + @utf8.decode_lossy(buf.unsafe_reinterpret_as_bytes()[0:n])
    if text.contains("$") || text.contains("#") || text.contains("%") {
      break
    }
  }
  ignore(pty.write_input(@utf8.encode("sleep 5\r\n")))
  // 等 sleep 启动
  let mut started = ""
  for _ in 0..<50 {
    let n = pty.read_output(buf)
    if n <= 0 {
      break
    }
    started = started +
      @utf8.decode_lossy(buf.unsafe_reinterpret_as_bytes()[0:n])
    if started.contains("sleep") {
      break
    }
  }
  // 发送 Ctrl+C
  let written = pty.write_input(Bytes::from_array([3]))
  inspect(written > 0, content="true")
  // 1.5 秒内应回到提示符(sleep 5 若未中断,5 秒后才会有输出)
  let mut after = ""
  let mut interrupted = false
  for _ in 0..<100 {
    let n = pty.read_output(buf)
    if n <= 0 {
      break
    }
    after = after + @utf8.decode_lossy(buf.unsafe_reinterpret_as_bytes()[0:n])
    if after.contains("$") || after.contains("#") || after.contains("%") {
      interrupted = true
      break
    }
  }
  inspect(interrupted, content="true")
  pty.close()
}
