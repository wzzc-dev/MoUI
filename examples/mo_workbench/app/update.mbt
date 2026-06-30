// Update loop: pure Model/Msg transitions + backend effect dispatch.

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
    SessionListed(_) => ([], false, None) // handled directly in update
    ActiveSessionChanged(_) => ([], false, None) // handled directly in update
  }
}

///|
/// The main update function.
fn WorkbenchModel::update(
  self : WorkbenchModel,
  msg : WorkbenchMsg,
) -> (WorkbenchModel, @moui.Effect[WorkbenchMsg]) {
  match msg {
    PromptChanged(value) => ({ ..self, prompt: value }, @moui.Effect::none())
    SteerChanged(value) => ({ ..self, steer_text: value }, @moui.Effect::none())
    ClearError => ({ ..self, error: None }, @moui.Effect::none())
    ToggleAppearance => {
      let next = match self.appearance {
        System => Light
        Light => Dark
        Dark => System
      }
      ({ ..self, appearance: next }, @moui.Effect::none())
    }
    ModelChanged(model) => {
      let model = (
        { ..self, current_model: model },
        self.backend.effect([SetModel(model)], event => ReceiveAgentEvent(event)),
      )
      model
    }
    ThinkingChanged(thinking) => {
      let model = (
        { ..self, current_thinking: thinking },
        self.backend.effect([SetThinking(thinking)], event => {
          ReceiveAgentEvent(event)
        }),
      )
      model
    }
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
          self.backend.effect([SendTask(task)], event => {
            ReceiveAgentEvent(event)
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
          self.backend.effect([Steer(text)], event => ReceiveAgentEvent(event)),
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
        self.backend.effect([NewSession(name_prefix)], event => {
          ReceiveAgentEvent(event)
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
        self.backend.effect([SwitchSession(id)], event => {
          ReceiveAgentEvent(event)
        }),
      )
    }
    ReceiveAgentEvent(event) =>
      match event {
        SessionListed(sessions) => ({ ..self, sessions, }, @moui.Effect::none())
        ActiveSessionChanged(id) =>
          ({ ..self, active_session_id: Some(id) }, @moui.Effect::none())
        SessionRebuilt(items) => {
          // Replace the whole message list.
          let rebuilt : Array[ChatMessage] = []
          for item in items {
            let (msgs, _, _) = project_agent_event(item)
            for m in msgs {
              rebuilt.push(m)
            }
          }
          ({ ..self, messages: rebuilt }, @moui.Effect::none())
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
          (model, @moui.Effect::none())
        }
      }
  }
}
