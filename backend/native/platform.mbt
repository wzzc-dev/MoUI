///|
pub fn run_counter_demo(title : String, runtime : @backend.AppRuntime) -> Unit {
  let config = @backend.WindowConfig::default(title~)
  let renderer = @wgpu_renderer.create_placeholder()
  let driver = @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let size = @core.Size::new(width=config.width, height=config.height)
  renderer.resize(@core.Size::new(width=config.width, height=config.height))
  ignore(
    driver.dispatch(
      @host.HostEvent::Resized(
        @host.HostSurfaceMetrics::from_logical(size~),
      ),
    ),
  )
  driver.begin_redraw()
  renderer.render(driver.draw_commands())
  driver.finish_redraw()
  println(
    "MoUI demo prepared: \{config.title} \{driver.size().width}x\{driver.size().height}",
  )
}
