///|
pub struct MoWorkbenchApp {
  unit : Unit
}

///|

pub fn MoWorkbenchApp::new() -> MoWorkbenchApp {
  { unit: () }
}

///|

fn WorkbenchModel::update(
  self : WorkbenchModel,
  message : WorkbenchMsg,
) -> WorkbenchModel {
  match message {
    SelectSession(id) => self.select_session(id)
    SelectPanel(panel) => { ..self, selected_panel: panel }
    SetAppearanceMode(mode) => self.set_appearance_mode(mode)
    SwitchAgentBackend(id) => self.switch_backend(id)
    CreateConversation => self.create_conversation()
    SelectAgent(id) => self.select_agent(id)
    PromptChanged(value) => { ..self, prompt: value }
    ToggleComposerControls =>
      { ..self, composer_controls_expanded: !self.composer_controls_expanded }
    DispatchPrompt => self.dispatch_prompt()
    DispatchSteering => self.dispatch_steering()
    DispatchFollowUp => self.dispatch_follow_up()
    InvokeCommand(name) => self.invoke_command(name)
    FollowTranscript(role, summary, detail) =>
      self.follow_transcript(role, summary, detail)
    FollowActivity(phase, title, detail) =>
      self.follow_activity(phase, title, detail)
    InspectFile(path) => self.inspect_file(path)
    ReviewDiff => self.review_diff()
    RefreshSession => self.refresh_session()
    ReceiveTransport(event) => self.receive_transport(event)
    ReceiveConnector(event) => self.receive_connector(event)
    NewSession => self.new_session()
    RefreshForkMessages => self.refresh_fork_messages()
    ForkFromMessage(entry_id) => self.fork_from_message(entry_id)
    ExportSessionHtml => self.export_session_html()
    QueueCommand(command) => self.queue_command(command)
    QueueFocusedChecks => self.queue_focused_checks()
    ToggleCommandDetails(id) => self.toggle_command_details(id)
    ToggleWorkspaceDetails => self.toggle_workspace_details()
    InspectCommandRun(command, status, cwd, output_path) =>
      self.inspect_command_run(command, status, cwd, output_path)
    FixCommandRun(command, status, cwd, output_path) =>
      self.fix_command_run(command, status, cwd, output_path)
    MarkCommandComplete(id, code) => self.mark_command_complete(id, code)
    FixDiagnostic(source, severity, message) =>
      self.fix_diagnostic(source, severity, message)
    SyncSessionName => self.sync_session_name()
    SetModel(provider, id, label) => self.set_model(provider, id, label)
    CycleModel => self.cycle_model()
    CompactSession => self.compact_session()
    CycleThinkingLevel => self.cycle_thinking_level()
    ToggleSteeringMode => self.toggle_steering_mode()
    ToggleFollowUpMode => self.toggle_follow_up_mode()
    CancelRun => self.cancel_run()
    ClearDiagnostics =>
      {
        ..self,
        diagnostics: [],
        last_status: "Diagnostics cleared for current session",
      }
    ToggleContext(id) =>
      { ..self, expanded_context: toggle_id(self.expanded_context, id) }
    MainScrollTo(offset_y) => self.scroll_main_to(offset_y)
  }
}

///|
fn update(model : WorkbenchModel, message : WorkbenchMsg) -> WorkbenchModel {
  model.update(message)
}

///|
fn WorkbenchModel::set_appearance_mode(
  self : WorkbenchModel,
  mode : String,
) -> WorkbenchModel {
  let normalized = mode.trim().to_owned()
  match normalized {
    "system" | "light" | "dark" =>
      {
        ..self,
        appearance_mode: normalized,
        last_status: "Appearance mode changed",
      }
    _ => { ..self, last_status: "Appearance mode unavailable" }
  }
}

///|
fn view(model : WorkbenchModel) -> @core.View[WorkbenchMsg] {
  model.view()
}

///|
pub fn MoWorkbenchApp::runtime(
  self : MoWorkbenchApp,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  ignore(self)
  runtime(width~, height~)
}

///|
pub fn MoWorkbenchApp::runtime_with_transport(
  self : MoWorkbenchApp,
  transport_runtime : PiTransportRuntime,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  ignore(self)
  runtime_with_transport(transport_runtime, width~, height~)
}

///|
pub fn MoWorkbenchApp::runtime_with_agent_connectors(
  self : MoWorkbenchApp,
  transport_runtime : PiTransportRuntime,
  connector_runtimes : Array[AgentConnectorRuntime],
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  ignore(self)
  runtime_with_agent_connectors(
    transport_runtime,
    connector_runtimes,
    width~,
    height~,
  )
}

///|
pub fn runtime(
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  WorkbenchModel::new().runtime(width~, height~)
}

///|
pub fn runtime_with_transport(
  transport_runtime : PiTransportRuntime,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  WorkbenchModel::new().runtime_with_transport(
    transport_runtime,
    width~,
    height~,
  )
}

///|
pub fn runtime_with_agent_connectors(
  transport_runtime : PiTransportRuntime,
  connector_runtimes : Array[AgentConnectorRuntime],
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  WorkbenchModel::new().runtime_with_agent_connectors(
    transport_runtime,
    connector_runtimes,
    width~,
    height~,
  )
}

///|
fn WorkbenchModel::runtime(
  self : WorkbenchModel,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  self.runtime_with_transport(
    PiTransportRuntime::unavailable(),
    width~,
    height~,
  )
}

///|
fn WorkbenchModel::runtime_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  self.runtime_with_agent_connectors(transport_runtime, [], width~, height~)
}

///|
fn WorkbenchModel::runtime_with_agent_connectors(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
  connector_runtimes : Array[AgentConnectorRuntime],
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::new_with_environment(
      init=() => (self, @core.Effect::none()),
      update=(model, message) => {
        model
        .update_with_agent_connectors(
          message, transport_runtime, connector_runtimes,
        )
        .as_tuple()
      },
      view=(model, env) => model.view_with_environment(env),
    ),
    size=@core.Size::new(width~, height~),
  )
}

///|
fn WorkbenchUpdate::new(
  model : WorkbenchModel,
  effect? : @core.Effect[WorkbenchMsg] = @core.Effect::none(),
) -> WorkbenchUpdate {
  { model, effect }
}

///|
fn WorkbenchUpdate::as_tuple(
  self : WorkbenchUpdate,
) -> (WorkbenchModel, @core.Effect[WorkbenchMsg]) {
  (self.model, self.effect)
}
