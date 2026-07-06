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
    TurnTerminal(status, message) => {
      let err = match status {
        Failed => Some(message)
        Aborted => Some(message)
        _ => None
      }
      ([ChatMessage::Terminal(status, message)], true, err)
    }
    ProgressNotice(_) => ([], false, None) // handled directly in apply_agent_event
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
      { ..self, messages: rebuilt, progress_notice: None }
    }
    ProgressNotice(text) => { ..self, progress_notice: Some(text) }
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
    ModelChanged(provider_id, model_id) =>
      // The shell intercepts `ModelChanged` to also dispatch the backend
      // `SetModel` with the provider's live connection; this arm keeps the
      // code model in sync if reached directly.
      (
        {
          ..self,
          current_model: model_id,
          current_provider_id: Some(provider_id),
          model_picker_open: false,
        },
        @moui.Effect::none(),
      )
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
        let model = {
          ..self,
          steer_text: "",
          progress_notice: Some("Sending steering note..."),
        }
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
fn dispatch_workspace_folder_response(
  response : @host.HostServiceResponse,
  dispatch : (CodeMsg) -> Unit,
) -> Unit {
  match response {
    @host.HostServiceResponse::FileDialogSelection(paths) =>
      if paths.is_empty() {
        dispatch(CodeMsg::WorkspaceFolderSelected(None))
      } else {
        dispatch(CodeMsg::WorkspaceFolderSelected(Some(paths[0])))
      }
    @host.HostServiceResponse::Unavailable(reason) =>
      dispatch(CodeMsg::WorkspaceFolderPickFailed(reason))
    _ => ()
  }
}

///|
fn pick_workspace_folder_effect(
  services : @host.HostAppServices,
) -> @moui.Effect[CodeMsg] {
  @moui.Effect::host_service(
    key="mo-workbench:pick-workspace-folder",
    label="Pick workspace folder",
    run=dispatch => {
      let response = services.pick_directory(title="选择文件夹")
      match response {
        @host.HostServiceResponse::Pending(id) =>
          ignore(
            services.on_completed(id, completion => {
              dispatch_workspace_folder_response(completion.response, dispatch)
            }),
          )
        _ => dispatch_workspace_folder_response(response, dispatch)
      }
    },
  )
}

// ---------------------------------------------------------------------------
// Task projection sync
// ---------------------------------------------------------------------------

///|
/// Rebuild the `task_tree` UI projection from `code.sessions`. Called after
/// any `CodeMsg` (and after `NewTask` / `SelectTask`) so the sidebar task tree
/// always reflects the current session list, active id, and streaming state.
/// The single source of truth remains `code.sessions`; `task_tree` is a
/// derived view that never needs independent mutation.
///
/// Sessions are grouped under folder nodes (one per top-level task group).
/// Folder expanded state is preserved from the previous `task_tree` when
/// available; new folders default to expanded.
fn sync_task_tree(model : WorkbenchModel) -> WorkbenchModel {
  let active_id = model.code.active_session_id
  let streaming = model.code.is_streaming
  let messages = model.code.messages
  // Build task leaves grouped by their group.
  let today_tasks : Array[TaskTreeNode] = []
  let yesterday_tasks : Array[TaskTreeNode] = []
  let earlier_tasks : Array[TaskTreeNode] = []
  for s in model.code.sessions {
    let title = if s.first_prompt == "" { "New task" } else { s.first_prompt }
    let group = derive_group(s.last_active_unix_seconds)
    let status = derive_task_status(s.id, active_id, streaming, messages)
    if !task_matches_filter(model.task_filter, s.id, status, active_id) {
      continue
    }
    if !task_matches_search(model.task_search_query, s.id, title) {
      continue
    }
    let node = TaskTreeNode::Task(s.id, title, group, status, 0)
    match group {
      Today => today_tasks.push(node)
      Yesterday => yesterday_tasks.push(node)
      Earlier => earlier_tasks.push(node)
    }
  }
  // Build folder nodes preserving expanded state from previous tree.
  let tree : Array[TaskTreeNode] = []
  if !today_tasks.is_empty() {
    let expanded = folder_was_expanded(model.task_tree, "folder_today")
    tree.push(
      TaskTreeNode::Folder(
        "folder_today",
        "Today",
        TaskGroup::Today,
        today_tasks,
        expanded,
      ),
    )
  }
  if !yesterday_tasks.is_empty() {
    let expanded = folder_was_expanded(model.task_tree, "folder_yesterday")
    tree.push(
      TaskTreeNode::Folder(
        "folder_yesterday",
        "Yesterday",
        TaskGroup::Yesterday,
        yesterday_tasks,
        expanded,
      ),
    )
  }
  if !earlier_tasks.is_empty() {
    let expanded = folder_was_expanded(model.task_tree, "folder_earlier")
    tree.push(
      TaskTreeNode::Folder(
        "folder_earlier",
        "Earlier",
        TaskGroup::Earlier,
        earlier_tasks,
        expanded,
      ),
    )
  }
  { ..model, task_tree: tree }
}

///|
/// Check whether a folder id was expanded in the previous tree.
fn folder_was_expanded(
  prev_tree : Array[TaskTreeNode],
  folder_id : String,
) -> Bool {
  for node in prev_tree {
    match node {
      Folder(id, _, _, _, expanded) => if id == folder_id { return expanded }
      _ => ()
    }
  }
  true // new folders default to expanded
}

///|
/// Toggle the expanded state of a folder in the task tree.
fn toggle_folder_expanded(
  tree : Array[TaskTreeNode],
  folder_id : String,
) -> Array[TaskTreeNode] {
  let result : Array[TaskTreeNode] = []
  for node in tree {
    result.push(
      match node {
        Folder(id, title, group, children, expanded) =>
          if id == folder_id {
            Folder(id, title, group, children, !expanded)
          } else {
            node
          }
        _ => node
      },
    )
  }
  result
}

///|
fn next_task_filter(filter : TaskFilter) -> TaskFilter {
  match filter {
    AllTasks => ActiveTask
    ActiveTask => RunningTasks
    RunningTasks => FailedTasks
    FailedTasks => AllTasks
  }
}

///|
fn task_matches_filter(
  filter : TaskFilter,
  id : String,
  status : TaskStatus,
  active_id : String?,
) -> Bool {
  match filter {
    AllTasks => true
    ActiveTask =>
      match active_id {
        Some(aid) => aid == id
        None => false
      }
    RunningTasks => status == TaskStatus::Running
    FailedTasks => status == TaskStatus::Failed
  }
}

///|
fn task_matches_search(query : String, id : String, title : String) -> Bool {
  let needle = query.trim().to_lower()
  if needle.is_empty() {
    true
  } else {
    title.to_lower().contains(needle) || id.to_lower().contains(needle)
  }
}

///|
/// Derive the time-based group for a task. The portable app package has no
/// wall-clock source, so all tasks currently group under `Today`. Refine once
/// a time injection (e.g. via ViewEnvironment or a backend-provided "now"
/// value) is wired in.
fn derive_group(_last_active : Int64?) -> TaskGroup {
  TaskGroup::Today
}

///|
/// Derive the lifecycle status of a task from the active session id, the
/// streaming flag, and the active session's message tail. Non-active sessions
/// are assumed completed (prior turns finished), since only the active
/// session's messages are held in memory.
fn derive_task_status(
  id : String,
  active_id : String?,
  streaming : Bool,
  messages : Array[ChatMessage],
) -> TaskStatus {
  let is_active = match active_id {
    Some(aid) => aid == id
    None => false
  }
  if is_active && streaming {
    TaskStatus::Running
  } else if is_active && messages.is_empty() {
    TaskStatus::Pending
  } else if is_active {
    // Inspect the active session's message tail for a terminal status.
    let tail = messages[messages.length() - 1]
    match tail {
      Terminal(TurnStatus::Failed, _) => TaskStatus::Failed
      _ => TaskStatus::Completed
    }
  } else {
    // Non-active sessions: assume completed (prior turns finished).
    TaskStatus::Completed
  }
}

///|
/// The shell update. Routes tab-scoped / task-scoped messages at the shell
/// level and delegates `CodeMsg` / `SettingsMsg` to the matching sub-update,
/// lifting sub-effects back to `Effect[WorkbenchMsg]`. After any `CodeMsg`
/// (which may change sessions / streaming state) the task tree projection is
/// re-synced via `sync_task_tree`.
fn WorkbenchModel::update(
  self : WorkbenchModel,
  msg : WorkbenchMsg,
) -> (WorkbenchModel, @moui.Effect[WorkbenchMsg]) {
  match msg {
    SwitchTab(tab) => ({ ..self, active_tab: tab }, @moui.Effect::none())
    ToggleSidebar =>
      ({ ..self, sidebar_visible: !self.sidebar_visible }, @moui.Effect::none())
    NewTask => {
      // Delegate to the code workspace's NewSession, switch to the Code tab
      // so the new task's chat surface is visible, and re-sync task tree.
      let (code, eff) = self.code.update(CodeMsg::NewSession, self.backend)
      let model = { ..self, code, active_tab: TopTab::Code }
      (sync_task_tree(model), eff.map(m => WorkbenchMsg::CodeMsg(m)))
    }
    SelectTask(id) => {
      // Delegate to the code workspace's SelectSession, switch to Code, sync.
      let (code, eff) = self.code.update(
        CodeMsg::SelectSession(id),
        self.backend,
      )
      let model = { ..self, code, active_tab: TopTab::Code }
      (sync_task_tree(model), eff.map(m => WorkbenchMsg::CodeMsg(m)))
    }
    ToggleFolder(folder_id) =>
      (
        { ..self, task_tree: toggle_folder_expanded(self.task_tree, folder_id) },
        @moui.Effect::none(),
      )
    CycleTaskFilter =>
      (
        sync_task_tree({
          ..self,
          task_filter: next_task_filter(self.task_filter),
        }),
        @moui.Effect::none(),
      )
    ShowAllTasks =>
      (
        sync_task_tree({ ..self, task_filter: TaskFilter::AllTasks }),
        @moui.Effect::none(),
      )
    ShowRunningTasks =>
      (
        sync_task_tree({ ..self, task_filter: TaskFilter::RunningTasks }),
        @moui.Effect::none(),
      )
    ShowFailedTasks =>
      (
        sync_task_tree({ ..self, task_filter: TaskFilter::FailedTasks }),
        @moui.Effect::none(),
      )
    TaskSearchChanged(query) =>
      (
        sync_task_tree({ ..self, task_search_query: query }),
        @moui.Effect::none(),
      )
    ToggleSettings =>
      ({ ..self, settings_open: !self.settings_open }, @moui.Effect::none())
    ToggleAppearance => {
      let next = match self.appearance {
        System => Light
        Light => Dark
        Dark => System
      }
      ({ ..self, appearance: next }, @moui.Effect::none())
    }
    CodeMsg(m) =>
      match m {
        SelectProvider(provider_id) => {
          // Switch the active provider from the chat picker. Keep the model in
          // sync (fall back to the provider's first model when the current one
          // is not offered) and re-point the backend connection live.
          let settings = self.settings.update(
              SettingsMsg::SelectProvider(provider_id),
            ).0
          let provider = settings.find_provider(provider_id)
          let (api_key, base_url) = match provider {
            Some(p) => (p.api_key, p.base_url)
            None => ("", "")
          }
          let code = match provider {
            Some(p) => {
              let model_id = if p.models.contains(self.code.current_model) {
                self.code.current_model
              } else if p.models.is_empty() {
                self.code.current_model
              } else {
                p.models[0]
              }
              {
                ..self.code,
                current_provider_id: Some(provider_id),
                current_model: model_id,
                model_picker_open: false,
              }
            }
            None =>
              {
                ..self.code,
                current_provider_id: Some(provider_id),
                model_picker_open: false,
              }
          }
          let eff = self.backend.effect(
            [SetModel(code.current_model, api_key, base_url)],
            event => CodeMsg::ReceiveAgentEvent(event),
          )
          (
            sync_task_tree({ ..self, settings, code }),
            eff.map(m => WorkbenchMsg::CodeMsg(m)),
          )
        }
        ModelChanged(provider_id, model_id) => {
          // Resolve the provider's live connection and switch both the model
          // and the backend endpoint in one backend command.
          let provider = self.settings.find_provider(provider_id)
          let (api_key, base_url) = match provider {
            Some(p) => (p.api_key, p.base_url)
            None => ("", "")
          }
          let code = {
            ..self.code,
            current_model: model_id,
            current_provider_id: Some(provider_id),
            model_picker_open: false,
          }
          let eff = self.backend.effect(
            [SetModel(model_id, api_key, base_url)],
            event => CodeMsg::ReceiveAgentEvent(event),
          )
          (
            sync_task_tree({ ..self, code, }),
            eff.map(m => WorkbenchMsg::CodeMsg(m)),
          )
        }
        PickWorkspaceFolder =>
          (
            self,
            pick_workspace_folder_effect(self.host_services).map(m => {
              WorkbenchMsg::CodeMsg(m)
            }),
          )
        WorkspaceFolderSelected(path) =>
          match path {
            Some(raw) => {
              let folder = raw.trim().to_owned()
              if folder.is_empty() {
                (self, @moui.Effect::none())
              } else {
                let settings = {
                  ..self.settings,
                  working_dir: folder,
                  save_notice: None,
                }
                match self.settings_persist {
                  Some(persist) =>
                    persist(
                      mo_workbench_settings_file_from_workspace(
                        settings,
                        self.appearance,
                        self.code.current_model,
                      ),
                    )
                  None => ()
                }
                (
                  { ..self, settings, code: { ..self.code, error: None } },
                  @moui.Effect::none(),
                )
              }
            }
            None => (self, @moui.Effect::none())
          }
        WorkspaceFolderPickFailed(reason) =>
          (
            {
              ..self,
              code: {
                ..self.code,
                error: Some("选择文件夹失败：" + reason),
              },
            },
            @moui.Effect::none(),
          )
        _ => {
          let (code, eff) = self.code.update(m, self.backend)
          // Re-sync the task tree projection then lift `Effect[CodeMsg]` to
          // `Effect[WorkbenchMsg]` via `Effect::map`.
          (
            sync_task_tree({ ..self, code, }),
            eff.map(m => WorkbenchMsg::CodeMsg(m)),
          )
        }
      }
    SettingsMsg(m) =>
      match m {
        AppearanceChanged(mode) => {
          let (settings, eff) = self.settings.update(m)
          (
            { ..self, settings, appearance: mode },
            eff.map(msg => WorkbenchMsg::SettingsMsg(msg)),
          )
        }
        DetectModels(provider_id) => {
          let settings = {
            ..self.settings,
            detect_busy: true,
            detect_error: None,
          }
          let base_url = match self.settings.find_provider(provider_id) {
            Some(p) => p.base_url
            None => ""
          }
          let api_key = match self.settings.find_provider(provider_id) {
            Some(p) => p.api_key
            None => ""
          }
          let run_detect = fn(dispatch : (WorkbenchMsg) -> Unit) {
            let on_result = fn(result : Array[String]?) {
              dispatch(
                WorkbenchMsg::SettingsMsg(
                  SettingsMsg::ModelsDetected(provider_id, result),
                ),
              )
            }
            match self.model_detect {
              Some(detect) => detect(base_url, api_key, on_result)
              None => on_result(None)
            }
          }
          let eff = @moui.Effect::run(
            key="model-detect:" + provider_id,
            kind="model-detect",
            label="Detect models",
            run=run_detect,
          )
          ({ ..self, settings, }, eff)
        }
        ModelsDetected(provider_id, result) => {
          let (providers2, detect_error) = match result {
            Some(ids) =>
              (
                replace_provider_models(
                  self.settings.providers,
                  provider_id,
                  ids,
                ),
                None,
              )
            None =>
              (
                self.settings.providers,
                Some(
                  "自动检测失败：请检查 Base URL 与 API Key，或在下方手动添加模型。",
                ),
              )
          }
          let settings = {
            ..self.settings,
            providers: providers2,
            detect_busy: false,
            detect_error,
          }
          ({ ..self, settings, }, @moui.Effect::none())
        }
        SaveToDisk =>
          match self.settings_persist {
            Some(persist) => {
              let file = mo_workbench_settings_file_from_workspace(
                self.settings,
                self.appearance,
                self.code.current_model,
              )
              persist(file)
              let settings = {
                ..self.settings,
                save_notice: Some("Saved to .mo_workbench/settings.json"),
                env_source: ".mo_workbench/settings.json",
              }
              ({ ..self, settings, }, @moui.Effect::none())
            }
            None => {
              let settings = {
                ..self.settings,
                save_notice: Some(
                  "Saving is available in the native macOS app only.",
                ),
              }
              ({ ..self, settings, }, @moui.Effect::none())
            }
          }
        _ => {
          let (settings, eff) = self.settings.update(m)
          (
            { ..self, settings, },
            eff.map(msg => WorkbenchMsg::SettingsMsg(msg)),
          )
        }
      }
  }
}
