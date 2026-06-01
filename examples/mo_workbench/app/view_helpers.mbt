///|
using @views {
  badge,
  button,
  column,
  empty,
  row,
  scroll_view,
  spacer,
  surface,
  text,
  text_field,
}

///|
priv struct WorkbenchLayout {
  viewport : @core.Size
  sidebar_width : Double
  sidebar_inner_width : Double
  main_width : Double
  panel_width : Double
  panel_body_width : Double
  row_badge_width : Double
  row_text_width : Double
  command_text_width : Double
  diff_text_width : Double
  top_title_width : Double
  top_path_width : Double
  scroll_height : Double
  composer_width : Double
  composer_input_width : Double
}

///|
priv struct WorkbenchNextAction {
  title : String
  detail : String
  primary_label : String
  primary_message : WorkbenchMsg
  secondary_label : String
  secondary_message : WorkbenchMsg?
  tone : @views.BadgeTone
}

///|
fn workbench_layout(viewport : @core.Size) -> WorkbenchLayout {
  let viewport = @core.Size::new(
    width=workbench_max_double(1.0, viewport.width),
    height=workbench_max_double(1.0, viewport.height),
  )
  let sidebar_width = if viewport.width < 980.0 {
    workbench_clamp_double(viewport.width * 0.26, 220.0, 268.0)
  } else {
    workbench_clamp_double(viewport.width * 0.24, 276.0, 316.0)
  }
  let main_width = workbench_max_double(1.0, viewport.width - sidebar_width)
  let panel_width = workbench_clamp_double(main_width - 80.0, 480.0, 920.0)
  let panel_body_width = workbench_max_double(1.0, panel_width - 24.0)
  let row_badge_width = if panel_width < 620.0 { 88.0 } else { 104.0 }
  let row_text_width = workbench_max_double(
    220.0,
    panel_body_width - row_badge_width - 58.0 - 16.0,
  )
  let command_text_width = workbench_max_double(
    190.0,
    panel_body_width - row_badge_width - 68.0 - 54.0 - 54.0 - 40.0,
  )
  let diff_text_width = workbench_max_double(
    220.0,
    panel_body_width - 126.0 - 10.0,
  )
  let composer_width = workbench_clamp_double(main_width - 80.0, 480.0, 900.0)
  {
    viewport,
    sidebar_width,
    sidebar_inner_width: workbench_max_double(160.0, sidebar_width - 28.0),
    main_width,
    panel_width,
    panel_body_width,
    row_badge_width,
    row_text_width,
    command_text_width,
    diff_text_width,
    top_title_width: workbench_clamp_double(main_width * 0.30, 180.0, 360.0),
    top_path_width: workbench_clamp_double(main_width * 0.34, 180.0, 420.0),
    scroll_height: workbench_max_double(240.0, viewport.height - 175.0),
    composer_width,
    composer_input_width: workbench_max_double(1.0, composer_width - 24.0),
  }
}

///|
fn workbench_clamp_double(value : Double, min : Double, max : Double) -> Double {
  workbench_min_double(max, workbench_max_double(min, value))
}

///|
fn workbench_max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn workbench_min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn WorkbenchModel::view(self : WorkbenchModel) -> @core.View[WorkbenchMsg] {
  self.view_for_size(@core.Size::new(width=1220.0, height=780.0))
}

///|
fn WorkbenchModel::view_with_environment(
  self : WorkbenchModel,
  env : @core.ViewEnvironment,
) -> @core.View[WorkbenchMsg] {
  self.view_for_size(env.viewport_size())
}

///|
fn WorkbenchModel::view_for_size(
  self : WorkbenchModel,
  viewport : @core.Size,
) -> @core.View[WorkbenchMsg] {
  let theme = @views.light_theme()
  let layout = workbench_layout(viewport)
  surface(
    row(
      [
        self.app_sidebar(layout, theme),
        self.conversation_surface(layout, theme),
      ],
      spacing=0.0,
      align=Stretch,
    ),
    width=layout.viewport.width,
    height=layout.viewport.height,
    background=ui_color(0.98, 0.98, 0.97),
    corner_radius=0.0,
    theme~,
    padding=0.0,
  )
}

///|
fn WorkbenchModel::app_sidebar(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        self.sidebar_brand(layout, theme),
        self.sidebar_section_label("会话", layout, theme),
        self.pinned_threads(layout, theme),
        self.sidebar_section_label("工作区", layout, theme),
        self.workspace_summary(layout, theme),
        spacer(min_length=8.0, weight=1.0),
        self.sidebar_footer(layout, theme),
      ],
      spacing=theme.spacing_scale.sm,
      align=Stretch,
    ),
    width=layout.sidebar_width,
    height=layout.viewport.height,
    background=ui_color(0.91, 0.92, 0.92),
    corner_radius=0.0,
    theme~,
    padding=14.0,
  )
}

///|
fn WorkbenchModel::sidebar_brand(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  column(
    [
      text(
        "Mo Workbench",
        role=Title,
        theme~,
        width=layout.sidebar_inner_width,
        height=34.0,
      ),
      text(
        "Pi agent 桌面工作台",
        role=Caption,
        theme~,
        width=layout.sidebar_inner_width,
        height=24.0,
      ),
    ],
    spacing=0.0,
    align=Start,
  )
}

///|
fn WorkbenchModel::pinned_threads(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  for session in self.sessions {
    rows.push(
      self.thread_button(
        session.title,
        SelectSession(session.id),
        layout,
        theme,
        selected=self.selected_session_id == session.id,
        meta=session.status,
      ),
    )
  }
  column(rows, spacing=2.0, align=Stretch)
}

///|
fn WorkbenchModel::workspace_summary(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  let pending = self.pending_transport_count()
  let rows : Array[@core.View[WorkbenchMsg]] = [
    text(
      active.project_path,
      role=Caption,
      theme~,
      width=layout.sidebar_inner_width - 30.0,
      height=40.0,
    ),
    text(
      active.branch,
      role=Control,
      theme~,
      width=layout.sidebar_inner_width - 30.0,
      height=26.0,
    ),
  ]
  if pending > 0 {
    rows.push(
      text(
        pending.to_string() + " 排队",
        role=Caption,
        theme~,
        width=layout.sidebar_inner_width - 30.0,
        height=24.0,
      ),
    )
  }
  surface(
    column(rows, spacing=2.0, align=Start),
    width=layout.sidebar_inner_width,
    height=if pending > 0 { 116.0 } else { 90.0 },
    background=ui_color(0.88, 0.89, 0.89),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  )
}

///|
fn WorkbenchModel::sidebar_footer(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let status = self.transport.display_status_label()
  row(
    [
      text("Pi RPC", role=Control, theme~, width=56.0, height=28.0),
      text(
        status,
        role=Caption,
        theme~,
        width=layout.sidebar_inner_width - 72.0,
        height=28.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::thread_button(
  self : WorkbenchModel,
  label : String,
  message : WorkbenchMsg,
  layout : WorkbenchLayout,
  theme : @core.Theme,
  selected~ : Bool,
  meta~ : String,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  let background = if selected {
    ui_color(0.84, 0.85, 0.85)
  } else {
    ui_color(0.91, 0.92, 0.92)
  }
  surface(
    row(
      [
        button(
          label,
          on_click=message,
          variant=Ghost,
          theme~,
          width=layout.sidebar_inner_width - 72.0,
          height=32.0,
        ),
        text(meta, role=Caption, theme~, width=54.0, height=28.0),
      ],
      spacing=4.0,
      align=Center,
    ),
    width=layout.sidebar_inner_width,
    height=38.0,
    background~,
    corner_radius=8.0,
    theme~,
    padding=2.0,
  )
}

///|
fn WorkbenchModel::conversation_surface(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        self.top_bar(layout, theme),
        divider(layout.main_width),
        scroll_view(
          self.chat_transcript(layout, theme),
          width=layout.main_width,
          height=layout.scroll_height,
        ),
        self.composer(layout, theme),
      ],
      spacing=0.0,
      align=Stretch,
    ),
    width=layout.main_width,
    height=layout.viewport.height,
    background=@core.Color::white(),
    corner_radius=0.0,
    theme~,
    padding=0.0,
  )
}

///|
fn WorkbenchModel::top_bar(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  surface(
    row(
      [
        badge("Pi", tone=Accent, theme~, width=42.0),
        text(
          active.title,
          role=Control,
          theme~,
          width=layout.top_title_width,
          height=30.0,
        ),
        text(
          active.project_path,
          role=Caption,
          theme~,
          width=layout.top_path_width,
          height=28.0,
        ),
        spacer(min_length=10.0, weight=1.0),
        text(active.branch, role=Caption, theme~, width=120.0, height=28.0),
      ],
      spacing=6.0,
      align=Center,
    ),
    width=layout.main_width,
    height=48.0,
    background=@core.Color::white(),
    theme~,
    padding=10.0,
  )
}

///|
fn WorkbenchModel::chat_transcript(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  column(
    [
      self.session_status_panel(layout, theme),
      self.transcript_panel(layout, theme),
      self.activity_panel(layout, theme),
      self.workspace_digest_panel(layout, theme),
    ],
    spacing=10.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::transcript_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  let visible_limit = if self.fork_messages.is_empty() { 3 } else { 2 }
  let mut visible = 0
  for item in self.transcript {
    if visible < visible_limit {
      rows.push(transcript_row(item, layout, theme))
      visible = visible + 1
    }
  }
  if !self.fork_messages.is_empty() {
    rows.push(fork_message_row(self.fork_messages[0], layout, theme))
  }
  let panel_rows : Array[@core.View[WorkbenchMsg]] = [
    row(
      [
        text(
          "会话记录",
          role=Control,
          theme~,
          width=layout.panel_body_width - 240.0,
          height=28.0,
        ),
        count_badge(
          self.transcript.length(),
          label=self.transcript.length().to_string() + " 条",
          tone=Neutral,
          theme~,
          width=112.0,
        ),
        count_badge(
          self.fork_messages.length(),
          label=self.fork_messages.length().to_string() + " 分叉",
          tone=Accent,
          theme~,
          width=112.0,
        ),
      ],
      spacing=8.0,
      align=Center,
    ),
  ]
  if !rows.is_empty() {
    panel_rows.push(column(rows, spacing=6.0, align=Start))
  }
  surface(
    column(panel_rows, spacing=8.0, align=Start),
    width=layout.panel_width,
    height=if rows.is_empty() { 54.0 } else { 178.0 },
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  )
}

///|
fn transcript_row(
  item : TranscriptItem,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        item.role,
        tone=transcript_badge_tone(item.tone),
        theme~,
        width=layout.row_badge_width,
      ),
      column(
        [
          text(
            item.summary,
            role=Control,
            theme~,
            width=layout.row_text_width,
            height=24.0,
          ),
          text(
            item.detail,
            role=Caption,
            theme~,
            width=layout.row_text_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      button(
        "跟进",
        on_click=FollowTranscript(item.role, item.summary, item.detail),
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
fn fork_message_row(
  message : PiForkMessage,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge("分叉", tone=Accent, theme~, width=layout.row_badge_width),
      column(
        [
          text(
            "可分叉消息",
            role=Control,
            theme~,
            width=layout.row_text_width,
            height=24.0,
          ),
          text(
            message.text,
            role=Caption,
            theme~,
            width=layout.row_text_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      button(
        "分支",
        on_click=ForkFromMessage(message.entry_id),
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
fn transcript_badge_tone(tone : String) -> @views.BadgeTone {
  match tone {
    "success" => Success
    "warning" => Warning
    "danger" => Danger
    "info" => Accent
    _ => Neutral
  }
}

///|
fn count_badge(
  count : Int,
  label~ : String,
  tone~ : @views.BadgeTone,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[WorkbenchMsg] {
  if count == 0 {
    blank_cell(width~, height=24.0)
  } else {
    badge(label, tone~, theme~, width~)
  }
}

///|
fn command_catalog_row(
  command : PiCommandInfo,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        command.source,
        tone=command_source_tone(command.source),
        theme~,
        width=layout.row_badge_width,
      ),
      column(
        [
          text(
            "/" + command.name,
            role=Control,
            theme~,
            width=layout.row_text_width,
            height=24.0,
          ),
          text(
            command_catalog_detail(command),
            role=Caption,
            theme~,
            width=layout.row_text_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      button(
        "运行",
        on_click=InvokeCommand(command.name),
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
fn command_catalog_detail(command : PiCommandInfo) -> String {
  let parts : Array[String] = []
  if command.description != "" {
    parts.push(command.description)
  }
  if command.source_scope != "" {
    parts.push(command.source_scope)
  }
  if command.source_path != "" {
    parts.push(command.source_path)
  }
  parts.join(" · ")
}

///|
fn command_source_tone(source : String) -> @views.BadgeTone {
  match source {
    "prompt" => Accent
    "skill" => Success
    "extension" => Warning
    _ => Neutral
  }
}

///|
fn WorkbenchModel::session_status_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  let binding = self.active_pi_session_binding()
  let rows : Array[@core.View[WorkbenchMsg]] = [
    row(
      [
        text(
          "当前会话",
          role=Control,
          theme~,
          width=layout.panel_body_width - 212.0,
          height=28.0,
        ),
        badge(active.status, tone=Success, theme~, width=92.0),
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
  if self.pi_session_stats.has_visible_metrics() {
    rows.push(session_stats_row(self.pi_session_stats, layout, theme))
  }
  if self.model_catalog.length() > 0 {
    rows.push(model_catalog_row(self.model_catalog, layout, theme))
  }
  if binding.has_visible_binding() {
    rows.push(session_binding_row(binding, layout, theme))
  }
  if self.has_runtime_signal() {
    rows.push(self.runtime_signal_row(layout, theme))
  }
  match self.next_action() {
    Some(action) => rows.push(next_action_row(action, layout, theme))
    None => ()
  }
  rows.push(self.session_controls_row(layout, theme))
  surface(
    column(rows, spacing=6.0, align=Start),
    width=layout.panel_width,
    height=session_status_panel_height(rows.length()),
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  )
}

///|
fn session_status_panel_height(row_count : Int) -> Double {
  92.0 + (row_count - 2).max(0).to_double() * 42.0
}

///|
fn WorkbenchModel::next_action(self : WorkbenchModel) -> WorkbenchNextAction? {
  let session = self.active_session()
  if self.has_cancel_target() {
    return Some({
      title: "等待 Pi 完成当前运行",
      detail: current_run_detail(session, self.last_status),
      primary_label: "停止",
      primary_message: CancelRun,
      secondary_label: "",
      secondary_message: None,
      tone: Warning,
    })
  }
  if !self.diagnostics.is_empty() {
    let diagnostic = self.diagnostics[self.diagnostics.length() - 1]
    return Some({
      title: "修复最新诊断",
      detail: diagnostic_detail_label(diagnostic),
      primary_label: "修复",
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
  match self.latest_failed_command() {
    Some(command) =>
      return Some({
        title: "分析失败命令",
        detail: command.command,
        primary_label: "分析",
        primary_message: InspectCommandRun(
          command.command,
          command.status,
          command.cwd,
          command.output_path,
        ),
        secondary_label: "重跑",
        secondary_message: Some(QueueCommand(command.command)),
        tone: Danger,
      })
    None => ()
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
  if !self.transcript.is_empty() {
    let item = self.transcript[self.transcript.length() - 1]
    return Some({
      title: "跟进最新消息",
      detail: item.summary,
      primary_label: "跟进",
      primary_message: FollowTranscript(item.role, item.summary, item.detail),
      secondary_label: "",
      secondary_message: None,
      tone: Neutral,
    })
  }
  if !self.command_catalog.is_empty() {
    let command = self.command_catalog[0]
    return Some({
      title: "运行可用命令",
      detail: "/" + command.name,
      primary_label: "运行",
      primary_message: InvokeCommand(command.name),
      secondary_label: "",
      secondary_message: None,
      tone: Accent,
    })
  }
  if !self.events.is_empty() {
    let event = self.events[self.events.length() - 1]
    return Some({
      title: "跟进最新事件",
      detail: event.title,
      primary_label: "跟进",
      primary_message: FollowActivity(event.phase, event.title, event.detail),
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let detail_width = workbench_max_double(
    180.0,
    layout.panel_body_width - 86.0 - 68.0 - 58.0 - 32.0,
  )
  row(
    [
      badge("接续建议", tone=action.tone, theme~, width=86.0),
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
    220.0,
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
  models : Array[PiModelInfo],
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
        width=layout.panel_body_width - 128.0 - 58.0 - 58.0 - 24.0,
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
fn model_catalog_label(models : Array[PiModelInfo]) -> String {
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let signal_width = (layout.panel_body_width - 8.0) / 2.0
  row(
    [
      text(
        "传输：" + self.transport.display_status_label(),
        role=Caption,
        theme~,
        width=signal_width,
        height=30.0,
      ),
      text(
        "Pi：" + self.pi_agent.display_status_label(),
        role=Caption,
        theme~,
        width=signal_width,
        height=30.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn PiTransportState::display_status_label(self : PiTransportState) -> String {
  match self.status {
    Disconnected => "未连接"
    Starting => "启动中"
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(layout)
  let controls : Array[@core.View[WorkbenchMsg]] = []
  if self.pi_agent.thinking_level != "" {
    controls.push(self.thinking_level_cell(theme))
  }
  controls.push(spacer(min_length=4.0, weight=1.0))
  controls.push(
    button(
      "新会话",
      on_click=NewSession,
      variant=Outline,
      theme~,
      width=66.0,
      height=34.0,
    ),
  )
  controls.push(
    button(
      "刷新",
      on_click=RefreshSession,
      variant=Outline,
      theme~,
      width=54.0,
      height=34.0,
    ),
  )
  controls.push(
    button(
      "找分叉",
      on_click=RefreshForkMessages,
      variant=Outline,
      theme~,
      width=66.0,
      height=34.0,
    ),
  )
  controls.push(
    button(
      "导出",
      on_click=ExportSessionHtml,
      variant=Outline,
      theme~,
      width=54.0,
      height=34.0,
    ),
  )
  controls.push(
    button(
      "压缩",
      on_click=CompactSession,
      variant=Outline,
      theme~,
      width=54.0,
      height=34.0,
    ),
  )
  controls.push(
    button(
      "思考",
      on_click=CycleThinkingLevel,
      variant=Outline,
      theme~,
      width=54.0,
      height=34.0,
    ),
  )
  controls.push(
    button(
      "同步名",
      on_click=SyncSessionName,
      variant=Outline,
      theme~,
      width=66.0,
      height=34.0,
    ),
  )
  if self.has_cancel_target() {
    controls.push(self.cancel_run_button(theme))
  }
  row(controls, spacing=8.0, align=Center)
}

///|
fn WorkbenchModel::thinking_level_cell(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
  self.transport.has_visible_signal() || self.pi_agent.has_visible_signal()
}

///|
fn WorkbenchModel::has_cancel_target(self : WorkbenchModel) -> Bool {
  self.has_active_shell_command(self.active_session()) ||
  self.transport.has_active_signal() ||
  self.pi_agent.has_active_signal()
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
fn PiSessionBinding::has_visible_binding(self : PiSessionBinding) -> Bool {
  self.status != "unbound" ||
  self.rpc_session_id != "" ||
  self.session_file != "" ||
  self.session_name != "" ||
  self.model != "" ||
  self.last_command != ""
}

///|
fn session_binding_row(
  binding : PiSessionBinding,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let cell_width = (layout.panel_body_width - 8.0) / 2.0
  row(
    [
      text(
        "Pi 会话：" + binding.display_status_label(),
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
  binding : PiSessionBinding,
  width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let detail = session_binding_detail_label(binding)
  if detail == "" {
    blank_cell(width~, height=30.0)
  } else {
    text(detail, role=Caption, theme~, width~, height=30.0)
  }
}

///|
fn session_binding_detail_label(binding : PiSessionBinding) -> String {
  if binding.model != "" {
    "模型：" + binding.model
  } else if binding.session_file != "" {
    "文件：" + binding.session_file
  } else {
    ""
  }
}

///|
fn PiSessionBinding::display_status_label(self : PiSessionBinding) -> String {
  if self.status == "unbound" {
    "未绑定"
  } else {
    let name = if self.session_name != "" {
      self.session_name
    } else if self.rpc_session_id != "" {
      self.rpc_session_id
    } else if self.session_file != "" {
      self.session_file
    } else {
      "Pi session"
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
  if self.pi_agent.thinking_level == "" {
    "default"
  } else {
    self.pi_agent.thinking_level
  }
}

///|
fn session_stats_row(
  stats : PiSessionStatsSnapshot,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let token_width = workbench_max_double(
    118.0,
    layout.panel_body_width - 128.0 - 108.0 - 112.0 - 24.0,
  )
  if stats.has_visible_metrics() {
    row(
      [
        text(
          "消息 " + stats.total_messages.to_string(),
          role=Caption,
          theme~,
          width=128.0,
          height=28.0,
        ),
        text(
          "工具 " +
          stats.tool_calls.to_string() +
          "/" +
          stats.tool_results.to_string(),
          role=Caption,
          theme~,
          width=108.0,
          height=28.0,
        ),
        text(
          "Token " + stats.token_total.to_string(),
          role=Caption,
          theme~,
          width=token_width,
          height=28.0,
        ),
        session_stats_context_cell(stats, theme),
      ],
      spacing=8.0,
      align=Center,
    )
  } else {
    blank_row(28.0)
  }
}

///|
fn PiSessionStatsSnapshot::has_visible_metrics(
  self : PiSessionStatsSnapshot,
) -> Bool {
  if self.total_messages > 0 ||
    self.tool_calls > 0 ||
    self.tool_results > 0 ||
    self.token_total > 0 {
    true
  } else {
    match self.context_percent {
      Some(_) => true
      None => false
    }
  }
}

///|
fn session_stats_context_cell(
  stats : PiSessionStatsSnapshot,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  match stats.context_percent {
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
fn WorkbenchModel::activity_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = [
    row(
      [
        text(
          "运行证据",
          role=Control,
          theme~,
          width=layout.panel_body_width - 290.0,
          height=28.0,
        ),
        count_badge(
          self.commands.length(),
          label=self.commands.length().to_string() + " 运行",
          tone=Neutral,
          theme~,
          width=94.0,
        ),
        count_badge(
          self.command_catalog.length(),
          label=self.command_catalog.length().to_string() + " 命令",
          tone=Accent,
          theme~,
          width=94.0,
        ),
        count_badge(
          self.events.length(),
          label=self.events.length().to_string() + " 事件",
          tone=Neutral,
          theme~,
          width=102.0,
        ),
      ],
      spacing=8.0,
      align=Center,
    ),
  ]
  if !self.events.is_empty() {
    rows.push(event_row(self.events[self.events.length() - 1], layout, theme))
  }
  if !self.commands.is_empty() {
    rows.push(
      command_run_row(self.commands[self.commands.length() - 1], layout, theme),
    )
  }
  if !self.command_catalog.is_empty() {
    rows.push(command_catalog_row(self.command_catalog[0], layout, theme))
  }
  surface(
    column(rows, spacing=7.0, align=Start),
    width=layout.panel_width,
    height=evidence_panel_height(rows.length(), expanded=188.0),
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  )
}

///|
fn event_row(
  event : AgentEvent,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        event.phase,
        tone=transcript_badge_tone(event.tone),
        theme~,
        width=layout.row_badge_width,
      ),
      column(
        [
          text(
            event.title,
            role=Control,
            theme~,
            width=layout.row_text_width,
            height=24.0,
          ),
          text(
            event.detail,
            role=Caption,
            theme~,
            width=layout.row_text_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      button(
        "跟进",
        on_click=FollowActivity(event.phase, event.title, event.detail),
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
fn command_run_row(
  command : CommandRun,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        command.status,
        tone=command_status_tone(command.status),
        theme~,
        width=layout.row_badge_width,
      ),
      column(
        [
          text(
            command.command,
            role=Control,
            theme~,
            width=layout.command_text_width,
            height=24.0,
          ),
          text(
            command_detail_label(command),
            role=Caption,
            theme~,
            width=layout.command_text_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      text(
        command_exit_label(command),
        role=Caption,
        theme~,
        width=68.0,
        height=30.0,
      ),
      button(
        "分析",
        on_click=InspectCommandRun(
          command.command,
          command.status,
          command.cwd,
          command.output_path,
        ),
        variant=Outline,
        theme~,
        width=54.0,
        height=32.0,
      ),
      button(
        "重跑",
        on_click=QueueCommand(command.command),
        variant=Outline,
        theme~,
        width=54.0,
        height=32.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn command_exit_label(command : CommandRun) -> String {
  match command.exit_code {
    Some(code) => "exit " + code.to_string()
    None => command.status
  }
}

///|
fn command_detail_label(command : CommandRun) -> String {
  if command.output_path == "" {
    command.cwd
  } else {
    "output " + command.output_path
  }
}

///|
fn command_status_tone(status : String) -> @views.BadgeTone {
  match status {
    "passed" | "ready" => Success
    "running" | "queued" | "cancelling" => Accent
    "failed" => Danger
    "cancelled" | "manual" => Warning
    _ => Neutral
  }
}

///|
fn file_context_row(
  file : FileContext,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        file.change_kind,
        tone=Neutral,
        theme~,
        width=layout.row_badge_width,
      ),
      column(
        [
          text(
            file.path,
            role=Control,
            theme~,
            width=layout.row_text_width,
            height=24.0,
          ),
          text(
            file.summary,
            role=Caption,
            theme~,
            width=layout.row_text_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      button(
        "聚焦",
        on_click=InspectFile(file.path),
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
fn WorkbenchModel::workspace_digest_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = [
    row(
      [
        text(
          "工作区证据",
          role=Control,
          theme~,
          width=layout.panel_body_width - 302.0,
          height=28.0,
        ),
        count_badge(
          self.files.length(),
          label=self.files.length().to_string() + " 文件",
          tone=Neutral,
          theme~,
          width=86.0,
        ),
        count_badge(
          self.open_diagnostic_count(),
          label=self.open_diagnostic_count().to_string() + " 诊断",
          tone=diagnostic_count_tone(self.open_diagnostic_count()),
          theme~,
          width=86.0,
        ),
        self.clear_diagnostics_button(theme),
        self.review_diff_button(theme),
      ],
      spacing=8.0,
      align=Center,
    ),
  ]
  if self.diff.has_context() {
    rows.push(diff_digest_row(self.diff, layout, theme))
  }
  if !self.files.is_empty() {
    rows.push(file_context_row(self.files[0], layout, theme))
  }
  if !self.diagnostics.is_empty() {
    rows.push(
      diagnostic_row(
        self.diagnostics[self.diagnostics.length() - 1],
        layout,
        theme,
      ),
    )
  }
  surface(
    column(rows, spacing=7.0, align=Start),
    width=layout.panel_width,
    height=evidence_panel_height(rows.length(), expanded=178.0),
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  )
}

///|
fn evidence_panel_height(row_count : Int, expanded~ : Double) -> Double {
  if row_count <= 1 {
    54.0
  } else {
    expanded
  }
}

///|
fn diagnostic_count_tone(count : Int) -> @views.BadgeTone {
  if count > 0 {
    Warning
  } else {
    Neutral
  }
}

///|
fn WorkbenchModel::clear_diagnostics_button(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if self.open_diagnostic_count() == 0 {
    blank_cell(width=58.0, height=34.0)
  } else {
    button(
      "清除",
      on_click=ClearDiagnostics,
      variant=Ghost,
      theme~,
      width=58.0,
      height=34.0,
    )
  }
}

///|
fn WorkbenchModel::review_diff_button(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if self.diff.has_context() {
    button(
      "审核",
      on_click=ReviewDiff,
      variant=Outline,
      theme~,
      width=64.0,
      height=34.0,
    )
  } else {
    blank_cell(width=64.0, height=34.0)
  }
}

///|
fn diff_digest_row(
  diff : DiffOverview,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if diff.has_context() {
    row(
      [
        badge(diff.status_label(), tone=Neutral, theme~, width=126.0),
        text(
          diff.changed_files.to_string() +
          " 文件 · +" +
          diff.additions.to_string() +
          " -" +
          diff.deletions.to_string(),
          role=Caption,
          theme~,
          width=layout.diff_text_width,
          height=28.0,
        ),
      ],
      spacing=10.0,
      align=Center,
    )
  } else {
    blank_row(28.0)
  }
}

///|
fn diagnostic_row(
  diagnostic : DiagnosticItem,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        diagnostic.severity,
        tone=diagnostic_badge_tone(diagnostic.severity),
        theme~,
        width=layout.row_badge_width,
      ),
      column(
        [
          text(
            diagnostic.source,
            role=Control,
            theme~,
            width=layout.row_text_width,
            height=24.0,
          ),
          text(
            diagnostic.message,
            role=Caption,
            theme~,
            width=layout.row_text_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      button(
        "修复",
        on_click=FixDiagnostic(
          diagnostic.source,
          diagnostic.severity,
          diagnostic.message,
        ),
        variant=Outline,
        theme~,
        width=58.0,
        height=32.0,
      ),
    ],
    spacing=10.0,
    align=Center,
  )
}

///|
fn diagnostic_badge_tone(severity : String) -> @views.BadgeTone {
  match severity {
    "error" => Danger
    "warning" | "watch" => Warning
    "note" => Accent
    _ => Neutral
  }
}

///|
fn blank_row(height : Double) -> @core.View[WorkbenchMsg] {
  blank_cell(width=650.0, height~)
}

///|
fn blank_cell(width~ : Double, height~ : Double) -> @core.View[WorkbenchMsg] {
  surface(
    empty(),
    width~,
    height~,
    background=@core.Color::white(),
    padding=0.0,
  )
}

///|
fn WorkbenchModel::composer(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        text_field(
          self.prompt,
          on_input=value => PromptChanged(value),
          on_submit=Some(DispatchPrompt),
          placeholder="给 Pi 一个任务",
          variant=Plain,
          theme~,
          width=layout.composer_input_width,
          height=54.0,
        ),
        row(
          [
            button(
              "+",
              on_click=ToggleContext("repo"),
              variant=Ghost,
              theme~,
              width=38.0,
              height=34.0,
            ),
            badge("RPC", tone=Accent, theme~, width=54.0),
            button(
              self.steering_mode_label(),
              on_click=ToggleSteeringMode,
              variant=Outline,
              theme~,
              width=76.0,
              height=34.0,
            ),
            button(
              self.follow_up_mode_label(),
              on_click=ToggleFollowUpMode,
              variant=Outline,
              theme~,
              width=82.0,
              height=34.0,
            ),
            spacer(min_length=10.0, weight=1.0),
            button(
              "引导",
              on_click=DispatchSteering,
              variant=Outline,
              theme~,
              width=54.0,
              height=36.0,
            ),
            button(
              "跟进",
              on_click=DispatchFollowUp,
              variant=Outline,
              theme~,
              width=54.0,
              height=36.0,
            ),
            button(
              "↑",
              on_click=DispatchPrompt,
              variant=Primary,
              theme~,
              width=42.0,
              height=36.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
      ],
      spacing=6.0,
      align=Stretch,
    ),
    width=layout.composer_width,
    height=126.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  )
}

///|
fn WorkbenchModel::steering_mode_label(self : WorkbenchModel) -> String {
  "引导 " + mode_short_label(self.pi_agent.steering_mode)
}

///|
fn WorkbenchModel::follow_up_mode_label(self : WorkbenchModel) -> String {
  "跟进 " + mode_short_label(self.pi_agent.follow_up_mode)
}

///|
fn mode_short_label(mode : String) -> String {
  if mode == "all" {
    "all"
  } else {
    "1"
  }
}

///|
fn WorkbenchModel::sidebar_section_label(
  self : WorkbenchModel,
  label : String,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  text(
    label,
    role=Caption,
    theme~,
    width=layout.sidebar_inner_width,
    height=30.0,
  )
}

///|
fn divider(width : Double) -> @core.View[WorkbenchMsg] {
  surface(
    empty(),
    width~,
    height=1.0,
    background=ui_color(0.90, 0.90, 0.90),
    padding=0.0,
  )
}

///|
fn ui_color(r : Double, g : Double, b : Double) -> @core.Color {
  @core.Color::rgba(r~, g~, b~)
}
