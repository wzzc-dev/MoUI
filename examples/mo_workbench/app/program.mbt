// Program assembly: wires Model/Msg/update/view into a MoUI Program.

///|
/// No active subscriptions; tab switching is immediate without animation.
fn workbench_subscriptions(
  _model : WorkbenchModel,
) -> @moui.Subscription[WorkbenchMsg] {
  @moui.Subscription::none()
}

///|
fn MoWorkbenchApp::initial_state(
  self : MoWorkbenchApp,
) -> (WorkbenchModel, @moui.Effect[WorkbenchMsg]) {
  let model = WorkbenchModel::new(
    backend=self.backend,
    settings_load=self.settings_load,
    settings_persist=self.settings_persist,
    model_detect=self.model_detect,
  )
  (
    model,
    self.backend.effect([FetchSessionList], event => {
      WorkbenchMsg::CodeMsg(CodeMsg::ReceiveAgentEvent(event))
    }),
  )
}

///|
/// Build the workbench program with the given backend runtime.
/// The entrypoint (macos_skia) injects the concrete openseek backend here.
pub fn MoWorkbenchApp::program_with_backend(
  self : MoWorkbenchApp,
) -> @moui.Program[WorkbenchModel, WorkbenchMsg] {
  @moui.Program::new_with_environment(
    init=() => self.initial_state(),
    update=(model, msg) => {
      model.update(msg, services=self.environment.services())
    },
    view=(model, env) => workbench_view(model, env),
    subscriptions=workbench_subscriptions,
  )
}

///|
/// Convenience constructor + program in one call (used by the entrypoint).
pub fn program_with_backend(
  backend~ : AgentBackendRuntime,
  settings_load? : SettingsLoadFn? = None,
  settings_persist? : SettingsPersistFn? = None,
  model_detect? : ModelDetectFn? = None,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @moui.Program[WorkbenchModel, WorkbenchMsg] {
  MoWorkbenchApp::new(
    backend~,
    settings_load~,
    settings_persist~,
    model_detect~,
    environment~,
  ).program_with_backend()
}
