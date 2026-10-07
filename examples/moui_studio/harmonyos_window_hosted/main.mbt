///|
/// MoUI Studio HarmonyOS entrypoint (window-hosted embedded runtime).
///
/// The window-hosted model (ADR 0021): the app session runs behind the
/// EmbedderHostChannel; XComponent callbacks are the only surface /
/// pointer / resize / detach source. Platform readiness stays
/// `experimental` (`ready=false`) — this entry proves compilation and
/// host-sim behaviour, not product readiness.
fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@studio_app.program(
      environment=@harmonyos_host.app_environment(),
    ),
    width=640.0,
    height=480.0,
  )
  println("moui-window-hosted harmonyos: waiting for HostCmd surface")
  @runtime.run_app("MoUI Studio (harmonyos window-hosted)", runtime)
  .render_all(@render_skia.from_env(platform=HarmonyOS))
  .backend(@harmonyos_host.entry())
  .run()
}
