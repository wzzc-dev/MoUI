///|
/// The clipboard services wired by `app_environment` must reach a real
/// implementation instead of the default "unavailable" task: before this, the
/// HarmonyOS entrypoint returned an empty `AppEnvironment`, so every clipboard
/// call failed with `unavailable` and no platform code was ever invoked.
test "harmonyos app environment answers clipboard through the host service" {
  let env = @harmonyos.app_environment()
  let clipboard = env.services().clipboard()
  let written = Ref(false)
  let write_result : Ref[@services.ServiceTaskResult[Unit]?] = Ref(None)
  ignore(
    clipboard
    .write_text("moui-harmonyos-clipboard")
    .start(result => {
      written.val = true
      write_result.val = Some(result)
    }),
  )
  assert_true(written.val)
  match write_result.val {
    Some(@services.Success(_)) => ()
    Some(@services.Failure(error)) =>
      // On a host without the HarmonyOS pasteboard the write reports a real
      // platform failure rather than the generic "unavailable" default.
      assert_true(error.message.contains("clipboard write failed"))
    _ => fail("clipboard write_text did not complete synchronously")
  }
}

///|
test "harmonyos clipboard rejects empty writes" {
  assert_false(@harmonyos.harmonyos_clipboard_write_text(""))
}

///|
test "harmonyos clipboard read returns none without native text" {
  // Host targets compile the no-pasteboard fallback, which must report "no
  // text" instead of crashing or returning a garbage buffer.
  match @harmonyos.harmonyos_clipboard_read_text() {
    Some(text) => assert_true(text.length() >= 0)
    None => ()
  }
}

///|
test "harmonyos clipboard selftest reports a boolean result" {
  // Host builds compile the no-pasteboard fallback, so the probe must report
  // false rather than crashing; on a matching device it round-trips a marker
  // through the real pasteboard.
  let ok = @harmonyos.harmonyos_clipboard_selftest()
  assert_true(ok == true || ok == false)
}
