///|
fn host_file_dialog_kind_code(kind : @host.HostFileDialogKind) -> Int {
  match kind {
    @host.HostFileDialogKind::OpenFile => 0
    @host.HostFileDialogKind::SaveFile => 1
    @host.HostFileDialogKind::PickDirectory => 2
  }
}

///|
fn encode_host_string(value : String) -> Bytes {
  @utf8.encode(value[:], bom=false)
}

///|
fn encode_host_filter_list(filters : Array[String]) -> Bytes {
  encode_host_string(filters.join("\n"))
}

///|
fn decode_file_dialog_selection(bytes : Bytes) -> Array[String] {
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=false)
  let paths : Array[String] = []
  if text != "" {
    for path_view in text.split("\n") {
      let path = path_view.to_owned()
      if path != "" {
        paths.push(path)
      }
    }
  }
  paths
}
