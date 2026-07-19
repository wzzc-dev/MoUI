///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@macos_backend.macos_service_bridge(),
  )
  let timer_source = @macos_backend.macos_timer_source()
  @macos_skia_backend.run_app(
    "Mo Desktop",
    @runtime.new_program_with_dimensions(
      program=@mo_desktop_app.program(
        services~,
        timer_source=Some(timer_source),
        wall_clock=@macos_backend.macos_wall_clock,
      ),
      width=1280.0,
      height=800.0,
    ),
  )
}
