// Settings overlay content: section nav + focused form panels.

///|
fn settings_workspace_view(
  model : SettingsWorkspace,
  appearance : AppearanceMode,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[SettingsMsg] {
  let nav_width = 168.0
  let gap = 20.0
  let panel_width = (width - nav_width - gap).max(280.0)
  @views.row(
    [
      settings_section_nav(model.active_section, theme, nav_width, height),
      settings_section_panel(model, appearance, theme, panel_width, height),
    ],
    spacing=gap,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn settings_section_nav(
  active : SettingsSection,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[SettingsMsg] {
  @views.container(
    @views.column(
      [
        @views.text(
          "Preferences",
          role=@views.TextRole::Subtitle,
          theme~,
          width~,
        ),
        settings_nav_item(
          "API & keys",
          SettingsSection::Api,
          active,
          theme,
          width,
        ),
        settings_nav_item("Agent", SettingsSection::Agent, active, theme, width),
        settings_nav_item(
          "Editor",
          SettingsSection::Editor,
          active,
          theme,
          width,
        ),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height~,
    background=workbench_subtle_background(theme),
    corner_radius=10.0,
    padding=14.0,
  ).border(hairline_border(theme))
}

///|
fn settings_nav_item(
  label : String,
  section : SettingsSection,
  active : SettingsSection,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  let selected = active == section
  let background = if selected {
    workbench_sidebar_active(theme)
  } else {
    @graphics.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
  }
  @views.container(
    @views.text(label, role=@views.TextRole::Label, theme~, width=width - 20.0),
    width~,
    height=36.0,
    background~,
    corner_radius=8.0,
    padding=10.0,
  ).on_tap(SettingsMsg::SelectSection(section))
}

///|
fn settings_section_panel(
  model : SettingsWorkspace,
  appearance : AppearanceMode,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[SettingsMsg] {
  let body = match model.active_section {
    SettingsSection::Api => settings_api_panel(model, theme, width)
    SettingsSection::Agent => settings_agent_panel(model, theme, width)
    SettingsSection::Editor =>
      settings_editor_panel(model, appearance, theme, width)
  }
  @views.container(
    @views.scroll_view(
      @views.column(
        [
          settings_panel_header(model, theme, width),
          body,
          settings_save_row(model, theme, width),
        ],
        spacing=18.0,
        align=@views.CrossAlign::Stretch,
      ),
      width~,
      height=height - 8.0,
    ),
    width~,
    height~,
    background=workbench_card_background(theme),
    corner_radius=10.0,
    padding=20.0,
  ).border(hairline_border(theme))
}

///|
fn settings_panel_header(
  model : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  @views.column(
    [
      @views.text(
        settings_section_title(model.active_section),
        role=@views.TextRole::Title,
        theme~,
        width~,
      ),
      @views.text(
        "Loaded from " +
        model.env_source +
        ". First run creates .mo_workbench/settings.json; edit openai_api_key there.",
        role=@views.TextRole::Caption,
        theme~,
        width~,
      ).foreground(theme.palette.muted),
    ],
    spacing=4.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn settings_section_title(section : SettingsSection) -> String {
  match section {
    SettingsSection::Api => "API & keys"
    SettingsSection::Agent => "Agent"
    SettingsSection::Editor => "Editor"
  }
}

///|
fn settings_api_panel(
  model : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  let field_w = width - 8.0
  @views.column(
    [
      settings_field_row(
        "OpenAI API key",
        "openai_api_key in .mo_workbench/settings.json",
        @views.text_field(
          model.api_key,
          on_input=value => SettingsMsg::ApiKeyChanged(value),
          on_submit=None,
          placeholder="sk-...",
          variant=@views.TextFieldVariant::Filled,
          theme~,
          width=field_w,
          height=40.0,
        ),
        theme,
        field_w,
      ),
      settings_field_row(
        "Base URL",
        "OpenAI-compatible endpoint (e.g. https://token.sensenova.cn/v1)",
        @views.text_field(
          model.base_url,
          on_input=value => SettingsMsg::BaseUrlChanged(value),
          on_submit=None,
          placeholder="https://api.deepseek.com/v1",
          variant=@views.TextFieldVariant::Filled,
          theme~,
          width=field_w,
          height=40.0,
        ),
        theme,
        field_w,
      ),
      settings_secret_status(model.api_key, theme, field_w),
    ],
    spacing=16.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn settings_agent_panel(
  model : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  let field_w = width - 8.0
  @views.column(
    [
      settings_field_row(
        "Workspace",
        "mo_workbench_workspace — agent working directory",
        @views.text_field(
          model.working_dir,
          on_input=value => SettingsMsg::WorkingDirChanged(value),
          on_submit=None,
          placeholder=".",
          variant=@views.TextFieldVariant::Filled,
          theme~,
          width=field_w,
          height=40.0,
        ),
        theme,
        field_w,
      ),
      settings_field_row(
        "Session store",
        "mo_workbench_session_root — OpenSeek session files",
        @views.text_field(
          model.session_root,
          on_input=value => SettingsMsg::SessionRootChanged(value),
          on_submit=None,
          placeholder="./.openseek",
          variant=@views.TextFieldVariant::Filled,
          theme~,
          width=field_w,
          height=40.0,
        ),
        theme,
        field_w,
      ),
      settings_field_row(
        "Approval",
        "When tool writes need confirmation",
        approval_segmented_control(model.approval_policy, theme, field_w),
        theme,
        field_w,
      ),
      settings_field_row(
        "Sandbox",
        "Filesystem access for tools",
        sandbox_segmented_control(model.sandbox_mode, theme, field_w),
        theme,
        field_w,
      ),
    ],
    spacing=16.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn settings_editor_panel(
  model : SettingsWorkspace,
  appearance : AppearanceMode,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  let field_w = width - 8.0
  @views.column(
    [
      settings_field_row(
        "Appearance",
        "Workbench color scheme",
        appearance_segmented_control(appearance, theme, field_w),
        theme,
        field_w,
      ),
      settings_field_row(
        "Font size",
        "Code surface typography (10–24 pt)",
        font_size_stepper(model.font_size, theme, field_w),
        theme,
        field_w,
      ),
    ],
    spacing=16.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn settings_field_row(
  title : String,
  hint : String,
  control : @moui.View[SettingsMsg],
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  @views.column(
    [
      @views.text(title, role=@views.TextRole::Label, theme~, width~),
      @views.text(hint, role=@views.TextRole::Caption, theme~, width~).foreground(
        theme.palette.muted,
      ),
      control,
    ],
    spacing=6.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn settings_secret_status(
  api_key : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  let text = if api_key.is_empty() {
    "No API key in settings — agent runs in stub mode until you save a key."
  } else {
    "Key configured (" +
    api_key.length().to_string() +
    " characters). Restart may be required for OpenSeek to pick up changes."
  }
  @views.text(text, role=@views.TextRole::Caption, theme~, width~).foreground(
    theme.palette.muted,
  )
}

///|
fn settings_save_row(
  model : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  let notice : Array[@moui.View[SettingsMsg]] = match model.save_notice {
    Some(text) =>
      [
        @views.text(
          text,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 120.0,
        ).foreground(theme.palette.muted),
      ]
    None => []
  }
  let children = notice
  children.push(
    @views.button(
      "Save to .mo_workbench/settings.json",
      on_click=SettingsMsg::SaveToDisk,
      variant=@views.ButtonVariant::Primary,
      theme~,
      width=200.0,
      height=40.0,
    ),
  )
  @views.row(children, spacing=12.0, align=@views.CrossAlign::Center)
}

///|
fn appearance_segmented_control(
  appearance : AppearanceMode,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  @views.segmented_control(
    [
      @views.choice_item("system", "System"),
      @views.choice_item("light", "Light"),
      @views.choice_item("dark", "Dark"),
    ],
    selected=appearance_mode_id(appearance),
    on_select=id => SettingsMsg::AppearanceChanged(appearance_mode_from_id(id)),
    size=@views.SegmentedControlSize::Compact,
    theme~,
    width~,
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
