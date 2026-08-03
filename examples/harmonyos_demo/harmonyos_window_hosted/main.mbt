///|
/// Window-hosted HarmonyOS demo entrypoint.
fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@demo_app.program(),
    width=320.0,
    height=640.0,
  )
  println("moui-window-hosted harmonyos: waiting for HostCmd surface")
  @moui.run_app("HarmonyOS Demo (window-hosted)", runtime)
  .render_all(@render_skia.from_env())
  .backend(@harmonyos_host.entry())
  .run()
}
