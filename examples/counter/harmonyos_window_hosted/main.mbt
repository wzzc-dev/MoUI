///|
/// Window-hosted Counter for HarmonyOS: HostCmd / ApplicationHandler only.
fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@counter_app.program(),
    width=320.0,
    height=640.0,
  )
  println("moui-window-hosted harmonyos counter: waiting for HostCmd surface")
  @moui.run_app("MoUI Counter (window-hosted)", runtime)
  .render_all(@render_skia.from_env())
  .backend(@harmonyos_host.entry())
  .run()
}
