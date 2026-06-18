///|
fn WorkbenchModel::session_status_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let active = self.active_session()
  let binding = self.active_agent_session_binding()
  let rows : Array[@moui.View[WorkbenchMsg]] = [
    row(
      [
        text(
          "当前任务",
          role=Control,
          theme~,
          width=workbench_max_double(1.0, layout.panel_body_width - 212.0),
          height=28.0,
        ),
        session_status_badge(active.status, theme),
        count_badge(
          self.pending_transport_count(),
          label=self.pending_transport_count().to_string() + " 排队",
          tone=Neutral,
          theme~,
          width=104.0,
        ),
      ],
      spacing=8.0,
      align=Center,
    ),
  ]
  if active.active_task != "" {
    rows.push(
      text(
        active.active_task,
        role=Body,
        theme~,
        width=layout.panel_body_width,
        height=28.0,
      ),
    )
  }
  if !self.plan.is_empty() {
    rows.push(plan_progress_row(self.plan, layout, theme))
  }
  if self.has_runtime_signal() {
    rows.push(self.runtime_signal_row(layout, theme))
  }
  match self.next_action() {
    Some(action) => rows.push(next_action_row(action, layout, theme))
    None => ()
  }
  if self.should_show_session_detail_rows() {
    let models = self.active_agent_model_catalog()
    let metrics = self.active_agent_session_metrics()
    if metrics.has_visible_metrics() {
      rows.push(session_stats_row(metrics, layout, theme))
    }
    if models.length() > 0 {
      rows.push(model_catalog_row(models, layout, theme))
    }
    if binding.has_visible_binding() {
      rows.push(session_binding_row(binding, layout, theme))
    }
    if self.has_session_panel_controls() {
      rows.push(self.session_controls_row(layout, theme))
    }
  }
  surface(
    column(rows, spacing=6.0, align=Start),
    width=layout.panel_width,
    height=session_status_panel_height(self.session_status_row_count()),
    background=workbench_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  ).border(workbench_hairline_border(theme))
}

///|
fn WorkbenchModel::session_status_row_count(self : WorkbenchModel) -> Int {
  let active = self.active_session()
  let binding = self.active_agent_session_binding()
  let mut count = 1
  if active.active_task != "" {
    count = count + 1
  }
  if !self.plan.is_empty() {
    count = count + 1
  }
  if self.has_runtime_signal() {
    count = count + 1
  }
  match self.next_action() {
    Some(_) => count = count + 1
    None => ()
  }
  if self.should_show_session_detail_rows() {
    let models = self.active_agent_model_catalog()
    let metrics = self.active_agent_session_metrics()
    if metrics.has_visible_metrics() {
      count = count + 1
    }
    if models.length() > 0 {
      count = count + 1
    }
    if binding.has_visible_binding() {
      count = count + 1
    }
    if self.has_session_panel_controls() {
      count = count + 1
    }
  }
  count
}

///|
fn session_status_badge(
  status : String,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  if should_show_session_status_meta(status) {
    badge(
      session_status_label(status),
      tone=session_status_tone(status),
      theme~,
      width=92.0,
    )
  } else {
    blank_cell(width=92.0, height=24.0)
  }
}

///|
fn WorkbenchModel::should_show_session_detail_rows(
  self : WorkbenchModel,
) -> Bool {
  let binding = self.active_agent_session_binding()
  self.composer_controls_expanded &&
  (
    self.active_agent_session_metrics().has_visible_metrics() ||
    self.active_agent_model_catalog().length() > 0 ||
    binding.has_visible_binding() ||
    self.has_session_panel_controls()
  )
}

///|
fn session_status_panel_height(row_count : Int) -> Double {
  54.0 + (row_count - 1).max(0).to_double() * 42.0
}

///|
fn session_status_label(status : String) -> String {
  match status {
    "active" => "活跃"
    "queued" => "排队"
    "running" => "运行中"
    "waiting" => "等待"
    "idle" => "空闲"
    "failed" => "失败"
    _ => status
  }
}

///|
fn session_status_tone(status : String) -> @views.BadgeTone {
  match status {
    "running" | "active" => Success
    "queued" => Accent
    "waiting" => Warning
    "failed" => Danger
    _ => Neutral
  }
}

///|
fn WorkbenchModel::next_action(self : WorkbenchModel) -> WorkbenchNextAction? {
  let session = self.active_session()
  if self.has_cancel_target() {
    return Some({
      title: "等待 Agent 完成当前运行",
      detail: current_run_detail(session, self.last_status),
      primary_label: "停止",
      primary_message: CancelRun,
      secondary_label: "",
      secondary_message: None,
      tone: Warning,
    })
  }
  match self.latest_failed_command() {
    Some(command) =>
      return Some({
        title: "修复失败命令",
        detail: failed_command_next_action_detail(command),
        primary_label: "修复",
        primary_message: FixCommandRun(
          command.command,
          command_status_context(command),
          command.cwd,
          command.output_path,
        ),
        secondary_label: "重跑",
        secondary_message: Some(QueueCommand(command.command)),
        tone: Danger,
      })
    None => ()
  }
  if !self.diagnostics.is_empty() {
    let diagnostic = self.diagnostics[self.diagnostics.length() - 1]
    return Some({
      title: if diagnostic_is_agent_intervention(diagnostic) {
        "处理 Agent 请求"
      } else {
        "修复最新诊断"
      },
      detail: diagnostic_detail_label(diagnostic),
      primary_label: if diagnostic_is_agent_intervention(diagnostic) {
        "处理"
      } else {
        "修复"
      },
      primary_message: FixDiagnostic(
        diagnostic.source,
        diagnostic.severity,
        diagnostic.message,
      ),
      secondary_label: "清除",
      secondary_message: Some(ClearDiagnostics),
      tone: Warning,
    })
  }
  match self.current_plan_action_step() {
    Some(step) =>
      return Some({
        title: "继续当前计划",
        detail: plan_step_detail_label(step),
        primary_label: "继续",
        primary_message: FollowActivity("plan", step.title, step.detail),
        secondary_label: "",
        secondary_message: None,
        tone: plan_step_tone(step.status),
      })
    None => ()
  }
  if self.diff.has_context() {
    return Some({
      title: "审核当前变更",
      detail: diff_next_action_detail(self.diff),
      primary_label: "审核",
      primary_message: ReviewDiff,
      secondary_label: "",
      secondary_message: None,
      tone: Accent,
    })
  }
  if !self.files.is_empty() {
    let file = self.files[self.files.length() - 1]
    return Some({
      title: "聚焦文件证据",
      detail: file.path,
      primary_label: "聚焦",
      primary_message: InspectFile(file.path),
      secondary_label: "",
      secondary_message: None,
      tone: Neutral,
    })
  }
  None
}

///|
fn WorkbenchModel::current_plan_action_step(self : WorkbenchModel) -> PlanStep? {
  current_plan_step(self.plan)
}

///|
fn WorkbenchModel::latest_failed_command(self : WorkbenchModel) -> CommandRun? {
  let mut failed : CommandRun? = None
  for command in self.commands {
    if command.status == "failed" {
      failed = Some(command)
    }
  }
  failed
}

///|
fn current_run_detail(session : WorkbenchSession, fallback : String) -> String {
  if session.active_task != "" {
    session.active_task
  } else {
    fallback
  }
}

///|
fn diagnostic_detail_label(diagnostic : DiagnosticItem) -> String {
  let source = diagnostic.source.trim().to_owned()
  let message = diagnostic.message.trim().to_owned()
  if source == "" {
    message
  } else if message == "" {
    source
  } else {
    source + ": " + message
  }
}

///|
fn diagnostic_is_agent_intervention(diagnostic : DiagnosticItem) -> Bool {
  diagnostic.source == "Agent approval" ||
  diagnostic.source == "Agent permission" ||
  diagnostic.source == "Agent input" ||
  diagnostic.source == "Agent intervention"
}

///|
fn failed_command_next_action_detail(command : CommandRun) -> String {
  let parts : Array[String] = []
  match command.exit_code {
    Some(code) => parts.push("退出码 " + code.to_string())
    None => ()
  }
  if command_has_output_details(command) {
    parts.push(command_output_available_label(command))
  }
  if parts.is_empty() {
    parts.push(command_status_label(command.status))
  }
  let evidence = parts.join(" · ")
  let command_label = compact_label(command.command, max_chars=44)
  if command_label == "" {
    evidence
  } else {
    command_label + " · " + evidence
  }
}

///|
fn diff_next_action_detail(diff : DiffOverview) -> String {
  diff.status_label() +
  " · " +
  diff.changed_files.to_string() +
  " 文件 · +" +
  diff.additions.to_string() +
  " -" +
  diff.deletions.to_string()
}

///|
fn next_action_row(
  action : WorkbenchNextAction,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let detail_width = workbench_max_double(
    1.0,
    layout.panel_body_width - 66.0 - 68.0 - 58.0 - 32.0,
  )
  row(
    [
      badge("下一步", tone=action.tone, theme~, width=66.0),
      column(
        [
          text(
            action.title,
            role=Control,
            theme~,
            width=detail_width,
            height=24.0,
          ),
          text(
            action.detail,
            role=Caption,
            theme~,
            width=detail_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      button(
        action.primary_label,
        on_click=action.primary_message,
        variant=Outline,
        theme~,
        width=58.0,
        height=32.0,
      ),
      secondary_next_action_button(action, theme),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn secondary_next_action_button(
  action : WorkbenchNextAction,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  match action.secondary_message {
    Some(message) =>
      button(
        action.secondary_label,
        on_click=message,
        variant=Ghost,
        theme~,
        width=58.0,
        height=32.0,
      )
    None => blank_cell(width=58.0, height=32.0)
  }
}

///|
fn plan_progress_row(
  steps : Array[PlanStep],
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let open_count = plan_open_count(steps)
  let current = current_plan_step(steps)
  let step_title = match current {
    Some(step) => step.title
    None => "计划已完成"
  }
  let step_detail = match current {
    Some(step) => plan_step_detail_label(step)
    None => steps.length().to_string() + " 步"
  }
  let tone = match current {
    Some(step) => plan_step_tone(step.status)
    None => Success
  }
  let detail_width = workbench_max_double(
    1.0,
    layout.panel_body_width - 86.0 - 84.0 - 58.0 - 32.0,
  )
  row(
    [
      badge("当前计划", tone~, theme~, width=86.0),
      column(
        [
          text(
            step_title,
            role=Control,
            theme~,
            width=detail_width,
            height=24.0,
          ),
          text(
            step_detail,
            role=Caption,
            theme~,
            width=detail_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      count_badge(
        open_count,
        label=open_count.to_string() + " 待办",
        tone=Neutral,
        theme~,
        width=84.0,
      ),
      plan_continue_button(current, theme),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn plan_continue_button(
  step : PlanStep?,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  match step {
    Some(value) =>
      button(
        "继续",
        on_click=FollowActivity("plan", value.title, value.detail),
        variant=Outline,
        theme~,
        width=58.0,
        height=32.0,
      )
    None => blank_cell(width=58.0, height=32.0)
  }
}

///|
fn plan_step_detail_label(step : PlanStep) -> String {
  let status = plan_step_status_label(step.status)
  let detail = step.detail.trim().to_owned()
  let owner = step.owner.trim().to_owned()
  let suffix = if detail != "" {
    detail
  } else if owner != "" {
    owner
  } else {
    step.id
  }
  if suffix == "" {
    status
  } else {
    status + " · " + suffix
  }
}

///|
fn plan_step_status_label(status : String) -> String {
  match status {
    "pending" => "待办"
    "in_progress" | "running" | "active" => "进行中"
    "blocked" => "受阻"
    "done" | "completed" => "完成"
    "cancelled" => "取消"
    "skipped" => "跳过"
    _ => status
  }
}

///|
fn plan_step_tone(status : String) -> @views.BadgeTone {
  match status {
    "in_progress" | "running" | "active" => Accent
    "blocked" => Warning
    "done" | "completed" => Success
    "cancelled" | "skipped" => Neutral
    _ => Neutral
  }
}

///|
fn model_catalog_row(
  models : Array[AgentModelInfo],
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let primary = models[0]
  row(
    [
      text(
        "模型 " + models.length().to_string(),
        role=Caption,
        theme~,
        width=128.0,
        height=28.0,
      ),
      text(
        model_catalog_label(models),
        role=Caption,
        theme~,
        width=workbench_max_double(
          1.0,
          layout.panel_body_width - 128.0 - 58.0 - 58.0 - 24.0,
        ),
        height=28.0,
      ),
      button(
        "使用",
        on_click=SetModel(primary.provider, primary.id, primary.label),
        variant=Outline,
        theme~,
        width=58.0,
        height=32.0,
      ),
      button(
        "切换",
        on_click=CycleModel,
        variant=Outline,
        theme~,
        width=58.0,
        height=32.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn model_catalog_label(models : Array[AgentModelInfo]) -> String {
  if models.length() == 0 {
    ""
  } else if models.length() == 1 {
    models[0].label
  } else {
    models[0].label + " +" + (models.length() - 1).to_string()
  }
}

///|
fn WorkbenchModel::runtime_signal_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  row(
    [
      text(
        "Agent：" + self.runtime_activity_label(),
        role=Caption,
        theme~,
        width=layout.panel_body_width,
        height=30.0,
      ),
    ],
    spacing=0.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::runtime_activity_label(self : WorkbenchModel) -> String {
  self.active_agent_runtime_signal().status_label
}

///|
fn WorkbenchModel::active_agent_runtime_signal(
  self : WorkbenchModel,
) -> AgentRuntimeSignal {
  let backend = self.active_agent_backend_profile()
  if backend.uses_connector_transport() {
    let connector = self.active_agent_connector_state()
    return AgentRuntimeSignal::new(
      backend_id=backend.id,
      status_label=connector.status_label(),
      active_tool_name=if connector.has_active_transport() {
        "connector"
      } else {
        ""
      },
      message_preview=connector.last_activity,
      thinking_level=connector.profile.protocol_label,
      visible=connector.status != ConnectorDisconnected ||
        connector.last_activity != "",
      active=connector.has_active_transport(),
    )
  }
  if !backend.uses_pi_transport() {
    return AgentRuntimeSignal::new(backend_id=backend.id)
  }
  if self.pi_agent.has_visible_signal() {
    AgentRuntimeSignal::new(
      backend_id=backend.id,
      status_label=self.pi_agent.display_status_label(),
      active_tool_name=self.pi_agent.active_tool_name,
      message_preview=self.pi_agent.message_preview,
      thinking_level=self.pi_agent.thinking_level,
      visible=true,
      active=self.pi_agent.has_active_signal(),
    )
  } else {
    AgentRuntimeSignal::new(
      backend_id=backend.id,
      status_label=self.transport.agent_status_label(),
      visible=self.transport.has_visible_signal(),
      active=self.transport.has_active_signal(),
    )
  }
}

///|
fn PiTransportState::agent_status_label(self : PiTransportState) -> String {
  match self.status {
    Disconnected =>
      if self.command_queue.length() > 0 {
        "排队中"
      } else {
        "待命"
      }
    Starting => "准备中"
    Running => "运行中"
    Failed(reason) => "失败：" + reason
  }
}

///|
fn PiAgentSnapshot::display_status_label(self : PiAgentSnapshot) -> String {
  let tool = if self.active_tool_name == "" {
    ""
  } else {
    " · 工具 " + self.active_tool_name
  }
  let queue = if self.queued_steering + self.queued_follow_up == 0 {
    ""
  } else {
    " · 排队 " + (self.queued_steering + self.queued_follow_up).to_string()
  }
  pi_agent_phase_display_label(self.phase) + tool + queue
}

///|
fn pi_agent_phase_display_label(phase : String) -> String {
  match phase {
    "idle" => "空闲"
    "queue idle" => "队列空闲"
    "queue pending" => "队列等待"
    "running" => "运行中"
    "turn" => "回合中"
    "turn complete" => "回合完成"
    "message" => "消息中"
    "message complete" => "消息完成"
    "streaming" => "流式输出"
    "tool" => "工具中"
    "tool streaming" => "工具输出"
    "compacting" => "压缩中"
    "compaction complete" => "压缩完成"
    "retrying" => "重试中"
    _ => phase
  }
}

///|
fn WorkbenchModel::session_controls_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  ignore(layout)
  let capabilities = self.active_agent_backend_capabilities()
  let settings = self.active_agent_input_settings()
  let controls : Array[@moui.View[WorkbenchMsg]] = []
  if capabilities.supports_thinking_level &&
    settings.has_visible_thinking_level() {
    controls.push(self.thinking_level_cell(theme))
  }
  controls.push(spacer(min_length=4.0, weight=1.0))
  if self.has_session_action_controls() {
    if self.should_show_session_fork_action() {
      controls.push(
        button(
          "分叉",
          on_click=RefreshForkMessages,
          variant=Ghost,
          theme~,
          width=54.0,
          height=34.0,
        ),
      )
    }
    if self.should_show_session_export_action() {
      controls.push(
        button(
          "导出",
          on_click=ExportSessionHtml,
          variant=Ghost,
          theme~,
          width=54.0,
          height=34.0,
        ),
      )
    }
    if self.should_show_session_compact_action() {
      controls.push(
        button(
          "压缩",
          on_click=CompactSession,
          variant=Ghost,
          theme~,
          width=54.0,
          height=34.0,
        ),
      )
    }
    if self.should_show_session_thinking_action() {
      controls.push(
        button(
          "思考",
          on_click=CycleThinkingLevel,
          variant=Ghost,
          theme~,
          width=54.0,
          height=34.0,
        ),
      )
    }
    if self.should_show_session_name_sync_action() {
      controls.push(
        button(
          "同步名",
          on_click=SyncSessionName,
          variant=Ghost,
          theme~,
          width=66.0,
          height=34.0,
        ),
      )
    }
  }
  if self.has_cancel_target() {
    controls.push(self.cancel_run_button(theme))
  }
  row(controls, spacing=8.0, align=Center)
}

///|
fn WorkbenchModel::has_session_panel_controls(self : WorkbenchModel) -> Bool {
  let capabilities = self.active_agent_backend_capabilities()
  let settings = self.active_agent_input_settings()
  (
    capabilities.supports_thinking_level &&
    settings.has_visible_thinking_level()
  ) ||
  self.has_session_action_controls() ||
  self.has_cancel_target()
}

///|
fn WorkbenchModel::has_session_action_controls(self : WorkbenchModel) -> Bool {
  self.should_show_session_fork_action() ||
  self.should_show_session_export_action() ||
  self.should_show_session_compact_action() ||
  self.should_show_session_thinking_action() ||
  self.should_show_session_name_sync_action()
}

///|
fn WorkbenchModel::should_show_session_fork_action(
  self : WorkbenchModel,
) -> Bool {
  self.active_agent_backend_capabilities().supports_fork &&
  (!self.transcript.is_empty() || !self.fork_messages.is_empty())
}

///|
fn WorkbenchModel::should_show_session_export_action(
  self : WorkbenchModel,
) -> Bool {
  self.active_agent_backend_capabilities().supports_html_export &&
  !self.transcript.is_empty()
}

///|
fn WorkbenchModel::should_show_session_compact_action(
  self : WorkbenchModel,
) -> Bool {
  self.active_agent_backend_capabilities().supports_context_compaction &&
  self.active_agent_session_metrics().has_visible_metrics()
}

///|
fn WorkbenchModel::should_show_session_thinking_action(
  self : WorkbenchModel,
) -> Bool {
  self.active_agent_backend_capabilities().supports_thinking_level &&
  self.active_agent_input_settings().has_visible_thinking_level()
}

///|
fn WorkbenchModel::should_show_session_name_sync_action(
  self : WorkbenchModel,
) -> Bool {
  let binding = self.active_agent_session_binding()
  self.active_agent_backend_profile().uses_pi_transport() &&
  binding.has_visible_binding() &&
  (
    binding.session_name == "" ||
    binding.session_name != self.active_session().title
  )
}

///|
fn WorkbenchModel::thinking_level_cell(
  self : WorkbenchModel,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  text(
    "思考：" + self.thinking_level_label(),
    role=Caption,
    theme~,
    width=118.0,
    height=30.0,
  )
}

///|
fn WorkbenchModel::cancel_run_button(
  self : WorkbenchModel,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  if self.has_cancel_target() {
    button(
      "停止",
      on_click=CancelRun,
      variant=Ghost,
      theme~,
      width=54.0,
      height=34.0,
    )
  } else {
    blank_cell(width=54.0, height=34.0)
  }
}

///|
fn WorkbenchModel::has_runtime_signal(self : WorkbenchModel) -> Bool {
  self.active_agent_runtime_signal().has_visible_signal()
}

///|
fn WorkbenchModel::has_cancel_target(self : WorkbenchModel) -> Bool {
  self.has_active_shell_command(self.active_session()) ||
  self.active_agent_runtime_signal().has_active_signal()
}

///|
fn PiTransportState::has_visible_signal(self : PiTransportState) -> Bool {
  if self.command_queue.length() > 0 || self.last_json_line != "" {
    true
  } else {
    self.has_active_signal()
  }
}

///|
fn PiTransportState::has_active_signal(self : PiTransportState) -> Bool {
  match self.status {
    Starting | Running => true
    _ => false
  }
}

///|
fn PiAgentSnapshot::has_visible_signal(self : PiAgentSnapshot) -> Bool {
  self.phase != "idle" ||
  self.message_preview != "" ||
  self.active_tool_name != "" ||
  self.queued_steering + self.queued_follow_up > 0
}

///|
fn PiAgentSnapshot::has_active_signal(self : PiAgentSnapshot) -> Bool {
  self.phase == "running" ||
  self.phase == "turn" ||
  self.phase == "message" ||
  self.phase == "streaming" ||
  self.phase == "tool" ||
  self.phase == "tool streaming" ||
  self.phase == "compacting" ||
  self.phase == "retrying"
}

///|
fn AgentSessionBinding::has_visible_binding(self : AgentSessionBinding) -> Bool {
  self.status != "unbound" ||
  self.provider_session_id != "" ||
  self.session_file != "" ||
  self.session_name != "" ||
  self.model != "" ||
  self.last_command != ""
}

///|
fn session_binding_row(
  binding : AgentSessionBinding,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let cell_width = workbench_max_double(
    1.0,
    (layout.panel_body_width - 8.0) / 2.0,
  )
  row(
    [
      text(
        "后端会话：" + binding.display_status_label(),
        role=Caption,
        theme~,
        width=cell_width,
        height=30.0,
      ),
      session_binding_detail(binding, cell_width, theme),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn session_binding_detail(
  binding : AgentSessionBinding,
  width : Double,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let detail = session_binding_detail_label(binding)
  if detail == "" {
    blank_cell(width~, height=30.0)
  } else {
    text(detail, role=Caption, theme~, width~, height=30.0)
  }
}

///|
fn session_binding_detail_label(binding : AgentSessionBinding) -> String {
  if binding.model != "" {
    "模型：" + binding.model
  } else if binding.session_file != "" {
    "文件：" + binding.session_file
  } else {
    ""
  }
}

///|
fn AgentSessionBinding::display_status_label(
  self : AgentSessionBinding,
) -> String {
  if self.status == "unbound" {
    "未绑定"
  } else {
    let name = if self.session_name != "" {
      self.session_name
    } else if self.provider_session_id != "" {
      self.provider_session_id
    } else if self.session_file != "" {
      self.session_file
    } else {
      "provider session"
    }
    pi_session_binding_status_label(self.status) + " · " + name
  }
}

///|
fn pi_session_binding_status_label(status : String) -> String {
  match status {
    "bound" => "已绑定"
    "switching" => "切换中"
    "active" => "活跃"
    "running" => "运行中"
    _ => status
  }
}

///|
fn WorkbenchModel::thinking_level_label(self : WorkbenchModel) -> String {
  match self.active_agent_input_settings().thinking_level {
    "" | "default" => "默认"
    "low" => "低"
    "medium" => "中"
    "high" => "高"
    other => other
  }
}

///|
fn session_stats_row(
  metrics : AgentSessionMetrics,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let token_width = workbench_max_double(
    1.0,
    layout.panel_body_width - 128.0 - 108.0 - 112.0 - 24.0,
  )
  if metrics.has_visible_metrics() {
    row(
      [
        text(
          "消息 " + metrics.total_messages.to_string(),
          role=Caption,
          theme~,
          width=128.0,
          height=28.0,
        ),
        text(
          "工具 " +
          metrics.tool_calls.to_string() +
          "/" +
          metrics.tool_results.to_string(),
          role=Caption,
          theme~,
          width=108.0,
          height=28.0,
        ),
        text(
          "Token " + metrics.token_total.to_string(),
          role=Caption,
          theme~,
          width=token_width,
          height=28.0,
        ),
        session_stats_context_cell(metrics, theme),
      ],
      spacing=8.0,
      align=Center,
    )
  } else {
    blank_row(28.0)
  }
}

///|
fn session_stats_context_cell(
  metrics : AgentSessionMetrics,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  match metrics.context_percent {
    Some(percent) =>
      text(
        "上下文 " + compact_percent(percent),
        role=Caption,
        theme~,
        width=112.0,
        height=28.0,
      )
    None => blank_cell(width=112.0, height=28.0)
  }
}

///|
fn compact_percent(percent : Double) -> String {
  if percent > 0.0 && percent < 1.0 {
    "<1%"
  } else {
    percent.to_int().to_string() + "%"
  }
}

///|
fn WorkbenchModel::visible_activity_command_count(self : WorkbenchModel) -> Int {
  let focused_count = workbench_check_presets().length()
  if self.commands_end_with_focused_check_batch(focused_count) {
    focused_count
  } else {
    workbench_min_int(self.commands.length(), 3)
  }
}

///|
fn WorkbenchModel::commands_end_with_focused_check_batch(
  self : WorkbenchModel,
  focused_count : Int,
) -> Bool {
  let presets = workbench_check_presets()
  if focused_count != presets.length() || self.commands.length() < focused_count {
    false
  } else {
    let start = self.commands.length() - focused_count
    let mut matches = true
    for index in 0..<focused_count {
      if self.commands[start + index].command != presets[index].command {
        matches = false
      }
    }
    matches
  }
}

///|
fn WorkbenchModel::visible_activity_command_start(self : WorkbenchModel) -> Int {
  self.commands.length() - self.visible_activity_command_count()
}

///|
fn WorkbenchModel::should_show_focused_check_presets(
  self : WorkbenchModel,
) -> Bool {
  self.commands.is_empty() && self.visible_workspace_diagnostic_count() > 0
}

///|
fn focused_check_preset_row(
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let presets = workbench_check_presets()
  let action_count = presets.length() + 1
  let button_width = workbench_clamp_double(
    (layout.panel_body_width - 72.0 - (action_count + 1).to_double() * 8.0) /
    action_count.to_double(),
    58.0,
    112.0,
  )
  let controls : Array[@moui.View[WorkbenchMsg]] = [
    text("常用检查", role=Caption, theme~, width=72.0, height=30.0),
  ]
  controls.push(
    button(
      "全部",
      on_click=QueueFocusedChecks,
      variant=Outline,
      theme~,
      width=button_width,
      height=30.0,
    ),
  )
  for preset in presets {
    controls.push(
      button(
        preset.label,
        on_click=QueueCommand(preset.command),
        variant=Ghost,
        theme~,
        width=button_width,
        height=30.0,
      ),
    )
  }
  controls.push(spacer(min_length=8.0, weight=1.0))
  row(controls, spacing=8.0, align=Center)
}
