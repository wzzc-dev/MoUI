///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@linux_backend.linux_service_bridge(),
  )
  let timer_source = @linux_backend.linux_timer_source()
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_host(
      @linux_backend.linux_capability_summary(),
      services~,
      timer_source=Some(timer_source),
    ),
    width=1100.0,
    height=680.0,
  )
  runtime.set_action_commands(@showcase_app.action_command_map())
  @moui.run_app("MoUI Showcase", runtime)
  .render(
    @render_wgpu.native(
      text_engine=@render_wgpu.native_platform_text_engine_with_fallback(
        @wgpu_fontconfig.fontconfig_text_provider(),
        fallback=@wgpu_cosmic.cosmic_text_engine(),
      ),
    ),
  )
  .backend(@linux_backend.entry())
  .run()
}
