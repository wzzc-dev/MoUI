///|
fn main {
  let app = @app.MoWorkbenchApp::new()
  let transport_owner = @native_transport.PiNativeTransportOwner::new(
    @native_transport.PiNativeTransportConfig::pi(),
    session_id="moui-skia",
  )
  let runtime = app.runtime_with_transport(
    transport_owner.runtime(),
    width=1220.0,
    height=780.0,
  )
  let exit_after_first_present = @env.get_env_var(
      "MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  let font_resolution = if exit_after_first_present {
    @skia_renderer.SkiaFontResolution::EmptyTypeface
  } else {
    @skia_renderer.SkiaFontResolution::SystemFontMgr
  }
  @async.run_async_main(() => {
    @async.with_task_group(group => {
      group.spawn_bg(allow_failure=true, () => transport_owner.run())
      @macos_skia_backend.run_app_with_options_async_pump(
        "Mo Workbench",
        runtime,
        options=@macos_skia_backend.MacosSkiaAppOptions::new(
          font_resolution~,
          exit_after_first_present~,
        ),
      )
      transport_owner.shutdown()
    })
  })
}
