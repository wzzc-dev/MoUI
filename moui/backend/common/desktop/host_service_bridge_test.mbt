///|
test "desktop router maps common requests once" {
  let bridge = DesktopHostServices::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_access=true,
      file_dialogs=true,
      open_url=true,
      system_theme=true,
    ),
    system_theme=@core.ColorScheme::Dark,
    clipboard=_ => @host.HostServiceResponse::ClipboardWritten,
    open_url=url => url == "https://example.test",
    file_dialog=_ => ["/tmp/example.txt"],
    settings=_ => @host.HostServiceResponse::SettingValue(None),
    show_menu=_ => @host.HostServiceResponse::Unavailable("no menu"),
  ).bridge()
  match
    bridge.dispatch(@host.HostServiceRequest::OpenUrl("https://example.test")) {
    @host.HostServiceResponse::UrlOpened => ()
    _ => abort("expected URL-opened response")
  }
  match bridge.dispatch(@host.HostServiceRequest::QuerySystemTheme) {
    @host.HostServiceResponse::SystemTheme(@core.ColorScheme::Dark) => ()
    _ => abort("expected dark system theme")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::FileDialog(
        @host.HostFileDialogOptions::new(
          kind=@host.HostFileDialogKind::OpenFile,
        ),
      ),
    ) {
    @host.HostServiceResponse::FileDialogSelection(["/tmp/example.txt"]) => ()
    _ => abort("expected shared file-dialog response")
  }
}

///|
test "shared filesystem handlers report missing paths consistently" {
  match
    @host_services_native.dispatch_text_file(
      @host.HostTextFileRequest::ReadText(
        "/tmp/moui-host-services-definitely-missing/text.txt",
      ),
    ) {
    @host.HostServiceResponse::Unavailable("file does not exist") => ()
    _ => abort("expected missing text-file response")
  }
  match
    @host_services_native.dispatch_binary_file(
      @host.HostBinaryFileRequest::ReadBytes(
        "/tmp/moui-host-services-definitely-missing/data.bin",
      ),
    ) {
    @host.HostServiceResponse::Unavailable("file does not exist") => ()
    _ => abort("expected missing binary-file response")
  }
  match
    @host_services_native.dispatch_list_directory(
      "/tmp/moui-host-services-definitely-missing",
    ) {
    @host.HostServiceResponse::DirectoryListing(_, []) => ()
    _ => abort("expected an empty missing-directory listing")
  }
}

///|
test "shared filesystem handlers read write and list consistently" {
  let directory = "/tmp/moui-host-services-desktop-test"
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
    @host_services_native.dispatch_text_file(
      @host.HostTextFileRequest::WriteText(text_path, "hello"),
    ) {
    @host.HostServiceResponse::TextFileWritten(path) =>
      assert_eq(path, text_path)
    _ => abort("expected text write completion")
  }
  match
    @host_services_native.dispatch_text_file(
      @host.HostTextFileRequest::ReadText(text_path),
    ) {
    @host.HostServiceResponse::TextFileContent(path, text) => {
      assert_eq(path, text_path)
      assert_eq(text, "hello")
    }
    _ => abort("expected text read completion")
  }

  match
    @host_services_native.dispatch_binary_file(
      @host.HostBinaryFileRequest::WriteBytes(binary_path, b"\x01\x02"),
    ) {
    @host.HostServiceResponse::BinaryFileWritten(path) =>
      assert_eq(path, binary_path)
    _ => abort("expected binary write completion")
  }
  match
    @host_services_native.dispatch_binary_file(
      @host.HostBinaryFileRequest::ReadBytes(binary_path),
    ) {
    @host.HostServiceResponse::BinaryFileContent(path, bytes) => {
      assert_eq(path, binary_path)
      assert_eq(bytes, b"\x01\x02")
    }
    _ => abort("expected binary read completion")
  }

  @fs.write_string_to_file(hidden_path, "hidden")
  match @host_services_native.dispatch_list_directory(directory) {
    @host.HostServiceResponse::DirectoryListing(path, entries) => {
      assert_eq(path, directory)
      assert_true(entries.any(entry => entry.name() == "note.txt"))
      assert_true(entries.any(entry => entry.name() == "data.bin"))
      assert_false(entries.any(entry => entry.name() == ".hidden"))
    }
    _ => abort("expected directory listing")
  }
}
