// Program assembly: wires Model/Msg/update/view into a MoUI Program.

///|
/// No active subscriptions; tab switching is immediate without animation.
fn workbench_subscriptions(
  _model : WorkbenchModel,
) -> @moui.Subscription[WorkbenchMsg] {
  @moui.Subscription::none()
}

///|
/// Build the workbench program with the given backend runtime.
/// The entrypoint (macos_skia) injects the concrete openseek backend here.
pub fn MoWorkbenchApp::program_with_backend(
  self : MoWorkbenchApp,
) -> @moui.Program[WorkbenchModel, WorkbenchMsg] {
  @moui.Program::new_with_environment(
    init=() => {
      let model = WorkbenchModel::new(backend=self.backend)
      // Start with an empty model; the UI renders the empty state first.
      // Session list / new session are triggered lazily once the UI is up.
      (model, @moui.Effect::none())
    },
    update=(model, msg) => model.update(msg),
    view=(model, env) => workbench_view(model, env),
    subscriptions=workbench_subscriptions,
  )
}

///|
/// Convenience constructor + program in one call (used by the entrypoint).
pub fn program_with_backend(
  backend~ : AgentBackendRuntime,
) -> @moui.Program[WorkbenchModel, WorkbenchMsg] {
  MoWorkbenchApp::new(backend~).program_with_backend()
}
