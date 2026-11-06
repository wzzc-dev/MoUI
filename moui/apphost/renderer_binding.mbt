///|
/// Bind the ordered provider list and surface, retaining the startup rejection
/// reasons for the host log. Platform entrypoints keep their
/// `RendererSession?` contract; a failed selection now names which providers
/// were tried and why they rejected the surface instead of exiting silently.
pub fn resolve_renderer_session(
  providers : Array[@render.RendererProvider],
  surface : @render.HostSurface,
) -> @render.RendererSession? {
  let resolution = @render_common.resolve_renderer_with_plan(providers, surface)
  match resolution.session {
    Some(session) => Some(session)
    None => {
      let summary = resolution.plan.rejection_summary()
      println(
        "renderer selection failed: " +
        (if summary == "" { "no providers" } else { summary }),
      )
      None
    }
  }
}
