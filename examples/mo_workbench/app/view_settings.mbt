// Settings workspace view: grouped runtime and workbench preferences.

///|
fn settings_workspace_view(
  model : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[SettingsMsg] {
  let inner_width = (width - 64.0).max(360.0)
  @views.container(
    @views.scroll_view(
      @views.column(
        [
          settings_header(theme, inner_width),
          runtime_settings_card(model, theme, inner_width),
          permission_settings_card(model, theme, inner_width),
          appearance_settings_card(model, theme, inner_width),
        ],
        spacing=24.0,
        align=@views.CrossAlign::Stretch,
      ),
      width~,
      height~,
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=32.0,
  )
}

///|
fn settings_header(
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  @views.column(
    [
      @views.text("Settings", role=@views.TextRole::Title, theme~, width~),
      @views.text(
        "UI-only in this prototype; persistence is reserved for backend integration.",
        role=@views.TextRole::Caption,
        theme~,
        width~,
      ).foreground(theme.palette.muted),
    ],
    spacing=6.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn runtime_settings_card(
  model : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  settings_card(
    "Agent Runtime",
    [
      field_label("API Key", theme, width - 32.0),
      api_key_field(model.api_key, theme, width - 32.0),
      field_label("Base URL", theme, width - 32.0),
      @views.text_field(
        model.base_url,
        on_input=value => SettingsMsg::BaseUrlChanged(value),
        on_submit=None,
        placeholder="https://api.deepseek.com",
        variant=@views.TextFieldVariant::Filled,
        theme~,
        width=width - 32.0,
        height=40.0,
      ),
      field_label("Working Directory", theme, width - 32.0),
      @views.text_field(
        model.working_dir,
        on_input=value => SettingsMsg::WorkingDirChanged(value),
        on_submit=None,
        placeholder="~/projects/my-app",
        variant=@views.TextFieldVariant::Filled,
        theme~,
        width=width - 32.0,
        height=40.0,
      ),
    ],
    theme,
    width,
  )
}

///|
fn permission_settings_card(
  model : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  settings_card(
    "Permissions",
    [
      field_label("Approval Policy", theme, width - 32.0),
      approval_segmented_control(model.approval_policy, theme, width - 32.0),
      field_label("Sandbox Mode", theme, width - 32.0),
      sandbox_segmented_control(model.sandbox_mode, theme, width - 32.0),
    ],
    theme,
    width,
  )
}

///|
fn appearance_settings_card(
  model : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  settings_card(
    "Workbench",
    [
      field_label("Font Size", theme, width - 32.0),
      font_size_stepper(model.font_size, theme, width - 32.0),
      @views.text(
        "Theme mode is available from the sidebar footer.",
        role=@views.TextRole::Caption,
        theme~,
        width=width - 32.0,
      ).foreground(theme.palette.muted),
    ],
    theme,
    width,
  )
}

///|
fn settings_card(
  title : String,
  children : Array[@moui.View[SettingsMsg]],
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  let rows : Array[@moui.View[SettingsMsg]] = [
    @views.text(
      title,
      role=@views.TextRole::Subtitle,
      theme~,
      width=width - 32.0,
    ),
  ]
  for child in children {
    rows.push(child)
  }
  @views.container(
    @views.column(rows, spacing=14.0, align=@views.CrossAlign::Stretch),
    width~,
    background=workbench_card_background(theme),
    corner_radius=10.0,
    padding=20.0,
  ).border(hairline_border(theme))
}

///|
fn field_label(
  text_ : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  @views.text(text_, role=@views.TextRole::Label, theme~, width~).foreground(
    theme.palette.muted,
  )
}

///|
fn api_key_field(
  api_key : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  let masked = if api_key.is_empty() {
    "(not set)"
  } else {
    let dots = "*".repeat(api_key.length().min(12))
    dots + " (" + api_key.length().to_string() + " chars)"
  }
  @views.column(
    [
      @views.text(masked, role=@views.TextRole::Caption, theme~, width~).foreground(
        theme.palette.muted,
      ),
      @views.text_field(
        api_key,
        on_input=value => SettingsMsg::ApiKeyChanged(value),
        on_submit=None,
        placeholder="sk-...",
        variant=@views.TextFieldVariant::Filled,
        theme~,
        width~,
        height=40.0,
      ),
    ],
    spacing=4.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn approval_segmented_control(
  policy : ApprovalPolicy,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  @views.segmented_control(
    [
      @views.choice_item("never", "Never"),
      @views.choice_item("write", "On write"),
      @views.choice_item("command", "Command"),
    ],
    selected=approval_policy_id(policy),
    on_select=id => SettingsMsg::ApprovalChanged(approval_policy_from_id(id)),
    size=@views.SegmentedControlSize::Compact,
    theme~,
    width~,
  )
}

///|
fn sandbox_segmented_control(
  mode : SandboxMode,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  @views.segmented_control(
    [
      @views.choice_item("read-only", "Read only"),
      @views.choice_item("workspace", "Workspace"),
      @views.choice_item("full", "Full"),
    ],
    selected=sandbox_mode_id(mode),
    on_select=id => SettingsMsg::SandboxChanged(sandbox_mode_from_id(id)),
    size=@views.SegmentedControlSize::Compact,
    theme~,
    width~,
  )
}

///|
fn font_size_stepper(
  font_size : Int,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  @views.row(
    [
      @views.button(
        "-",
        on_click=SettingsMsg::FontSizeChanged(font_size - 1),
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=40.0,
        height=36.0,
      ),
      @views.text(
        font_size.to_string() + " pt",
        role=@views.TextRole::Label,
        theme~,
        width=width - 96.0,
      ),
      @views.button(
        "+",
        on_click=SettingsMsg::FontSizeChanged(font_size + 1),
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=40.0,
        height=36.0,
      ),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  )
}
