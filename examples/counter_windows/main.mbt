///|
fn main {
  let root = @views.column(
    [@views.label("MoUI Counter"), @views.button("Increment")],
    spacing=12.0,
  )
  let runtime = @core.RuntimeState::new(
    root~,
    size=@core.Size::new(width=800.0, height=600.0),
  )
  @backend_windows.run_counter_demo("MoUI Counter", runtime)
}
