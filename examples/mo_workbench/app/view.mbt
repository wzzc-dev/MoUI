// Mo Workbench shell: left sidebar (segmented tab bar + new-task entry + task
// tree list + user area), center work surface routed by the active top tab,
// and a settings overlay rendered on top when `settings_open` is true.
//
// Layout: HorizontalSplit(sidebar=~300px) | Center(column: topbar + main +
// statusbar). Sidebar tabs use a Segmented Control; task list is a tree with
// expandable folder groups.

///|
priv struct WorkbenchLayout {
  sidebar_width : Double
  topbar_height : Double
  statusbar_height : Double
  center_width : Double
  center_height : Double
}

///|
fn workbench_layout(viewport : @geometry.Size) -> WorkbenchLayout {
  let topbar_height = 50.0
  let statusbar_height = 26.0
  let sidebar_width = if viewport.width < 760.0 {
    200.0
  } else if viewport.width < 1120.0 {
    248.0
  } else {
    280.0
  }
  let center_width = (viewport.width - sidebar_width).max(320.0)
  let center_height = (viewport.height - topbar_height - statusbar_height - 16.0).max(
    262.0,
  )
  {
    sidebar_width,
    topbar_height,
    statusbar_height,
    center_width,
    center_height,
  }
}

///|
fn workbench_view(
  model : WorkbenchModel,
  env : @moui.ViewEnvironment,
) -> @moui.View[WorkbenchMsg] {
  let theme = workbench_theme(model.appearance, env)
  let viewport = env.viewport_size()
  let layout = workbench_layout(viewport)
  let main_height = viewport.height
  // Left column: traffic-light area (no toggle — it lives as a floating
  // overlay so it is never lost).
  let left_width = if model.sidebar_visible {
    layout.sidebar_width
  } else {
    0.0
  }
  let left_column = @views.container(
    @views.column(
      [
        @views.container(
          @views.spacer(min_length=78.0, weight=0.0),
          width=left_width,
          height=40.0,
          background=workbench_sidebar_background(theme),
          padding=0.0,
        ),
        sidebar_view(model, theme, left_width, main_height - 40.0),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width=left_width,
    height=main_height,
    background=workbench_sidebar_background(theme),
    padding=0.0,
  )
  // Right column: canvas + statusbar pinned to bottom, bar centered horizontally.
  let right_width = viewport.width - left_width
  let right_inner_width = (right_width - 16.0).max(280.0)
  let right_body_height = (main_height - layout.statusbar_height - 16.0).max(200.0)
  let right_column = @views.container(
    @views.column(
      [
        @views.container(
          @views.container(
            center_shell(model, theme, layout, right_inner_width),
            width=right_inner_width,
            background=workbench_canvas_background(theme),
            padding=0.0,
          ),
          width=right_width,
          height=right_body_height,
          background=workbench_app_background(theme),
          padding=8.0,
        ),
        @views.center(
          statusbar_view(
            model,
            theme,
            right_width,
            layout.statusbar_height,
          ),
          width=right_width,
          height=layout.statusbar_height,
        ),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width=right_width,
    height=main_height,
    background=workbench_app_background(theme),
    padding=0.0,
  )
  let shell = @views.container(
    @views.row(
      if model.sidebar_visible {
        [left_column, right_column]
      } else {
        [right_column]
      },
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width=viewport.width,
    height=viewport.height,
    background=workbench_app_background(theme),
    padding=0.0,
  )
  // Floating sidebar-toggle overlay — always visible at (78, 6).
  let toggle_icon_name = if model.sidebar_visible {
    @views.IconName::Sidebar
  } else {
    @views.IconName::Columns
  }
  let toggle_background = if model.sidebar_visible {
    workbench_subtle_background(theme)
  } else {
    @graphics.Color::rgba(r=1.0, g=1.0, b=1.0, a=1.0)
  }
  let toggle_overlay = @views.padding_edges(
    @views.container(
      @views.icon(
        toggle_icon_name,
        size=14.0,
        color=workbench_text_muted(theme),
      ),
      width=28.0,
      height=28.0,
      background=toggle_background,
      corner_radius=6.0,
      padding=4.0,
    ).on_tap(WorkbenchMsg::ToggleSidebar),
    top=6.0,
    left=78.0,
    bottom=0.0,
    right=0.0,
  )
  let base = @views.overlay(shell, toggle_overlay)
  if model.settings_open {
    @views.overlay(
      base,
      settings_overlay_view(model, theme, viewport.width, viewport.height),
    )
  } else {
    base
  }
}

///|
fn center_shell(
  model : WorkbenchModel,
  theme : @moui.Theme,
  layout : WorkbenchLayout,
  center_width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        topbar_view(model, theme, center_width, layout.topbar_height),
        main_surface(model, theme, center_width, layout.center_height),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width=center_width,
    background=workbench_canvas_background(theme),
    padding=0.0,
  )
}

///|
fn topbar_view(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let title_width = (width - 56.0).max(160.0)
  let title = match model.active_tab {
    Code => code_session_title(model.code)
    _ => tab_label(model.active_tab)
  }
  @views.padding_edges(
    @views.container(
      @views.row(
        [
          @views.column(
            [
              @views.text(
                title,
                role=@views.TextRole::Label,
                theme~,
                width=title_width,
                height=20.0,
              ),
              @views.text(
                tab_subtitle(model),
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
        ],
        spacing=16.0,
        align=@views.CrossAlign::Center,
      ),
      width~,
      height~,
      background=workbench_card_background(theme),
      padding=0.0,
    ),
    top=0.0,
    left=28.0,
    bottom=0.0,
    right=24.0,
  )
}

///|
fn statusbar_view(
  model : WorkbenchModel,
  theme : @moui.Theme,
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
  let labels = [
    "Mo Workbench",
    tab_label(model.active_tab),
    runtime_status,
    model_choice_label(model.code.current_model),
    thinking_choice_label(model.code.current_thinking),
    session_status,
  ]
  let segments : Array[@moui.View[WorkbenchMsg]] = []
  for label in labels {
    segments.push(
      @views.text(
        label,
        role=@views.TextRole::Caption,
        theme~,
        width=label.length().to_double() * 7.5 + 8.0,
        height=22.0,
      ).foreground(workbench_text_muted(theme)),
    )
  }
  let bar_inner_width = workbench_statusbar_inner_width(labels)
  @views.container(
    @views.row(
      segments,
      spacing=12.0,
      align=@views.CrossAlign::Center,
      justify=@views.MainAlign::Center,
    ),
    width=bar_inner_width,
    height~,
    background=theme.palette.surface_variant.multiply_alpha(0.52),
    corner_radius=theme.radius_scale.sm,
    padding=4.0,
  )
}

///|
fn workbench_statusbar_inner_width(labels : Array[String]) -> Double {
  let mut total = 24.0
  for label in labels {
    total = total + label.length().to_double() * 7.5 + 12.0
  }
  total.min(920.0).max(280.0)
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

///|
fn sidebar_view(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let rows : Array[@moui.View[WorkbenchMsg]] = [
    tab_segmented_control(model, theme, width),
    new_task_section(model, theme, width),
    task_tree_view(model, theme, width, (height - 220.0).max(160.0)),
    @views.spacer(),
    sidebar_footer(model, theme, width),
  ]
  @views.container(
    @views.column(rows, spacing=0.0, align=@views.CrossAlign::Stretch),
    width~,
    height~,
    background=workbench_sidebar_background(theme),
    padding=0.0,
  )
}

///|
fn workbench_tab_segment_button(
  label : String,
  item_id : String,
  active : Bool,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let tab = match item_id {
    "work" => TopTab::Work
    "design" => TopTab::Design
    _ => TopTab::Code
  }
  if active {
    @views.button(
      label,
      on_click=WorkbenchMsg::SwitchTab(tab),
      variant=@views.ButtonVariant::Ghost,
      theme~,
      style=workbench_tab_selected_button_style(theme),
      width~,
      height=32.0,
    )
  } else {
    @views.button(
      label,
      on_click=WorkbenchMsg::SwitchTab(tab),
      variant=@views.ButtonVariant::Ghost,
      theme~,
      width~,
      height=32.0,
    )
  }
}

///|
/// Segmented control tab bar: Work / Code / Design. Tapping switches the active
/// tab. The selected tab renders with highlighted background and accent text.
fn tab_segmented_control(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let items : Array[@views.ChoiceItem] = [
    @views.choice_item("work", "Work"),
    @views.choice_item("code", "Code"),
    @views.choice_item("design", "Design"),
  ]
  let selected_id = match model.active_tab {
    Work => "work"
    Code => "code"
    Design => "design"
  }
  let bar_width = width - 24.0
  let item_width = bar_width / 3.0
  let segments : Array[@moui.View[WorkbenchMsg]] = []
  for item in items {
    let active = item.id == selected_id
    segments.push(
      workbench_tab_segment_button(
        item.label,
        item.id,
        active,
        theme,
        item_width,
      ),
    )
  }
  @views.padding_xy(
    @views.container(
      @views.row(segments, spacing=0.0, align=@views.CrossAlign::Center),
      width=bar_width,
      height=32.0,
      background=workbench_subtle_background(theme),
      corner_radius=8.0,
      padding=2.0,
    ),
    horizontal=12.0,
    vertical=12.0,
  )
}

///|
/// The "New Task" entry button + secondary static chips (skills / automations).
fn new_task_section(
  _model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.padding_xy(
    @views.column(
      [
        @views.button(
          "新建任务",
          on_click=WorkbenchMsg::NewTask,
          variant=@views.ButtonVariant::Tonal,
          theme~,
          icon=Some(@views.IconName::Plus),
          width=width - 32.0,
          height=36.0,
        ),
        @views.row(
          [
            @views.chip("技能", theme~, width=64.0, height=26.0),
            @views.chip("自动化", theme~, width=76.0, height=26.0),
            @views.spacer(),
          ],
          spacing=8.0,
          align=@views.CrossAlign::Center,
        ),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Stretch,
    ),
    horizontal=16.0,
    vertical=10.0,
  )
}

///|
/// The task tree: sessions projected as a tree with expandable folder groups.
/// Folder nodes toggle expand/collapse; task leaf nodes select the session.
fn task_tree_view(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let body : Array[@moui.View[WorkbenchMsg]] = []
  if model.task_tree.is_empty() {
    body.push(sidebar_caption("暂无任务,点击上方新建", theme, width - 32.0))
  } else {
    body.push(
      @views.row(
        [
          @views.text(
            "任务列表",
            role=@views.TextRole::Label,
            theme~,
            width=width - 80.0,
          ),
          @views.container(
            @views.icon(@views.IconName::ListOrdered, size=14.0, color=workbench_text_muted(theme)),
            width=24.0,
            height=24.0,
            padding=0.0,
          ),
          @views.chip("Filter", theme~, width=50.0, height=22.0),
        ],
        spacing=4.0,
        align=@views.CrossAlign::Center,
      ),
    )
    for node in model.task_tree {
      body.push(task_tree_node_view(node, model, theme, width - 48.0))
    }
  }
  @views.container(
    @views.scroll_view(
      @views.padding_xy(
        @views.column(body, spacing=4.0, align=@views.CrossAlign::Stretch),
        horizontal=16.0,
        vertical=12.0,
      ),
      width~,
      height~,
    ),
    width~,
    height~,
    background=workbench_sidebar_background(theme),
    padding=0.0,
  )
}

///|
/// Render a single task tree node (folder or leaf).
fn task_tree_node_view(
  node : TaskTreeNode,
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  match node {
    Folder(id, title, _, children, expanded) => {
      let icon = if expanded {
        @views.IconName::ChevronDown
      } else {
        @views.IconName::ChevronRight
      }
      let rows : Array[@moui.View[WorkbenchMsg]] = [
        @views.container(
          @views.row(
            [
              @views.container(
                @views.icon(icon, size=12.0, color=theme.palette.muted),
                width=20.0,
                height=20.0,
                padding=0.0,
              ),
              @views.text(
                title,
                role=@views.TextRole::Label,
                theme~,
                width=width - 28.0,
              ),
            ],
            spacing=4.0,
            align=@views.CrossAlign::Center,
          ),
          width~,
          corner_radius=4.0,
          padding=6.0,
        ).on_tap(WorkbenchMsg::ToggleFolder(id)),
      ]
      if expanded {
        for child in children {
          rows.push(indented_task_view(child, model, theme, width - 20.0))
        }
      }
      @views.column(rows, spacing=2.0, align=@views.CrossAlign::Stretch)
    }
    Task(id, title, _, status, _) => task_row(id, title, status, model, theme, width)
  }
}

///|
/// An indented wrapper for child tasks inside a folder.
fn indented_task_view(
  node : TaskTreeNode,
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.padding_edges(
    task_tree_node_view(node, model, theme, width),
    left=20.0,
    top=0.0,
    right=0.0,
    bottom=0.0,
  )
}

///|
/// A single task row: a colored status dot + the task title. Tapping selects
/// the task (and its underlying session).
fn task_row(
  id : String,
  title : String,
  status : TaskStatus,
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let is_active = match model.code.active_session_id {
    Some(aid) => aid == id
    None => false
  }
  let status_color = match status {
    Pending => workbench_text_faint(theme)
    Running => workbench_accent(theme)
    Completed => workbench_success(theme)
    Failed => workbench_danger(theme)
  }
  let title_color = if is_active {
    workbench_accent(theme)
  } else {
    workbench_text(theme)
  }
  let row_bg = if is_active {
    workbench_sidebar_active(theme)
  } else {
    @graphics.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
  }
  @views.container(
    @views.row(
      [
        @views.container(
          @views.spacer(min_length=0.0),
          width=8.0,
          height=8.0,
          background=status_color,
          corner_radius=4.0,
          padding=0.0,
        ),
        @views.text(
          truncate_text(title, 22),
          role=@views.TextRole::Label,
          theme~,
          width=width - 28.0,
        ).foreground(title_color),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    background=row_bg,
    corner_radius=6.0,
    padding=8.0,
  ).on_tap(WorkbenchMsg::SelectTask(id))
}

///|
/// Sidebar footer: settings gear + appearance toggle row only (no avatar/name).
fn sidebar_footer(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.padding_xy(
    @views.column(
      [
        @views.divider(theme~),
        @views.row(
          [
            @views.container(
              @views.icon(
                @views.IconName::Settings,
                size=18.0,
                color=workbench_text_muted(theme),
              ),
              width=28.0,
              height=28.0,
              padding=0.0,
            ).on_tap(WorkbenchMsg::ToggleSettings),
            @views.text(
              appearance_label(model.appearance),
              role=@views.TextRole::Caption,
              theme~,
              width=width - 72.0,
            ),
            @views.text(
              theme_label(theme),
              role=@views.TextRole::Caption,
              theme~,
              width=32.0,
            ),
            @views.spacer(),
          ],
          spacing=8.0,
          align=@views.CrossAlign::Center,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Stretch,
    ),
    horizontal=16.0,
    vertical=12.0,
  )
}

///|
fn theme_label(theme : @moui.Theme) -> String {
  match theme.scheme {
    Light => "☀"
    Dark => "☾"
  }
}

// ---------------------------------------------------------------------------
// Settings overlay
// ---------------------------------------------------------------------------

///|
/// The settings overlay: a semi-transparent backdrop with a centered card
/// containing the settings form. Rendered on top of the whole window via
/// `@views.overlay` when `model.settings_open` is true.
fn settings_overlay_view(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let card_width = (width * 0.62).min(640.0).max(360.0)
  let card_height = (height * 0.82).min(560.0).max(360.0)
  @views.container(
    @views.column(
      [
        @views.spacer(weight=1.0),
        @views.container(
          @views.column(
            [
              @views.row(
                [
                  @views.text(
                    "Settings",
                    role=@views.TextRole::Title,
                    theme~,
                  ),
@views.spacer(min_length=78.0, weight=0.0),
                  @views.container(
                    @views.icon(
                      @views.IconName::Close,
                      size=18.0,
                      color=workbench_text_muted(theme),
                    ),
                    width=32.0,
                    height=32.0,
                    padding=0.0,
                  ).on_tap(WorkbenchMsg::ToggleSettings),
                ],
                align=@views.CrossAlign::Center,
              ),
              @views.divider(theme~),
              settings_workspace_view(
                model.settings,
                theme,
                card_width - 48.0,
                card_height - 120.0,
              ).map(m => WorkbenchMsg::SettingsMsg(m)),
            ],
            spacing=14.0,
            align=@views.CrossAlign::Stretch,
          ),
          width=card_width,
          height=card_height,
          background=workbench_card_background(theme),
          corner_radius=14.0,
          padding=24.0,
        ).border(hairline_border(theme)),
        @views.spacer(weight=1.0),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height~,
    background=@graphics.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.45),
    padding=0.0,
  )
}

// ---------------------------------------------------------------------------
// Main surface
// ---------------------------------------------------------------------------

///|
fn main_surface(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  match model.active_tab {
    Code =>
      code_workspace_view(model.code, theme, width, height).map(m => {
        WorkbenchMsg::CodeMsg(m)
      })
    Work => work_tab_placeholder_view(theme, width, height)
    Design => design_tab_placeholder_view(theme, width, height)
  }
}

///|
fn[Msg] sidebar_caption(
  text_ : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  @views.text(text_, role=@views.TextRole::Caption, theme~, width~).foreground(
    theme.palette.muted,
  )
}

// ---------------------------------------------------------------------------
// Pure helpers
// ---------------------------------------------------------------------------

///|
fn tab_label(tab : TopTab) -> String {
  match tab {
    Work => "Work"
    Code => "Code"
    Design => "Design"
  }
}

///|
fn tab_subtitle(model : WorkbenchModel) -> String {
  match model.active_tab {
    Code =>
      if model.code.is_streaming {
        "Agent 正在工作…"
      } else {
        "向 Mo 描述你的任务"
      }
    Work => "任务看板"
    Design => "设计预览"
  }
}

///|
fn code_session_title(code : CodeWorkspace) -> String {
  match code.active_session_id {
    Some(id) => truncate_text(id, 34)
    None => "新建任务"
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
fn model_choice_label(model : ModelChoice) -> String {
  match model {
    V4Flash => "V4 Flash"
    V4Pro => "V4 Pro"
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
