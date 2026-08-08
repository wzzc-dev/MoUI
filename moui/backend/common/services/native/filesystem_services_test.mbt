///|
test "native filesystem services preserve bytes and skip hidden entries" {
  let directory = "/tmp/moui-host-services-native-test"
  let text_path = directory + "/note.txt"
  let binary_path = directory + "/data.bin"
  let hidden_path = directory + "/.hidden"
  @fs.remove_file(text_path) catch {
    _ => ()
  }
  @fs.remove_file(binary_path) catch {
    _ => ()
  }
  @fs.remove_file(hidden_path) catch {
    _ => ()
  }
  @fs.remove_dir(directory) catch {
    _ => ()
  }
  @fs.create_dir(directory)
  defer (@fs.remove_file(text_path) catch { _ => () })
  defer (@fs.remove_file(binary_path) catch { _ => () })
  defer (@fs.remove_file(hidden_path) catch { _ => () })
  defer (@fs.remove_dir(directory) catch { _ => () })

  match
    dispatch_text_file(@host.HostTextFileRequest::WriteText(text_path, "hello")) {
    @host.HostServiceResponse::TextFileWritten(path) =>
      assert_eq(path, text_path)
    _ => abort("expected text write completion")
  }
  match
    dispatch_binary_file(
      @host.HostBinaryFileRequest::WriteBytes(binary_path, b"\x01\x02"),
    ) {
    @host.HostServiceResponse::BinaryFileWritten(path) =>
      assert_eq(path, binary_path)
    _ => abort("expected binary write completion")
  }
  @fs.write_string_to_file(hidden_path, "hidden")

  match dispatch_list_directory(directory) {
    @host.HostServiceResponse::DirectoryListing(path, entries) => {
      assert_eq(path, directory)
      assert_true(entries.any(entry => entry.name() == "note.txt"))
      assert_true(entries.any(entry => entry.name() == "data.bin"))
      assert_false(entries.any(entry => entry.name() == ".hidden"))
    }
    _ => abort("expected directory listing")
  }
}
