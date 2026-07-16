///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@macos_host.macos_service_bridge(),
  )
  let timer_source = @macos_host.macos_timer_source()
  let event_sources = @host.HostPlatformEventSources::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=@platform_lab_app.program(
      services~,
      timer_source=Some(timer_source),
      window_events=Some(event_sources.window_events()),
    ),
    width=720.0,
    height=780.0,
  )
  runtime.set_action_commands(@platform_lab_app.action_command_map())
  @macos_skia_backend.run_app_with_options(
    "MoUI Platform Lab",
    runtime,
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      event_sources=Some(event_sources),
      on_ready=Some(() => install_application_menu(services)),
    ),
  )
}

///|
fn install_application_menu(services : @host.HostAppServices) -> Unit {
  // L2 application menu bar preview (macOS). Other platforms return Unavailable.
  let cmd = 1_048_576
  let file_menu = @host.HostApplicationMenu::new(
    title="File",
    items=[
      @host.HostApplicationMenuItem::new(
        title="Open…",
        action_id=1,
        key_equivalent="o",
        key_modifier_mask=cmd,
      ),
      @host.HostApplicationMenuItem::separator(),
      @host.HostApplicationMenuItem::new(
        title="Write Clipboard Sample",
        action_id=2,
        key_equivalent="c",
        key_modifier_mask=cmd,
      ),
    ],
  )
  ignore(services.set_application_menu([file_menu]))
}
