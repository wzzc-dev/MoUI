///|
fn main {
  let root = @views.column([
    @views.label("MoUI Counter"),
    @views.button("Increment"),
  ], spacing=12.0)
  let runtime = @core.RuntimeState::new(root~, size=@core.Size::new(width=800.0, height=600.0))
  runtime.dispatch_event(@core.Redraw(@core.Initial))
  let renderer = @render.RendererHandle::new()
  renderer.resize(runtime.size)
  let commands = runtime.build_draw_commands()
  renderer.render(commands)
  @backend.run_counter_demo("MoUI Counter", runtime)
}
