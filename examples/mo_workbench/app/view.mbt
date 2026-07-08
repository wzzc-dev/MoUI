// Mo Workbench shell: left sidebar (segmented tab bar + new-task entry + task
// tree list + user area), center work surface routed by the active top tab,
// and a settings overlay rendered on top when `settings_open` is true.
//
// Layout: HorizontalSplit(sidebar=~300px) | Center(column: topbar + main).
// Sidebar tabs use a Segmented Control; task list is a tree with
// expandable folder groups.

///|
priv struct WorkbenchLayout {
  sidebar_width : Double
  topbar_height : Double
  center_height : Double
}

///|
fn workbench_layout(viewport : @geometry.Size) -> WorkbenchLayout {
  let topbar_height = 50.0
  let app_margin = 8.0
  let sidebar_width = if viewport.width < 760.0 {
    200.0
  } else if viewport.width < 1120.0 {
    248.0
  } else {
    280.0
  }
  let center_height = (viewport.height - topbar_height - app_margin * 2.0).max(
    262.0,
  )
  { sidebar_width, topbar_height, center_height }
}

///|
fn workbench_view(
  model : WorkbenchModel,
  env : @moui.ViewEnvironment,
) -> @moui.View[WorkbenchMsg] {
  let theme = workbench_theme(model.appearance, env)
  let sidebar_theme = workbench_sidebar_theme(theme)
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
          background=workbench_sidebar_background(sidebar_theme),
          padding=0.0,
        ),
        sidebar_view(model, sidebar_theme, left_width, main_height - 40.0),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width=left_width,
    height=main_height,
    background=workbench_sidebar_background(sidebar_theme),
    padding=0.0,
  )
  // Right column: symmetric app-bg margin around the main canvas.
  let right_width = viewport.width - left_width
  let app_margin = 8.0
  let right_inner_width = (right_width - app_margin * 2.0).max(280.0)
  let canvas_height = (main_height - app_margin * 2.0).max(200.0)
  let right_canvas = @views.container(
    center_shell(model, theme, layout, right_inner_width),
    width=right_inner_width,
    height=canvas_height,
    background=workbench_canvas_background(theme),
    corner_radius=14.0,
    padding=0.0,
  )
  let right_column = @views.container(
    @views.padding_edges(
      @views.rounded_clip(right_canvas, radius=14.0),
      top=app_margin,
      left=app_margin,
      right=app_margin,
      bottom=app_margin,
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
        size=18.0,
        color=workbench_text_muted(theme),
      ),
      width=20.0,
      height=20.0,
      background=toggle_background,
      corner_radius=6.0,
      padding=2.0,
    ).on_tap(WorkbenchMsg::ToggleSidebar),
    top=7.0,
    left=78.0,
    bottom=0.0,
    right=0.0,
  )
  let base = @views.overlay(shell, toggle_overlay)
  if model.settings_open {
    let settings_theme = workbench_lightweight_theme(
      theme,
      model.settings.font_size,
    )
    @views.overlay(
      base,
      settings_overlay_view(
        model,
        settings_theme,
        viewport.width,
        viewport.height,
      ),
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
  let shell_height = layout.topbar_height + layout.center_height
  let surface_theme = workbench_lightweight_theme(
    theme,
    model.settings.font_size,
  )
  @views.container(
    @views.column(
      [
        topbar_view(model, surface_theme, center_width, layout.topbar_height),
        main_surface(model, surface_theme, center_width, layout.center_height),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width=center_width,
    height=shell_height,
    background=workbench_canvas_background(theme),
    corner_radius=14.0,
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
  let title = match model.active_tab {
    Code => code_session_title(model.code)
    _ => tab_label(model.active_tab)
  }
  let horizontal_pad = 24.0
  let inner_width = (width - horizontal_pad * 2.0).max(160.0)
  let title_block = @views.column(
    [
      @views.text(
        title,
        role=@views.TextRole::Label,
        theme~,
        width=inner_width,
        height=20.0,
      ),
      @views.text(
        tab_subtitle(model),
        role=@views.TextRole::Caption,
        theme~,
        width=inner_width,
        height=16.0,
      ).foreground(theme.palette.muted),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Center,
  )
  @views.container(
    @views.padding_edges(
      @views.center(title_block, width=inner_width, height~, theme~),
      left=horizontal_pad,
      right=horizontal_pad,
      top=0.0,
      bottom=0.0,
    ),
    width~,
    height~,
    background=workbench_card_background(theme),
    padding=0.0,
  )
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
          theme=sidebar_control_theme(theme, size_delta=-0.5, weight=300),
          icon=Some(@views.IconName::Plus),
          width=width - 32.0,
          height=36.0,
        ),
        @views.row(
          [
            sidebar_secondary_chip("技能", theme, 60.0, 24.0),
            sidebar_secondary_chip("自动化", theme, 70.0, 24.0),
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
fn sidebar_fine_font(
  theme : @moui.Theme,
  size_delta? : Double = -1.0,
  weight? : Int = 300,
) -> @text.FontSpec {
  let base = theme.typography.caption
  { ..base, size: (base.size + size_delta).max(10.0), weight }
}

///|
fn sidebar_control_font(
  theme : @moui.Theme,
  size_delta? : Double = -0.5,
  weight? : Int = 300,
) -> @text.FontSpec {
  let base = theme.typography.control
  { ..base, size: (base.size + size_delta).max(10.0), weight }
}

///|
fn sidebar_control_theme(
  theme : @moui.Theme,
  size_delta? : Double = -0.5,
  weight? : Int = 300,
) -> @moui.Theme {
  theme.with_typography({
    ..theme.typography,
    control: sidebar_control_font(theme, size_delta~, weight~),
  })
}

///|
fn sidebar_secondary_chip(
  label : String,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.center(
      @views.text(
        label,
        role=@views.TextRole::Caption,
        theme~,
        width=(width - 16.0).max(32.0),
        height=16.0,
      )
      .font(sidebar_fine_font(theme, size_delta=-1.0, weight=280))
      .foreground(workbench_text_muted(theme)),
      width=width - 8.0,
      height=height - 8.0,
      theme~,
    ),
    width~,
    height~,
    background=workbench_subtle_background(theme),
    corner_radius=height / 2.0,
    border=Some(hairline_border(theme)),
    padding=4.0,
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
  if model.code.sessions.is_empty() {
    body.push(
      sidebar_caption("暂无任务,点击上方新建", theme, width - 32.0),
    )
  } else {
    let header_width = width - 32.0
    let filter_width = 54.0
    let sort_width = 22.0
    let title_width = (header_width - filter_width - sort_width - 8.0).max(64.0)
    body.push(
      @views.container(
        @views.row(
          [
            @views.text(
              "任务列表",
              role=@views.TextRole::Caption,
              theme~,
              width=title_width,
              height=20.0,
            )
            .font(sidebar_fine_font(theme, size_delta=0.5, weight=320))
            .foreground(workbench_text_muted(theme)),
            @views.container(
              @views.icon(
                @views.IconName::ListOrdered,
                size=13.0,
                color=workbench_text_muted(theme),
              ),
              width=sort_width,
              height=22.0,
              padding=0.0,
            ),
            task_filter_chip(model.task_filter, theme, filter_width),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Center,
        ),
        width=header_width,
        padding=0.0,
      ),
    )
    body.push(task_search_field(model, theme, width - 32.0))
    if model.task_tree.is_empty() {
      body.push(sidebar_caption("没有匹配任务", theme, width - 32.0))
    } else {
      for node in model.task_tree {
        body.push(task_tree_node_view(node, model, theme, width - 48.0))
      }
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
fn task_search_field(
  model : WorkbenchModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.text_field(
    model.task_search_query,
    on_input=query => WorkbenchMsg::TaskSearchChanged(query),
    placeholder="搜索任务或 session",
    variant=@views.TextFieldVariant::Filled,
    theme~,
    style=sidebar_search_field_style(theme),
    width~,
    height=30.0,
  )
}

///|
fn sidebar_search_field_style(theme : @moui.Theme) -> @views.TextFieldStyle {
  let base = @views.TextFieldStyle::filled(theme~)
  {
    ..base,
    font: sidebar_fine_font(theme, size_delta=-0.75, weight=280),
    placeholder_color: workbench_text_muted(theme),
  }
}

///|
fn task_filter_chip(
  filter : TaskFilter,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let label = task_filter_label(filter)
  @views.container(
    @views.text(
      label,
      role=@views.TextRole::Caption,
      theme~,
      width=width - 6.0,
      height=15.0,
    )
    .font(sidebar_fine_font(theme, size_delta=-1.5, weight=300))
    .foreground(workbench_accent(theme)),
    width~,
    height=20.0,
    background=workbench_accent_soft(theme),
    corner_radius=10.0,
    border=Some(hairline_border(theme)),
    padding=2.5,
  ).on_tap(WorkbenchMsg::CycleTaskFilter)
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
                width=18.0,
                height=18.0,
                padding=0.0,
              ),
              @views.text(
                title,
                role=@views.TextRole::Caption,
                theme~,
                width=width - 26.0,
                height=18.0,
              )
              .font(sidebar_fine_font(theme, size_delta=-1.0, weight=300))
              .foreground(workbench_text_muted(theme)),
            ],
            spacing=4.0,
            align=@views.CrossAlign::Center,
          ),
          width~,
          corner_radius=4.0,
          padding=4.0,
        ).on_tap(WorkbenchMsg::ToggleFolder(id)),
      ]
      if expanded {
        for child in children {
          rows.push(indented_task_view(child, model, theme, width - 20.0))
        }
      }
      @views.column(rows, spacing=2.0, align=@views.CrossAlign::Stretch)
    }
    Task(id, title, _, status, _) =>
      task_row(id, title, status, model, theme, width)
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
          width=6.0,
          height=6.0,
          background=status_color,
          corner_radius=3.0,
          padding=0.0,
        ),
        @views.text(
          truncate_text(title, 22),
          role=@views.TextRole::Caption,
          theme~,
          width=width - 24.0,
          height=18.0,
        )
        .font(sidebar_fine_font(theme, size_delta=-1.0, weight=300))
        .foreground(title_color),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    background=row_bg,
    corner_radius=6.0,
    padding=6.0,
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
  let card_width = (width * 0.78).min(920.0).max(560.0)
  let available_card_height = (height - 32.0).max(280.0)
  let card_height = (height * 0.88)
    .min(640.0)
    .max(420.0)
    .min(available_card_height)
  let card_padding = 24.0
  let card_inner_width = card_width - card_padding * 2.0
  let settings_body_height = (card_height - card_padding * 2.0 - 64.0).max(
    140.0,
  )
  @views.container(
    @views.column(
      [
        @views.spacer(weight=1.0),
        @views.container(
          @views.column(
            [
              @views.container(
                @views.row(
                  [
                    @views.text(
                      "Settings",
                      role=@views.TextRole::Title,
                      theme~,
                      width=card_inner_width - 48.0,
                    ),
                    @views.spacer(),
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
                  spacing=12.0,
                  align=@views.CrossAlign::Center,
                ),
                width=card_inner_width,
                height=36.0,
                padding=0.0,
              ),
              @views.divider(theme~),
              settings_workspace_view(
                model.settings,
                model.appearance,
                theme,
                card_inner_width,
                settings_body_height,
              ).map(m => WorkbenchMsg::SettingsMsg(m)),
            ],
            spacing=12.0,
            align=@views.CrossAlign::Stretch,
          ),
          width=card_width,
          height=card_height,
          background=workbench_card_background(theme),
          corner_radius=14.0,
          padding=card_padding,
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
      code_workspace_view(model.code, model.settings, theme, width, height).map(m => {
          WorkbenchMsg::CodeMsg(m)
        },
      )
    Work => work_tab_view(model, theme, width, height)
    Design => design_tab_view(model, theme, width, height)
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
fn next_thinking_choice(thinking : ThinkingChoice) -> ThinkingChoice {
  match thinking {
    Normal => ThinkingChoice::High
    High => ThinkingChoice::Max
    Max => ThinkingChoice::Normal
  }
}

///|
fn task_filter_label(filter : TaskFilter) -> String {
  match filter {
    AllTasks => "All"
    ActiveTask => "Active"
    RunningTasks => "Running"
    FailedTasks => "Failed"
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
