fn workbench_layout(
  viewport : @core.Size,
  inspector_requested : Bool,
) -> WorkbenchLayout {
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
  let status_bar_height = 30.0
  let workspace_body_height = workbench_max_double(
    280.0,
    viewport.height - main_padding * 2.0 - status_bar_height - 10.0,
  )
  let inspector_visible = inspector_requested && viewport.width >= 1120.0
  let inspector_gap = if inspector_visible { 14.0 } else { 0.0 }
  let inspector_width = if inspector_visible {
    workbench_clamp_double(main_available_width * 0.32, 286.0, 340.0)
  } else {
    0.0
  }
  let content_available_width = workbench_max_double(
    1.0,
    main_available_width - inspector_width - inspector_gap - scrollbar_width,
  )
  let content_width = workbench_clamp_double(
    content_available_width,
    workbench_min_double(460.0, content_available_width),
    860.0,
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
    panel_body_width - row_badge_width - 68.0 - 54.0 - 54.0 - 54.0 - 48.0,
  )
  let composer_width = workbench_max_double(
    1.0,
    content_width + scrollbar_width,
  )
  let composer_height = 70.0
  let top_inner_width = workbench_max_double(
    1.0,
    content_width + scrollbar_width - 24.0,
  )
  {
    viewport,
    sidebar_width,
    sidebar_inner_width: workbench_max_double(160.0, sidebar_width - 36.0),
    main_width,
    main_padding,
    workspace_body_height,
    inspector_visible,
    inspector_width,
    inspector_gap,
    inspector_body_width: workbench_max_double(1.0, inspector_width - 24.0),
    content_width,
    scrollbar_width,
    panel_width,
    panel_body_width,
    row_badge_width,
    row_text_width,
    command_text_width,
    top_identity_width: top_inner_width,
    composer_width,
    composer_input_width: workbench_max_double(1.0, composer_width - 24.0),
    composer_height,
    status_bar_height,
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
fn WorkbenchModel::view(self : WorkbenchModel) -> @core.View[WorkbenchMsg] {
  self.view_for_size(@core.Size::new(width=1220.0, height=780.0))
}

///|
fn WorkbenchModel::view_with_environment(
  self : WorkbenchModel,
  env : @core.ViewEnvironment,
) -> @core.View[WorkbenchMsg] {
  self.view_for_size(
    env.viewport_size(),
    scheme=self.appearance_color_scheme(env.environment().color_scheme),
  )
}

///|
fn WorkbenchModel::view_for_size(
  self : WorkbenchModel,
  viewport : @core.Size,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> @core.View[WorkbenchMsg] {
  let theme = workbench_theme(scheme)
  let layout = workbench_layout(viewport, true)
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
    background=workbench_app_background(theme),
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
  let rows : Array[@core.View[WorkbenchMsg]] = [
    self.sidebar_brand(layout, theme),
    self.sidebar_new_session_button(layout, theme),
    self.sidebar_section_label("任务历史", layout, theme),
    self.pinned_threads(layout, theme),
  ]
  rows.push(spacer(min_length=8.0, weight=1.0))
  rows.push(self.sidebar_settings_button(layout, theme))
  if self.should_show_sidebar_transport_footer() {
    rows.push(self.sidebar_footer(layout, theme))
  }
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=Stretch),
    width=layout.sidebar_width,
    height=layout.viewport.height,
    background=workbench_sidebar_background(theme),
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
        "Agent 桌面工作台",
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
        meta=sidebar_session_meta(session),
      ),
    )
  }
  column(rows, spacing=2.0, align=Stretch)
}

///|
fn WorkbenchModel::sidebar_new_session_button(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  button(
    "新对话",
    on_click=CreateConversation,
    variant=Outline,
    theme~,
    width=layout.sidebar_inner_width,
    height=34.0,
  )
}

///|
fn WorkbenchModel::should_show_sidebar_transport_footer(
  self : WorkbenchModel,
) -> Bool {
  self.active_agent_backend_status().has_sidebar_status()
}

///|
fn WorkbenchModel::sidebar_settings_button(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  button(
    "设置",
    on_click=SelectPanel("settings"),
    variant=if self.settings_page_active() { Outline } else { Ghost },
    theme~,
    width=layout.sidebar_inner_width,
    height=34.0,
  )
}

///|
fn WorkbenchModel::sidebar_footer(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let status = self.active_agent_backend_status()
  row(
    [
      text("Agent", role=Control, theme~, width=56.0, height=28.0),
      sidebar_backend_status_cell(status, layout, theme),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn sidebar_backend_status_cell(
  status : AgentBackendStatus,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let width = layout.sidebar_inner_width - 72.0
  if status.status_label == "" || status.status_label == "未连接" {
    if status.pending_count > 0 {
      text(
        status.pending_count.to_string() + " 排队",
        role=Caption,
        theme~,
        width~,
        height=28.0,
      )
    } else {
      blank_cell(width~, height=28.0)
    }
  } else {
    text(status.status_label, role=Caption, theme~, width~, height=28.0)
  }
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
    workbench_sidebar_selected_background(theme)
  } else {
    workbench_sidebar_background(theme)
  }
  let label_width = layout.sidebar_inner_width - 72.0
  surface(
    row(
      [
        button(
          end_ellipsis_label(
            label,
            max_chars=readable_line_char_limit(label_width),
          ),
          on_click=message,
          variant=Ghost,
          theme~,
          width=label_width,
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
    corner_radius=6.0,
    theme~,
    padding=2.0,
  ).border(
    if selected {
      workbench_hairline_border(theme)
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
  let scroll_height = self.main_scroll_height(layout)
  let content_height = self.chat_content_height(layout)
  let max_scroll = workbench_max_double(0.0, content_height - scroll_height)
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
            height=scroll_height,
            on_scroll=Some(delta => {
              MainScrollTo(
                workbench_clamp_double(offset_y - delta.y, 0.0, max_scroll),
              )
            }),
          ),
          main_scrollbar(
            theme,
            viewport_height=scroll_height,
            content_height~,
            offset_y~,
          ),
        ],
        spacing=0.0,
        align=Start,
      ).frame(
        width=layout.content_width + layout.scrollbar_width,
        height=scroll_height,
      ),
      self.composer(layout, theme),
    ],
    spacing=14.0,
    align=Center,
  )
  let workspace_body = if self.settings_page_active() {
    self.settings_page(layout, theme)
  } else if layout.inspector_visible {
    row(
      [center_column, self.workspace_inspector(layout, theme)],
      spacing=layout.inspector_gap,
      align=Start,
    )
  } else {
    center_column
  }
  surface(
    column(
      [workspace_body, self.workspace_status_bar(layout, theme)],
      spacing=10.0,
      align=Center,
    ),
    width=layout.main_width,
    height=layout.viewport.height,
    background=workbench_main_background(theme),
    corner_radius=0.0,
    theme~,
    padding=layout.main_padding,
  )
}

///|
fn WorkbenchModel::settings_page_active(self : WorkbenchModel) -> Bool {
  self.selected_panel == "settings"
}

///|
fn WorkbenchModel::settings_page(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let width = settings_page_width(layout)
  let body_width = workbench_max_double(1.0, width - 28.0)
  let rows : Array[@core.View[WorkbenchMsg]] = [
    self.settings_header_row(body_width, theme),
    self.settings_appearance_row(body_width, theme),
    self.settings_workspace_row(body_width, theme),
    self.settings_context_row(body_width, theme),
    self.settings_backend_row(body_width, theme),
  ]
  surface(
    column(rows, spacing=10.0, align=Stretch),
    width~,
    height=layout.workspace_body_height,
    background=workbench_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=14.0,
  ).border(workbench_hairline_border(theme))
}

///|
fn settings_page_width(layout : WorkbenchLayout) -> Double {
  let inspector_width = if layout.inspector_visible {
    layout.inspector_gap + layout.inspector_width
  } else {
    0.0
  }
  layout.content_width + layout.scrollbar_width + inspector_width
}

///|
fn WorkbenchModel::settings_header_row(
  self : WorkbenchModel,
  width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  row(
    [
      column(
        [
          text("设置", role=Title, theme~, width=width - 78.0, height=28.0),
          text(
            "工作台偏好",
            role=Caption,
            theme~,
            width=width - 78.0,
            height=20.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      button(
        "返回",
        on_click=SelectPanel("agent"),
        variant=Ghost,
        theme~,
        width=64.0,
        height=34.0,
      ),
    ],
    spacing=14.0,
    align=Center,
  ).frame(width~, height=52.0)
}

///|
fn WorkbenchModel::settings_appearance_row(
  self : WorkbenchModel,
  width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let label_width = 112.0
  let button_width = workbench_clamp_double(
    (width - label_width - 16.0 - 16.0) / 3.0,
    82.0,
    122.0,
  )
  settings_row_surface(
    row(
      [
        settings_row_label(
          "外观",
          appearance_mode_label(self.appearance_mode),
          label_width,
          theme,
        ),
        setting_choice_button(
          "跟随系统",
          selected=self.appearance_mode == "system",
          message=SetAppearanceMode("system"),
          width=button_width,
          theme,
        ),
        setting_choice_button(
          "浅色",
          selected=self.appearance_mode == "light",
          message=SetAppearanceMode("light"),
          width=button_width,
          theme,
        ),
        setting_choice_button(
          "深色",
          selected=self.appearance_mode == "dark",
          message=SetAppearanceMode("dark"),
          width=button_width,
          theme,
        ),
      ],
      spacing=8.0,
      align=Center,
    ),
    width,
    theme,
  )
}

///|
fn WorkbenchModel::settings_workspace_row(
  self : WorkbenchModel,
  width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let label_width = 112.0
  let button_width = workbench_clamp_double(
    (width - label_width - 16.0 - 8.0) / 2.0,
    112.0,
    154.0,
  )
  settings_row_surface(
    row(
      [
        settings_row_label("界面", "工作流", label_width, theme),
        button(
          if self.composer_controls_expanded {
            "收起选项"
          } else {
            "展开选项"
          },
          on_click=ToggleComposerControls,
          variant=if self.composer_controls_expanded { Outline } else { Ghost },
          theme~,
          width=button_width,
          height=34.0,
        ),
        button(
          if self.workspace_details_expanded {
            "收起详情"
          } else {
            "展开详情"
          },
          on_click=ToggleWorkspaceDetails,
          variant=if self.workspace_details_expanded { Outline } else { Ghost },
          theme~,
          width=button_width,
          height=34.0,
        ),
      ],
      spacing=8.0,
      align=Center,
    ),
    width,
    theme,
  )
}

///|
fn WorkbenchModel::settings_context_row(
  self : WorkbenchModel,
  width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let label_width = 112.0
  let chip_width = workbench_clamp_double(
    (width - label_width - 16.0 - 18.0) / 4.0,
    54.0,
    82.0,
  )
  settings_row_surface(
    row(
      [
        settings_row_label(
          "范围",
          self.status_bar_context_label(),
          label_width,
          theme,
        ),
        self.context_chip("仓库", "repo", theme, width=chip_width),
        self.context_chip("示例", "examples", theme, width=chip_width),
        self.context_chip("证据", "evidence", theme, width=chip_width),
        self.context_chip("会话", "session", theme, width=chip_width),
      ],
      spacing=6.0,
      align=Center,
    ),
    width,
    theme,
  )
}

///|
fn WorkbenchModel::settings_backend_row(
  self : WorkbenchModel,
  width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let label_width = 112.0
  settings_row_surface(
    row(
      [
        settings_row_label(
          "Agent",
          self.active_agent_backend_profile().label,
          label_width,
          theme,
        ),
        self.backend_selector_cell(theme),
        spacer(min_length=8.0, weight=1.0),
      ],
      spacing=8.0,
      align=Center,
    ),
    width,
    theme,
  )
}

///|
fn settings_row_label(
  title : String,
  detail : String,
  width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  column(
    [
      text(title, role=Control, theme~, width~, height=22.0),
      text(
        if detail == "" {
          "默认"
        } else {
          detail
        },
        role=Caption,
        theme~,
        width~,
        height=18.0,
      ),
    ],
    spacing=0.0,
    align=Start,
  )
}

///|
fn setting_choice_button(
  label : String,
  selected~ : Bool,
  message~ : WorkbenchMsg,
  width~ : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  button(
    label,
    on_click=message,
    variant=if selected { Outline } else { Ghost },
    theme~,
    width~,
    height=34.0,
  )
}

///|
fn settings_row_surface(
  child : @core.View[WorkbenchMsg],
  width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    child,
    width~,
    height=58.0,
    background=workbench_panel_raised_background(theme),
    corner_radius=6.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border(theme))
}

///|
fn WorkbenchModel::appearance_color_scheme(
  self : WorkbenchModel,
  environment_scheme : @core.ColorScheme,
) -> @core.ColorScheme {
  match self.appearance_mode {
    "light" => @core.ColorScheme::Light
    "dark" => @core.ColorScheme::Dark
    _ => environment_scheme
  }
}

///|
fn appearance_mode_label(mode : String) -> String {
  match mode {
    "light" => "浅色"
    "dark" => "深色"
    _ => "跟随系统"
  }
}

///|
fn WorkbenchModel::main_scroll_height(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
) -> Double {
  ignore(self)
  workbench_max_double(
    220.0,
    layout.workspace_body_height - 58.0 - self.composer_height(layout) - 28.0,
  )
}

///|
fn WorkbenchModel::top_bar(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  let show_backend_chip = self.should_show_top_bar_backend_chip()
  let show_status_meta = should_show_session_status_meta(active.status)
  let identity_width = top_bar_identity_width(
    layout,
    show_backend_chip~,
    show_status_meta~,
  )
  let controls : Array[@core.View[WorkbenchMsg]] = [
    self.top_bar_identity(active, identity_width, theme),
    spacer(min_length=10.0, weight=1.0),
  ]
  if show_backend_chip {
    controls.push(self.active_agent_backend_chip(theme))
  }
  if show_status_meta {
    controls.push(
      badge(
        session_status_label(active.status),
        tone=session_status_tone(active.status),
        theme~,
        width=74.0,
      ),
    )
  }
  surface(
    row(controls, spacing=8.0, align=Center),
    width=layout.content_width + layout.scrollbar_width,
    height=58.0,
    background=workbench_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  ).border(workbench_hairline_border(theme))
}

///|
fn top_bar_identity_width(
  layout : WorkbenchLayout,
  show_backend_chip~ : Bool,
  show_status_meta~ : Bool,
) -> Double {
  let chip_count = (if show_backend_chip { 1 } else { 0 }) +
    (if show_status_meta { 1 } else { 0 })
  let chip_width = (if show_backend_chip { 82.0 } else { 0.0 }) +
    (if show_status_meta { 74.0 } else { 0.0 })
  let spacing = (chip_count + 1).to_double() * 8.0
  let reserved = 10.0 + spacing + chip_width
  workbench_max_double(1.0, layout.top_identity_width - reserved)
}

///|
fn WorkbenchModel::should_show_top_bar_backend_chip(
  self : WorkbenchModel,
) -> Bool {
  self.active_agent_backend_status().has_top_bar_chip()
}

///|
fn WorkbenchModel::active_agent_backend_chip(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let status = self.active_agent_backend_status()
  badge("Agent " + status.label, tone=Neutral, theme~, width=82.0)
}

///|
fn WorkbenchModel::backend_selector_cell(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_agent_backend_profile()
  let controls : Array[@core.View[WorkbenchMsg]] = []
  for profile in agent_backend_profiles() {
    controls.push(
      button(
        profile.label,
        on_click=SwitchAgentBackend(profile.id),
        variant=if profile.id == active.id { Outline } else { Ghost },
        theme~,
        width=64.0,
        height=30.0,
      ),
    )
  }
  row(controls, spacing=4.0, align=Center)
}

///|
fn WorkbenchModel::top_bar_identity(
  self : WorkbenchModel,
  active : WorkbenchSession,
  identity_width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  let title_width = workbench_max_double(1.0, identity_width - 78.0 - 8.0)
  let title_label = end_ellipsis_label(
    active.title,
    max_chars=readable_line_char_limit(title_width),
  )
  column(
    [
      row(
        [
          badge("当前会话", tone=Accent, theme~, width=78.0),
          text(
            title_label,
            role=Control,
            theme~,
            width=title_width,
            height=24.0,
          ),
        ],
        spacing=8.0,
        align=Center,
      ),
      text(
        top_bar_session_meta_label(active, identity_width),
        role=Caption,
        theme~,
        width=identity_width,
        height=20.0,
      ),
    ],
    spacing=0.0,
    align=Start,
  ).frame(width=identity_width, height=46.0)
}

///|
fn top_bar_session_meta_label(
  session : WorkbenchSession,
  width : Double,
) -> String {
  let project = project_display_label(session.project_path)
  let branch = session.branch.trim().to_owned()
  let max_chars = readable_line_char_limit(width)
  if branch == "" {
    middle_ellipsis_label(project, max_chars~)
  } else {
    let branch_limit = workbench_clamp_int(
      (max_chars.to_double() * 0.42).to_int(),
      12,
      workbench_max_int(12, max_chars - 8),
    )
    let project_limit = workbench_max_int(8, max_chars - branch_limit - 3)
    middle_ellipsis_label(project, max_chars=project_limit) +
    " · " +
    middle_ellipsis_label(branch, max_chars=branch_limit)
  }
}

///|
fn sidebar_session_meta(session : WorkbenchSession) -> String {
  if should_show_session_status_meta(session.status) {
    session_status_label(session.status)
  } else {
    ""
  }
}

///|
fn should_show_session_status_meta(status : String) -> Bool {
  match status {
    "" | "active" | "idle" => false
    _ => true
  }
}

///|
fn project_display_label(path : String) -> String {
  let clean = path.trim().to_owned()
  if clean == "" {
    "未绑定工作区"
  } else {
    let chars = clean.to_array()
    let mut start = 0
    for index in 0..<chars.length() {
      if chars[index] == '/' || chars[index] == '\\' {
        start = index + 1
      }
    }
    if start >= chars.length() {
      clean
    } else {
      String::from_array(chars[start:])
    }
  }
}
