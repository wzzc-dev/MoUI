///|
pub fn run_counter_demo(title : String, runtime : @backend.AppRuntime) -> Unit {
  let config = @backend.WindowConfig::default(title~)
  let renderer = @native_wgpu.RendererHandle::new()
  renderer.resize(@core.Size::new(width=config.width, height=config.height))
  runtime.dispatch_event(
    @core.AppEvent::Resize(
      @core.Size::new(width=config.width, height=config.height),
    ),
  )
  renderer.render(runtime.draw_commands())
  println(
    "MoUI demo prepared: \{config.title} \{runtime.size().width}x\{runtime.size().height}",
  )
}
