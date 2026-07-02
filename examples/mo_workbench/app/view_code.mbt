// Code workspace center column: message timeline plus floating composer.

///|
fn code_workspace_view(
  model : CodeWorkspace,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[CodeMsg] {
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

///|
fn code_message_list(
  model : CodeWorkspace,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[CodeMsg] {
  let inner_width = (width - 48.0).max(320.0)
  if model.messages.is_empty() {      @views.container(
      @views.scroll_view(
        code_empty_state(model, theme, inner_width),
        width~,
        height~,
      ),
      width~,
      height~,
      background=workbench_canvas_background(theme),
      padding=28.0,
    )
  } else {
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
}

///|
fn code_empty_state(
  model : CodeWorkspace,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let status = if model.is_streaming {
    "A turn is already running."
  } else {
    "Bind a repo, ask for a plan, review a diff, or run a focused check."
  }
  @views.column(
    [
      @views.spacer(),
      @views.container(
        @views.column(
          [
            @views.icon(
              @views.IconName::Focus,
              size=32.0,
              color=workbench_accent(theme),
            ),
            @views.text(
              "What should the agent do in this project?",
              role=@views.TextRole::Headline,
              theme~,
              width~,
            ),
            @views.text(
              status,
              role=@views.TextRole::Body,
              theme~,
              width~,
            ).foreground(theme.palette.muted),
          ],
          spacing=12.0,
          align=@views.CrossAlign::Center,
        ),
        width~,
      ),
      starter_card_grid(theme, width),
      @views.spacer(),
    ],      spacing=32.0,
      align=@views.CrossAlign::Center,
  )
}

///|
fn starter_card_grid(
  theme : @core.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let card_width = ((width - 16.0) / 2.0).max(180.0)
  @views.column(
    [
      @views.row(
        [
          starter_card(
            "Map the codebase",
            "Summarize architecture and risky seams.",
            "Inspect this repository and summarize its architecture, key packages, and likely risk areas.",
            @views.IconName::Search,
            theme,
            card_width,
          ),
          starter_card(
            "Plan a change",
            "Turn a feature request into steps.",
            "Create a concise implementation plan for the next change in this app.",
            @views.IconName::ListTask,
            theme,
            card_width,
          ),
        ],
        spacing=20.0,
        align=@views.CrossAlign::Start,
      ),
      @views.row(
        [
          starter_card(
            "Review diff",
            "Find regressions before commit.",
            "Review the current uncommitted changes and report only actionable findings.",
            @views.IconName::Clipboard,
            theme,
            card_width,
          ),
          starter_card(
            "Fix a failing check",
            "Use local evidence first.",
            "Run the smallest relevant check, explain the failure, and propose a fix.",
            @views.IconName::Check,
            theme,
            card_width,
          ),
        ],
        spacing=20.0,
        align=@views.CrossAlign::Start,
      ),
    ],
    spacing=20.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn starter_card(
  title : String,
  detail : String,
  prompt : String,
  icon : @views.IconName,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  @views.container(
    @views.column(
      [
        @views.row(
          [
            @views.icon(icon, size=18.0, color=workbench_accent(theme)),
            @views.text(
              title,
              role=@views.TextRole::Label,
              theme~,
              width=width - 58.0,
            ),
          ],
          spacing=8.0,
          align=@views.CrossAlign::Center,
        ),
        @views.text(
          detail,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 24.0,
        ).foreground(theme.palette.muted),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    background=workbench_card_background(theme),
    corner_radius=12.0,
    padding=20.0,
  )
  .border(hairline_border(theme))
  .on_tap(CodeMsg::PromptChanged(prompt))
}

///|
fn code_composer(
  model : CodeWorkspace,
  theme : @core.Theme,
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
  rows.push(
    @views.row(
      [
        @views.chip(
          "Workspace write",
          theme~,
          width=108.0,
          height=26.0,
        ),
        @views.chip(
          "Approval on write",
          theme~,
          width=118.0,
          height=26.0,
        ),
        @views.chip(
          "Stub backend",
          theme~,
          width=96.0,
          height=26.0,
        ),
        @views.spacer(),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
  )
  rows.push(
    @views.row(
      [
        @views.text_area(
          model.prompt,
          on_input=value => CodeMsg::PromptChanged(value),
          placeholder="Ask the agent to plan, edit, test, or review...",
          lines=2,
          variant=@views.TextFieldVariant::Filled,
          theme~,
          width=inner_width - 96.0,
          line_height=28.0,
        ),
        @views.button(
          "Send",
          on_click=CodeMsg::SubmitPrompt,
          variant=@views.ButtonVariant::Primary,
          theme~,
          icon=Some(@views.IconName::ArrowRight),
          width=80.0,
          height=56.0,
        ),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Center,
    ),
  )
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
      padding=20.0,
    ).border(hairline_border(theme)),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=28.0,
  )
}
