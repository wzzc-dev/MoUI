// Work / Design tab surfaces. Work is a compact task dashboard over the
// existing session projection; Design remains a placeholder until preview
// workflows are wired.

///|
priv struct WorkTabSummary {
  total : Int
  active : Int
  running : Int
  completed : Int
  failed : Int
}

///|
priv struct WorkAction {
  title : String
  detail : String
  label : String
  icon : @views.IconName
  action : WorkbenchMsg
  variant : @views.ButtonVariant
}

///|
priv struct DesignTabSummary {
  total_tasks : Int
  active_session : String
  model : String
  approval : String
  sandbox : String
  font_size : String
}

///|
fn work_tab_summary(model : WorkbenchModel) -> WorkTabSummary {
  let active_id = model.code.active_session_id
  let messages = model.code.messages
  let mut active = 0
  let mut running = 0
  let mut completed = 0
  let mut failed = 0
  for session in model.code.sessions {
    let is_active = match active_id {
      Some(id) => id == session.id
      None => false
    }
    if is_active {
      active += 1
    }
    let status = derive_task_status(
      session.id,
      active_id,
      model.code.is_streaming,
      messages,
    )
    match status {
      Pending => ()
      Running => running += 1
      Completed => completed += 1
      Failed => failed += 1
    }
  }
  { total: model.code.sessions.length(), active, running, completed, failed }
}

///|
fn work_next_actions(model : WorkbenchModel) -> Array[WorkAction] {
  let summary = work_tab_summary(model)
  let actions : Array[WorkAction] = []
  if summary.failed > 0 {
    actions.push({
      title: "Review failed tasks",
      detail: "\{summary.failed} task needs attention",
      label: "Review",
      icon: @views.IconName::Info,
      action: WorkbenchMsg::ShowFailedTasks,
      variant: @views.ButtonVariant::Primary,
    })
  }
  if summary.running > 0 {
    actions.push({
      title: "Watch running work",
      detail: "\{summary.running} agent turn in progress",
      label: "Running",
      icon: @views.IconName::Focus,
      action: WorkbenchMsg::ShowRunningTasks,
      variant: @views.ButtonVariant::Tonal,
    })
  }
  match model.code.active_session_id {
    Some(_) =>
      actions.push({
        title: "Continue active task",
        detail: "Open the current code timeline",
        label: "Open Code",
        icon: @views.IconName::ArrowRight,
        action: WorkbenchMsg::SwitchTab(TopTab::Code),
        variant: @views.ButtonVariant::Tonal,
      })
    None => ()
  }
  if summary.total > 0 {
    actions.push({
      title: "Show all tasks",
      detail: "\{summary.total} sessions in this workspace",
      label: "All tasks",
      icon: @views.IconName::ListTask,
      action: WorkbenchMsg::ShowAllTasks,
      variant: @views.ButtonVariant::Ghost,
    })
  }
  actions.push({
    title: "Start a new task",
    detail: "Create a fresh agent session",
    label: "New task",
    icon: @views.IconName::Plus,
    action: WorkbenchMsg::NewTask,
    variant: @views.ButtonVariant::Primary,
  })
  actions.push({
    title: "Agent settings",
    detail: "Model, approval, sandbox, and workspace",
    label: "Settings",
    icon: @views.IconName::Settings,
    action: WorkbenchMsg::ToggleSettings,
    variant: @views.ButtonVariant::Ghost,
  })
  actions
}

///|
fn task_status_for_session(
  model : WorkbenchModel,
  session : SessionSummary,
) -> TaskStatus {
  derive_task_status(
    session.id,
    model.code.active_session_id,
    model.code.is_streaming,
    model.code.messages,
  )
}

///|
fn work_tab_view(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let inner_width = (width - 64.0).max(360.0)
  let summary = work_tab_summary(model)
  @views.container(
    @views.scroll_view(
      @views.column(
        [
          work_tab_header(summary, theme, inner_width),
          work_summary_cards(summary, theme, inner_width),
          work_next_actions_section(model, theme, inner_width),
          work_recent_tasks(model, theme, inner_width),
        ],
        spacing=18.0,
        align=@views.CrossAlign::Stretch,
      ),
      width=inner_width,
      height=(height - 64.0).max(260.0),
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=32.0,
  )
}

///|
fn work_tab_header(
  summary : WorkTabSummary,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.row(
    [
      @views.column(
        [
          @views.text(
            "Work",
            role=@views.TextRole::Title,
            theme~,
            width=width - 150.0,
          ),
          @views.text(
            "任务概览、运行状态和最近会话 · Active \{summary.active}",
            role=@views.TextRole::Caption,
            theme~,
            width=width - 150.0,
          ).foreground(workbench_text_muted(theme)),
        ],
        spacing=4.0,
        align=@views.CrossAlign::Start,
      ),
      @views.spacer(),
      @views.button(
        "新建任务",
        on_click=WorkbenchMsg::NewTask,
        variant=@views.ButtonVariant::Tonal,
        theme~,
        icon=Some(@views.IconName::Plus),
        width=112.0,
        height=34.0,
      ),
    ],
    spacing=16.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn work_summary_cards(
  summary : WorkTabSummary,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let card_width = (width - 36.0) / 4.0
  @views.row(
    [
      work_metric_card(
        "Total",
        "\{summary.total}",
        workbench_accent(theme),
        theme,
        card_width,
      ),
      work_metric_card(
        "Running",
        "\{summary.running}",
        workbench_accent(theme),
        theme,
        card_width,
      ),
      work_metric_card(
        "Failed",
        "\{summary.failed}",
        workbench_danger(theme),
        theme,
        card_width,
      ),
      work_metric_card(
        "Done",
        "\{summary.completed}",
        workbench_success(theme),
        theme,
        card_width,
      ),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn work_metric_card(
  label : String,
  value : String,
  color : @graphics.Color,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        @views.text(
          value,
          role=@views.TextRole::Title,
          theme~,
          width=width - 24.0,
        ).foreground(color),
        @views.text(
          label,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 24.0,
        ).foreground(workbench_text_muted(theme)),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=82.0,
    background=workbench_card_background(theme),
    corner_radius=10.0,
    border=Some(hairline_border(theme)),
    padding=12.0,
  )
}

///|
fn work_next_actions_section(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let summary = work_tab_summary(model)
  let actions = work_next_actions(model)
  let badge = if summary.failed > 0 {
    "Needs review"
  } else if summary.running > 0 {
    "In progress"
  } else {
    "Ready"
  }
  let rows : Array[@moui.View[WorkbenchMsg]] = [
    @views.row(
      [
        @views.text(
          "Next actions",
          role=@views.TextRole::Label,
          theme~,
          width=width - 120.0,
        ),
        @views.spacer(),
        @views.badge(badge, theme~, width=104.0, height=24.0),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Center,
    ),
  ]
  if width < 560.0 {
    for action in actions {
      rows.push(work_action_card(action, theme, width))
    }
  } else {
    let card_width = (width - 12.0) / 2.0
    let mut index = 0
    while index < actions.length() {
      let row_items : Array[@moui.View[WorkbenchMsg]] = [
        work_action_card(actions[index], theme, card_width),
      ]
      if index + 1 < actions.length() {
        row_items.push(work_action_card(actions[index + 1], theme, card_width))
      } else {
        row_items.push(@views.spacer(min_length=card_width))
      }
      rows.push(
        @views.row(row_items, spacing=12.0, align=@views.CrossAlign::Center),
      )
      index += 2
    }
  }
  @views.column(rows, spacing=8.0, align=@views.CrossAlign::Stretch)
}

///|
fn work_action_card(
  action : WorkAction,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        @views.row(
          [
            @views.icon(action.icon, size=18.0, color=workbench_accent(theme)),
            @views.text(
              action.title,
              role=@views.TextRole::Label,
              theme~,
              width=width - 54.0,
            ),
          ],
          spacing=8.0,
          align=@views.CrossAlign::Center,
        ),
        @views.text(
          action.detail,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 28.0,
        ).foreground(workbench_text_muted(theme)),
        @views.button(
          action.label,
          on_click=action.action,
          variant=action.variant,
          theme~,
          icon=Some(action.icon),
          width=(width - 28.0).min(132.0),
          height=32.0,
        ),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=132.0,
    background=workbench_card_background(theme),
    corner_radius=10.0,
    border=Some(hairline_border(theme)),
    padding=14.0,
  )
}

///|
fn work_recent_tasks(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let rows : Array[@moui.View[WorkbenchMsg]] = [
    @views.text("Recent tasks", role=@views.TextRole::Label, theme~, width~),
  ]
  if model.code.sessions.is_empty() {
    rows.push(work_empty_task_card(theme, width))
  } else {
    let mut shown = 0
    for session in model.code.sessions {
      if shown < 5 {
        rows.push(work_task_row(model, session, theme, width))
        shown += 1
      }
    }
  }
  @views.column(rows, spacing=8.0, align=@views.CrossAlign::Stretch)
}

///|
fn work_empty_task_card(
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        @views.text(
          "暂无任务",
          role=@views.TextRole::Label,
          theme~,
          width=width - 32.0,
        ),
        @views.text(
          "点击新建任务开始一次 agent 工作流",
          role=@views.TextRole::Caption,
          theme~,
          width=width - 32.0,
        ).foreground(workbench_text_muted(theme)),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    background=workbench_card_background(theme),
    corner_radius=10.0,
    border=Some(hairline_border(theme)),
    padding=16.0,
  )
}

///|
fn work_task_row(
  model : WorkbenchModel,
  session : SessionSummary,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let status = task_status_for_session(model, session)
  let title = if session.first_prompt == "" {
    "New task"
  } else {
    session.first_prompt
  }
  let status_color = task_status_color(status, theme)
  @views.container(
    @views.row(
      [
        @views.container(
          @views.spacer(min_length=0.0),
          width=10.0,
          height=10.0,
          background=status_color,
          corner_radius=5.0,
          padding=0.0,
        ),
        @views.column(
          [
            @views.text(
              truncate_text(title, 48),
              role=@views.TextRole::Label,
              theme~,
              width=width - 160.0,
            ),
            @views.text(
              truncate_text(session.id, 28),
              role=@views.TextRole::Caption,
              theme~,
              width=width - 160.0,
            ).foreground(workbench_text_muted(theme)),
          ],
          spacing=2.0,
          align=@views.CrossAlign::Start,
        ),
        @views.spacer(),
        @views.badge(task_status_label(status), theme~, width=78.0, height=24.0),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    background=workbench_card_background(theme),
    corner_radius=8.0,
    border=Some(hairline_border(theme)),
    padding=12.0,
  ).on_tap(WorkbenchMsg::SelectTask(session.id))
}

///|
fn task_status_label(status : TaskStatus) -> String {
  match status {
    Pending => "Pending"
    Running => "Running"
    Completed => "Done"
    Failed => "Failed"
  }
}

///|
fn task_status_color(
  status : TaskStatus,
  theme : @moui.Theme,
) -> @graphics.Color {
  match status {
    Pending => workbench_text_faint(theme)
    Running => workbench_accent(theme)
    Completed => workbench_success(theme)
    Failed => workbench_danger(theme)
  }
}

///|
fn design_tab_summary(model : WorkbenchModel) -> DesignTabSummary {
  let active_session = match model.code.active_session_id {
    Some(id) => truncate_text(id, 24)
    None => "Draft"
  }
  {
    total_tasks: model.code.sessions.length(),
    active_session,
    model: truncate_text(model.code.current_model, 24),
    approval: approval_policy_label(model.settings.approval_policy),
    sandbox: sandbox_mode_label(model.settings.sandbox_mode),
    font_size: model.settings.font_size.to_string() + " pt",
  }
}

///|
fn approval_policy_label(policy : ApprovalPolicy) -> String {
  match policy {
    NeverAsk => "Never"
    AskOnWrite => "On write"
    AskOnCommand => "Command"
  }
}

///|
fn sandbox_mode_label(mode : SandboxMode) -> String {
  match mode {
    ReadOnly => "Read only"
    WorkspaceWritable => "Workspace"
    FullAccess => "Full access"
  }
}

///|
fn design_tab_view(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let inner_width = (width - 64.0).max(360.0)
  let summary = design_tab_summary(model)
  @views.container(
    @views.scroll_view(
      @views.column(
        [
          design_tab_header(summary, theme, inner_width),
          design_status_grid(summary, theme, inner_width),
          design_component_preview(summary, theme, inner_width),
          design_palette_preview(theme, inner_width),
        ],
        spacing=18.0,
        align=@views.CrossAlign::Stretch,
      ),
      width=inner_width,
      height=(height - 64.0).max(260.0),
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=32.0,
  )
}

///|
fn design_tab_header(
  summary : DesignTabSummary,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.row(
    [
      @views.column(
        [
          @views.text(
            "Design",
            role=@views.TextRole::Title,
            theme~,
            width=width - 150.0,
          ),
          @views.text(
            "界面状态、控件样式和主题 token · " +
            summary.active_session,
            role=@views.TextRole::Caption,
            theme~,
            width=width - 150.0,
          ).foreground(workbench_text_muted(theme)),
        ],
        spacing=4.0,
        align=@views.CrossAlign::Start,
      ),
      @views.spacer(),
      @views.button(
        "设置",
        on_click=WorkbenchMsg::ToggleSettings,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        icon=Some(@views.IconName::Settings),
        width=104.0,
        height=34.0,
      ),
    ],
    spacing=16.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn design_status_grid(
  summary : DesignTabSummary,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let card_width = (width - 12.0) / 2.0
  @views.column(
    [
      @views.row(
        [
          design_fact_card(
            "Tasks",
            summary.total_tasks.to_string(),
            workbench_accent(theme),
            theme,
            card_width,
          ),
          design_fact_card(
            "Model",
            summary.model,
            workbench_accent(theme),
            theme,
            card_width,
          ),
        ],
        spacing=12.0,
        align=@views.CrossAlign::Center,
      ),
      @views.row(
        [
          design_fact_card(
            "Approval",
            summary.approval,
            workbench_success(theme),
            theme,
            card_width,
          ),
          design_fact_card(
            "Sandbox",
            summary.sandbox,
            workbench_accent(theme),
            theme,
            card_width,
          ),
        ],
        spacing=12.0,
        align=@views.CrossAlign::Center,
      ),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn design_fact_card(
  label : String,
  value : String,
  color : @graphics.Color,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        @views.text(
          value,
          role=@views.TextRole::Label,
          theme~,
          width=width - 28.0,
        ).foreground(color),
        @views.text(
          label,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 28.0,
        ).foreground(workbench_text_muted(theme)),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=74.0,
    background=workbench_card_background(theme),
    corner_radius=10.0,
    border=Some(hairline_border(theme)),
    padding=14.0,
  )
}

///|
fn design_component_preview(
  summary : DesignTabSummary,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        @views.row(
          [
            @views.text(
              "Controls",
              role=@views.TextRole::Label,
              theme~,
              width=width - 128.0,
            ),
            @views.badge(summary.font_size, theme~, width=74.0, height=24.0),
          ],
          spacing=12.0,
          align=@views.CrossAlign::Center,
        ),
        @views.row(
          [
            @views.button(
              "New task",
              on_click=WorkbenchMsg::NewTask,
              variant=@views.ButtonVariant::Primary,
              theme~,
              icon=Some(@views.IconName::Plus),
              width=118.0,
              height=36.0,
            ),
            @views.button(
              "Review",
              on_click=WorkbenchMsg::SwitchTab(TopTab::Work),
              variant=@views.ButtonVariant::Tonal,
              theme~,
              width=98.0,
              height=36.0,
            ),
            @views.button(
              "Code",
              on_click=WorkbenchMsg::SwitchTab(TopTab::Code),
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=82.0,
              height=36.0,
            ),
            @views.spacer(),
          ],
          spacing=10.0,
          align=@views.CrossAlign::Center,
        ),
        @views.row(
          [
            @views.chip(
              summary.sandbox,
              selected=true,
              theme~,
              width=104.0,
              height=28.0,
            ),
            @views.chip(summary.approval, theme~, width=96.0, height=28.0),
            @views.badge("Ready", theme~, width=70.0, height=24.0),
            @views.badge("Diff", theme~, width=58.0, height=24.0),
            @views.spacer(),
          ],
          spacing=8.0,
          align=@views.CrossAlign::Center,
        ),
      ],
      spacing=14.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    background=workbench_card_background(theme),
    corner_radius=10.0,
    border=Some(hairline_border(theme)),
    padding=16.0,
  )
}

///|
fn design_palette_preview(
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let swatch_width = (width - 32.0) / 5.0
  @views.column(
    [
      @views.text("Palette", role=@views.TextRole::Label, theme~, width~),
      @views.row(
        [
          design_swatch(
            "Canvas",
            workbench_canvas_background(theme),
            theme,
            swatch_width,
          ),
          design_swatch(
            "Card",
            workbench_card_background(theme),
            theme,
            swatch_width,
          ),
          design_swatch("Accent", workbench_accent(theme), theme, swatch_width),
          design_swatch("OK", workbench_success(theme), theme, swatch_width),
          design_swatch("Risk", workbench_danger(theme), theme, swatch_width),
        ],
        spacing=8.0,
        align=@views.CrossAlign::Center,
      ),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn design_swatch(
  label : String,
  color : @graphics.Color,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.row(
      [
        @views.container(
          @views.spacer(min_length=0.0),
          width=16.0,
          height=16.0,
          background=color,
          corner_radius=4.0,
          border=Some(hairline_border(theme)),
          padding=0.0,
        ),
        @views.text(
          label,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 28.0,
        ).foreground(workbench_text_muted(theme)),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=44.0,
    background=workbench_card_background(theme),
    corner_radius=8.0,
    border=Some(hairline_border(theme)),
    padding=8.0,
  )
}
