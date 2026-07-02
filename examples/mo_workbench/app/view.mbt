// DeepSeek-GUI-style shell: left workspace rail, topbar, center work surface,
// optional right inspector, and a low-noise status bar.

///|
priv struct WorkbenchLayout {
  sidebar_width : Double
  inspector_width : Double
  inspector_visible : Bool
  topbar_height : Double
  statusbar_height : Double
  center_width : Double
  center_height : Double
}

///|
fn workbench_layout(viewport : @core.Size) -> WorkbenchLayout {
  let topbar_height = 50.0
  let statusbar_height = 26.0
  let sidebar_width = if viewport.width < 760.0 {
    200.0
  } else if viewport.width < 1120.0 {
    248.0
  } else {
    280.0
  }
  let inspector_visible = viewport.width >= 1180.0
  let inspector_width = if inspector_visible { 340.0 } else { 0.0 }
  let center_width = (viewport.width - sidebar_width - inspector_width).max(
    320.0,
  )
  let center_height = (viewport.height - topbar_height - statusbar_height).max(
    320.0,
  )
  {
    sidebar_width,
    inspector_width,
    inspector_visible,
    topbar_height,
    statusbar_height,
    center_width,
    center_height,
  }
}

///|
fn workbench_view(
  model : WorkbenchModel,
  env : @core.ViewEnvironment,
) -> @moui.View[WorkbenchMsg] {
  let theme = workbench_theme(model.appearance, env)
  let viewport = env.viewport_size()
  let layout = workbench_layout(viewport)
  let panes : Array[@moui.View[WorkbenchMsg]] = [
    sidebar_view(model, theme, layout.sidebar_width, viewport.height),
    center_shell(model, theme, layout),
  ]
  if layout.inspector_visible {
    panes.push(
      inspector_shell(model, theme, layout.inspector_width, viewport.height),
    )
  }
  @views.container(
    @views.row(panes, spacing=0.0, align=@views.CrossAlign::Stretch),
    width=viewport.width,
    height=viewport.height,
    background=workbench_app_background(theme),
    padding=0.0,
  )
}

///|
fn center_shell(
  model : WorkbenchModel,
  theme : @core.Theme,
  layout : WorkbenchLayout,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        topbar_view(model, theme, layout.center_width, layout.topbar_height),
        main_surface(model, theme, layout.center_width, layout.center_height),
        statusbar_view(
          model,
          theme,
          layout.center_width,
          layout.statusbar_height,
        ),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width=layout.center_width,
    height=layout.topbar_height + layout.center_height + layout.statusbar_height,
    background=workbench_canvas_background(theme),
    padding=0.0,
  )
}

///|
fn topbar_view(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let title_width = (width - 420.0).max(160.0)
  let session_title = match model.active_workspace {
    Code => code_session_title(model.code)
    _ => workspace_label(model.active_workspace)
  }
  let controls : Array[@moui.View[WorkbenchMsg]] = []
  if model.active_workspace == Workspace::Code {
    controls.push(code_model_control(model.code, theme))
    controls.push(code_thinking_control(model.code, theme))
  } else {
    controls.push(
      @views.badge(
        workspace_label(model.active_workspace),
        tone=@views.BadgeTone::Neutral,
        theme~,
        width=132.0,
      ),
    )
  }
  @views.padding_edges(
    @views.container(
      @views.row(
        [
          @views.column(
            [
              @views.text(
                session_title,
                role=@views.TextRole::Label,
                theme~,
                width=title_width,
                height=20.0,
              ),
              @views.text(
                workspace_subtitle(model),
                role=@views.TextRole::Caption,
                theme~,
                width=title_width,
                height=16.0,
              ).foreground(theme.palette.muted),
            ],
            spacing=0.0,
            align=@views.CrossAlign::Start,
          ),
          @views.spacer(),
          @views.row(controls, spacing=12.0, align=@views.CrossAlign::Center),
        ],
        spacing=16.0,
        align=@views.CrossAlign::Center,
      ),
      width~,
      height~,
      background=workbench_card_background(theme),
      padding=0.0,
    ).border(hairline_border(theme)),
    top=0.0,
    left=28.0,
    bottom=0.0,
    right=24.0,
  )
}

///|
fn code_model_control(
  code : CodeWorkspace,
  theme : @core.Theme,
) -> @moui.View[WorkbenchMsg] {
  @views.segmented_control(
    [
      @views.choice_item("v4-pro", "V4 Pro"),
      @views.choice_item("v4-flash", "Flash"),
    ],
    selected=model_choice_id(code.current_model),
    on_select=id => {
      WorkbenchMsg::CodeMsg(CodeMsg::ModelChanged(model_choice_from_id(id)))
    },
    size=@views.SegmentedControlSize::Compact,
    theme~,
    width=148.0,
  )
}

///|
fn code_thinking_control(
  code : CodeWorkspace,
  theme : @core.Theme,
) -> @moui.View[WorkbenchMsg] {
  @views.segmented_control(
    [
      @views.choice_item("no", "No"),
      @views.choice_item("high", "High"),
      @views.choice_item("max", "Max"),
    ],
    selected=thinking_choice_id(code.current_thinking),
    on_select=id => {
      WorkbenchMsg::CodeMsg(
        CodeMsg::ThinkingChanged(thinking_choice_from_id(id)),
      )
    },
    size=@views.SegmentedControlSize::Compact,
    theme~,
    width=172.0,
  )
}

///|
///|
fn statusbar_view(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let runtime_status = if model.code.is_streaming {
    "Runtime: streaming"
  } else {
    "Runtime: ready"
  }
  let session_status = match model.code.active_session_id {
    Some(id) => "Session: " + truncate_text(id, 18)
    None => "Session: draft"
  }
  @views.status_bar(
    [
      "Mo Workbench",
      workspace_label(model.active_workspace),
      runtime_status,
      model_choice_label(model.code.current_model),
      thinking_choice_label(model.code.current_thinking),
      session_status,
    ],
    theme~,
    width~,
    height~,
  )
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

///|
fn sidebar_view(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let rows : Array[@moui.View[WorkbenchMsg]] = [
    workspace_switcher_section(model, theme, width),
    @views.divider(theme~),
    sidebar_workspace_body(model, theme, width, (height - 240.0).max(180.0)),
    @views.spacer(),
    sidebar_footer(model, theme, width),
  ]
  @views.container(
    @views.column(rows, spacing=0.0, align=@views.CrossAlign::Stretch),
    width~,
    height~,
    background=workbench_sidebar_background(theme),
    padding=0.0,
  ).border(hairline_border(theme))
}

///|
fn workspace_switcher_section(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let rows : Array[@moui.View[WorkbenchMsg]] = []
  for
    ws in [
      Workspace::Code,
      Workspace::Write,
      Workspace::ConnectPhone,
      Workspace::ScheduledTasks,
      Workspace::Plugins,
    ] {
    rows.push(
      workspace_switch_button(
        ws,
        model.active_workspace,
        theme,
        width,
        model.animation_progress,
      ),
    )
  }
  @views.padding_xy(
    @views.column(rows, spacing=4.0, align=@views.CrossAlign::Stretch),
    horizontal=12.0,
    vertical=12.0,
  )
}

///|
fn workspace_switch_button(
  ws : Workspace,
  active : Workspace,
  theme : @core.Theme,
  width : Double,
  anim_progress : Double,
) -> @moui.View[WorkbenchMsg] {
  let is_active = ws == active
  // Forward-only interpolation: the newly-active item's indicator fades in;
  // previously-active items snap to inactive immediately (no flash across
  // every button). A symmetric fade-out would require tracking the previous
  // active workspace on the model.
  let row_bg = if is_active {
    @core.animated_color(
      from=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
      to=workbench_sidebar_active(theme),
      progress=anim_progress,
    )
  } else {
    @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
  }
  let text_color = if is_active {
    workbench_accent(theme)
  } else {
    workbench_text_muted(theme)
  }
  let icon_color_final = if is_active { workbench_accent(theme) } else { workbench_text_muted(theme) }
  @views.container(
    @views.row(
      [
        @views.container(
          @views.icon(workspace_icon(ws), size=16.0, color=icon_color_final),
          width=28.0,
          height=28.0,
          padding=0.0,
        ),
        @views.text(
          workspace_label(ws),
          role=@views.TextRole::Label,
          theme~,
          width=width - 64.0,
        ).foreground(text_color),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    background=row_bg,
    corner_radius=6.0,
    padding=6.0,
  ).on_tap(WorkbenchMsg::SwitchWorkspace(ws))
}

///|
fn sidebar_workspace_body(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let body = match model.active_workspace {
    Code => code_sidebar_section(model.code, theme, width)
    Write =>
      static_sidebar_list(
        "Writing Spaces",
        ["Drafts", "Articles", "Release notes", "Research"],
        theme,
        width,
      )
    ConnectPhone =>
      static_sidebar_list(
        "Channels",
        ["Feishu / Lark", "WeChat relay", "Local webhook", "Manual test"],
        theme,
        width,
      )
    ScheduledTasks =>
      static_sidebar_list(
        "Task Queues",
        ["Today", "Daily", "Interval", "Manual"],
        theme,
        width,
      )
    Plugins =>
      static_sidebar_list(
        "Extensions",
        ["Skills", "MCP servers", "Web tools", "Memory"],
        theme,
        width,
      )
    Settings => settings_sidebar_section(model.settings, theme, width)
  }
  @views.container(
    @views.scroll_view(body, width~, height~),
    width~,
    height~,
    background=workbench_sidebar_background(theme),
    padding=0.0,
  )
}

///|
fn code_sidebar_section(
  code : CodeWorkspace,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let rows : Array[@moui.View[WorkbenchMsg]] = [
    @views.button(
      "New Chat",
      on_click=WorkbenchMsg::CodeMsg(CodeMsg::NewSession),
      variant=@views.ButtonVariant::Primary,
      theme~,
      icon=Some(@views.IconName::Plus),
      width=width - 32.0,
      height=36.0,
    ),
    sidebar_overline("Workspace", theme, width - 32.0),
    sidebar_info_row("Root", "~/projects/MoUI", theme, width - 32.0),
    sidebar_info_row("Policy", "Workspace write", theme, width - 32.0),
    sidebar_overline("History", theme, width - 32.0),
  ]
  if code.sessions.is_empty() {
    rows.push(sidebar_caption("No sessions yet", theme, width - 32.0))
  } else {
    for s in code.sessions {
      let is_active = code.active_session_id == Some(s.id)
      let label = if s.first_prompt.is_empty() { s.id } else { s.first_prompt }
      rows.push(
        session_row(
          s.id,
          truncate_text(label, 24),
          is_active,
          theme,
          width - 32.0,
        ),
      )
    }
  }
  @views.padding_xy(
    @views.column(rows, spacing=12.0, align=@views.CrossAlign::Stretch),
    horizontal=20.0,
    vertical=20.0,
  )
}

///|
fn static_sidebar_list(
  title : String,
  items : Array[String],
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let rows : Array[@moui.View[WorkbenchMsg]] = [
    sidebar_overline(title, theme, width - 32.0),
  ]
  for item in items {
    rows.push(sidebar_info_row(item, "Ready", theme, width - 32.0))
  }
  @views.padding_xy(
    @views.column(rows, spacing=12.0, align=@views.CrossAlign::Stretch),
    horizontal=20.0,
    vertical=16.0,
  )
}

///|
fn settings_sidebar_section(
  settings : SettingsWorkspace,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.padding_xy(
    @views.column(
      [
        sidebar_overline("Settings", theme, width - 32.0),
        sidebar_info_row(
          "Base URL",
          truncate_text(settings.base_url, 24),
          theme,
          width - 32.0,
        ),
        sidebar_info_row(
          "Approval",
          approval_policy_label(settings.approval_policy),
          theme,
          width - 32.0,
        ),
        sidebar_info_row(
          "Sandbox",
          sandbox_mode_label(settings.sandbox_mode),
          theme,
          width - 32.0,
        ),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Stretch,
    ),
    horizontal=20.0,
    vertical=16.0,
  )
}

///|
fn session_row(
  id : String,
  label : String,
  is_active : Bool,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.button(
    label,
    on_click=WorkbenchMsg::CodeMsg(CodeMsg::SelectSession(id)),
    variant=if is_active {
      @views.ButtonVariant::SubtleBrand
    } else {
      @views.ButtonVariant::Ghost
    },
    theme~,
    icon=Some(@views.IconName::Clipboard),
    width~,
    height=38.0,
  )
}

///|
fn sidebar_footer(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.padding_xy(
    @views.column(
      [
        workspace_switch_button(
          Workspace::Settings,
          model.active_workspace,
          theme,
          width,
          model.animation_progress,
        ),
        @views.padding_edges(
          @views.container(
            @views.row(
              [
                @views.text(
                  appearance_label(model.appearance),
                  role=@views.TextRole::Caption,
                  theme~,
                  width=width - 72.0,
                ),
                @views.spacer(),
                @views.text(
                  theme_label(theme),
                  role=@views.TextRole::Caption,
                  theme~,
                  width=32.0,
                ),
              ],
              align=@views.CrossAlign::Center,
            ),
            width~,
            corner_radius=8.0,
            padding=0.0,
          ).on_tap(WorkbenchMsg::ToggleAppearance),
          top=6.0,
          left=10.0,
          bottom=6.0,
          right=10.0,
        ),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Stretch,
    ),
    horizontal=20.0,
    vertical=16.0,
  )
}

///|
fn theme_label(theme : @core.Theme) -> String {
  match theme.scheme {
    Light => "☀"
    Dark => "☾"
  }
}

// ---------------------------------------------------------------------------
// Main surface and inspector
// ---------------------------------------------------------------------------

///|
fn main_surface(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let content = match model.active_workspace {
    Code =>
      code_workspace_view(model.code, theme, width, height).map(m => {
        WorkbenchMsg::CodeMsg(m)
      })
    Settings =>
      settings_workspace_view(model.settings, theme, width, height).map(m => {
        WorkbenchMsg::SettingsMsg(m)
      })
    Write => write_workspace_view(theme, width, height)
    ConnectPhone => connect_phone_workspace_view(theme, width, height)
    ScheduledTasks => scheduled_tasks_workspace_view(theme, width, height)
    Plugins => plugins_workspace_view(theme, width, height)
  }
  // Fade-in entrance when switching workspaces.
  content.transition(
    spec=@core.TransitionSpec::fade(
      from_opacity=0.0,
      to_opacity=1.0,
      duration_ms=180.0,
    ),
    progress=model.animation_progress,
  )
}

///|
fn inspector_shell(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {    @views.container(
    @views.scroll_view(inspector_content(model, theme, width), width~, height~),
    width~,
    height~,
    background=workbench_sidebar_background(theme),
    padding=20.0,
  ).border(hairline_border(theme))
}

///|
fn inspector_content(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  match model.active_workspace {
    Code => code_inspector(model.code, theme, width - 28.0)
    Write => write_inspector(theme, width - 28.0)
    ConnectPhone => connect_phone_inspector(theme, width - 28.0)
    ScheduledTasks => schedule_inspector(theme, width - 28.0)
    Plugins => plugins_inspector(theme, width - 28.0)
    Settings => settings_inspector(model.settings, theme, width - 28.0)
  }
}

///|
fn code_inspector(
  code : CodeWorkspace,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.column(
    [
      inspector_card(
        "Plan",
        [
          "1. Inspect current app shell", "2. Refactor UI surfaces", "3. Run focused checks",
        ],
        @views.BadgeTone::Accent,
        theme,
        width,
      ),
      inspector_card(
        "Todo",
        [
          "Keep backend boundary stable", "Preserve session state", "Avoid framework API churn",
        ],
        @views.BadgeTone::Neutral,
        theme,
        width,
      ),
      inspector_card(
        "Changes",
        [
          "No file edits yet in this turn", "Diff inspector reserved for backend events",
        ],
        @views.BadgeTone::Warning,
        theme,
        width,
      ),
      inspector_card(
        "Context",
        [
          model_choice_label(code.current_model),
          thinking_choice_label(code.current_thinking),
          if code.is_streaming {
            "Turn is streaming"
          } else {
            "Ready for a task"
          },
        ],
        @views.BadgeTone::Success,
        theme,
        width,
      ),
    ],
    spacing=18.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn write_inspector(
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.column(
    [
      inspector_card(
        "Assistant",
        ["Summarize selection", "Rewrite tone", "Continue draft"],
        @views.BadgeTone::Accent,
        theme,
        width,
      ),
      inspector_card(
        "Outline",
        ["Overview", "Architecture", "Validation"],
        @views.BadgeTone::Neutral,
        theme,
        width,
      ),
      inspector_card(
        "Export",
        ["HTML", "PDF", "DOCX"],
        @views.BadgeTone::Success,
        theme,
        width,
      ),
    ],
    spacing=16.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn connect_phone_inspector(
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.column(
    [
      inspector_card(
        "Channels",
        ["Feishu / Lark ready", "WeChat relay offline", "Webhook local only"],
        @views.BadgeTone::Neutral,
        theme,
        width,
      ),
      inspector_card(
        "Manual Task",
        ["Send a test prompt", "Inspect reply payload"],
        @views.BadgeTone::Accent,
        theme,
        width,
      ),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn schedule_inspector(
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.column(
    [
      inspector_card(
        "Next Runs",
        ["Daily standup: 09:00", "Dependency audit: Friday"],
        @views.BadgeTone::Success,
        theme,
        width,
      ),
      inspector_card(
        "Defaults",
        ["Model: V4 Pro", "Sandbox: workspace"],
        @views.BadgeTone::Neutral,
        theme,
        width,
      ),
    ],
    spacing=16.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn plugins_inspector(
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.column(
    [
      inspector_card(
        "Capabilities",
        ["Skills enabled", "MCP catalog reserved", "Web tools reserved"],
        @views.BadgeTone::Accent,
        theme,
        width,
      ),
      inspector_card(
        "Diagnostics",
        ["No runtime provider connected"],
        @views.BadgeTone::Warning,
        theme,
        width,
      ),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn settings_inspector(
  settings : SettingsWorkspace,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  inspector_card(
    "Current Settings",
    [
      "Approval: " + approval_policy_label(settings.approval_policy),
      "Sandbox: " + sandbox_mode_label(settings.sandbox_mode),
      "Font: " + settings.font_size.to_string() + " pt",
    ],
    @views.BadgeTone::Neutral,
    theme,
    width,
  )
}

// ---------------------------------------------------------------------------
// Small view helpers
// ---------------------------------------------------------------------------

///|
fn[Msg] inspector_card(
  title : String,
  lines : Array[String],
  tone : @views.BadgeTone,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = [
    @views.row(
      [
        @views.badge(title, tone~, theme~, width=(width - 24.0).min(132.0)),
        @views.spacer(),
      ],
      align=@views.CrossAlign::Center,
    ),
  ]
  for line in lines {
    rows.push(
      @views.text(
        line,
        role=@views.TextRole::Caption,
        theme~,
        width=width - 24.0,
      ).foreground(theme.palette.muted),
    )
  }
  @views.container(
    @views.column(rows, spacing=8.0, align=@views.CrossAlign::Start),
    width~,
    background=workbench_card_background(theme),
    corner_radius=10.0,
    padding=16.0,
  )
}

///|
fn[Msg] sidebar_overline(
  text_ : String,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[Msg] {
  @views.text(text_, role=@views.TextRole::Overline, theme~, width~).foreground(
    theme.palette.muted,
  )
}

///|
fn[Msg] sidebar_caption(
  text_ : String,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[Msg] {
  @views.text(text_, role=@views.TextRole::Caption, theme~, width~).foreground(
    theme.palette.muted,
  )
}

///|
fn[Msg] sidebar_info_row(
  label : String,
  value : String,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[Msg] {
  @views.container(
    @views.column(
      [
        @views.text(
          label,
          role=@views.TextRole::Label,
          theme~,
          width=width - 20.0,
        ),
        @views.text(
          value,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 20.0,
        ).foreground(theme.palette.muted),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    background=workbench_subtle_background(theme),
    corner_radius=8.0,
    padding=12.0,
  )
}

// ---------------------------------------------------------------------------
// Pure helpers
// ---------------------------------------------------------------------------

///|
fn workspace_label(ws : Workspace) -> String {
  match ws {
    Code => "Code"
    Write => "Write"
    Settings => "Settings"
    ConnectPhone => "Connect Phone"
    ScheduledTasks => "Scheduled Tasks"
    Plugins => "Plugins"
  }
}

///|
fn workspace_icon(ws : Workspace) -> @views.IconName {
  match ws {
    Code => @views.IconName::CodeInline
    Write => @views.IconName::FileNew
    Settings => @views.IconName::Settings
    ConnectPhone => @views.IconName::Link
    ScheduledTasks => @views.IconName::ListTask
    Plugins => @views.IconName::Columns
  }
}

///|
fn workspace_subtitle(model : WorkbenchModel) -> String {
  match model.active_workspace {
    Code =>
      if model.code.is_streaming {
        "Agent is working in the current repository."
      } else {
        "Ask the agent to inspect, edit, test, or review."
      }
    Write => "Draft, review, and export Markdown documents."
    Settings => "Configure runtime, permissions, and workbench preferences."
    ConnectPhone => "Connect IM channels and manual phone-side tasks."
    ScheduledTasks => "Prepare repeatable prompts for later execution."
    Plugins => "Manage skills, MCP servers, and tool capabilities."
  }
}

///|
fn code_session_title(code : CodeWorkspace) -> String {
  match code.active_session_id {
    Some(id) => truncate_text(id, 34)
    None => "New coding session"
  }
}

///|
fn appearance_label(appearance : AppearanceMode) -> String {
  match appearance {
    System => "Appearance: System"
    Light => "Appearance: Light"
    Dark => "Appearance: Dark"
  }
}

///|
fn model_choice_id(model : ModelChoice) -> String {
  match model {
    V4Flash => "v4-flash"
    V4Pro => "v4-pro"
  }
}

///|
fn model_choice_from_id(id : String) -> ModelChoice {
  match id {
    "v4-flash" => ModelChoice::V4Flash
    _ => ModelChoice::V4Pro
  }
}

///|
fn model_choice_label(model : ModelChoice) -> String {
  match model {
    V4Flash => "V4 Flash"
    V4Pro => "V4 Pro"
  }
}

///|
fn thinking_choice_id(thinking : ThinkingChoice) -> String {
  match thinking {
    No => "no"
    High => "high"
    Max => "max"
  }
}

///|
fn thinking_choice_from_id(id : String) -> ThinkingChoice {
  match id {
    "no" => ThinkingChoice::No
    "high" => ThinkingChoice::High
    _ => ThinkingChoice::Max
  }
}

///|
fn thinking_choice_label(thinking : ThinkingChoice) -> String {
  match thinking {
    No => "Thinking: Off"
    High => "Thinking: High"
    Max => "Thinking: Max"
  }
}

///|
fn approval_policy_id(policy : ApprovalPolicy) -> String {
  match policy {
    NeverAsk => "never"
    AskOnWrite => "write"
    AskOnCommand => "command"
  }
}

///|
fn approval_policy_from_id(id : String) -> ApprovalPolicy {
  match id {
    "never" => ApprovalPolicy::NeverAsk
    "command" => ApprovalPolicy::AskOnCommand
    _ => ApprovalPolicy::AskOnWrite
  }
}

///|
fn approval_policy_label(policy : ApprovalPolicy) -> String {
  match policy {
    NeverAsk => "Never ask"
    AskOnWrite => "Ask on write"
    AskOnCommand => "Ask on command"
  }
}

///|
fn sandbox_mode_id(mode : SandboxMode) -> String {
  match mode {
    ReadOnly => "read-only"
    WorkspaceWritable => "workspace"
    FullAccess => "full"
  }
}

///|
fn sandbox_mode_from_id(id : String) -> SandboxMode {
  match id {
    "read-only" => SandboxMode::ReadOnly
    "full" => SandboxMode::FullAccess
    _ => SandboxMode::WorkspaceWritable
  }
}

///|
fn sandbox_mode_label(mode : SandboxMode) -> String {
  match mode {
    ReadOnly => "Read only"
    WorkspaceWritable => "Workspace writable"
    FullAccess => "Full access"
  }
}

///|
fn truncate_text(text : String, max : Int) -> String {
  let chars = text.to_array()
  if chars.length() <= max {
    text
  } else {
    let buf = StringBuilder::new()
    for c in chars[0:max] {
      buf.write_char(c)
    }
    buf.write_string("...")
    buf.to_string()
  }
}
