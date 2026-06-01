///|
using @views {
  badge,
  button,
  column,
  custom_layout,
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
  main_padding : Double
  workflow_rail_visible : Bool
  workflow_rail_width : Double
  workflow_rail_gap : Double
  workflow_rail_body_width : Double
  content_width : Double
  scrollbar_width : Double
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
  composer_height : Double
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
    workbench_clamp_double(viewport.width * 0.22, 260.0, 300.0)
  }
  let main_width = workbench_max_double(1.0, viewport.width - sidebar_width)
  let main_padding = if main_width < 760.0 { 14.0 } else { 22.0 }
  let scrollbar_width = 12.0
  let main_available_width = workbench_max_double(
    1.0,
    main_width - main_padding * 2.0,
  )
  let workflow_rail_visible = viewport.width >= 1180.0
  let workflow_rail_gap = if workflow_rail_visible { 16.0 } else { 0.0 }
  let workflow_rail_width = if workflow_rail_visible {
    workbench_clamp_double(main_available_width * 0.28, 240.0, 276.0)
  } else {
    0.0
  }
  let content_available_width = workbench_max_double(
    1.0,
    main_available_width -
    workflow_rail_width -
    workflow_rail_gap -
    scrollbar_width,
  )
  let content_width = workbench_clamp_double(
    content_available_width,
    workbench_min_double(460.0, content_available_width),
    920.0,
  )
  let panel_width = content_width
  let panel_body_width = workbench_max_double(1.0, panel_width - 24.0)
  let row_badge_width = if panel_width < 620.0 { 88.0 } else { 104.0 }
  let row_text_width = workbench_max_double(
    1.0,
    panel_body_width - row_badge_width - 58.0 - 16.0,
  )
  let command_text_width = workbench_max_double(
    1.0,
    panel_body_width - row_badge_width - 68.0 - 54.0 - 54.0 - 40.0,
  )
  let diff_text_width = workbench_max_double(
    1.0,
    panel_body_width - 126.0 - 10.0,
  )
  let composer_width = workbench_clamp_double(
    content_available_width,
    workbench_min_double(460.0, content_available_width),
    860.0,
  )
  let composer_height = 160.0
  let top_text_available = workbench_max_double(
    1.0,
    content_width - 86.0 - 120.0 - 10.0 - 24.0,
  )
  let top_title_width = workbench_clamp_double(
    top_text_available * 0.45,
    workbench_min_double(180.0, top_text_available * 0.45),
    360.0,
  )
  let top_path_width = workbench_min_double(
    420.0,
    workbench_max_double(1.0, top_text_available - top_title_width),
  )
  {
    viewport,
    sidebar_width,
    sidebar_inner_width: workbench_max_double(160.0, sidebar_width - 36.0),
    main_width,
    main_padding,
    workflow_rail_visible,
    workflow_rail_width,
    workflow_rail_gap,
    workflow_rail_body_width: workbench_max_double(
      1.0,
      workflow_rail_width - 24.0,
    ),
    content_width,
    scrollbar_width,
    panel_width,
    panel_body_width,
    row_badge_width,
    row_text_width,
    command_text_width,
    diff_text_width,
    top_title_width,
    top_path_width,
    scroll_height: workbench_max_double(220.0, viewport.height - 292.0),
    composer_width,
    composer_input_width: workbench_max_double(1.0, composer_width - 24.0),
    composer_height,
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
        self.sidebar_section_label("任务历史", layout, theme),
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
    background=ui_color(0.93, 0.94, 0.93),
    corner_radius=0.0,
    theme~,
    padding=18.0,
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
    background=ui_color(0.96, 0.96, 0.95),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
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
    @core.Color::white()
  } else {
    ui_color(0.93, 0.94, 0.93)
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
  ).border(
    if selected {
      workbench_hairline_border()
    } else {
      workbench_clear_border()
    },
  )
}

///|
fn WorkbenchModel::conversation_surface(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let content_height = self.chat_content_height(layout)
  let max_scroll = workbench_max_double(
    0.0,
    content_height - layout.scroll_height,
  )
  let offset_y = workbench_clamp_double(
    self.main_scroll_offset_y,
    0.0,
    max_scroll,
  )
  let center_column = column(
    [
      self.top_bar(layout, theme),
      row(
        [
          scroll_view(
            self.chat_transcript(layout, theme),
            offset=@core.Point::new(x=0.0, y=offset_y),
            width=layout.content_width,
            height=layout.scroll_height,
            on_scroll=Some(delta => {
              MainScrollTo(
                workbench_clamp_double(offset_y - delta.y, 0.0, max_scroll),
              )
            }),
          ),
          main_scrollbar(
            theme,
            viewport_height=layout.scroll_height,
            content_height~,
            offset_y~,
          ),
        ],
        spacing=0.0,
        align=Start,
      ).frame(
        width=layout.content_width + layout.scrollbar_width,
        height=layout.scroll_height,
      ),
      self.composer(layout, theme),
    ],
    spacing=14.0,
    align=Center,
  )
  let content = if layout.workflow_rail_visible {
    row(
      [center_column, self.workflow_rail(layout, theme)],
      spacing=layout.workflow_rail_gap,
      align=Start,
    )
  } else {
    center_column
  }
  surface(
    content,
    width=layout.main_width,
    height=layout.viewport.height,
    background=ui_color(0.975, 0.976, 0.970),
    corner_radius=0.0,
    theme~,
    padding=layout.main_padding,
  )
}

///|
fn WorkbenchModel::workflow_rail(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  column(
    [
      self.workflow_progress_card(layout, theme),
      self.workflow_agents_card(layout, theme),
      self.workflow_folder_card(layout, theme),
    ],
    spacing=14.0,
    align=Stretch,
  ).frame(
    width=layout.workflow_rail_width,
    height=workbench_max_double(
      1.0,
      layout.viewport.height - layout.main_padding * 2.0,
    ),
  )
}

///|
fn WorkbenchModel::workflow_progress_card(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  if self.plan.is_empty() {
    rows.push(workflow_note_row("等待 Pi 计划更新", layout, theme))
  } else {
    let limit = workbench_min_int(self.plan.length(), 3)
    for index in 0..<limit {
      rows.push(workflow_plan_step_row(self.plan[index], layout, theme))
    }
  }
  workflow_rail_card(
    "进度",
    workflow_plan_summary_label(self.plan),
    rows,
    layout,
    theme,
    height=self.workflow_progress_card_height(),
  )
}

///|
fn WorkbenchModel::workflow_progress_card_height(
  self : WorkbenchModel,
) -> Double {
  if self.plan.is_empty() {
    110.0
  } else {
    66.0 + workbench_min_int(self.plan.length(), 3).to_double() * 44.0
  }
}

///|
fn workflow_plan_summary_label(steps : Array[PlanStep]) -> String {
  if steps.is_empty() {
    ""
  } else {
    let done = steps.length() - plan_open_count(steps)
    done.to_string() + "/" + steps.length().to_string() + " 完成"
  }
}

///|
fn workflow_plan_step_row(
  step : PlanStep,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let text_width = workbench_max_double(
    1.0,
    layout.workflow_rail_body_width - 52.0 - 8.0,
  )
  row(
    [
      badge(
        workflow_plan_step_badge(step.status),
        tone=plan_step_tone(step.status),
        theme~,
        width=52.0,
      ),
      column(
        [
          text(step.title, role=Control, theme~, width=text_width, height=24.0),
          text(
            plan_step_detail_label(step),
            role=Caption,
            theme~,
            width=text_width,
            height=20.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn workflow_plan_step_badge(status : String) -> String {
  match status {
    "done" | "completed" => "完成"
    "in_progress" | "running" | "active" => "进行"
    "blocked" => "受阻"
    "cancelled" | "skipped" => "跳过"
    _ => "待办"
  }
}

///|
fn WorkbenchModel::workflow_agents_card(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  if !self.plan.is_empty() {
    let limit = workbench_min_int(self.plan.length(), 3)
    for index in 0..<limit {
      rows.push(workflow_agent_plan_row(self.plan[index], layout, theme))
    }
  } else if !self.events.is_empty() {
    let start = workbench_max_int(0, self.events.length() - 3)
    for index in start..<self.events.length() {
      rows.push(workflow_agent_event_row(self.events[index], layout, theme))
    }
  } else {
    rows.push(self.workflow_agent_idle_row(layout, theme))
  }
  workflow_rail_card(
    "Agents",
    workflow_agents_summary_label(self),
    rows,
    layout,
    theme,
    height=self.workflow_agents_card_height(),
  )
}

///|
fn WorkbenchModel::workflow_agents_card_height(self : WorkbenchModel) -> Double {
  let row_count = if !self.plan.is_empty() {
    workbench_min_int(self.plan.length(), 3)
  } else if !self.events.is_empty() {
    workbench_min_int(self.events.length(), 3)
  } else {
    1
  }
  66.0 + row_count.to_double() * 46.0
}

///|
fn workflow_agents_summary_label(model : WorkbenchModel) -> String {
  if !model.plan.is_empty() {
    "计划所有者"
  } else if !model.events.is_empty() {
    "最近活动"
  } else {
    "等待活动"
  }
}

///|
fn workflow_agent_plan_row(
  step : PlanStep,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let owner = if step.owner.trim().to_owned() == "" { "Pi" } else { step.owner }
  workflow_agent_row(
    owner,
    step.title,
    plan_step_tone(step.status),
    layout,
    theme,
  )
}

///|
fn workflow_agent_event_row(
  event : AgentEvent,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  workflow_agent_row(
    event_phase_label(event.phase),
    event.title,
    transcript_badge_tone(event.tone),
    layout,
    theme,
  )
}

///|
fn WorkbenchModel::workflow_agent_idle_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  workflow_agent_row(
    "Pi",
    self.pi_agent.display_status_label(),
    Neutral,
    layout,
    theme,
  )
}

///|
fn workflow_agent_row(
  label : String,
  detail : String,
  tone : @views.BadgeTone,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let text_width = workbench_max_double(
    1.0,
    layout.workflow_rail_body_width - 58.0 - 8.0,
  )
  row(
    [
      badge(label, tone~, theme~, width=58.0),
      text(detail, role=Caption, theme~, width=text_width, height=28.0),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::workflow_folder_card(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  let rows : Array[@core.View[WorkbenchMsg]] = [
    workflow_folder_project_row(active, layout, theme),
  ]
  if self.files.is_empty() {
    rows.push(workflow_note_row("等待 Pi 文件证据", layout, theme))
  } else {
    rows.push(
      workflow_file_context_row(
        self.files[self.files.length() - 1],
        layout,
        theme,
      ),
    )
  }
  workflow_rail_card(
    "工作文件夹",
    active.title,
    rows,
    layout,
    theme,
    height=154.0,
  )
}

///|
fn workflow_folder_project_row(
  session : WorkbenchSession,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  column(
    [
      text(
        "项目",
        role=Caption,
        theme~,
        width=layout.workflow_rail_body_width,
        height=20.0,
      ),
      text(
        session.project_path,
        role=Control,
        theme~,
        width=layout.workflow_rail_body_width,
        height=24.0,
      ),
    ],
    spacing=0.0,
    align=Start,
  )
}

///|
fn workflow_file_context_row(
  file : FileContext,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let text_width = workbench_max_double(
    1.0,
    layout.workflow_rail_body_width - 58.0 - 8.0,
  )
  row(
    [
      column(
        [
          text(file.path, role=Control, theme~, width=text_width, height=24.0),
          text(
            file.summary,
            role=Caption,
            theme~,
            width=text_width,
            height=20.0,
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
fn workflow_note_row(
  value : String,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  text(
    value,
    role=Caption,
    theme~,
    width=layout.workflow_rail_body_width,
    height=28.0,
  )
}

///|
fn workflow_rail_card(
  title : String,
  summary : String,
  rows : Array[@core.View[WorkbenchMsg]],
  layout : WorkbenchLayout,
  theme : @core.Theme,
  height~ : Double,
) -> @core.View[WorkbenchMsg] {
  let content : Array[@core.View[WorkbenchMsg]] = [
    row(
      [
        text(
          title,
          role=Control,
          theme~,
          width=workbench_max_double(
            1.0,
            layout.workflow_rail_body_width - 76.0,
          ),
          height=28.0,
        ),
        workflow_card_summary(summary, theme),
      ],
      spacing=8.0,
      align=Center,
    ),
  ]
  for row in rows {
    content.push(row)
  }
  surface(
    column(content, spacing=8.0, align=Start),
    width=layout.workflow_rail_width,
    height~,
    background=@core.Color::white(),
    corner_radius=12.0,
    theme~,
    padding=12.0,
  ).border(workbench_hairline_border())
}

///|
fn workflow_card_summary(
  summary : String,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if summary == "" {
    blank_cell(width=68.0, height=28.0)
  } else {
    text(summary, role=Caption, theme~, width=68.0, height=28.0)
  }
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
        badge("当前会话", tone=Accent, theme~, width=86.0),
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
        badge(
          session_status_label(active.status),
          tone=session_status_tone(active.status),
          theme~,
          width=74.0,
        ),
        text(active.branch, role=Caption, theme~, width=120.0, height=28.0),
      ],
      spacing=6.0,
      align=Center,
    ),
    width=layout.content_width + layout.scrollbar_width,
    height=58.0,
    background=@core.Color::white(),
    corner_radius=12.0,
    theme~,
    padding=12.0,
  ).border(workbench_hairline_border())
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
fn WorkbenchModel::chat_content_height(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
) -> Double {
  session_status_panel_height(self.session_status_row_count()) +
  self.transcript_panel_height(layout) +
  evidence_panel_height(self.activity_panel_row_count(), expanded=188.0) +
  evidence_panel_height(self.workspace_digest_panel_row_count(), expanded=178.0) +
  30.0
}

///|
fn WorkbenchModel::transcript_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  for item in self.transcript {
    rows.push(transcript_row(item, layout, theme))
  }
  for message in self.fork_messages {
    rows.push(fork_message_row(message, layout, theme))
  }
  let panel_rows : Array[@core.View[WorkbenchMsg]] = [
    row(
      [
        text(
          "会话记录",
          role=Control,
          theme~,
          width=workbench_max_double(1.0, layout.panel_body_width - 240.0),
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
  if rows.is_empty() {
    panel_rows.push(
      text(
        "等待 Pi 回复，当前 digest 保持安静。",
        role=Caption,
        theme~,
        width=layout.panel_body_width,
        height=28.0,
      ),
    )
  } else {
    panel_rows.push(column(rows, spacing=8.0, align=Start))
  }
  surface(
    column(panel_rows, spacing=8.0, align=Start),
    width=layout.panel_width,
    height=self.transcript_panel_height(layout),
    background=@core.Color::white(),
    corner_radius=12.0,
    theme~,
    padding=12.0,
  ).border(workbench_hairline_border())
}

///|
fn WorkbenchModel::transcript_panel_height(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
) -> Double {
  if self.transcript.is_empty() && self.fork_messages.is_empty() {
    84.0
  } else {
    let mut height = 24.0 + 28.0 + 8.0
    for item in self.transcript {
      height = height + transcript_row_height(item, layout) + 8.0
    }
    for message in self.fork_messages {
      height = height + fork_message_row_height(message, layout) + 8.0
    }
    height
  }
}

///|
fn transcript_row(
  item : TranscriptItem,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let inner_width = workbench_max_double(1.0, layout.panel_body_width - 20.0)
  let text_width = workbench_max_double(1.0, inner_width - 58.0 - 12.0)
  surface(
    column(
      [
        row(
          [
            badge(
              transcript_role_label(item.role),
              tone=transcript_badge_tone(item.tone),
              theme~,
              width=layout.row_badge_width,
            ),
            spacer(min_length=8.0, weight=1.0),
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
        ),
        transcript_text_block(item, text_width, theme),
      ],
      spacing=8.0,
      align=Start,
    ),
    width=layout.panel_body_width,
    height=transcript_row_height(item, layout),
    background=transcript_row_background(item.role),
    corner_radius=10.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn transcript_text_block(
  item : TranscriptItem,
  width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let max_chars = readable_line_char_limit(width)
  let lines : Array[@core.View[WorkbenchMsg]] = []
  for line in readable_text_lines(item.summary, max_chars, max_lines=3) {
    lines.push(text(line, role=Body, theme~, width~, height=24.0))
  }
  for line in readable_text_lines(item.detail, max_chars, max_lines=6) {
    lines.push(text(line, role=Caption, theme~, width~, height=22.0))
  }
  if lines.is_empty() {
    lines.push(text("空消息", role=Caption, theme~, width~, height=22.0))
  }
  column(lines, spacing=2.0, align=Start)
}

///|
fn transcript_row_height(
  item : TranscriptItem,
  layout : WorkbenchLayout,
) -> Double {
  let inner_width = workbench_max_double(1.0, layout.panel_body_width - 20.0)
  let text_width = workbench_max_double(1.0, inner_width - 58.0 - 12.0)
  20.0 + 32.0 + 8.0 + readable_text_block_height(item, text_width)
}

///|
fn readable_text_block_height(item : TranscriptItem, width : Double) -> Double {
  let max_chars = readable_line_char_limit(width)
  let line_count = readable_text_lines(item.summary, max_chars, max_lines=3).length() +
    readable_text_lines(item.detail, max_chars, max_lines=6).length()
  let safe_line_count = line_count.max(1)
  safe_line_count.to_double() * 23.0 +
  (safe_line_count - 1).max(0).to_double() * 2.0
}

///|
fn transcript_row_background(role : String) -> @core.Color {
  match role {
    "assistant" => ui_color(0.985, 0.987, 0.982)
    "user" => ui_color(0.965, 0.974, 0.985)
    _ => ui_color(0.985, 0.985, 0.980)
  }
}

///|
fn readable_line_char_limit(width : Double) -> Int {
  workbench_clamp_int((width / 7.2).to_int(), 24, 92)
}

///|
fn readable_text_lines(
  value : String,
  max_chars : Int,
  max_lines~ : Int,
) -> Array[String] {
  let clean = value.trim().to_owned()
  let lines : Array[String] = []
  if clean == "" || max_lines <= 0 {
    return lines
  }
  let chars = clean.to_array()
  let limit = max_chars.max(1)
  let mut start = 0
  while start < chars.length() && lines.length() < max_lines {
    let end = workbench_min_int(chars.length(), start + limit)
    if lines.length() + 1 == max_lines && end < chars.length() {
      let trim_end = workbench_max_int(start, end - 3)
      lines.push(String::from_array(chars[start:trim_end]) + "...")
    } else {
      lines.push(String::from_array(chars[start:end]))
    }
    start = end
  }
  lines
}

///|
fn workbench_clamp_int(value : Int, min : Int, max : Int) -> Int {
  workbench_min_int(max, workbench_max_int(min, value))
}

///|
fn workbench_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn workbench_min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn fork_message_row_height(
  message : PiForkMessage,
  layout : WorkbenchLayout,
) -> Double {
  let item = TranscriptItem::new(
    id=message.entry_id,
    role="branchSummary",
    summary="可分叉消息",
    detail=message.text,
    tone="info",
  )
  transcript_row_height(item, layout)
}

///|
fn fork_message_item(message : PiForkMessage) -> TranscriptItem {
  TranscriptItem::new(
    id=message.entry_id,
    role="branchSummary",
    summary="可分叉消息",
    detail=message.text,
    tone="info",
  )
}

///|
fn fork_message_row(
  message : PiForkMessage,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let item = fork_message_item(message)
  let inner_width = workbench_max_double(1.0, layout.panel_body_width - 20.0)
  let text_width = workbench_max_double(1.0, inner_width - 58.0 - 12.0)
  surface(
    column(
      [
        row(
          [
            badge("分叉", tone=Accent, theme~, width=layout.row_badge_width),
            spacer(min_length=8.0, weight=1.0),
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
        ),
        transcript_text_block(item, text_width, theme),
      ],
      spacing=8.0,
      align=Start,
    ),
    width=layout.panel_body_width,
    height=fork_message_row_height(message, layout),
    background=ui_color(0.980, 0.985, 0.990),
    corner_radius=10.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
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
fn transcript_role_label(role : String) -> String {
  match role {
    "user" => "用户"
    "assistant" => "Pi"
    "toolResult" => "工具"
    "bashExecution" => "命令"
    "branchSummary" => "分支"
    "compactionSummary" => "压缩"
    "message" => "消息"
    _ => role
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
        command_source_label(command.source),
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
fn command_source_label(source : String) -> String {
  match source {
    "prompt" => "提示"
    "skill" => "技能"
    "extension" => "扩展"
    _ => source
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
          "Pi 运行状态",
          role=Control,
          theme~,
          width=workbench_max_double(1.0, layout.panel_body_width - 212.0),
          height=28.0,
        ),
        badge(
          session_status_label(active.status),
          tone=session_status_tone(active.status),
          theme~,
          width=92.0,
        ),
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
    height=session_status_panel_height(self.session_status_row_count()),
    background=@core.Color::white(),
    corner_radius=12.0,
    theme~,
    padding=12.0,
  ).border(workbench_hairline_border())
}

///|
fn WorkbenchModel::session_status_row_count(self : WorkbenchModel) -> Int {
  let active = self.active_session()
  let binding = self.active_pi_session_binding()
  let mut count = 2
  if active.active_task != "" {
    count = count + 1
  }
  if !self.plan.is_empty() {
    count = count + 1
  }
  if self.pi_session_stats.has_visible_metrics() {
    count = count + 1
  }
  if self.model_catalog.length() > 0 {
    count = count + 1
  }
  if binding.has_visible_binding() {
    count = count + 1
  }
  if self.has_runtime_signal() {
    count = count + 1
  }
  match self.next_action() {
    Some(_) => count = count + 1
    None => ()
  }
  count
}

///|
fn session_status_panel_height(row_count : Int) -> Double {
  92.0 + (row_count - 2).max(0).to_double() * 42.0
}

///|
fn session_status_label(status : String) -> String {
  match status {
    "active" => "活跃"
    "queued" => "排队"
    "running" => "运行中"
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
    "failed" => Danger
    _ => Neutral
  }
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
  let signal_width = workbench_max_double(
    1.0,
    (layout.panel_body_width - 8.0) / 2.0,
  )
  row(
    [
      text(
        "RPC 通道：" + self.transport.display_status_label(),
        role=Caption,
        theme~,
        width=signal_width,
        height=30.0,
      ),
      text(
        "Pi 运行：" + self.pi_agent.display_status_label(),
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
      variant=Ghost,
      theme~,
      width=66.0,
      height=34.0,
    ),
  )
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
  let cell_width = workbench_max_double(
    1.0,
    (layout.panel_body_width - 8.0) / 2.0,
  )
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
  match self.pi_agent.thinking_level {
    "" | "default" => "默认"
    "low" => "低"
    "medium" => "中"
    "high" => "高"
    _ => self.pi_agent.thinking_level
  }
}

///|
fn session_stats_row(
  stats : PiSessionStatsSnapshot,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let token_width = workbench_max_double(
    1.0,
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
          width=workbench_max_double(1.0, layout.panel_body_width - 290.0),
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
    height=evidence_panel_height(
      self.activity_panel_row_count(),
      expanded=188.0,
    ),
    background=@core.Color::white(),
    corner_radius=12.0,
    theme~,
    padding=12.0,
  ).border(workbench_hairline_border())
}

///|
fn WorkbenchModel::activity_panel_row_count(self : WorkbenchModel) -> Int {
  let mut count = 1
  if !self.events.is_empty() {
    count = count + 1
  }
  if !self.commands.is_empty() {
    count = count + 1
  }
  if !self.command_catalog.is_empty() {
    count = count + 1
  }
  count
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
        event_phase_label(event.phase),
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
fn event_phase_label(phase : String) -> String {
  match phase {
    "user" => "用户"
    "agent" => "Pi"
    "assistant" => "Pi"
    "tool" => "工具"
    "transport" => "传输"
    "diagnostic" => "诊断"
    "context" => "上下文"
    "diff" => "变更"
    "plan" => "计划"
    "control" => "操作"
    _ => phase
  }
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
        command_status_label(command.status),
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
    Some(code) => "退出码 " + code.to_string()
    None => command_status_label(command.status)
  }
}

///|
fn command_detail_label(command : CommandRun) -> String {
  if command.output_path == "" {
    command.cwd
  } else {
    "输出 " + command.output_path
  }
}

///|
fn command_status_label(status : String) -> String {
  match status {
    "passed" | "ready" => "通过"
    "running" => "运行中"
    "queued" => "排队"
    "cancelling" => "停止中"
    "failed" => "失败"
    "cancelled" => "已取消"
    "manual" => "手动"
    _ => status
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
          width=workbench_max_double(1.0, layout.panel_body_width - 302.0),
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
    height=evidence_panel_height(
      self.workspace_digest_panel_row_count(),
      expanded=178.0,
    ),
    background=@core.Color::white(),
    corner_radius=12.0,
    theme~,
    padding=12.0,
  ).border(workbench_hairline_border())
}

///|
fn WorkbenchModel::workspace_digest_panel_row_count(
  self : WorkbenchModel,
) -> Int {
  let mut count = 1
  if self.diff.has_context() {
    count = count + 1
  }
  if !self.files.is_empty() {
    count = count + 1
  }
  if !self.diagnostics.is_empty() {
    count = count + 1
  }
  count
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
        self.context_chip_row(layout, theme),
        row(
          [
            button(
              self.steering_mode_label(),
              on_click=ToggleSteeringMode,
              variant=Outline,
              theme~,
              width=82.0,
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
              "发送",
              on_click=DispatchPrompt,
              variant=Primary,
              theme~,
              width=54.0,
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
    height=layout.composer_height,
    background=@core.Color::white(),
    corner_radius=14.0,
    theme~,
    padding=12.0,
  )
  .border(workbench_hairline_border())
  .shadow(workbench_soft_shadow())
}

///|
fn WorkbenchModel::context_chip_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      text("上下文", role=Caption, theme~, width=52.0, height=30.0),
      self.context_chip("仓库", "repo", theme, width=50.0),
      self.context_chip("示例", "examples", theme, width=50.0),
      self.context_chip("证据", "evidence", theme, width=50.0),
      self.context_chip("会话", "session", theme, width=50.0),
      spacer(min_length=8.0, weight=1.0),
      text(
        self.context_summary_label(),
        role=Caption,
        theme~,
        width=workbench_max_double(1.0, layout.composer_input_width - 304.0),
        height=30.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::context_chip(
  self : WorkbenchModel,
  label : String,
  id : String,
  theme : @core.Theme,
  width~ : Double,
) -> @core.View[WorkbenchMsg] {
  button(
    label,
    on_click=ToggleContext(id),
    variant=if self.context_is_selected(id) { Outline } else { Ghost },
    theme~,
    width~,
    height=30.0,
  )
}

///|
fn WorkbenchModel::context_summary_label(self : WorkbenchModel) -> String {
  let labels : Array[String] = []
  for id in ["repo", "examples", "evidence", "session"] {
    if self.context_is_selected(id) {
      labels.push(context_display_label(id))
    }
  }
  for id in self.expanded_context {
    if !known_context_id(id) {
      labels.push(id)
    }
  }
  if labels.is_empty() {
    "不附加上下文"
  } else {
    labels.join("、")
  }
}

///|
fn context_display_label(id : String) -> String {
  match id {
    "repo" => "仓库"
    "examples" => "示例"
    "evidence" => "证据"
    "session" => "Pi 会话"
    _ => id
  }
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
    "全部"
  } else {
    "单条"
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
fn main_scrollbar(
  theme : @core.Theme,
  viewport_height~ : Double,
  content_height~ : Double,
  offset_y~ : Double,
) -> @core.View[WorkbenchMsg] {
  let width = 12.0
  custom_layout(
    measure=_ => @core.Size::new(width~, height=viewport_height),
    paint=frame => {
      let max_scroll = workbench_max_double(
        0.0,
        content_height - viewport_height,
      )
      if max_scroll <= 0.0 {
        return []
      }
      let track_width = 4.0
      let track = @core.Rect::new(
        x=frame.origin.x + (frame.size.width - track_width) / 2.0,
        y=frame.origin.y,
        width=track_width,
        height=frame.size.height,
      )
      let thumb_height = workbench_clamp_double(
        frame.size.height * frame.size.height / content_height,
        36.0,
        frame.size.height,
      )
      let thumb_y = frame.origin.y +
        (frame.size.height - thumb_height) *
        workbench_clamp_double(offset_y, 0.0, max_scroll) /
        max_scroll
      let thumb = @core.Rect::new(
        x=track.origin.x,
        y=thumb_y,
        width=track_width,
        height=thumb_height,
      )
      [
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=track, radius=2.0),
          @core.Brush::solid(theme.palette.outline.multiply_alpha(0.18)),
        ),
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=thumb, radius=2.0),
          @core.Brush::solid(theme.palette.primary.multiply_alpha(0.58)),
        ),
      ]
    },
    semantics_label="Mo Workbench main scrollbar",
  )
}

///|
fn workbench_hairline_border() -> @core.BorderStyle {
  @core.BorderStyle::new(
    brush=@core.Brush::solid(@core.Color::black().multiply_alpha(0.08)),
    width=1.0,
  )
}

///|
fn workbench_clear_border() -> @core.BorderStyle {
  @core.BorderStyle::new(
    brush=@core.Brush::solid(@core.Color::black().multiply_alpha(0.0)),
    width=1.0,
  )
}

///|
fn workbench_soft_shadow() -> @core.ShadowStyle {
  @core.ShadowStyle::new(
    color=@core.Color::black().multiply_alpha(0.10),
    offset=@core.Point::new(x=0.0, y=3.0),
    blur_radius=18.0,
  )
}

///|
fn ui_color(r : Double, g : Double, b : Double) -> @core.Color {
  @core.Color::rgba(r~, g~, b~)
}
