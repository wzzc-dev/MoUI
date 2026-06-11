///|
fn encode_menu_commands(commands : Array[@core.ActionCommand]) -> Bytes {
  let rows : Array[String] = []
  for command in commands {
    let label_bytes = @utf8.encode(command.label[:], bom=false)
    let enabled = if command.enabled { "1" } else { "0" }
    rows.push("\{enabled}:\{label_bytes.length()}:\{command.label}")
  }
  encode_host_string(rows.join("\n"))
}

///|
fn menu_command_response(
  commands : Array[@core.ActionCommand],
  selected_index : Int,
) -> @host.HostServiceResponse {
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
