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
  @views.container(
    @views.row(
      [
        settings_section_nav(model.active_section, theme, nav_width, height),
        settings_section_panel(model, appearance, theme, panel_width, height),
      ],
      spacing=gap,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height~,
    padding=0.0,
  )
}

///|
fn settings_section_nav(
  active : SettingsSection,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[SettingsMsg] {
  let panel_padding = 14.0
  let content_width = (width - panel_padding * 2.0).max(96.0)
  @views.container(
    @views.column(
      [
        @views.text(
          "Preferences",
          role=@views.TextRole::Subtitle,
          theme~,
          width=content_width,
        ),
        settings_nav_item(
          "Providers",
          SettingsSection::Api,
          active,
          theme,
          content_width,
        ),
        settings_nav_item(
          "Agent",
          SettingsSection::Agent,
          active,
          theme,
          content_width,
        ),
        settings_nav_item(
          "Editor",
          SettingsSection::Editor,
          active,
          theme,
          content_width,
        ),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height~,
    background=workbench_subtle_background(theme),
    corner_radius=10.0,
    padding=panel_padding,
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
  let panel_padding = 20.0
  let content_width = (width - panel_padding * 2.0).max(220.0)
  let content_height = (height - panel_padding * 2.0).max(120.0)
  let body = match model.active_section {
    SettingsSection::Api =>
      settings_providers_panel(model, theme, content_width)
    SettingsSection::Agent => settings_agent_panel(model, theme, content_width)
    SettingsSection::Editor =>
      settings_editor_panel(model, appearance, theme, content_width)
  }
  @views.container(
    @views.scroll_view(
      @views.column(
        [
          settings_panel_header(model, theme, content_width),
          body,
          settings_save_row(model, theme, content_width),
        ],
        spacing=18.0,
        align=@views.CrossAlign::Stretch,
      ),
      width=content_width,
      height=content_height,
      state=Some(model.scroll_state),
    ),
    width~,
    height~,
    background=workbench_card_background(theme),
    corner_radius=10.0,
    padding=panel_padding,
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
        ". 可配置多个 OpenAI 兼容供应商，每个供应商可自动检测或手动添加模型。",
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
    SettingsSection::Api => "Providers"
    SettingsSection::Agent => "Agent"
    SettingsSection::Editor => "Editor"
  }
}

///|
/// Providers panel: a list of configured LLM providers (OpenAI-compatible),
/// each editable (name / base URL / API key), with `v1/models` auto-detection
/// and manual model add. The active provider drives the chat surface.
fn settings_providers_panel(
  model : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  let field_w = width - 8.0
  let rows : Array[@moui.View[SettingsMsg]] = []
  rows.push(provider_selector_row(model, theme, field_w))
  match model.active_provider() {
    Some(p) => rows.push(provider_edit_form(p, model, theme, field_w))
    None => ()
  }
  if model.detect_busy {
    rows.push(
      @views.text(
        "正在通过 v1/models 检测模型…",
        role=@views.TextRole::Caption,
        theme~,
        width=field_w,
      ).foreground(theme.palette.muted),
    )
  }
  match model.detect_error {
    Some(err) =>
      rows.push(
        @views.text(err, role=@views.TextRole::Caption, theme~, width=field_w).foreground(
          theme.palette.danger,
        ),
      )
    None => ()
  }
  @views.column(rows, spacing=16.0, align=@views.CrossAlign::Stretch)
}

///|
/// A vertical provider list plus an "add" button. The active provider is
/// highlighted; tapping a provider row makes it active.
fn provider_selector_row(
  model : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  let children : Array[@moui.View[SettingsMsg]] = []
  for p in model.providers {
    let selected = model.active_provider_id == Some(p.id)
    children.push(provider_selector_item(p, selected, theme, width))
  }
  children.push(
    @views.button(
      "+ 添加提供商",
      on_click=SettingsMsg::AddProvider,
      variant=@views.ButtonVariant::Ghost,
      theme~,
      width~,
      height=36.0,
    ),
  )
  @views.column(children, spacing=6.0, align=@views.CrossAlign::Stretch)
}

///|
fn provider_selector_item(
  provider : ProviderConfig,
  selected : Bool,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  @views.container(
    @views.text(
      provider.name,
      role=@views.TextRole::Caption,
      theme~,
      width=(width - 16.0).max(48.0),
      height=20.0,
    ).foreground(
      if selected {
        workbench_accent(theme)
      } else {
        workbench_text(theme)
      },
    ),
    width~,
    height=36.0,
    background=if selected {
      workbench_selector_chip_background(theme)
    } else {
      workbench_subtle_background(theme)
    },
    corner_radius=8.0,
    border=if selected { Some(hairline_border(theme)) } else { None },
    padding=8.0,
  ).on_tap(SettingsMsg::SelectProvider(provider.id))
}

///|
/// The edit form for the active provider: name / base URL / API key fields,
/// a `v1/models` auto-detect button, the model list, a manual-add row, and a
/// remove button (hidden when only one provider remains).
fn provider_edit_form(
  p : ProviderConfig,
  model : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[SettingsMsg] {
  let field_w = width - 8.0
  let rows : Array[@moui.View[SettingsMsg]] = []
  rows.push(
    settings_field_row(
      "名称",
      "供应商显示名",
      @views.text_field(
        p.name,
        on_input=value => SettingsMsg::UpdateProviderField(p.id, Name, value),
        on_submit=None,
        placeholder="DeepSeek",
        variant=@views.TextFieldVariant::Filled,
        theme~,
        width=field_w,
        height=40.0,
      ),
      theme,
      field_w,
    ),
  )
  rows.push(
    settings_field_row(
      "Base URL",
      "OpenAI 兼容端点，例如 https://api.deepseek.com/v1",
      @views.text_field(
        p.base_url,
        on_input=value => SettingsMsg::UpdateProviderField(p.id, BaseUrl, value),
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
  )
  rows.push(
    settings_field_row(
      "API Key",
      "仅保存在本地 settings.json",
      @views.text_field(
        p.api_key,
        on_input=value => SettingsMsg::UpdateProviderField(p.id, ApiKey, value),
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
  )
  let detect_btn = @views.button(
    if model.detect_busy {
      "检测中…"
    } else {
      "自动检测模型 (v1/models)"
    },
    on_click=SettingsMsg::DetectModels(p.id),
    variant=@views.ButtonVariant::Primary,
    theme~,
    width=field_w,
    height=40.0,
  ).disabled(disabled=model.detect_busy)
  rows.push(detect_btn)
  rows.push(
    @views.text(
      "模型 (" + p.models.length().to_string() + ")",
      role=@views.TextRole::Label,
      theme~,
      width=field_w,
    ).foreground(workbench_text(theme)),
  )
  for m in p.models {
    let supported = mo_workbench_model_supported_by_openseek(m)
    rows.push(
      @views.container(
        @views.text(
          m,
          role=@views.TextRole::Label,
          theme~,
          width=field_w - 16.0,
          height=22.0,
        ).foreground(
          if supported {
            workbench_text(theme)
          } else {
            theme.palette.muted
          },
        ),
        width=field_w,
        height=38.0,
        background=if supported {
          workbench_subtle_background(theme)
        } else {
          @graphics.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.03)
        },
        corner_radius=6.0,
        padding=8.0,
      ),
    )
  }
  rows.push(
    @views.row(
      [
        @views.text_field(
          model.new_model_id,
          on_input=value => SettingsMsg::NewModelInputChanged(value),
          on_submit=Some(SettingsMsg::AddManualModel(p.id, model.new_model_id)),
          placeholder="手动添加模型 id",
          variant=@views.TextFieldVariant::Filled,
          theme~,
          width=field_w - 92.0,
          height=40.0,
        ),
        @views.button(
          "添加",
          on_click=SettingsMsg::AddManualModel(p.id, model.new_model_id),
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=80.0,
          height=40.0,
        ),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Center,
    ),
  )
  if model.providers.length() > 1 {
    rows.push(
      @views.button(
        "移除该供应商",
        on_click=SettingsMsg::RemoveProvider(p.id),
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=field_w,
        height=40.0,
      ),
    )
  }
  @views.column(rows, spacing=12.0, align=@views.CrossAlign::Stretch)
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
