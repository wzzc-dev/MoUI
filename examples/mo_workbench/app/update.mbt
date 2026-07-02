// Update loop: shell routing + per-workspace sub-updates + backend dispatch.
//
// The shell (`WorkbenchModel::update`) routes `CodeMsg` / `SettingsMsg` /
// `WriteMsg` to the matching sub-update and lifts the sub-effect back to
// `Effect[WorkbenchMsg]` via `Effect::map`. `SwitchWorkspace` and
// `ToggleAppearance` are handled at the shell level.

///|
/// Project an `AgentEvent` into the UI `ChatMessage` list and streaming state.
/// Returns `(new_messages_appended, is_terminal, error_msg)`.
fn project_agent_event(
  event : AgentEvent,
) -> (Array[ChatMessage], Bool, String?) {
  match event {
    UserMessageAdded(text) => ([ChatMessage::User(text)], false, None)
    AssistantMessageAdded(content, reasoning) =>
      ([ChatMessage::Assistant(content, reasoning)], false, None)
    ToolResultAdded(tool_name, content, is_error, brief) =>
      (
        [ChatMessage::ToolResult(tool_name, content, is_error, brief)],
        false,
        None,
      )
    RuntimeNoticeAdded(text) =>
      ([ChatMessage::RuntimeNotice(text)], false, None)
    TurnTerminal(status, message) => {
      let err = match status {
        Failed => Some(message)
        Aborted => Some(message)
        _ => None
      }
      ([ChatMessage::Terminal(status, message)], true, err)
    }
    ProgressNotice(_) => ([], false, None) // progress notices are transient; not stored
    SessionRebuilt(items) => {
      // Replace the whole message list. Items are full events to project.
      let rebuilt : Array[ChatMessage] = []
      for item in items {
        let (msgs, _, _) = project_agent_event(item)
        for m in msgs {
          rebuilt.push(m)
        }
      }
      // Signal a full replace via a sentinel: caller handles separately.
      (rebuilt, false, None)
    }
    SessionListed(_) => ([], false, None) // handled directly in apply_agent_event
    ActiveSessionChanged(_) => ([], false, None) // handled directly in apply_agent_event
  }
}

// ---------------------------------------------------------------------------
// Code workspace sub-update
// ---------------------------------------------------------------------------

///|
/// Apply an `AgentEvent` to the code workspace (session list / active id /
/// message stream updates). Pure model transition; returns no effect.
fn CodeWorkspace::apply_agent_event(
  self : CodeWorkspace,
  event : AgentEvent,
) -> CodeWorkspace {
  match event {
    SessionListed(sessions) => { ..self, sessions, }
    ActiveSessionChanged(id) => { ..self, active_session_id: Some(id) }
    SessionRebuilt(items) => {
      // Replace the whole message list.
      let rebuilt : Array[ChatMessage] = []
      for item in items {
        let (msgs, _, _) = project_agent_event(item)
        for m in msgs {
          rebuilt.push(m)
        }
      }
      { ..self, messages: rebuilt }
    }
    _ => {
      let (appended, is_terminal, err) = project_agent_event(event)
      let messages = Array::copy(self.messages)
      for m in appended {
        messages.push(m)
      }
      let is_streaming = if is_terminal { false } else { self.is_streaming }
      let error = err
      let model = { ..self, messages, is_streaming, error }
      // Auto-scroll to bottom on new content.
      if !appended.is_empty() {
        // Estimate bottom offset; the scroll view will clamp.
        let estimated = messages.length().to_double() * 64.0
        model.scroll_state.smooth_scroll_to(x=0.0, y=estimated)
      }
      model
    }
  }
}

///|
/// The code workspace sub-update. Owns chat transitions + backend dispatch.
/// Backend events are mapped to `CodeMsg::ReceiveAgentEvent` so the code
/// workspace handles them end-to-end.
fn CodeWorkspace::update(
  self : CodeWorkspace,
  msg : CodeMsg,
  backend : AgentBackendRuntime,
) -> (CodeWorkspace, @moui.Effect[CodeMsg]) {
  match msg {
    PromptChanged(value) => ({ ..self, prompt: value }, @moui.Effect::none())
    SteerChanged(value) => ({ ..self, steer_text: value }, @moui.Effect::none())
    ClearError => ({ ..self, error: None }, @moui.Effect::none())
    ModelChanged(model) =>
      (
        { ..self, current_model: model },
        backend.effect([SetModel(model)], event => {
          CodeMsg::ReceiveAgentEvent(event)
        }),
      )
    ThinkingChanged(thinking) =>
      (
        { ..self, current_thinking: thinking },
        backend.effect([SetThinking(thinking)], event => {
          CodeMsg::ReceiveAgentEvent(event)
        }),
      )
    SubmitPrompt => {
      let task = self.prompt
      if task.is_empty() {
        (self, @moui.Effect::none())
      } else {
        // Optimistically append the user message and start streaming.
        let messages = Array::copy(self.messages)
        messages.push(ChatMessage::User(task))
        let model = {
          ..self,
          messages,
          prompt: "",
          is_streaming: true,
          error: None,
        }
        (
          model,
          backend.effect([SendTask(task)], event => {
            CodeMsg::ReceiveAgentEvent(event)
          }),
        )
      }
    }
    SubmitSteer => {
      let text = self.steer_text
      if text.is_empty() || !self.is_streaming {
        (self, @moui.Effect::none())
      } else {
        let model = { ..self, steer_text: "" }
        (
          model,
          backend.effect([Steer(text)], event => {
            CodeMsg::ReceiveAgentEvent(event)
          }),
        )
      }
    }
    NewSession => {
      let name_prefix = "session"
      let model = {
        ..self,
        messages: [],
        is_streaming: false,
        error: None,
        prompt: "",
      }
      (
        model,
        backend.effect([NewSession(name_prefix)], event => {
          CodeMsg::ReceiveAgentEvent(event)
        }),
      )
    }
    SelectSession(id) => {
      let model = {
        ..self,
        messages: [],
        is_streaming: false,
        error: None,
        active_session_id: Some(id),
      }
      (
        model,
        backend.effect([SwitchSession(id)], event => {
          CodeMsg::ReceiveAgentEvent(event)
        }),
      )
    }
    ReceiveAgentEvent(event) =>
      (self.apply_agent_event(event), @moui.Effect::none())
  }
}

// ---------------------------------------------------------------------------
// Settings workspace sub-update
// ---------------------------------------------------------------------------

///|
/// The settings workspace sub-update. Pure UI form transitions; no backend
/// dispatch (persistence is reserved for the future backend integration).
fn SettingsWorkspace::update(
  self : SettingsWorkspace,
  msg : SettingsMsg,
) -> (SettingsWorkspace, @moui.Effect[SettingsMsg]) {
  match msg {
    ApiKeyChanged(value) => ({ ..self, api_key: value }, @moui.Effect::none())
    BaseUrlChanged(value) => ({ ..self, base_url: value }, @moui.Effect::none())
    ApprovalChanged(policy) =>
      ({ ..self, approval_policy: policy }, @moui.Effect::none())
    SandboxChanged(mode) =>
      ({ ..self, sandbox_mode: mode }, @moui.Effect::none())
    WorkingDirChanged(value) =>
      ({ ..self, working_dir: value }, @moui.Effect::none())
    FontSizeChanged(size) => {
      // Clamp font size to a sane range.
      let clamped = if size < 10 { 10 } else if size > 24 { 24 } else { size }
      ({ ..self, font_size: clamped }, @moui.Effect::none())
    }
  }
}

// ---------------------------------------------------------------------------
// Shell update (routing)
// ---------------------------------------------------------------------------

///|
/// Advance animation progress by one frame increment (~10 frames total).
fn advance_animation(progress : Double) -> Double {
  let next = progress + 0.12
  if next >= 1.0 { 1.0 } else { next }
}

///|
/// The shell update. Routes workspace-scoped messages to the matching
/// sub-update and lifts sub-effects back to `Effect[WorkbenchMsg]`.
fn WorkbenchModel::update(
  self : WorkbenchModel,
  msg : WorkbenchMsg,
) -> (WorkbenchModel, @moui.Effect[WorkbenchMsg]) {
  match msg {
    SwitchWorkspace(ws) =>
      // Start animation: set progress to 0 so the view renders the "from"
      // state of the transition. The subscription drives frames until 1.0.
      ({ ..self, active_workspace: ws, animation_progress: 0.0 }, @moui.Effect::none())
    AnimationTick => {
      let next = advance_animation(self.animation_progress)
      ({ ..self, animation_progress: next }, @moui.Effect::none())
    }
    ToggleAppearance => {
      let next = match self.appearance {
        System => Light
        Light => Dark
        Dark => System
      }
      ({ ..self, appearance: next }, @moui.Effect::none())
    }
    CodeMsg(m) => {
      let (code, eff) = self.code.update(m, self.backend)
      // Lift `Effect[CodeMsg]` to `Effect[WorkbenchMsg]` via `Effect::map`.
      ({ ..self, code, }, eff.map(m => WorkbenchMsg::CodeMsg(m)))
    }
    SettingsMsg(m) => {
      let (settings, eff) = self.settings.update(m)
      ({ ..self, settings, }, eff.map(m => WorkbenchMsg::SettingsMsg(m)))
    }
    WriteMsg(_) => (self, @moui.Effect::none())
  }
}
