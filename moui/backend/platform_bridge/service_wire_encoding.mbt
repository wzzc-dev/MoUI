///|
/// Shared host-service wire encoding (ADR 0020). Desktop backends encode
/// menus and file-dialog options into the same byte layout and decode
/// selections back; these helpers live in the bridge so every platform
/// shares one implementation instead of three local copies.
///|
pub fn encode_menu_commands(commands : Array[@core.ActionCommand]) -> Bytes {
  let rows : Array[String] = []
  for command in commands {
    let label_bytes = @utf8.encode(command.label[:], bom=false)
    let enabled = if command.enabled { "1" } else { "0" }
    rows.push("\{enabled}:\{label_bytes.length()}:\{command.label}")
  }
  encode_host_string(rows.join("\n"))
}

///|
/// Map a native menu selection index to a host service response.
/// Negative or out-of-range selections are reported as cancelled, disabled
/// commands as unavailable.
pub fn menu_command_response(
  commands : Array[@core.ActionCommand],
  selected_index : Int,
) -> @host.HostServiceResponse {
  menu_command_response_with_unavailable_sentinel(commands, selected_index, None)
}

///|
/// Linux variant: the native menu host reports `-2` when the menu service
/// itself is unavailable, which maps to its own response message.
pub fn menu_command_response_with_unavailable(
  commands : Array[@core.ActionCommand],
  selected_index : Int,
) -> @host.HostServiceResponse {
  menu_command_response_with_unavailable_sentinel(commands, selected_index, Some(-2))
}

///|
fn menu_command_response_with_unavailable_sentinel(
  commands : Array[@core.ActionCommand],
  selected_index : Int,
  unavailable_sentinel : Int?,
) -> @host.HostServiceResponse {
  match unavailable_sentinel {
    Some(sentinel) if selected_index == sentinel =>
      @host.HostServiceResponse::Unavailable("menu service is unavailable")
    _ =>
      if selected_index < 0 || selected_index >= commands.length() {
        @host.HostServiceResponse::Unavailable("menu selection cancelled")
      } else {
        let command = commands[selected_index]
        if command.enabled {
          @host.HostServiceResponse::MenuAction(command)
        } else {
          @host.HostServiceResponse::Unavailable("menu command is disabled")
        }
      }
  }
}

///|
/// Encode a file-dialog kind into the shared wire code.
pub fn host_file_dialog_kind_code(kind : @host.HostFileDialogKind) -> Int {
  match kind {
    @host.HostFileDialogKind::OpenFile => 0
    @host.HostFileDialogKind::SaveFile => 1
    @host.HostFileDialogKind::PickDirectory => 2
  }
}

///|
/// Encode a host string as UTF-8 bytes without a BOM.
pub fn encode_host_string(value : String) -> Bytes {
  @utf8.encode(value[:], bom=false)
}

///|
/// Encode a filter list joined by newlines.
pub fn encode_host_filter_list(filters : Array[String]) -> Bytes {
  encode_host_string(filters.join("\n"))
}

///|
/// Decode a newline-separated path list returned by a native file dialog.
/// Linux trims each path (portals/zenity may pad entries); other platforms
/// preserve the raw bytes.
pub fn decode_file_dialog_selection(
  bytes : Bytes,
  trim_paths~ : Bool = false,
) -> Array[String] {
  let text = @utf8.decode_lossy(bytes[:], ignore_bom=false)
  let paths : Array[String] = []
  if text != "" {
    for path_view in text.split("\n") {
      let path = if trim_paths {
        path_view.trim().to_owned()
      } else {
        path_view.to_owned()
      }
      if path != "" {
        paths.push(path)
      }
    }
  }
  paths
}
