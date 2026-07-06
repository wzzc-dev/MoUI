// the streaming message timeline + composer (chat mode).

///|
/// The code workspace view. When there are no messages and no streaming turn,
// quick cards). Otherwise render the streaming timeline + composer.
fn code_workspace_view(
  model : CodeWorkspace,
  settings : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[CodeMsg] {
  if model.messages.is_empty() && !model.is_streaming {
    code_welcome_view(model, settings, theme, width, height)
  } else {
    code_chat_pane_view(model, settings, theme, width, height)
  }
}

///|
/// Chat pane: messages fill the area above a bottom-pinned composer.
fn code_chat_pane_view(
  model : CodeWorkspace,
  settings : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[CodeMsg] {
  let list = code_message_list(model, theme, width)
  let composer = code_composer(model, settings, theme, width)
  @views.container(
    @views.custom_children_layout(
      children=[list, composer],
      measure=ctx => {
        ctx.constraints.constrain(@geometry.Size::new(width~, height~))
      },
      place=ctx => {
        let composer_h = ctx.child_sizes[1].height
        let list_h = (ctx.frame.size.height - composer_h).max(0.0)
        let w = ctx.frame.size.width
        [
          @geometry.Rect::new(x=0.0, y=0.0, width=w, height=list_h),
          @geometry.Rect::new(x=0.0, y=list_h, width=w, height=composer_h),
        ]
      },
      paint=(_ctx, _frame) => (),
      semantics_label="Code chat pane",
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=0.0,
  )
}

///|
/// Brand title + input card, context bar with icons, and bottom quick-action
/// chips. The whole block scrolls so it fits narrow windows.
fn code_welcome_view(
  model : CodeWorkspace,
  settings : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[CodeMsg] {
  let inner_width = (width - 96.0).max(320.0)
  let welcome_block = @views.column(
    [
      @views.text(
        "Code with Mo",
        role=@views.TextRole::Headline,
        theme~,
        width=inner_width,
      ).foreground(workbench_accent(theme)),
      @views.spacer(min_length=30.0, weight=0.0),
      code_input_card(model, settings, theme, inner_width),
      @views.spacer(min_length=10.0, weight=0.0),
      code_context_bar(settings, theme, inner_width),
      @views.spacer(min_length=50.0, weight=0.0),
      @views.container(
        quick_action_chips(theme, inner_width),
        width=inner_width,
        padding=0.0,
      ),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  )
  let welcome_area_height = (height - 96.0).max(0.0)
  @views.container(
    @views.center(welcome_block, width~, height=welcome_area_height, theme~),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=48.0,
  )
}

///|
/// The input card: a multi-line text area for the prompt and a compact tool
/// row with model and thinking pickers directly before Send.
fn code_input_card(
  model : CodeWorkspace,
  settings : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let text_area_theme = code_input_text_area_theme(theme)
  let rows : Array[@moui.View[CodeMsg]] = []
  // Prompt text area – the main interactive zone.
  rows.push(
    @views.text_area(
      model.prompt,
      on_input=value => CodeMsg::PromptChanged(value),
      on_submit=Some(CodeMsg::SubmitPrompt),
      placeholder="帮你编写代码、调试 Bug、优化性能等开发工作…",
      lines=4,
      variant=@views.TextFieldVariant::Filled,
      theme=text_area_theme,
      width~,
      line_height=28.0,
    ),
  )
  rows.push(
    @views.row(
      [
        @views.container(
          @views.icon(
            @views.IconName::Link,
            size=18.0,
            color=workbench_text_muted(theme),
          ),
          width=20.0,
          height=20.0,
          padding=0.0,
        ),
        @views.spacer(),
        code_model_picker(
          model,
          theme,
          code_model_picker_width(model, max_width=(width - 150.0).max(120.0)),
        ),
        code_thinking_picker(model, theme, 58.0),
        workbench_send_button(theme, on_tap=CodeMsg::SubmitPrompt),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
  )
  if model.model_picker_open {
    rows.push(code_model_dropdown_panel(model, settings, theme, width))
  }
  @views.container(
    @views.column(rows, spacing=1.0, align=@views.CrossAlign::Stretch),
    width~,
    background=workbench_card_background(theme),
    corner_radius=14.0,
    border=Some(hairline_border(theme)),
    padding=1.0,
  )
}

///|
fn code_input_text_area_theme(theme : @moui.Theme) -> @moui.Theme {
  let radius_scale = { ..theme.radius_scale, md: 14.0 }
  theme.with_radius_scale(radius_scale)
}

///|
/// Compact model chip. Tapping toggles the inline model picker; the expanded
/// panel is rendered by the caller (`code_input_card` / `code_composer`) so it
/// can drop down over the surrounding surface.
fn code_model_picker(
  code : CodeWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  code_compact_select_chip(code.current_model, theme, width).on_tap(
    CodeMsg::ToggleModelPicker,
  )
}

///|
fn code_model_picker_width(
  code : CodeWorkspace,
  max_width? : Double = 320.0,
) -> Double {
  let text_width = code.current_model.to_array().length().to_double() * 8.0 +
    28.0
  text_width.max(82.0).min(max_width)
}

///|
/// The inline-expanding model panel: a provider switcher plus the active
/// provider's model list. Selecting a model or provider dispatches the
/// matching `CodeMsg`; the shell resolves the backend connection.
fn code_model_dropdown_panel(
  code : CodeWorkspace,
  settings : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let panel_width = width.max(240.0)
  let rows : Array[@moui.View[CodeMsg]] = []
  rows.push(provider_switcher_row(settings, theme, panel_width))
  rows.push(
    @views.container(
      @views.text(
        "模型",
        role=@views.TextRole::Caption,
        theme~,
        width=panel_width,
      ).foreground(theme.palette.muted),
      width=panel_width,
      height=18.0,
    ),
  )
  match settings.active_provider() {
    Some(p) =>
      if p.models.is_empty() {
        rows.push(
          @views.text(
            "该供应商暂无模型。可在设置中自动检测或手动添加。",
            role=@views.TextRole::Caption,
            theme~,
            width=panel_width,
          ).foreground(theme.palette.muted),
        )
      } else {
        for m in p.models {
          let selected = code.current_model == m &&
            code.current_provider_id == Some(p.id)
          rows.push(model_option_row(p.id, m, selected, theme, panel_width))
        }
      }
    None => ()
  }
  let list_h = (rows.length().to_double() * 44.0 + 16.0).min(300.0)
  @views.container(
    @views.scroll_view(
      @views.column(rows, spacing=4.0, align=@views.CrossAlign::Stretch),
      width=panel_width,
      height=list_h,
    ),
    width=panel_width,
    background=workbench_card_background(theme),
    corner_radius=12.0,
    border=Some(hairline_border(theme)),
    padding=8.0,
  )
}

///|
/// Horizontal provider chips; the active provider is highlighted. Tapping
/// switches the chat's active provider.
fn provider_switcher_row(
  settings : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let count = settings.providers.length().to_double().max(1.0)
  let gap = 6.0
  let chip_w = ((width - gap * (count - 1.0)) / count).max(64.0)
  let chips : Array[@moui.View[CodeMsg]] = []
  for p in settings.providers {
    let selected = settings.active_provider_id == Some(p.id)
    let chip = @views.container(
      @views.center(
        @views.text(
          p.name,
          role=@views.TextRole::Caption,
          theme~,
          width=(chip_w - 12.0).max(40.0),
          height=18.0,
        ).foreground(
          if selected {
            workbench_accent(theme)
          } else {
            workbench_text(theme)
          },
        ),
        width=chip_w,
        height=22.0,
        theme~,
      ),
      width=chip_w,
      height=32.0,
      background=if selected {
        workbench_selector_chip_background(theme)
      } else {
        workbench_subtle_background(theme)
      },
      corner_radius=14.0,
      border=if selected { Some(hairline_border(theme)) } else { None },
      padding=4.0,
    ).on_tap(CodeMsg::SelectProvider(p.id))
    chips.push(chip)
  }
  @views.row(chips, spacing=6.0, align=@views.CrossAlign::Center)
}

///|
/// A single model row. OpenSeek-supported models are selectable; custom ids
/// stay visible but muted until the native backend can parse them.
fn model_option_row(
  provider_id : String,
  model_id : String,
  selected : Bool,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let supported = mo_workbench_model_supported_by_openseek(model_id)
  let trailing : @moui.View[CodeMsg] = if selected {
    @views.icon(
      @views.IconName::Check,
      size=16.0,
      color=workbench_accent(theme),
    )
  } else if !supported {
    @views.text(
      "待支持",
      role=@views.TextRole::Caption,
      theme~,
      width=44.0,
      height=16.0,
    ).foreground(theme.palette.muted)
  } else {
    @views.container(
      @views.text("", role=@views.TextRole::Caption, theme~, width=16.0),
      width=16.0,
      height=16.0,
    )
  }
  let label_width = if supported { width - 36.0 } else { width - 64.0 }
  let row = @views.container(
    @views.row(
      [
        @views.text(
          model_id,
          role=@views.TextRole::Label,
          theme~,
          width=label_width.max(80.0),
          height=22.0,
        ).foreground(
          if supported { workbench_text(theme) } else { theme.palette.muted },
        ),
        trailing,
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=40.0,
    background=if selected {
      workbench_selector_chip_background(theme)
    } else if !supported {
      workbench_subtle_background(theme)
    } else {
      @graphics.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
    },
    corner_radius=8.0,
    padding=8.0,
  )
  if supported {
    row.on_tap(CodeMsg::ModelChanged(provider_id, model_id))
  } else {
    row
  }
}

///|
fn code_thinking_picker(
  code : CodeWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let label = match code.current_thinking {
    Normal => "Normal"
    High => "High"
    Max => "Max"
  }
  code_compact_select_chip(label, theme, width).on_tap(
    CodeMsg::ThinkingChanged(next_thinking_choice(code.current_thinking)),
  )
}

///|
fn code_compact_select_chip(
  label : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  @views.container(
    @views.center(
      @views.text(
        label,
        role=@views.TextRole::Caption,
        theme~,
        width=(width - 12.0).max(32.0),
        height=18.0,
      ).foreground(workbench_accent(theme)),
      width=(width - 12.0).max(32.0),
      height=22.0,
      theme~,
    ),
    width~,
    height=32.0,
    background=workbench_subtle_background(theme),
    corner_radius=14.0,
    padding=4.0,
  )
}

///|
/// Context bar: the active local workspace folder selector.
fn code_context_bar(
  settings : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let label = workspace_folder_label(settings.working_dir)
  let chip_width = workspace_folder_chip_width(label, max_width=width)
  @views.row(
    [
      @views.container(
        @views.row(
          [
            @views.icon(
              @views.IconName::FolderOpen,
              size=14.0,
              color=workbench_text_muted(theme),
            ),
            @views.text(
              label,
              role=@views.TextRole::Caption,
              theme~,
              width=(chip_width - 52.0).max(60.0),
            ).foreground(workbench_text(theme)),
            @views.icon(
              @views.IconName::ChevronDown,
              size=10.0,
              color=workbench_text_muted(theme),
            ),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Center,
        ),
        width=chip_width,
        height=28.0,
        background=workbench_subtle_background(theme),
        corner_radius=6.0,
        padding=6.0,
      ).on_tap(CodeMsg::PickWorkspaceFolder),
      @views.spacer(),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Start,
  ).frame(width~)
}

///|
fn workspace_folder_label(path : String) -> String {
  let trimmed = path.trim().to_owned()
  if trimmed.is_empty() || trimmed == "." {
    "选择文件夹"
  } else {
    workspace_folder_basename(trimmed)
  }
}

///|
fn workspace_folder_basename(path : String) -> String {
  let chars = path.to_array()
  let mut end = chars.length()
  while end > 0 && (chars[end - 1] == '/' || chars[end - 1] == '\\') {
    end = end - 1
  }
  if end <= 0 {
    path
  } else {
    let mut last_slash : Int = -1
    for index in 0..<end {
      if chars[index] == '/' || chars[index] == '\\' {
        last_slash = index
      }
    }
    let label = String::from_array(chars[last_slash + 1:end])
    if label.is_empty() {
      path
    } else {
      label
    }
  }
}

///|
fn workspace_folder_chip_width(
  label : String,
  max_width? : Double = 320.0,
) -> Double {
  let text_width = label.to_array().length().to_double() * 8.0 + 52.0
  text_width.max(118.0).min(max_width)
}

///|
/// Bottom quick-action chips: four rounded rect capsules with icons.
/// 应用开发 / 项目理解 / 游戏创意 / 工具脚本. Tapping fills the prompt with
/// a preset.
fn quick_action_chips(
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let chip_width = (width - 24.0) / 4.0
  @views.row(
    [
      quick_chip(
        "应用开发",
        @views.IconName::ListTask,
        "帮我开发一个应用",
        theme,
        chip_width,
      ),
      quick_chip(
        "项目理解",
        @views.IconName::Search,
        "帮我理解这个项目的结构",
        theme,
        chip_width,
      ),
      quick_chip(
        "游戏创意",
        @views.IconName::Focus,
        "帮我设计一个游戏创意",
        theme,
        chip_width,
      ),
      quick_chip(
        "工具脚本",
        @views.IconName::Settings,
        "帮我写一个工具脚本",
        theme,
        chip_width,
      ),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  )
}

///|
/// A single quick-action chip: icon + label in a rounded rect with border.
fn quick_chip(
  label : String,
  icon : @views.IconName,
  prompt : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let text_width = (width - 38.0).max(40.0)
  @views.container(
    @views.row(
      [
        @views.icon(icon, size=14.0, color=workbench_accent(theme)),
        @views.text(
          label,
          role=@views.TextRole::Caption,
          theme~,
          width=text_width,
          height=20.0,
        ).foreground(workbench_accent(theme)),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=40.0,
    background=workbench_accent_soft(theme),
    corner_radius=18.0,
    border=Some(hairline_border(theme)),
    padding=8.0,
  ).on_tap(CodeMsg::PromptChanged(prompt))
}

///|
/// Streaming message timeline (chat mode). Renders each message via
/// `message_row` inside a scroll view bound to the workspace scroll state.
fn code_message_list(
  model : CodeWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let inner_width = (width - 56.0).max(320.0)
  let rows : Array[@moui.View[CodeMsg]] = []
  for msg in model.messages {
    rows.push(message_row(msg, theme, inner_width))
  }
  if model.is_streaming {
    rows.push(code_activity_row(model, theme, inner_width))
  }
  @views.padding(
    @views.scroll_view(
      @views.list(rows, spacing=12.0),
      state=Some(model.scroll_state),
      width=inner_width,
    ),
    28.0,
  )
}

///|
fn code_activity_text(model : CodeWorkspace) -> String {
  match model.progress_notice {
    Some(text) => if text.is_empty() { "Working..." } else { text }
    None => "Working..."
  }
}

///|
fn code_activity_row(
  model : CodeWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let card_width = (width * 0.62).max(260.0).min(width)
  @views.container(
    @views.row(
      [
        @views.container(
          @views.icon(
            @views.IconName::Info,
            size=13.0,
            color=workbench_accent(theme),
          ),
          width=22.0,
          height=22.0,
          background=workbench_accent_soft(theme),
          corner_radius=11.0,
          padding=0.0,
        ),
        @views.text(
          truncate_text(code_activity_text(model), 54),
          role=@views.TextRole::Caption,
          theme~,
          width=card_width - 38.0,
          height=22.0,
        ).foreground(workbench_text_muted(theme)),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width=card_width,
    background=workbench_subtle_background(theme),
    corner_radius=12.0,
    border=Some(hairline_border(theme)),
    padding=10.0,
  )
}

///|
/// The chat-mode composer: prompt input + model/thinking pickers + Send, plus
/// a steer field while a turn is streaming.
fn code_composer(
  model : CodeWorkspace,
  settings : SettingsWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let inner_width = (width - 56.0).max(320.0)
  let thinking_width = 58.0
  let send_diameter = 32.0
  let model_width = code_model_picker_width(
    model,
    max_width=(inner_width - thinking_width - send_diameter - 42.0).max(120.0),
  )
  let rows : Array[@moui.View[CodeMsg]] = []
  match model.error {
    Some(err) =>
      rows.push(
        @views.text(
          err,
          role=@views.TextRole::Caption,
          theme~,
          width=inner_width,
        ).foreground(theme.palette.danger),
      )
    None => ()
  }
  // Prompt input above a compact tool row.
  rows.push(
    @views.text_field(
      model.prompt,
      on_input=value => CodeMsg::PromptChanged(value),
      on_submit=Some(CodeMsg::SubmitPrompt),
      placeholder=if model.is_streaming {
        "Agent 正在运行；请使用下方 Steer 调整方向"
      } else {
        "继续描述你的任务…"
      },
      variant=@views.TextFieldVariant::Filled,
      theme~,
      width=inner_width,
      height=44.0,
    ).disabled(disabled=model.is_streaming),
  )
  rows.push(
    @views.row(
      [
        code_model_picker(model, theme, model_width),
        code_thinking_picker(model, theme, thinking_width),
        @views.spacer(),
        workbench_send_button(
          theme,
          diameter=send_diameter,
          on_tap=CodeMsg::SubmitPrompt,
        ).disabled(disabled=model.is_streaming),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
  )
  if model.model_picker_open {
    rows.push(code_model_dropdown_panel(model, settings, theme, inner_width))
  }
  // Steer field while streaming.
  if model.is_streaming {
    rows.push(
      @views.row(
        [
          @views.text_field(
            model.steer_text,
            on_input=value => CodeMsg::SteerChanged(value),
            on_submit=Some(CodeMsg::SubmitSteer),
            placeholder="Steer the running turn...",
            variant=@views.TextFieldVariant::Filled,
            theme~,
            width=inner_width - 96.0,
            height=34.0,
          ),
          @views.button(
            "Steer",
            on_click=CodeMsg::SubmitSteer,
            variant=@views.ButtonVariant::Ghost,
            theme~,
            width=80.0,
            height=34.0,
          ),
        ],
        spacing=10.0,
        align=@views.CrossAlign::Center,
      ),
    )
  }
  @views.padding(
    @views.column(rows, spacing=10.0, align=@views.CrossAlign::Stretch),
    28.0,
  )
}

// ---------------------------------------------------------------------------
// Deprecated starter_card_grid / starter_card (replaced by quick_action_chips).
// These can be removed once all callers are migrated.
// ---------------------------------------------------------------------------
