// Program assembly: wires Model/Msg/update/view into a MoUI Program.

///|
/// Drive workspace switch animation frames while progress < 1.0.
/// The runtime calls `start` each animation frame for kind="animation"
/// subscriptions, giving us ~60fps ticks until the transition completes.
fn workbench_subscriptions(
  model : WorkbenchModel,
) -> @moui.Subscription[WorkbenchMsg] {
  if model.animation_progress < 1.0 {
    @moui.Subscription::animation_tick(
      key="workspace-switch-anim",
      start=dispatch => {
        dispatch(WorkbenchMsg::AnimationTick)
        None
      },
      label="Workspace switch transition",
    )
  } else {
    @moui.Subscription::none()
  }
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
