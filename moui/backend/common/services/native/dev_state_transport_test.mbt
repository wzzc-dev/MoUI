///|
test "dev_state_transport round-trips payload through the filesystem" {
  let directory = "/tmp/moui-dev-state-transport-test"
  let path = directory + "/state.json"
  @fs.remove_file(path) catch {
    _ => ()
  }
  @fs.remove_dir(directory) catch {
    _ => ()
  }
  @fs.create_dir(directory)
  defer (@fs.remove_file(path) catch { _ => () })
  defer (@fs.remove_dir(directory) catch { _ => () })

  let transport = @native.dev_state_transport(path)
  assert_true(transport.read() is None)
  transport.write("{\"count\":3}")
  match transport.read() {
    Some(payload) => assert_eq(payload, "{\"count\":3}")
    None => abort("expected payload after write")
  }
}

///|
test "dev_state_transport_path is unset outside the dev loop" {
  assert_true(@native.dev_state_transport_path() is None)
}
