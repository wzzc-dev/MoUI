// the streaming message timeline + composer (chat mode).

///|
/// The code workspace view. When there are no messages and no streaming turn,
// quick cards). Otherwise render the streaming timeline + composer.
fn code_workspace_view(
  model : CodeWorkspace,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[CodeMsg] {
  if model.messages.is_empty() && !model.is_streaming {
    code_welcome_view(model, theme, width, height)
  } else {
    let composer_height = if model.is_streaming { 194.0 } else { 148.0 }
    let list_height = (height - composer_height).max(220.0)
    @views.container(
      @views.column(
        [
          code_message_list(model, theme, width, list_height),
          code_composer(model, theme, width, composer_height),
        ],
        spacing=0.0,
        align=@views.CrossAlign::Stretch,
      ),
      width~,
      height~,
      background=workbench_canvas_background(theme),
      padding=0.0,
    )
  }
}

///|
/// Brand title + input card (with model dropdown + toolbar + round purple Send)
/// + context bar with icons + bottom quick-action chips. The whole block
/// scrolls so it fits narrow windows.
fn code_welcome_view(
  model : CodeWorkspace,
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
      code_input_card(model, theme, inner_width),
      @views.spacer(min_length=10.0, weight=0.0),
      code_context_bar(theme, inner_width),
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
/// The input card: a multi-line text area for the prompt + a tool row with
/// left-side (attachment / image / 速通) and right-side (model selector /
/// mic / send) buttons. Uses a shadow-like border for emphasis.
fn code_input_card(
  model : CodeWorkspace,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  @views.container(
    @views.column(
      [
        // Prompt text area – the main interactive zone.
        @views.text_area(
          model.prompt,
          on_input=value => CodeMsg::PromptChanged(value),
          placeholder="帮你编写代码、调试 Bug、优化性能等开发工作…",
          lines=4,
          variant=@views.TextFieldVariant::Filled,
          theme~,
          width~,
          line_height=28.0,
        ),
        @views.spacer(min_length=12.0),
        // Toolbar: left tools + spacer + right controls.
        @views.row(
          [
            // Left side: attachment, image.
            @views.container(
              @views.icon(
                @views.IconName::Link,
                size=18.0,
                color=workbench_text_muted(theme),
              ),
              width=32.0,
              height=32.0,
              padding=0.0,
            ),
            @views.spacer(),
            // Right side: model dropdown, mic, send.
            code_model_dropdown(model, theme),
            @views.container(
              @views.icon(
                @views.IconName::Info,
                size=18.0,
                color=workbench_text_muted(theme),
              ),
              width=32.0,
              height=32.0,
              padding=0.0,
            ),
            workbench_send_button(theme, on_tap=CodeMsg::SubmitPrompt),
          ],
          spacing=8.0,
          align=@views.CrossAlign::Center,
        ),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    background=workbench_card_background(theme),
    corner_radius=14.0,
    border=Some(hairline_border(theme)),
    padding=0.0,
  )
}

///|
/// Model selector as a dropdown-style chip showing the current model + an arrow,
fn code_model_dropdown(
  code : CodeWorkspace,
  theme : @moui.Theme,
) -> @moui.View[CodeMsg] {
  let label = model_choice_label(code.current_model)
  @views.container(
    @views.row(
      [
        @views.text(
          label,
          role=@views.TextRole::Caption,
          theme~,
          width=72.0,
          height=20.0,
        ).foreground(workbench_accent(theme)),
        @views.icon(
          @views.IconName::ChevronDown,
          size=12.0,
          color=workbench_accent(theme),
        ),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Center,
    ),
    width=100.0,
    height=32.0,
    background=workbench_accent_soft(theme),
    corner_radius=6.0,
    padding=6.0,
  ).on_tap(
    CodeMsg::ModelChanged(
      match code.current_model {
        V4Pro => ModelChoice::V4Flash
        V4Flash => ModelChoice::V4Pro
      },
    ),
  )
}

///|
/// Context bar: chips with icons showing the active context roots
/// (local / MoUI / main). Styled with icons + dropdown arrows + a git branch
/// indicator.
fn code_context_bar(theme : @moui.Theme, width : Double) -> @moui.View[CodeMsg] {
  @views.row(
    [
      // "本地" with computer icon.
      @views.container(
        @views.row(
          [
            @views.icon(
              @views.IconName::Sidebar,
              size=14.0,
              color=workbench_text_muted(theme),
            ),
            @views.text(
              "本地",
              role=@views.TextRole::Caption,
              theme~,
              width=36.0,
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
        width=80.0,
        height=28.0,
        background=workbench_subtle_background(theme),
        corner_radius=6.0,
        padding=6.0,
      ),
      // "MoUI" with folder icon.
      @views.container(
        @views.row(
          [
            @views.icon(
              @views.IconName::FolderOpen,
              size=14.0,
              color=workbench_text_muted(theme),
            ),
            @views.text(
              "MoUI",
              role=@views.TextRole::Caption,
              theme~,
              width=44.0,
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
        width=84.0,
        height=28.0,
        background=workbench_subtle_background(theme),
        corner_radius=6.0,
        padding=6.0,
      ),
      // "main" with git branch icon.
      @views.container(
        @views.row(
          [
            @views.icon(
              @views.IconName::CodeInline,
              size=14.0,
              color=workbench_text_muted(theme),
            ),
            @views.text(
              "main",
              role=@views.TextRole::Caption,
              theme~,
              width=36.0,
            ).foreground(workbench_text(theme)),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Center,
        ),
        width=72.0,
        height=28.0,
        background=workbench_subtle_background(theme),
        corner_radius=6.0,
        padding=6.0,
      ),
      @views.spacer(),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Start,
  ).frame(width~)
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
  height : Double,
) -> @moui.View[CodeMsg] {
  let inner_width = (width - 48.0).max(320.0)
  let rows : Array[@moui.View[CodeMsg]] = []
  for msg in model.messages {
    rows.push(message_row(msg, theme, inner_width))
  }
  @views.container(
    @views.scroll_view(
      @views.list(rows, spacing=12.0),
      state=Some(model.scroll_state),
      width~,
      height~,
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=28.0,
  )
}

///|
/// The chat-mode composer: prompt input + Send, plus a steer field while a
/// turn is streaming. The tool row carries the model selector so the active
/// model is always adjustable.
fn code_composer(
  model : CodeWorkspace,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[CodeMsg] {
  let inner_width = (width - 48.0).max(320.0)
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
  // Tool row: model selector (dropdown style) + spacer.
  rows.push(
    @views.row(
      [code_model_dropdown(model, theme), @views.spacer()],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
  )
  // Prompt input + Send.
  rows.push(
    @views.row(
      [
        @views.text_area(
          model.prompt,
          on_input=value => CodeMsg::PromptChanged(value),
          placeholder="继续描述你的任务…",
          lines=2,
          variant=@views.TextFieldVariant::Filled,
          theme~,
          width=inner_width - 64.0,
          line_height=28.0,
        ),
        workbench_send_button(
          theme,
          diameter=40.0,
          on_tap=CodeMsg::SubmitPrompt,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
  )
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
  @views.container(
    @views.container(
      @views.column(rows, spacing=14.0, align=@views.CrossAlign::Stretch),
      width=inner_width,
      background=workbench_card_background(theme),
      corner_radius=12.0,
      border=Some(hairline_border(theme)),
      padding=20.0,
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=28.0,
  )
}

// ---------------------------------------------------------------------------
// Deprecated starter_card_grid / starter_card (replaced by quick_action_chips).
// These can be removed once all callers are migrated.
// ---------------------------------------------------------------------------
