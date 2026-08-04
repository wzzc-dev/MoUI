// Update loop: shell routing + per-tab sub-updates + backend dispatch + task
// tree projection sync.
//
// The shell (`WorkbenchModel::update`) routes `CodeMsg` / `SettingsMsg` to the
// matching sub-update and lifts the sub-effect back to `Effect[WorkbenchMsg]`
// via `Effect::map`. `SwitchTab`, `NewTask`, `SelectTask`, `ToggleFolder`,
// `ToggleSettings` and `ToggleAppearance` are handled at the shell level.
// After any `CodeMsg` that may change sessions/streaming state,
// `sync_task_tree` rebuilds the UI task tree projection from `code.sessions`
// so the sidebar never holds stale state.

///|
fn should_skip_duplicate_user_message(
  messages : Array[ChatMessage],
  candidate : ChatMessage,
) -> Bool {
  match candidate {
    User(text) =>
      if messages.is_empty() {
        false
      } else {
        match messages[messages.length() - 1] {
          User(last) => last == text
          _ => false
        }
      }
    _ => false
  }
}

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
    PermissionRequested(request) =>
      ([ChatMessage::PermissionRequest(request)], false, None)
    TurnTerminal(status, message) => {
      let err = match status {
        Failed => Some(message)
        Aborted => Some(message)
        _ => None
      }
      let messages = match status {
        Finished => []
        _ => [ChatMessage::Terminal(status, message)]
      }
      (messages, true, err)
    }
    ProgressNotice(_) => ([], false, None) // handled directly in apply_agent_event
    UserMessageChunk(_, _) => ([], false, None)
    AssistantMessageChunk(_, _) => ([], false, None)
    ThoughtMessageChunk(_, _) => ([], false, None)
    SessionModeStateChanged(_) => ([], false, None)
    SessionConfigOptionsChanged(_) => ([], false, None)
    SessionInfoUpdated(_, _, _) => ([], false, None)
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

///|
fn append_text_chunk(existing : String, chunk : String) -> String {
  if existing.is_empty() {
    chunk
  } else {
    existing + chunk
  }
}

///|
fn message_id_matches(previous : String?, next : String?) -> Bool {
  match (previous, next) {
    (Some(a), Some(b)) => a == b
    _ => false
  }
}

///|
fn append_user_chunk(
  messages : Array[ChatMessage],
  previous_id : String?,
  next_id : String?,
  chunk : String,
) -> Array[ChatMessage] {
  let out = Array::copy(messages)
  if !out.is_empty() && message_id_matches(previous_id, next_id) {
    let index = out.length() - 1
    match out[index] {
      User(text) =>
        out[index] = ChatMessage::User(append_text_chunk(text, chunk))
      _ => out.push(ChatMessage::User(chunk))
    }
  } else {
    out.push(ChatMessage::User(chunk))
  }
  out
}

///|
fn append_assistant_chunk(
  messages : Array[ChatMessage],
  previous_id : String?,
  next_id : String?,
  chunk : String,
) -> Array[ChatMessage] {
  let out = Array::copy(messages)
  if !out.is_empty() && message_id_matches(previous_id, next_id) {
    let index = out.length() - 1
    match out[index] {
      Assistant(content, reasoning) =>
        out[index] = ChatMessage::Assistant(
          append_text_chunk(content, chunk),
          reasoning,
        )
      _ => out.push(ChatMessage::Assistant(chunk, None))
    }
  } else {
    out.push(ChatMessage::Assistant(chunk, None))
  }
  out
}

///|
fn append_thought_chunk(
  messages : Array[ChatMessage],
  previous_id : String?,
  next_id : String?,
  chunk : String,
) -> Array[ChatMessage] {
  let out = Array::copy(messages)
  if out.is_empty() {
    out.push(ChatMessage::Assistant("", Some(chunk)))
    return out
  }
  let index = out.length() - 1
  match out[index] {
    Assistant(content, reasoning) =>
      if message_id_matches(previous_id, next_id) || previous_id == None {
        let next_reasoning = match reasoning {
          Some(text) => Some(append_text_chunk(text, chunk))
          None => Some(chunk)
        }
        out[index] = ChatMessage::Assistant(content, next_reasoning)
      } else {
        out.push(ChatMessage::Assistant("", Some(chunk)))
      }
    _ => out.push(ChatMessage::Assistant("", Some(chunk)))
  }
  out
}

///|
fn CodeWorkspace::scroll_to_latest(self : CodeWorkspace) -> Unit {
  self.scroll_state.scroll_to(x=0.0, y=1.0e9)
}

///|
fn CodeWorkspace::scroll_to_latest_if_following(self : CodeWorkspace) -> Unit {
  if self.follow_latest {
    self.scroll_to_latest()
  }
}

///|
fn code_follow_latest_after_scroll(
  current : Bool,
  delta : @geometry.Point,
) -> Bool {
  if delta.y > 0.0 {
    false
  } else if delta.y < 0.0 {
    true
  } else {
    current
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
    UserMessageChunk(message_id, content) => {
      let messages = append_user_chunk(
        self.messages,
        self.last_user_message_id,
        message_id,
        content,
      )
      let model = { ..self, messages, last_user_message_id: message_id }
      model.scroll_to_latest_if_following()
      model
    }
    AssistantMessageChunk(message_id, content) => {
      let messages = append_assistant_chunk(
        self.messages,
        self.last_assistant_message_id,
        message_id,
        content,
      )
      let model = { ..self, messages, last_assistant_message_id: message_id }
      model.scroll_to_latest_if_following()
      model
    }
    ThoughtMessageChunk(message_id, content) => {
      let messages = append_thought_chunk(
        self.messages,
        self.last_thought_message_id,
        message_id,
        content,
      )
      let model = { ..self, messages, last_thought_message_id: message_id }
      model.scroll_to_latest_if_following()
      model
    }
    SessionModeStateChanged(modes) => {
      let merged_modes = match self.session_modes {
        Some(existing) =>
          if modes.available_modes.is_empty() {
            { ..existing, current_mode_id: modes.current_mode_id }
          } else {
            modes
          }
        None => modes
      }
      { ..self, session_modes: Some(merged_modes) }
    }
    SessionConfigOptionsChanged(options) =>
      { ..self, session_config_options: options }
    SessionInfoUpdated(session_id, title, updated_at) => {
      let sessions : Array[SessionSummary] = []
      for s in self.sessions {
        if s.id == session_id {
          let first_prompt = match title {
            Some(t) => t
            None => s.first_prompt
          }
          sessions.push({
            ..s,
            first_prompt,
            last_active_unix_seconds: s.last_active_unix_seconds,
          })
        } else {
          sessions.push(s)
        }
      }
      let notice = match updated_at {
        Some(text) => "Session updated: " + text
        None => "Session updated"
      }
      { ..self, sessions, progress_notice: Some(notice) }
    }
    SessionRebuilt(items) => {
      // Replace the whole message list.
      let rebuilt : Array[ChatMessage] = []
      for item in items {
        let (msgs, _, _) = project_agent_event(item)
        for m in msgs {
          rebuilt.push(m)
        }
      }
      let model = {
        ..self,
        messages: rebuilt,
        progress_notice: None,
        last_user_message_id: None,
        last_assistant_message_id: None,
        last_thought_message_id: None,
        follow_latest: true,
      }
      model.scroll_to_latest()
      model
    }
    ProgressNotice(text) => {
      let model = { ..self, progress_notice: Some(text) }
      model.scroll_to_latest_if_following()
      model
    }
    _ => {
      let (appended, is_terminal, err) = project_agent_event(event)
      let messages = Array::copy(self.messages)
      for m in appended {
        if !should_skip_duplicate_user_message(messages, m) {
          messages.push(m)
        }
      }
      let is_streaming = if is_terminal { false } else { self.is_streaming }
      let error = err
      let progress_notice = if is_terminal {
        None
      } else {
        self.progress_notice
      }
      let model = { ..self, messages, is_streaming, progress_notice, error }
      // Auto-scroll to bottom on new content.
      if !appended.is_empty() || is_terminal || self.is_streaming {
        model.scroll_to_latest_if_following()
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
    MessageListScrolled(delta) =>
      (
        {
          ..self,
          follow_latest: code_follow_latest_after_scroll(
            self.follow_latest,
            delta,
          ),
        },
        @moui.Effect::none(),
      )
    ModelChanged(provider_id, model_id) =>
      // The shell intercepts `ModelChanged` to also dispatch the backend
      // `SetModel` with the provider's live connection; this arm keeps the
      // code model in sync if reached directly.
      if mo_workbench_model_supported_by_openseek(model_id) {
        (
          {
            ..self,
            current_model: model_id,
            current_provider_id: Some(provider_id),
            model_picker_open: false,
          },
          @moui.Effect::none(),
        )
      } else {
        (self, @moui.Effect::none())
      }
    ToggleModelPicker =>
      (
        { ..self, model_picker_open: !self.model_picker_open },
        @moui.Effect::none(),
      )
    PickWorkspaceFolder
    | WorkspaceFolderSelected(_)
    | WorkspaceFolderPickFailed(_) => (self, @moui.Effect::none())
    SelectProvider(_) =>
      // Provider switching is resolved at the shell level (it also re-points
      // the backend). The code workspace stays as-is here.
      (self, @moui.Effect::none())
    ThinkingChanged(thinking) =>
      (
        { ..self, current_thinking: thinking },
        backend.effect([SetThinking(thinking)], event => {
          CodeMsg::ReceiveAgentEvent(event)
        }),
      )
    CancelTurn =>
      if self.is_streaming {
        (
          {
            ..self,
            is_streaming: false,
            progress_notice: Some("Cancelling agent turn..."),
          },
          backend.effect([CancelTurn], event => {
            CodeMsg::ReceiveAgentEvent(event)
          }),
        )
      } else {
        (self, @moui.Effect::none())
      }
    SetSessionMode(mode_id) =>
      (
        {
          ..self,
          session_modes: update_session_mode_state(self.session_modes, mode_id),
        },
        backend.effect([SetSessionMode(mode_id)], event => {
          CodeMsg::ReceiveAgentEvent(event)
        }),
      )
    SetSessionConfigOption(config_id, value) =>
      (
        {
          ..self,
          session_config_options: update_session_config_option(
            self.session_config_options,
            config_id,
            value,
          ),
        },
        backend.effect([SetSessionConfigOption(config_id, value)], event => {
          CodeMsg::ReceiveAgentEvent(event)
        }),
      )
    RespondPermission(request_id, outcome) =>
      (
        {
          ..self,
          messages: mark_permission_response(self.messages, request_id, outcome),
        },
        backend.effect([RespondPermission(request_id, outcome)], event => {
          CodeMsg::ReceiveAgentEvent(event)
        }),
      )
    SubmitPrompt => {
      let task = self.prompt.trim().to_owned()
      if task.is_empty() || self.is_streaming {
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
          progress_notice: Some("Starting agent turn..."),
          error: None,
          follow_latest: true,
        }
        model.scroll_to_latest()
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
        let model = {
          ..self,
          steer_text: "",
          progress_notice: Some("Sending steering note..."),
          follow_latest: true,
        }
        model.scroll_to_latest()
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
        progress_notice: None,
        error: None,
        prompt: "",
        follow_latest: true,
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
        progress_notice: None,
        error: None,
        active_session_id: Some(id),
        follow_latest: true,
      }
      (
        model,
        backend.effect([SwitchSession(id)], event => {
          CodeMsg::ReceiveAgentEvent(event)
        }),
      )
    }
    ReceiveAgentEvent(event) =>
      match event {
        SessionListed(sessions) => {
          let model = self.apply_agent_event(event)
          match self.active_session_id {
            Some(_) => (model, @moui.Effect::none())
            None =>
              if sessions.is_empty() {
                (model, @moui.Effect::none())
              } else {
                let id = sessions[0].id
                (
                  { ..model, active_session_id: Some(id), messages: [] },
                  backend.effect([SwitchSession(id)], event => {
                    CodeMsg::ReceiveAgentEvent(event)
                  }),
                )
              }
          }
        }
        _ => (self.apply_agent_event(event), @moui.Effect::none())
      }
  }
}

///|
fn update_session_mode_state(
  state : AgentSessionModeState?,
  mode_id : String,
) -> AgentSessionModeState? {
  match state {
    Some(s) => Some({ ..s, current_mode_id: mode_id })
    None => None
  }
}

///|
fn update_session_config_option(
  options : Array[AgentSessionConfigOption],
  config_id : String,
  value : AgentConfigValue,
) -> Array[AgentSessionConfigOption] {
  let out : Array[AgentSessionConfigOption] = []
  for option in options {
    if option.id == config_id {
      out.push({ ..option, current_value: value })
    } else {
      out.push(option)
    }
  }
  out
}

///|
fn permission_outcome_label(outcome : PermissionOutcome) -> String {
  match outcome {
    Selected(option_id) => "Permission response: " + option_id
    Cancelled => "Permission cancelled"
  }
}

///|
fn mark_permission_response(
  messages : Array[ChatMessage],
  request_id : String,
  outcome : PermissionOutcome,
) -> Array[ChatMessage] {
  let out : Array[ChatMessage] = []
  let label = permission_outcome_label(outcome)
  for msg in messages {
    match msg {
      PermissionRequest(req) =>
        if req.request_id == request_id {
          out.push(ChatMessage::RuntimeNotice(label))
        } else {
          out.push(msg)
        }
      _ => out.push(msg)
    }
  }
  out
}

// ---------------------------------------------------------------------------
// Settings workspace sub-update
// ---------------------------------------------------------------------------

///|
/// The settings workspace sub-update (form fields and section navigation).
fn SettingsWorkspace::update(
  self : SettingsWorkspace,
  msg : SettingsMsg,
) -> (SettingsWorkspace, @moui.Effect[SettingsMsg]) {
  match msg {
    SelectSection(section) => {
      self.scroll_state.scroll_to(x=0.0, y=0.0)
      (
        { ..self, active_section: section, save_notice: None },
        @moui.Effect::none(),
      )
    }
    BackendChanged(kind) =>
      ({ ..self, agent_backend: kind, save_notice: None }, @moui.Effect::none())
    ApprovalChanged(policy) =>
      (
        { ..self, approval_policy: policy, save_notice: None },
        @moui.Effect::none(),
      )
    SandboxChanged(mode) =>
      ({ ..self, sandbox_mode: mode, save_notice: None }, @moui.Effect::none())
    WorkingDirChanged(value) =>
      ({ ..self, working_dir: value, save_notice: None }, @moui.Effect::none())
    SessionRootChanged(value) =>
      ({ ..self, session_root: value, save_notice: None }, @moui.Effect::none())
    AcpCommandChanged(value) =>
      ({ ..self, acp_command: value, save_notice: None }, @moui.Effect::none())
    AcpArgsChanged(value) =>
      ({ ..self, acp_args: value, save_notice: None }, @moui.Effect::none())
    AcpProcessCwdChanged(value) =>
      (
        { ..self, acp_process_cwd: value, save_notice: None },
        @moui.Effect::none(),
      )
    FontSizeChanged(size) => {
      let clamped = if size < 10 { 10 } else if size > 24 { 24 } else { size }
      ({ ..self, font_size: clamped, save_notice: None }, @moui.Effect::none())
    }
    SelectProvider(id) =>
      (
        { ..self, active_provider_id: Some(id), save_notice: None },
        @moui.Effect::none(),
      )
    AddProvider => {
      let id = next_provider_id(self.providers)
      let np = ProviderConfig::new(
        id~,
        name=next_provider_name(self.providers),
        base_url="https://api.openai.com/v1",
        api_key="",
        models=[],
      )
      (
        {
          ..self,
          providers: self.providers + [np],
          active_provider_id: Some(id),
          save_notice: None,
          detect_error: None,
          new_model_id: "",
        },
        @moui.Effect::none(),
      )
    }
    UpdateProviderField(id, field, value) =>
      (
        {
          ..self,
          providers: update_provider_field(self.providers, id, field, value),
          save_notice: None,
        },
        @moui.Effect::none(),
      )
    RemoveProvider(id) =>
      if self.providers.length() <= 1 {
        (self, @moui.Effect::none())
      } else {
        let providers2 = self.providers.filter(fn(p) { p.id != id })
        let first_id = if providers2.is_empty() {
          None
        } else {
          Some(providers2[0].id)
        }
        let active = match self.active_provider_id {
          Some(a) => if a == id { first_id } else { Some(a) }
          None => first_id
        }
        (
          {
            ..self,
            providers: providers2,
            active_provider_id: active,
            save_notice: None,
          },
          @moui.Effect::none(),
        )
      }
    AddManualModel(id, model_id) =>
      (
        {
          ..self,
          providers: add_manual_model(self.providers, id, model_id),
          new_model_id: "",
          save_notice: None,
        },
        @moui.Effect::none(),
      )
    NewModelInputChanged(value) =>
      ({ ..self, new_model_id: value }, @moui.Effect::none())
    DetectModels(_) | ModelsDetected(_, _) => (self, @moui.Effect::none())
    AppearanceChanged(_) | SaveToDisk => (self, @moui.Effect::none())
    DismissSaveNotice => ({ ..self, save_notice: None }, @moui.Effect::none())
  }
}

///|
fn pick_workspace_folder_effect(
  services : @services.AppServices,
) -> @moui.Effect[CodeMsg] {
  services
  .files()
  .pick_directory(
    options=@services.FileDialogOptions::new(title="选择文件夹"),
  )
  .effect(map=result => {
    match result {
      Success(path) => CodeMsg::WorkspaceFolderSelected(Some(path))
      Cancelled => CodeMsg::WorkspaceFolderSelected(None)
      Failure(error) => CodeMsg::WorkspaceFolderPickFailed(error.message)
    }
  })
}
