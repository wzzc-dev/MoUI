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
  workspace_body_height : Double
  inspector_visible : Bool
  inspector_width : Double
  inspector_gap : Double
  inspector_body_width : Double
  content_width : Double
  scrollbar_width : Double
  panel_width : Double
  panel_body_width : Double
  row_badge_width : Double
  row_text_width : Double
  command_text_width : Double
  top_identity_width : Double
  composer_width : Double
  composer_input_width : Double
  composer_height : Double
  status_bar_height : Double
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
pub fn WorkbenchModel::view(self : WorkbenchModel) -> @core.View[WorkbenchMsg] {
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

///|
fn WorkbenchModel::chat_transcript(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if self.should_show_chat_empty_state() {
    return self.chat_empty_state(layout, theme)
  }
  let rows : Array[@core.View[WorkbenchMsg]] = []
  if self.has_session_status_panel_content() {
    rows.push(self.session_status_panel(layout, theme))
  }
  if self.has_transcript_panel_content() {
    rows.push(self.transcript_panel(layout, theme))
  }
  if !layout.inspector_visible && self.has_turn_evidence_card_content() {
    rows.push(self.turn_evidence_card(layout, theme))
  }
  column(rows, spacing=10.0, align=Center)
}

///|
fn WorkbenchModel::chat_content_height(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
) -> Double {
  if self.should_show_chat_empty_state() {
    return self.main_scroll_height(layout)
  }
  let mut height = 0.0
  if self.has_session_status_panel_content() {
    height = height +
      session_status_panel_height(self.session_status_row_count())
  }
  if self.has_transcript_panel_content() {
    if height > 0.0 {
      height = height + 10.0
    }
    height = height + self.transcript_panel_height(layout)
  }
  if !layout.inspector_visible && self.has_turn_evidence_card_content() {
    if height > 0.0 {
      height = height + 10.0
    }
    height = height + self.turn_evidence_card_height()
  }
  height
}

///|
fn WorkbenchModel::should_show_chat_empty_state(self : WorkbenchModel) -> Bool {
  !self.has_session_status_panel_content() &&
  !self.has_transcript_panel_content() &&
  !self.has_turn_evidence_card_content()
}

///|
fn WorkbenchModel::chat_empty_state(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  let width = layout.content_width
  let body_width = workbench_clamp_double(width - 96.0, 220.0, 520.0)
  let height = self.main_scroll_height(layout)
  column(
    [
      spacer(min_length=1.0, weight=1.0),
      text(
        "准备开始这个会话",
        role=Control,
        theme~,
        width=body_width,
        height=28.0,
      ),
      text(
        "告诉 Agent 你想推进的任务。",
        role=Caption,
        theme~,
        width=body_width,
        height=24.0,
      ),
      spacer(min_length=1.0, weight=1.0),
    ],
    spacing=2.0,
    align=Center,
  ).frame(width~, height~)
}

///|
fn WorkbenchModel::has_session_status_panel_content(
  self : WorkbenchModel,
) -> Bool {
  let active = self.active_session()
  active.active_task != "" ||
  self.pending_transport_count() > 0 ||
  !self.plan.is_empty() ||
  self.has_runtime_signal() ||
  self.next_action() is Some(_) ||
  self.should_show_session_detail_rows()
}

///|
fn WorkbenchModel::has_transcript_panel_content(self : WorkbenchModel) -> Bool {
  self.transcript.any(item => transcript_item_is_visible_conversation(item))
}

///|
fn WorkbenchModel::has_activity_panel_content(self : WorkbenchModel) -> Bool {
  self.has_raw_activity_panel_content() &&
  !self.completed_process_should_collapse()
}

///|
fn WorkbenchModel::has_raw_activity_panel_content(
  self : WorkbenchModel,
) -> Bool {
  self.should_show_focused_check_presets() ||
  self.latest_visible_activity_event() is Some(_) ||
  !self.commands.is_empty()
}

///|
fn WorkbenchModel::has_turn_evidence_card_content(
  self : WorkbenchModel,
) -> Bool {
  self.has_activity_panel_content() || self.has_workspace_digest_content()
}

///|
fn WorkbenchModel::has_workspace_digest_content(self : WorkbenchModel) -> Bool {
  self.diff.has_context() ||
  !self.files.is_empty() ||
  self.visible_workspace_diagnostic_count() > 0
}

///|
fn WorkbenchModel::turn_evidence_card(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = [
    self.turn_evidence_header_row(layout, theme),
  ]
  if self.has_activity_panel_content() {
    if self.should_show_focused_check_presets() {
      rows.push(focused_check_preset_row(layout, theme))
    }
    if self.commands_end_with_focused_check_batch(
        workbench_check_presets().length(),
      ) {
      let command_start = self.visible_activity_command_start()
      for index in command_start..<self.commands.length() {
        rows.push(command_run_row(self.commands[index], layout, theme))
      }
    } else {
      match self.primary_turn_evidence_command() {
        Some(command) => rows.push(command_run_row(command, layout, theme))
        None =>
          match self.latest_visible_activity_event() {
            Some(event) => rows.push(event_row(event, layout, theme))
            None => ()
          }
      }
    }
  }
  match self.latest_visible_workspace_diagnostic() {
    Some(diagnostic) => rows.push(diagnostic_row(diagnostic, layout, theme))
    None =>
      if self.diff.has_context() {
        rows.push(self.workspace_summary_row(layout, theme))
      } else if !self.files.is_empty() {
        rows.push(
          file_context_row(self.files[self.files.length() - 1], layout, theme),
        )
      }
  }
  surface(
    column(rows, spacing=7.0, align=Start),
    width=layout.panel_width,
    height=self.turn_evidence_card_height(),
    background=workbench_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  ).border(workbench_hairline_border(theme))
}

///|
fn WorkbenchModel::turn_evidence_header_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      text("当前证据", role=Control, theme~, width=104.0, height=28.0),
      text(
        self.turn_evidence_summary_label(),
        role=Caption,
        theme~,
        width=workbench_max_double(1.0, layout.panel_body_width - 112.0),
        height=28.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::turn_evidence_summary_label(self : WorkbenchModel) -> String {
  match self.primary_turn_evidence_command() {
    Some(command) => command_turn_summary(command)
    None =>
      match self.latest_visible_workspace_diagnostic() {
        Some(diagnostic) => "诊断 · " + diagnostic_detail_label(diagnostic)
        None =>
          if self.diff.has_context() {
            self.workspace_summary_label()
          } else if !self.files.is_empty() {
            self.workspace_summary_label()
          } else {
            match self.latest_visible_activity_event() {
              Some(event) => event.title
              None => "等待证据"
            }
          }
      }
  }
}

///|
fn WorkbenchModel::latest_visible_activity_event(
  self : WorkbenchModel,
) -> AgentEvent? {
  let mut visible : AgentEvent? = None
  for event in self.events {
    if event_is_visible_activity_evidence(event) {
      visible = Some(event)
    }
  }
  visible
}

///|
fn event_is_visible_activity_evidence(event : AgentEvent) -> Bool {
  match event.phase {
    "user" | "control" | "transport" => false
    _ => true
  }
}

///|
fn command_turn_summary(command : CommandRun) -> String {
  let parts : Array[String] = [
    compact_label(command.command, max_chars=44),
    command_status_label(command.status),
  ]
  match command.exit_code {
    Some(code) => parts.push("退出码 " + code.to_string())
    None => ()
  }
  if command.output_path != "" {
    parts.push("输出可用")
  }
  parts.join(" · ")
}

///|
fn WorkbenchModel::workspace_summary_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let summary_width = workbench_max_double(
    1.0,
    layout.panel_body_width - layout.row_badge_width - 124.0 - 16.0,
  )
  let rows : Array[@core.View[WorkbenchMsg]] = [
    row(
      [
        badge("工作区", tone=Accent, theme~, width=layout.row_badge_width),
        column(
          [
            text(
              self.workspace_summary_label(),
              role=Control,
              theme~,
              width=summary_width,
              height=24.0,
            ),
            text(
              self.workspace_summary_detail_label(),
              role=Caption,
              theme~,
              width=summary_width,
              height=22.0,
            ),
          ],
          spacing=0.0,
          align=Start,
        ),
        self.workspace_summary_actions(theme),
      ],
      spacing=8.0,
      align=Center,
    ),
  ]
  if self.workspace_details_expanded {
    rows.push(self.workspace_detail_panel(layout, theme))
  }
  column(rows, spacing=7.0, align=Start)
}

///|
fn WorkbenchModel::workspace_summary_label(self : WorkbenchModel) -> String {
  let parts : Array[String] = []
  if self.diff.has_context() {
    parts.push(self.diff.changed_files.to_string() + " 文件")
  } else if !self.files.is_empty() {
    parts.push(self.files.length().to_string() + " 文件")
  }
  if self.diff.has_context() {
    parts.push(
      "+" +
      self.diff.additions.to_string() +
      " -" +
      self.diff.deletions.to_string(),
    )
  }
  let diagnostic_count = self.visible_workspace_diagnostic_count()
  if diagnostic_count > 0 {
    parts.push(diagnostic_count.to_string() + " 诊断")
  }
  if parts.is_empty() {
    "工作区无新证据"
  } else {
    parts.join(" · ")
  }
}

///|
fn WorkbenchModel::workspace_summary_detail_label(
  self : WorkbenchModel,
) -> String {
  if self.diff.has_context() {
    self.diff.status_label()
  } else if !self.files.is_empty() {
    self.files[self.files.length() - 1].summary
  } else {
    "等待文件、变更或诊断"
  }
}

///|
fn WorkbenchModel::workspace_summary_actions(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      button(
        if self.workspace_details_expanded {
          "收起"
        } else {
          "展开"
        },
        on_click=ToggleWorkspaceDetails,
        variant=Ghost,
        theme~,
        width=58.0,
        height=32.0,
      ),
      self.workspace_summary_action_button(theme),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::workspace_summary_action_button(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if self.diff.has_context() {
    button(
      "审核",
      on_click=ReviewDiff,
      variant=Outline,
      theme~,
      width=58.0,
      height=32.0,
    )
  } else if !self.files.is_empty() {
    let file = self.files[self.files.length() - 1]
    button(
      "聚焦",
      on_click=InspectFile(file.path),
      variant=Outline,
      theme~,
      width=58.0,
      height=32.0,
    )
  } else {
    blank_cell(width=58.0, height=32.0)
  }
}

///|
fn WorkbenchModel::workspace_detail_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let detail_width = workbench_max_double(
    1.0,
    layout.panel_body_width - layout.row_badge_width - 8.0,
  )
  let max_chars = readable_line_char_limit(detail_width)
  let lines : Array[@core.View[WorkbenchMsg]] = []
  for line in self.workspace_detail_lines(max_chars, max_lines=5) {
    lines.push(
      text(line, role=Caption, theme~, width=detail_width, height=22.0),
    )
  }
  row(
    [
      blank_cell(width=layout.row_badge_width, height=1.0),
      surface(
        column(lines, spacing=2.0, align=Start),
        width=detail_width,
        height=self.workspace_detail_panel_height(),
        background=workbench_panel_nested_background(theme),
        corner_radius=6.0,
        theme~,
        padding=8.0,
      ).border(workbench_hairline_border(theme)),
    ],
    spacing=8.0,
    align=Start,
  )
}

///|
fn WorkbenchModel::workspace_detail_lines(
  self : WorkbenchModel,
  max_chars : Int,
  max_lines~ : Int,
) -> Array[String] {
  let lines : Array[String] = []
  if self.diff.has_context() {
    for
      line in readable_text_lines(
        "diff " + diff_next_action_detail(self.diff),
        max_chars,
        max_lines=2,
      ) {
      lines.push(line)
    }
  }
  match self.latest_visible_workspace_diagnostic() {
    Some(diagnostic) =>
      if lines.length() < max_lines {
        for
          line in readable_text_lines(
            "诊断 " + diagnostic_detail_label(diagnostic),
            max_chars,
            max_lines=max_lines - lines.length(),
          ) {
          lines.push(line)
        }
      }
    None => ()
  }
  if !self.files.is_empty() && lines.length() < max_lines {
    let file = self.files[self.files.length() - 1]
    for
      line in readable_text_lines(
        "文件 " + file.path + " · " + file.summary,
        max_chars,
        max_lines=max_lines - lines.length(),
      ) {
      lines.push(line)
    }
  }
  if lines.is_empty() {
    lines.push("暂无工作区详情")
  }
  lines
}

///|
fn WorkbenchModel::workspace_detail_panel_height(
  self : WorkbenchModel,
) -> Double {
  let line_count = self.workspace_detail_lines(68, max_lines=5).length().max(1)
  16.0 +
  line_count.to_double() * 22.0 +
  (line_count - 1).max(0).to_double() * 2.0
}

///|
fn WorkbenchModel::turn_evidence_card_height(self : WorkbenchModel) -> Double {
  let mut height = 24.0 + 28.0
  if self.has_activity_panel_content() {
    if self.should_show_focused_check_presets() {
      height = height + 7.0 + 30.0
    }
    if self.commands_end_with_focused_check_batch(
        workbench_check_presets().length(),
      ) {
      let command_start = self.visible_activity_command_start()
      for index in command_start..<self.commands.length() {
        height = height + 7.0 + command_run_row_height(self.commands[index])
      }
    } else {
      match self.primary_turn_evidence_command() {
        Some(command) => height = height + 7.0 + command_run_row_height(command)
        None =>
          if self.latest_visible_activity_event() is Some(_) {
            height = height + 7.0 + 46.0
          }
      }
    }
  }
  if self.latest_visible_workspace_diagnostic() is Some(_) {
    height = height + 7.0 + 46.0
  } else if self.diff.has_context() || !self.files.is_empty() {
    height = height + 7.0 + self.workspace_summary_row_height()
  }
  height.max(54.0)
}

///|
fn WorkbenchModel::primary_turn_evidence_command(
  self : WorkbenchModel,
) -> CommandRun? {
  match self.latest_failed_command() {
    Some(command) => Some(command)
    None =>
      match self.latest_active_command() {
        Some(command) => Some(command)
        None =>
          if self.commands.is_empty() {
            None
          } else {
            Some(self.commands[self.commands.length() - 1])
          }
      }
  }
}

///|
fn WorkbenchModel::latest_active_command(self : WorkbenchModel) -> CommandRun? {
  let mut active : CommandRun? = None
  for command in self.commands {
    if shell_command_status_is_active(command.status) {
      active = Some(command)
    }
  }
  active
}

///|
fn WorkbenchModel::transcript_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  for item in self.transcript {
    if transcript_item_is_visible_conversation(item) {
      if self.should_show_process_summary_before_item(item) {
        rows.push(self.process_summary_row(layout, theme))
        if self.should_show_expanded_process_details() {
          rows.push(self.process_detail_panel(layout, theme))
        }
      }
      rows.push(self.transcript_row(item, layout, theme))
      let fork_points = self.active_agent_fork_points_for_transcript_item(item)
      for point in fork_points {
        rows.push(fork_affordance_row(point, layout, theme))
      }
    }
  }
  surface(
    column(rows, spacing=4.0, align=Start),
    width=layout.panel_width,
    height=self.transcript_panel_height(layout),
    background=workbench_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=8.0,
  ).border(workbench_hairline_border(theme))
}

///|
fn WorkbenchModel::transcript_panel_height(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
) -> Double {
  if !self.transcript.any(item => transcript_item_is_visible_conversation(item)) {
    0.0
  } else {
    let mut height = 16.0
    let mut row_count = 0
    for item in self.transcript {
      if transcript_item_is_visible_conversation(item) {
        if row_count > 0 {
          height = height + 4.0
        }
        if self.should_show_process_summary_before_item(item) {
          height = height + process_summary_row_height()
          row_count = row_count + 1
          if self.should_show_expanded_process_details() {
            height = height + 4.0 + self.process_detail_panel_height()
            row_count = row_count + 1
          }
        }
        if row_count > 0 {
          height = height + 4.0
        }
        height = height + transcript_row_height(item, layout)
        row_count = row_count + 1
        let fork_points = self.active_agent_fork_points_for_transcript_item(
          item,
        )
        for point in fork_points {
          height = height + 4.0 + fork_affordance_row_height(point, layout)
          row_count = row_count + 1
        }
      }
    }
    height
  }
}

///|
fn WorkbenchModel::should_show_process_summary_before_item(
  self : WorkbenchModel,
  item : TranscriptItem,
) -> Bool {
  self.completed_process_should_collapse() &&
  item.role == "assistant" &&
  self.latest_visible_assistant_transcript_item_id() == item.id
}

///|
fn WorkbenchModel::completed_process_should_collapse(
  self : WorkbenchModel,
) -> Bool {
  self.has_process_evidence() &&
  !self.has_live_process_signal() &&
  self.latest_visible_assistant_transcript_item_id() != ""
}

///|
fn WorkbenchModel::should_show_expanded_process_details(
  self : WorkbenchModel,
) -> Bool {
  self.workspace_details_expanded && self.completed_process_should_collapse()
}

///|
fn WorkbenchModel::latest_visible_assistant_transcript_item_id(
  self : WorkbenchModel,
) -> String {
  let mut id = ""
  for item in self.transcript {
    if item.role == "assistant" && transcript_item_is_visible_conversation(item) {
      id = item.id
    }
  }
  id
}

///|
fn WorkbenchModel::has_process_evidence(self : WorkbenchModel) -> Bool {
  let signal = self.active_agent_runtime_signal()
  !self.commands.is_empty() ||
  self.transcript.any(item => transcript_item_is_process_evidence(item)) ||
  self.events.any(event => event_is_process_evidence(event)) ||
  signal.message_preview != "" ||
  signal.active_tool_name != ""
}

///|
fn WorkbenchModel::has_live_process_signal(self : WorkbenchModel) -> Bool {
  self.active_agent_runtime_signal().has_active_signal() ||
  self.latest_active_command() is Some(_)
}

///|
fn event_is_process_evidence(event : AgentEvent) -> Bool {
  event.phase == "tool" ||
  event.title.contains("Pi agent") ||
  event.title.contains("Pi turn") ||
  event.title.contains("Pi message") ||
  event.title.contains("Pi tool")
}

///|
fn WorkbenchModel::process_summary_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let badge_width = transcript_compact_badge_width(layout)
  let action_width = 58.0
  let text_width = workbench_max_double(
    1.0,
    layout.panel_body_width - badge_width - action_width - 24.0,
  )
  surface(
    row(
      [
        badge("过程", tone=Neutral, theme~, width=badge_width),
        column(
          [
            text(
              self.process_summary_title(),
              role=Body,
              theme~,
              width=text_width,
              height=20.0,
            ),
            text(
              self.process_summary_detail(),
              role=Caption,
              theme~,
              width=text_width,
              height=18.0,
            ),
          ],
          spacing=1.0,
          align=Start,
        ),
        button(
          if self.workspace_details_expanded {
            "收起"
          } else {
            "展开"
          },
          on_click=ToggleWorkspaceDetails,
          variant=Ghost,
          theme~,
          width=action_width,
          height=28.0,
        ),
      ],
      spacing=8.0,
      align=Start,
    ),
    width=layout.panel_body_width,
    height=process_summary_row_height(),
    background=workbench_panel_subtle_background(theme),
    corner_radius=6.0,
    theme~,
    padding=7.0,
  )
}

///|
fn process_summary_row_height() -> Double {
  14.0 + 39.0
}

///|
fn WorkbenchModel::process_detail_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let detail_width = layout.process_detail_text_width()
  let lines = self.process_detail_lines(readable_line_char_limit(detail_width))
  let views : Array[@core.View[WorkbenchMsg]] = []
  for line in lines {
    views.push(
      text(line, role=Caption, theme~, width=detail_width, height=20.0),
    )
  }
  row(
    [
      blank_cell(width=transcript_compact_badge_width(layout), height=1.0),
      surface(
        column(views, spacing=2.0, align=Start),
        width=detail_width + 16.0,
        height=self.process_detail_panel_height(),
        background=workbench_panel_nested_background(theme),
        corner_radius=6.0,
        theme~,
        padding=8.0,
      ).border(workbench_hairline_border(theme)),
    ],
    spacing=8.0,
    align=Start,
  )
}

///|
fn WorkbenchLayout::process_detail_text_width(self : WorkbenchLayout) -> Double {
  workbench_max_double(
    1.0,
    self.panel_body_width - transcript_compact_badge_width(self) - 24.0,
  )
}

///|
fn WorkbenchModel::process_detail_panel_height(self : WorkbenchModel) -> Double {
  let line_count = self.process_detail_lines(72).length().max(1)
  16.0 +
  line_count.to_double() * 20.0 +
  (line_count - 1).max(0).to_double() * 2.0
}

///|
fn WorkbenchModel::process_summary_title(self : WorkbenchModel) -> String {
  ignore(self)
  "已处理"
}

///|
fn WorkbenchModel::process_summary_detail(self : WorkbenchModel) -> String {
  let signal = self.active_agent_runtime_signal()
  let parts : Array[String] = []
  if !self.commands.is_empty() {
    parts.push(self.commands.length().to_string() + " 命令")
  }
  let event_count = self.process_event_count()
  if event_count > 0 {
    parts.push(event_count.to_string() + " 事件")
  }
  if signal.thinking_level != "" {
    parts.push("思考 " + self.thinking_level_label())
  }
  let transcript_count = self.process_transcript_item_count()
  if transcript_count > 0 {
    parts.push(transcript_count.to_string() + " 工具")
  }
  if parts.is_empty() {
    "过程已收起"
  } else {
    parts.join(" · ")
  }
}

///|
fn WorkbenchModel::process_transcript_item_count(self : WorkbenchModel) -> Int {
  let mut count = 0
  for item in self.transcript {
    if transcript_item_is_process_evidence(item) {
      count = count + 1
    }
  }
  count
}

///|
fn WorkbenchModel::process_event_count(self : WorkbenchModel) -> Int {
  let mut count = 0
  for event in self.events {
    if event_is_process_evidence(event) {
      count = count + 1
    }
  }
  count
}

///|
fn WorkbenchModel::process_detail_lines(
  self : WorkbenchModel,
  max_chars : Int,
) -> Array[String] {
  let signal = self.active_agent_runtime_signal()
  let max_lines = 8
  let lines : Array[String] = []
  if signal.thinking_level != "" {
    lines.push("思考等级 " + self.thinking_level_label())
  }
  if signal.message_preview != "" && lines.length() < max_lines {
    for
      line in readable_text_lines(
        "消息 " + signal.message_preview,
        max_chars,
        max_lines=max_lines - lines.length(),
      ) {
      lines.push(line)
    }
  }
  for item in self.transcript {
    if lines.length() >= max_lines {
      break
    }
    if transcript_item_is_process_evidence(item) {
      for
        line in readable_text_lines(
          transcript_process_detail_label(item),
          max_chars,
          max_lines=max_lines - lines.length(),
        ) {
        lines.push(line)
      }
    }
  }
  let command_start = workbench_max_int(0, self.commands.length() - 4)
  for index in command_start..<self.commands.length() {
    if lines.length() >= max_lines {
      break
    }
    let command = self.commands[index]
    for
      line in readable_text_lines(
        "命令 " +
        command_status_label(command.status) +
        " · " +
        command.command +
        " · " +
        command_detail_label(command),
        max_chars,
        max_lines=max_lines - lines.length(),
      ) {
      lines.push(line)
    }
  }
  let event_start = workbench_max_int(0, self.events.length() - 6)
  for index in event_start..<self.events.length() {
    if lines.length() >= max_lines {
      break
    }
    let event = self.events[index]
    if event_is_process_evidence(event) {
      for
        line in readable_text_lines(
          event_phase_label(event.phase) +
          " · " +
          event.title +
          " · " +
          event.detail,
          max_chars,
          max_lines=max_lines - lines.length(),
        ) {
        lines.push(line)
      }
    }
  }
  if lines.is_empty() {
    lines.push("过程已收起，暂无可显示细节")
  }
  lines
}

///|
fn WorkbenchModel::fork_points_for_transcript_item(
  self : WorkbenchModel,
  item : TranscriptItem,
) -> Array[AgentForkPoint] {
  let points : Array[AgentForkPoint] = []
  if item.role == "assistant" {
    for message in self.fork_messages {
      let point = message.as_agent_fork_point()
      if self.assistant_transcript_item_id_for_fork_point(point) == item.id {
        points.push(point)
      }
    }
  }
  points
}

///|
fn WorkbenchModel::assistant_transcript_item_id_for_fork_point(
  self : WorkbenchModel,
  point : AgentForkPoint,
) -> String {
  let mut matched_index = -1
  for index in 0..<self.transcript.length() {
    if matched_index == -1 &&
      self.fork_point_matches_transcript_item(point, self.transcript[index]) {
      matched_index = index
    }
  }
  if matched_index == -1 {
    ""
  } else if self.transcript[matched_index].role == "assistant" {
    self.transcript[matched_index].id
  } else {
    for index in (matched_index + 1)..<self.transcript.length() {
      if self.transcript[index].role == "assistant" &&
        transcript_item_is_visible_conversation(self.transcript[index]) {
        return self.transcript[index].id
      }
    }
    ""
  }
}

///|
pub fn WorkbenchModel::active_agent_fork_points_for_transcript_item(
  self : WorkbenchModel,
  item : TranscriptItem,
) -> Array[AgentForkPoint] {
  let points : Array[AgentForkPoint] = []
  if !self.active_agent_backend_capabilities().supports_fork {
    return points
  }
  let seen : Array[String] = []
  for point in self.fork_points_for_transcript_item(item) {
    let key = point.entry_id + "\n" + point.text
    if !seen.any(value => value == key) {
      seen.push(key)
      points.push(point)
    }
  }
  points
}

///|
fn WorkbenchModel::fork_point_matches_transcript_item(
  self : WorkbenchModel,
  point : AgentForkPoint,
  item : TranscriptItem,
) -> Bool {
  ignore(self)
  point.entry_id == item.id || fork_point_text_matches_item(point.text, item)
}

///|
fn fork_point_text_matches_item(text : String, item : TranscriptItem) -> Bool {
  let clean = text.trim().to_owned()
  clean != "" &&
  (
    item.summary.trim().to_owned() == clean ||
    item.detail.trim().to_owned() == clean
  )
}

///|
fn transcript_item_is_visible_conversation(item : TranscriptItem) -> Bool {
  match item.role {
    "assistantProcess" | "toolResult" | "bashExecution" => false
    "assistant" =>
      item.summary.trim().to_owned() != "" ||
      item.detail.trim().to_owned() != ""
    _ => true
  }
}

///|
fn transcript_item_is_process_evidence(item : TranscriptItem) -> Bool {
  match item.role {
    "assistantProcess" | "toolResult" | "bashExecution" => true
    _ => false
  }
}

///|
fn transcript_process_detail_label(item : TranscriptItem) -> String {
  let title = item.summary.trim().to_owned()
  let detail = item.detail.trim().to_owned()
  let label = match item.role {
    "assistantProcess" => "Agent 过程"
    "toolResult" => "工具结果"
    "bashExecution" => "命令"
    _ => transcript_role_label(item.role)
  }
  if title == "" && detail == "" {
    label
  } else if detail == "" || detail == title {
    label + " · " + title
  } else if title == "" {
    label + " · " + detail
  } else {
    label + " · " + title + " · " + detail
  }
}

///|
fn WorkbenchModel::transcript_row(
  self : WorkbenchModel,
  item : TranscriptItem,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  transcript_compact_row(
    item,
    layout,
    theme,
    badge_label=transcript_role_label(item.role),
    tone=transcript_badge_tone(item.tone),
    background=transcript_row_background(item.role, theme),
  )
}

///|
fn transcript_compact_row(
  item : TranscriptItem,
  layout : WorkbenchLayout,
  theme : @core.Theme,
  badge_label~ : String,
  tone~ : @views.BadgeTone,
  background~ : @core.Color,
) -> @core.View[WorkbenchMsg] {
  let badge_width = transcript_compact_badge_width(layout)
  let text_width = transcript_row_text_width(layout)
  surface(
    row(
      [
        badge(badge_label, tone~, theme~, width=badge_width),
        transcript_text_block(item, text_width, theme),
      ],
      spacing=8.0,
      align=Start,
    ),
    width=layout.panel_body_width,
    height=transcript_row_height(item, layout),
    background~,
    corner_radius=8.0,
    theme~,
    padding=8.0,
  )
}

///|
fn transcript_text_block(
  item : TranscriptItem,
  width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let max_chars = readable_line_char_limit(width)
  let lines : Array[@core.View[WorkbenchMsg]] = []
  for line in readable_text_lines(item.summary, max_chars, max_lines=2) {
    lines.push(text(line, role=Body, theme~, width~, height=22.0))
  }
  for line in readable_text_lines(item.detail, max_chars, max_lines=4) {
    lines.push(text(line, role=Caption, theme~, width~, height=20.0))
  }
  if lines.is_empty() {
    lines.push(text("空消息", role=Caption, theme~, width~, height=20.0))
  }
  column(lines, spacing=1.0, align=Start)
}

///|
fn transcript_row_height(
  item : TranscriptItem,
  layout : WorkbenchLayout,
) -> Double {
  let text_width = transcript_row_text_width(layout)
  16.0 +
  workbench_max_double(28.0, readable_text_block_height(item, text_width))
}

///|
fn readable_text_block_height(item : TranscriptItem, width : Double) -> Double {
  let max_chars = readable_line_char_limit(width)
  let summary_count = readable_text_lines(item.summary, max_chars, max_lines=2).length()
  let detail_count = readable_text_lines(item.detail, max_chars, max_lines=4).length()
  let line_count = summary_count + detail_count
  if line_count == 0 {
    20.0
  } else {
    summary_count.to_double() * 22.0 +
    detail_count.to_double() * 20.0 +
    (line_count - 1).max(0).to_double() * 1.0
  }
}

///|
fn transcript_compact_badge_width(layout : WorkbenchLayout) -> Double {
  if layout.panel_width < 620.0 {
    60.0
  } else {
    72.0
  }
}

///|
fn transcript_row_text_width(layout : WorkbenchLayout) -> Double {
  workbench_max_double(
    1.0,
    layout.panel_body_width - 16.0 - transcript_compact_badge_width(layout),
  )
}

///|
fn transcript_row_background(role : String, theme : @core.Theme) -> @core.Color {
  match role {
    "assistant" => workbench_transcript_assistant_background(theme)
    "user" => workbench_transcript_user_background(theme)
    _ => workbench_panel_subtle_background(theme)
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
fn end_ellipsis_label(value : String, max_chars~ : Int) -> String {
  let clean = value.trim().to_owned()
  let chars = clean.to_array()
  let limit = max_chars.max(4)
  if chars.length() <= limit {
    clean
  } else {
    let end = workbench_max_int(1, limit - 3)
    String::from_array(chars[0:end]) + "..."
  }
}

///|
fn middle_ellipsis_label(value : String, max_chars~ : Int) -> String {
  let clean = value.trim().to_owned()
  let chars = clean.to_array()
  let limit = max_chars.max(5)
  if chars.length() <= limit {
    clean
  } else {
    let available = workbench_max_int(2, limit - 3)
    let head = workbench_max_int(1, (available.to_double() * 0.45).to_int())
    let tail = workbench_max_int(1, available - head)
    let tail_start = workbench_max_int(head, chars.length() - tail)
    String::from_array(chars[0:head]) +
    "..." +
    String::from_array(chars[tail_start:])
  }
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
fn fork_affordance_row_height(
  point : AgentForkPoint,
  layout : WorkbenchLayout,
) -> Double {
  ignore(point)
  ignore(layout)
  34.0
}

///|
fn fork_affordance_row(
  point : AgentForkPoint,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let indent = transcript_compact_badge_width(layout) + 8.0
  let width = workbench_max_double(1.0, layout.panel_body_width - indent)
  let action_width = 54.0
  let text_width = workbench_max_double(1.0, width - action_width - 22.0)
  row(
    [
      blank_cell(width=transcript_compact_badge_width(layout), height=1.0),
      surface(
        row(
          [
            button(
              "分叉",
              on_click=ForkFromMessage(point.entry_id),
              variant=Ghost,
              theme~,
              width=action_width,
              height=26.0,
            ),
            text(
              end_ellipsis_label(
                fork_affordance_detail(point),
                max_chars=readable_line_char_limit(text_width),
              ),
              role=Caption,
              theme~,
              width=text_width,
              height=24.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        width~,
        height=fork_affordance_row_height(point, layout),
        background=workbench_panel_nested_background(theme),
        corner_radius=6.0,
        theme~,
        padding=4.0,
      ),
    ],
    spacing=8.0,
    align=Start,
  )
}

///|
fn fork_affordance_detail(point : AgentForkPoint) -> String {
  if point.text.trim().to_owned() == "" {
    "从这条回复创建分支"
  } else {
    point.text
  }
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
fn agent_activity_queue_badge_tone(tone : String) -> @views.BadgeTone {
  match tone {
    "success" => Success
    "warning" => Warning
    "danger" => Danger
    "accent" | "info" => Accent
    _ => Neutral
  }
}

///|
fn transcript_role_label(role : String) -> String {
  match role {
    "user" => "用户"
    "assistant" => "Agent"
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
fn WorkbenchModel::session_status_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  let binding = self.active_agent_session_binding()
  let rows : Array[@core.View[WorkbenchMsg]] = [
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
  models : Array[AgentModelInfo],
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
pub fn WorkbenchModel::active_agent_runtime_signal(
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(layout)
  let capabilities = self.active_agent_backend_capabilities()
  let settings = self.active_agent_input_settings()
  let controls : Array[@core.View[WorkbenchMsg]] = []
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let presets = workbench_check_presets()
  let action_count = presets.length() + 1
  let button_width = workbench_clamp_double(
    (layout.panel_body_width - 72.0 - (action_count + 1).to_double() * 8.0) /
    action_count.to_double(),
    58.0,
    112.0,
  )
  let controls : Array[@core.View[WorkbenchMsg]] = [
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

///|
fn event_row(
  event : AgentEvent,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let text_width = workbench_max_double(
    1.0,
    layout.panel_body_width - layout.row_badge_width - 8.0,
  )
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
          text(event.title, role=Control, theme~, width=text_width, height=24.0),
          text(
            event.detail,
            role=Caption,
            theme~,
            width=text_width,
            height=22.0,
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
fn event_phase_label(phase : String) -> String {
  match phase {
    "user" => "用户"
    "agent" => "Agent"
    "assistant" => "Agent"
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
  let rows : Array[@core.View[WorkbenchMsg]] = [
    command_run_summary_row(command, layout, theme),
  ]
  if command.details_expanded {
    rows.push(command_detail_panel(command, layout, theme))
  }
  column(rows, spacing=7.0, align=Start)
}

///|
fn command_run_summary_row(
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
        if command.details_expanded {
          "收起"
        } else {
          "展开"
        },
        on_click=ToggleCommandDetails(command.id),
        variant=Ghost,
        theme~,
        width=54.0,
        height=32.0,
      ),
      button(
        command_primary_action_label(command),
        on_click=command_primary_action_message(command),
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
fn command_detail_panel(
  command : CommandRun,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let detail_width = workbench_max_double(
    1.0,
    layout.panel_body_width - layout.row_badge_width - 8.0,
  )
  let max_chars = readable_line_char_limit(detail_width)
  let lines : Array[@core.View[WorkbenchMsg]] = []
  for line in command_detail_lines(command, max_chars, max_lines=7) {
    lines.push(
      text(line, role=Caption, theme~, width=detail_width, height=22.0),
    )
  }
  row(
    [
      blank_cell(width=layout.row_badge_width, height=1.0),
      surface(
        column(lines, spacing=2.0, align=Start),
        width=detail_width,
        height=command_detail_panel_height(command),
        background=workbench_panel_nested_background(theme),
        corner_radius=6.0,
        theme~,
        padding=8.0,
      ).border(workbench_hairline_border(theme)),
    ],
    spacing=8.0,
    align=Start,
  )
}

///|
fn command_primary_action_label(command : CommandRun) -> String {
  if command.status == "failed" {
    "修复"
  } else {
    "分析"
  }
}

///|
fn command_primary_action_message(command : CommandRun) -> WorkbenchMsg {
  if command.status == "failed" {
    FixCommandRun(
      command.command,
      command_status_context(command),
      command.cwd,
      command.output_path,
    )
  } else {
    InspectCommandRun(
      command.command,
      command_status_context(command),
      command.cwd,
      command.output_path,
    )
  }
}

///|
fn command_status_context(command : CommandRun) -> String {
  let status = command.status.trim().to_owned()
  match command.exit_code {
    Some(code) =>
      if status == "" {
        "exit code " + code.to_string()
      } else {
        status + ", exit code " + code.to_string()
      }
    None => status
  }
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
  if command_has_output_details(command) {
    command_output_available_label(command) + " · " + command.cwd
  } else if command.cwd == "" {
    "等待命令输出"
  } else {
    command.cwd
  }
}

///|
fn command_has_output_details(command : CommandRun) -> Bool {
  command.output.trim().to_owned() != "" || command.output_path != ""
}

///|
fn command_output_available_label(command : CommandRun) -> String {
  if command.output_truncated {
    "输出可用 · 已截断"
  } else {
    "输出可用"
  }
}

///|
fn command_run_row_height(command : CommandRun) -> Double {
  if command.details_expanded {
    46.0 + 7.0 + command_detail_panel_height(command)
  } else {
    46.0
  }
}

///|
fn command_detail_panel_height(command : CommandRun) -> Double {
  let line_count = command_detail_lines(command, 68, max_lines=7)
    .length()
    .max(1)
  16.0 +
  line_count.to_double() * 22.0 +
  (line_count - 1).max(0).to_double() * 2.0
}

///|
fn command_detail_lines(
  command : CommandRun,
  max_chars : Int,
  max_lines~ : Int,
) -> Array[String] {
  let lines : Array[String] = []
  if command.output_path != "" {
    for
      line in readable_text_lines(
        "日志 " + command.output_path,
        max_chars,
        max_lines=2,
      ) {
      lines.push(line)
    }
  }
  let output = command.output.trim().to_owned()
  if output != "" && lines.length() < max_lines {
    lines.push(
      if command.output_truncated {
        "stdout 已截断"
      } else {
        "stdout"
      },
    )
    for raw_line in output.split("\n") {
      if lines.length() >= max_lines {
        break
      }
      let clean = raw_line.to_owned()
      let wrapped = readable_text_lines(
        if clean == "" {
          " "
        } else {
          clean
        },
        max_chars,
        max_lines=max_lines - lines.length(),
      )
      for line in wrapped {
        if lines.length() < max_lines {
          lines.push(line)
        }
      }
    }
  }
  if lines.is_empty() {
    lines.push("暂无详细输出")
  }
  lines
}

///|
fn WorkbenchModel::workspace_summary_row_height(
  self : WorkbenchModel,
) -> Double {
  if self.workspace_details_expanded {
    46.0 + 7.0 + self.workspace_detail_panel_height()
  } else {
    46.0
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
fn WorkbenchModel::visible_workspace_diagnostic_count(
  self : WorkbenchModel,
) -> Int {
  let mut count = 0
  for diagnostic in self.diagnostics {
    if !self.workspace_diagnostic_is_command_shadow(diagnostic) {
      count = count + 1
    }
  }
  count
}

///|
fn WorkbenchModel::latest_visible_workspace_diagnostic(
  self : WorkbenchModel,
) -> DiagnosticItem? {
  let mut latest : DiagnosticItem? = None
  for diagnostic in self.diagnostics {
    if !self.workspace_diagnostic_is_command_shadow(diagnostic) {
      latest = Some(diagnostic)
    }
  }
  latest
}

///|
fn WorkbenchModel::workspace_diagnostic_is_command_shadow(
  self : WorkbenchModel,
  diagnostic : DiagnosticItem,
) -> Bool {
  let source = diagnostic.source.trim().to_owned()
  let message = diagnostic.message.trim().to_owned()
  source == "Pi bash" &&
  (
    (message.contains("bash exited with code") && self.has_failed_command()) ||
    (message == "bash command was cancelled" && self.has_cancelled_command())
  )
}

///|
fn WorkbenchModel::has_failed_command(self : WorkbenchModel) -> Bool {
  self.commands.any(command => command.status == "failed")
}

///|
fn WorkbenchModel::has_cancelled_command(self : WorkbenchModel) -> Bool {
  self.commands.any(command => command.status == "cancelled")
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
    background=workbench_transparent(),
    padding=0.0,
  )
}

///|
fn WorkbenchModel::composer(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let content : Array[@core.View[WorkbenchMsg]] = [
    text_field(
      self.prompt,
      on_input=value => PromptChanged(value),
      on_submit=Some(DispatchPrompt),
      placeholder="给 Agent 一个任务",
      variant=Plain,
      theme~,
      width=layout.composer_input_width,
      height=42.0,
    ),
  ]
  if self.should_show_composer_request_row() {
    content.push(self.composer_request_row(layout, theme))
  }
  if self.should_show_composer_route_row() {
    content.push(self.composer_route_row(layout, theme))
  }
  if self.should_show_composer_scope_row() {
    content.push(self.composer_scope_row(layout, theme))
  }
  if self.should_show_agent_control_row() {
    content.push(self.agent_control_row(theme))
  }
  if self.should_show_composer_command_row() {
    content.push(self.composer_command_row(layout, theme))
  }
  if self.should_show_composer_action_row() {
    content.push(self.composer_action_row(theme))
  }
  surface(
    column(content, spacing=6.0, align=Stretch),
    width=layout.composer_width,
    height=self.composer_height(layout),
    background=workbench_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border(theme))
}

///|
fn WorkbenchModel::composer_height(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
) -> Double {
  let mut height = layout.composer_height
  if self.should_show_agent_control_row() {
    height = height + 36.0
  }
  if self.should_show_composer_request_row() {
    height = height + 36.0
  }
  if self.should_show_composer_route_row() {
    height = height + 36.0
  }
  if self.should_show_composer_scope_row() {
    height = height + 36.0
  }
  if self.should_show_composer_command_row() {
    height = height + 36.0
  }
  if self.should_show_composer_action_row() {
    height = height + 42.0
  }
  height
}

///|
fn WorkbenchModel::should_show_composer_route_row(
  self : WorkbenchModel,
) -> Bool {
  self.agent_composer_route_summary().has_visible_route()
}

///|
fn WorkbenchModel::composer_route_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let summary = self.agent_composer_route_summary()
  let detail_width = workbench_max_double(
    1.0,
    layout.composer_input_width - 54.0 - 8.0,
  )
  row(
    [
      badge(
        "Agent",
        tone=agent_activity_queue_badge_tone(summary.tone),
        theme~,
        width=54.0,
      ),
      text(
        compact_label(
          summary.detail,
          max_chars=readable_line_char_limit(detail_width),
        ),
        role=Caption,
        theme~,
        width=detail_width,
        height=30.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::should_show_composer_request_row(
  self : WorkbenchModel,
) -> Bool {
  self.agent_composer_request_summary().has_visible_request()
}

///|
fn WorkbenchModel::composer_request_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let summary = self.agent_composer_request_summary()
  let action_width = if summary.action_message is Some(_) { 64.0 } else { 0.0 }
  let detail_width = workbench_max_double(
    1.0,
    layout.composer_input_width - 54.0 - action_width - 24.0,
  )
  let controls : Array[@core.View[WorkbenchMsg]] = [
    badge(
      summary.badge_label,
      tone=agent_activity_queue_badge_tone(summary.tone),
      theme~,
      width=54.0,
    ),
    text(
      compact_label(
        summary.title + " · " + summary.detail,
        max_chars=readable_line_char_limit(detail_width),
      ),
      role=Caption,
      theme~,
      width=detail_width,
      height=30.0,
    ),
  ]
  match summary.action_message {
    Some(message) =>
      controls.push(
        button(
          summary.action_label,
          on_click=message,
          variant=Outline,
          theme~,
          width=64.0,
          height=30.0,
        ),
      )
    None => ()
  }
  row(controls, spacing=8.0, align=Center)
}

///|
fn WorkbenchModel::should_show_agent_control_row(self : WorkbenchModel) -> Bool {
  self.composer_controls_expanded &&
  !self.is_composer_slash_prompt() &&
  (
    agent_backend_profiles().length() > 1 ||
    self.active_agent_backend_capabilities().supports_session_refresh ||
    self.active_agent_backend_capabilities().supports_new_session
  )
}

///|
fn WorkbenchModel::agent_control_row(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let capabilities = self.active_agent_backend_capabilities()
  let controls : Array[@core.View[WorkbenchMsg]] = [
    text("Agent", role=Caption, theme~, width=42.0, height=30.0),
    self.backend_selector_cell(theme),
  ]
  controls.push(spacer(min_length=8.0, weight=1.0))
  if capabilities.supports_session_refresh {
    controls.push(
      button(
        "刷新",
        on_click=RefreshSession,
        variant=Ghost,
        theme~,
        width=54.0,
        height=30.0,
      ),
    )
  }
  if capabilities.supports_new_session {
    controls.push(
      button(
        "新会话",
        on_click=NewSession,
        variant=Ghost,
        theme~,
        width=66.0,
        height=30.0,
      ),
    )
  }
  row(controls, spacing=8.0, align=Center)
}

///|
fn WorkbenchModel::should_show_composer_scope_row(
  self : WorkbenchModel,
) -> Bool {
  !self.is_composer_slash_prompt() &&
  (
    self.composer_controls_expanded ||
    self.active_agent_profile() is Some(_) ||
    !self.context_is_default()
  )
}

///|
fn WorkbenchModel::context_is_default(self : WorkbenchModel) -> Bool {
  self.expanded_context.length() == 2 &&
  self.context_is_selected("repo") &&
  self.context_is_selected("examples")
}

///|
fn WorkbenchModel::composer_scope_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(layout)
  let controls : Array[@core.View[WorkbenchMsg]] = [
    text("范围", role=Caption, theme~, width=42.0, height=30.0),
    self.context_chip("仓库", "repo", theme, width=50.0),
    self.context_chip("示例", "examples", theme, width=50.0),
    self.context_chip("证据", "evidence", theme, width=50.0),
    self.context_chip("会话", "session", theme, width=50.0),
  ]
  if self.composer_controls_expanded || self.active_agent_profile() is Some(_) {
    controls.push(spacer(min_length=8.0, weight=1.0))
    for profile in workbench_agent_profiles() {
      controls.push(
        button(
          profile.label,
          on_click=SelectAgent(profile.id),
          variant=if self.selected_agent_id == profile.id {
            Outline
          } else {
            Ghost
          },
          theme~,
          width=64.0,
          height=30.0,
        ),
      )
    }
  } else {
    controls.push(spacer(min_length=8.0, weight=1.0))
  }
  row(controls, spacing=8.0, align=Center)
}

///|
fn WorkbenchModel::composer_action_row(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let controls : Array[@core.View[WorkbenchMsg]] = []
  if self.should_show_composer_options_toggle() {
    controls.push(
      button(
        if self.composer_controls_expanded {
          "收起"
        } else {
          "选项"
        },
        on_click=ToggleComposerControls,
        variant=Ghost,
        theme~,
        width=54.0,
        height=36.0,
      ),
    )
  }
  if self.should_show_composer_secondary_actions() {
    controls.push(
      button(
        self.steering_mode_label(),
        on_click=ToggleSteeringMode,
        variant=Outline,
        theme~,
        width=82.0,
        height=34.0,
      ),
    )
    controls.push(
      button(
        self.follow_up_mode_label(),
        on_click=ToggleFollowUpMode,
        variant=Outline,
        theme~,
        width=82.0,
        height=34.0,
      ),
    )
  }
  controls.push(spacer(min_length=10.0, weight=1.0))
  if self.has_composer_prompt() &&
    !self.is_composer_slash_prompt() &&
    self.should_show_composer_secondary_actions() {
    controls.push(
      button(
        "引导",
        on_click=DispatchSteering,
        variant=Outline,
        theme~,
        width=54.0,
        height=36.0,
      ),
    )
    controls.push(
      button(
        "跟进",
        on_click=DispatchFollowUp,
        variant=Outline,
        theme~,
        width=54.0,
        height=36.0,
      ),
    )
  }
  if self.has_composer_prompt() {
    controls.push(
      button(
        "发送",
        on_click=DispatchPrompt,
        variant=Primary,
        theme~,
        width=54.0,
        height=36.0,
      ),
    )
  }
  row(controls, spacing=8.0, align=Center)
}

///|
fn WorkbenchModel::should_show_composer_action_row(
  self : WorkbenchModel,
) -> Bool {
  self.has_composer_prompt() ||
  self.should_show_composer_options_toggle() ||
  self.should_show_composer_secondary_actions()
}

///|
fn WorkbenchModel::should_show_composer_options_toggle(
  self : WorkbenchModel,
) -> Bool {
  !self.is_composer_slash_prompt() &&
  (self.has_composer_prompt() || self.composer_controls_expanded)
}

///|
fn WorkbenchModel::should_show_composer_secondary_actions(
  self : WorkbenchModel,
) -> Bool {
  let settings = self.active_agent_input_settings()
  !self.is_composer_slash_prompt() &&
  self.active_agent_backend_capabilities().supports_input_modes &&
  (self.composer_controls_expanded || settings.has_visible_input_modes())
}

///|
fn WorkbenchModel::has_composer_prompt(self : WorkbenchModel) -> Bool {
  self.prompt.trim().to_owned() != ""
}

///|
fn WorkbenchModel::is_composer_slash_prompt(self : WorkbenchModel) -> Bool {
  self.composer_slash_query() is Some(_)
}

///|
fn WorkbenchModel::composer_command_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let suggestions = self.composer_command_suggestions()
  let limit = workbench_min_int(suggestions.length(), 3)
  let button_width = workbench_clamp_double(
    (layout.composer_input_width - 42.0 - 16.0) / 3.0,
    96.0,
    142.0,
  )
  let controls : Array[@core.View[WorkbenchMsg]] = [
    text("命令", role=Caption, theme~, width=42.0, height=30.0),
  ]
  for index in 0..<limit {
    let command = suggestions[index]
    controls.push(
      button(
        command.composer_label(button_width),
        on_click=InvokeCommand(command.name),
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

///|
fn WorkbenchModel::should_show_composer_command_row(
  self : WorkbenchModel,
) -> Bool {
  !self.composer_command_suggestions().is_empty()
}

///|
fn WorkbenchModel::composer_command_suggestions(
  self : WorkbenchModel,
) -> Array[AgentCommandInfo] {
  let suggestions : Array[AgentCommandInfo] = []
  if !self.active_agent_backend_capabilities().supports_command_catalog {
    return suggestions
  }
  match self.composer_slash_query() {
    Some(query) =>
      for command in self.active_agent_command_catalog() {
        if command.matches_composer_query(query) {
          suggestions.push(command)
        }
      }
    None => ()
  }
  suggestions
}

///|
fn WorkbenchModel::composer_slash_query(self : WorkbenchModel) -> String? {
  let clean = self.prompt.trim().to_owned()
  let chars = clean.to_array()
  if chars.length() == 0 || chars[0] != '/' {
    None
  } else {
    Some(String::from_array(chars[1:]).trim().to_owned().to_lower())
  }
}

///|
fn AgentCommandInfo::matches_composer_query(
  self : AgentCommandInfo,
  query : String,
) -> Bool {
  query == "" ||
  self.name.to_lower().contains(query) ||
  self.description.to_lower().contains(query) ||
  self.source.to_lower().contains(query)
}

///|
fn AgentCommandInfo::composer_label(
  self : AgentCommandInfo,
  width : Double,
) -> String {
  compact_label("/" + self.name, max_chars=readable_line_char_limit(width))
}

///|
fn compact_label(value : String, max_chars~ : Int) -> String {
  let chars = value.to_array()
  if chars.length() <= max_chars {
    value
  } else {
    let end = workbench_max_int(1, max_chars - 3)
    String::from_array(chars[0:end]) + "..."
  }
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
fn WorkbenchModel::steering_mode_label(self : WorkbenchModel) -> String {
  "引导 " + mode_short_label(self.active_agent_input_settings().steering_mode)
}

///|
fn WorkbenchModel::follow_up_mode_label(self : WorkbenchModel) -> String {
  "跟进 " +
  mode_short_label(self.active_agent_input_settings().follow_up_mode)
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
fn workbench_hairline_border(theme : @core.Theme) -> @core.BorderStyle {
  let color = match theme.scheme {
    @core.ColorScheme::Light => @core.Color::black().multiply_alpha(0.10)
    @core.ColorScheme::Dark => @core.Color::white().multiply_alpha(0.10)
  }
  @core.BorderStyle::new(brush=@core.Brush::solid(color), width=1.0)
}

///|
fn workbench_clear_border() -> @core.BorderStyle {
  @core.BorderStyle::new(
    brush=@core.Brush::solid(@core.Color::black().multiply_alpha(0.0)),
    width=1.0,
  )
}

///|
fn ui_color(r : Double, g : Double, b : Double) -> @core.Color {
  @core.Color::rgba(r~, g~, b~)
}

///|
fn workbench_theme(scheme : @core.ColorScheme) -> @core.Theme {
  match scheme {
    @core.ColorScheme::Light =>
      @views.light_theme().with_accent(ui_color(0.22, 0.38, 0.95))
    @core.ColorScheme::Dark =>
      @views.dark_theme().with_accent(ui_color(0.48, 0.62, 1.0))
  }
}

///|
fn workbench_app_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.965, 0.966, 0.958)
    @core.ColorScheme::Dark => ui_color(0.055, 0.060, 0.070)
  }
}

///|
fn workbench_sidebar_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.905, 0.910, 0.905)
    @core.ColorScheme::Dark => ui_color(0.075, 0.080, 0.092)
  }
}

///|
fn workbench_sidebar_selected_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.985, 0.986, 0.980)
    @core.ColorScheme::Dark => ui_color(0.145, 0.153, 0.174)
  }
}

///|
fn workbench_main_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.975, 0.976, 0.968)
    @core.ColorScheme::Dark => ui_color(0.062, 0.067, 0.078)
  }
}

///|
fn workbench_panel_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.992, 0.993, 0.988)
    @core.ColorScheme::Dark => ui_color(0.105, 0.112, 0.128)
  }
}

///|
fn workbench_panel_raised_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.975, 0.977, 0.972)
    @core.ColorScheme::Dark => ui_color(0.132, 0.141, 0.160)
  }
}

///|
fn workbench_panel_subtle_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.955, 0.961, 0.956)
    @core.ColorScheme::Dark => ui_color(0.122, 0.130, 0.148)
  }
}

///|
fn workbench_panel_nested_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.930, 0.938, 0.934)
    @core.ColorScheme::Dark => ui_color(0.087, 0.093, 0.108)
  }
}

///|
fn workbench_status_bar_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.910, 0.918, 0.912)
    @core.ColorScheme::Dark => ui_color(0.083, 0.089, 0.102)
  }
}

///|
fn workbench_transcript_assistant_background(
  theme : @core.Theme,
) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.985, 0.987, 0.982)
    @core.ColorScheme::Dark => ui_color(0.116, 0.124, 0.141)
  }
}

///|
fn workbench_transcript_user_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.940, 0.958, 0.985)
    @core.ColorScheme::Dark => ui_color(0.105, 0.132, 0.168)
  }
}

///|
fn workbench_danger_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    @core.ColorScheme::Light => ui_color(0.995, 0.975, 0.970)
    @core.ColorScheme::Dark => ui_color(0.185, 0.094, 0.096)
  }
}

///|
fn workbench_transparent() -> @core.Color {
  @core.Color::black().multiply_alpha(0.0)
}
