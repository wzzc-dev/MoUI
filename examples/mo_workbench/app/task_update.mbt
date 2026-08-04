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
  services? : @services.AppServices = @services.AppServices::unavailable(),
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
        sync_task_tree({
          ..self,
          active_tab: TopTab::Code,
          task_filter: TaskFilter::AllTasks,
        }),
        @moui.Effect::none(),
      )
    ShowRunningTasks =>
      (
        sync_task_tree({
          ..self,
          active_tab: TopTab::Code,
          task_filter: TaskFilter::RunningTasks,
        }),
        @moui.Effect::none(),
      )
    ShowFailedTasks =>
      (
        sync_task_tree({
          ..self,
          active_tab: TopTab::Code,
          task_filter: TaskFilter::FailedTasks,
        }),
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
          // Switch the active provider from the chat picker. If it exposes a
          // model OpenSeek can parse, select that model and re-point the
          // backend; otherwise keep the active backend model and leave the
          // picker open so the disabled rows remain visible.
          let settings = self.settings.update(
              SettingsMsg::SelectProvider(provider_id),
            ).0
          let provider = settings.find_provider(provider_id)
          let (api_key, base_url) = match provider {
            Some(p) => (p.api_key, p.base_url)
            None => ("", "")
          }
          match provider {
            Some(p) => {
              let current_is_supported = p.models.contains(
                  self.code.current_model,
                ) &&
                mo_workbench_model_supported_by_openseek(
                  self.code.current_model,
                )
              let selected_model = if current_is_supported {
                Some(self.code.current_model)
              } else {
                mo_workbench_first_openseek_supported_model(p.models)
              }
              match selected_model {
                Some(model_id) => {
                  let code = {
                    ..self.code,
                    current_provider_id: Some(provider_id),
                    current_model: model_id,
                    model_picker_open: false,
                  }
                  let eff = self.backend.effect(
                    [SetModel(model_id, api_key, base_url)],
                    event => CodeMsg::ReceiveAgentEvent(event),
                  )
                  (
                    sync_task_tree({ ..self, settings, code }),
                    eff.map(m => WorkbenchMsg::CodeMsg(m)),
                  )
                }
                None =>
                  (
                    sync_task_tree({
                      ..self,
                      settings,
                      code: { ..self.code, model_picker_open: true },
                    }),
                    @moui.Effect::none(),
                  )
              }
            }
            None =>
              (sync_task_tree({ ..self, settings, }), @moui.Effect::none())
          }
        }
        ModelChanged(provider_id, model_id) => {
          if !mo_workbench_model_supported_by_openseek(model_id) {
            return (self, @moui.Effect::none())
          }
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
            pick_workspace_folder_effect(services).map(m => {
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
