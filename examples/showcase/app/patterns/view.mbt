///|
/// Hosted body for the unified Showcase shell (no local chrome).
pub fn view_body(
  model : Model,
  env : @moui.ViewEnvironment,
  width? : Double = 0.0,
) -> @moui.View[Msg] {
  let theme = @views.light_theme()
  let page_width = if width > 0.0 {
    width
  } else {
    env.viewport_size().width.max(320.0)
  }
  let inner = page_width.max(240.0)
  match model.route {
    "counter" => counter_pattern(model, theme)
    "todo" => todo_pattern(model, theme, inner)
    "forms" => form_pattern(model, theme, inner)
    "data" => data_pattern(model, theme, inner)
    "navigation" => navigation_pattern(model, theme, inner)
    "workflow" => workflow_pattern(model, theme, inner)
    "text-media" => text_media_pattern(theme, inner)
    _ => welcome_pattern(theme, inner)
  }
}

///|
pub fn view(model : Model, env : @moui.ViewEnvironment) -> @moui.View[Msg] {
  let theme = @views.light_theme()
  let width = env.viewport_size().width.max(320.0)
  let height = env.viewport_size().height.max(320.0)
  @views.container(
    @views.scroll_view(
      view_body(model, env, width=width),
      width~,
      height=(height - 32.0).max(288.0),
      state=Some(model.scroll),
    ),
    width~,
    height~,
    padding=16.0,
    background=theme.palette.background,
    theme~,
  )
}

///|
fn welcome_pattern(theme : @moui.Theme, width : Double) -> @moui.View[Msg] {
  let card_width = (width - 8.0).max(220.0)
  @views.column(
    [
      @views.text(
        "Patterns",
        role=@views.TextRole::Headline,
        theme~,
        width=card_width,
      ),
      @views.text(
        "These pages are small, complete app features — not single-widget demos. Open one from the left rail under Patterns, or jump below.",
        role=@views.TextRole::Body,
        theme~,
        width=card_width,
      ),
      @views.callout(
        "How to use this section",
        "Copy a pattern package as a whole: model + messages + update + view. The Showcase shell only routes into the package.",
        tone=@views.FeedbackTone::Info,
        width=card_width,
        theme~,
      ),
      @views.text(
        "Jump to a pattern",
        role=@views.TextRole::Subtitle,
        theme~,
        width=card_width,
      ),
      @views.column(
        [
          pattern_jump_row(
            "Counter",
            "Tiny TEA loop with increment / decrement.",
            "counter",
            theme,
            card_width,
          ),
          pattern_jump_row(
            "Todo",
            "Draft field, list toggle, and remove.",
            "todo",
            theme,
            card_width,
          ),
          pattern_jump_row(
            "Forms",
            "Profile fields with simple validation.",
            "forms",
            theme,
            card_width,
          ),
          pattern_jump_row(
            "Data",
            "Filter a small in-memory collection.",
            "data",
            theme,
            card_width,
          ),
          pattern_jump_row(
            "Navigation",
            "Feature-owned routes inside one workspace.",
            "navigation",
            theme,
            card_width,
          ),
          pattern_jump_row(
            "Workflow",
            "Multi-step progress with back / next.",
            "workflow",
            theme,
            card_width,
          ),
          pattern_jump_row(
            "Text & Media",
            "Markdown-style content via app-safe views.",
            "text-media",
            theme,
            card_width,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Stretch,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn pattern_jump_row(
  title : String,
  summary : String,
  route : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  @views.card(
    @views.column(
      [
        @views.row(
          [
            @views.text(title, role=@views.TextRole::Subtitle, theme~),
            @views.spacer(weight=1.0),
            @views.button(
              "Open",
              on_click=Navigate(route),
              variant=@views.ButtonVariant::Outline,
              theme~,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
        @views.text(summary, role=@views.TextRole::Caption, theme~, width~),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    padding=12.0,
    theme~,
  )
}

///|
fn counter_pattern(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  @views.column(
    [
      @views.text("Counter: \{model.counter}", role=@views.TextRole::Headline, theme~),
      @views.row([
        @views.button("-", on_click=Decrement, variant=@views.ButtonVariant::Outline, theme~),
        @views.button("+", on_click=Increment, theme~),
      ], spacing=theme.spacing_scale.sm),
    ],
    spacing=theme.spacing_scale.md,
  )
}

///|
fn todo_pattern(
  model : Model,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = [
    @views.text("Todo", role=@views.TextRole::Headline, theme~),
    @views.row(
      [
        @views.text_field(
          model.todo_draft,
          on_input=value => TodoDraftChanged(value),
          on_submit=Some(TodoSubmit),
          placeholder="Add a task",
          width=(width - 110.0).max(160.0),
          theme~,
        ),
        @views.button("Add", on_click=TodoSubmit, theme~),
      ],
      spacing=theme.spacing_scale.sm,
    ),
  ]
  for item in model.todo_items {
    rows.push(
      @views.row(
        [
          @views.checkbox(
            item.label,
            checked=item.completed,
            on_change=value => TodoToggled(item.id, value),
            theme~,
          ),
          @views.button("Remove", on_click=TodoRemoved(item.id), variant=@views.ButtonVariant::Ghost, theme~),
        ],
        spacing=theme.spacing_scale.sm,
      ),
    )
  }
  @views.column(rows, spacing=theme.spacing_scale.sm, align=@views.CrossAlign::Stretch)
}

///|
fn form_pattern(
  model : Model,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  let valid = model.profile_name.length() >= 2
  @views.column(
    [
      @views.text("Profile form", role=@views.TextRole::Headline, theme~),
      @views.text_field(
        model.profile_name,
        on_input=value => ProfileNameChanged(value),
        placeholder="Display name",
        width~,
        theme~,
      ),
      @views.text(if valid { "Ready to save" } else { "Display name must be at least 2 characters" }),
      @views.button("Save profile", on_click=SaveProfile, theme~),
      if model.notice == "" {
        @views.text("")
      } else {
        @views.banner("Saved", model.notice, tone=@views.FeedbackTone::Success, width~, theme~)
      },
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn data_pattern(
  model : Model,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  let records = ["Project Atlas", "Design System", "Mobile Runtime", "Web Presentation"]
  let visible = records.filter(record => model.data_filter == "" || record.contains(model.data_filter))
  @views.column(
    [
      @views.text("Data collection", role=@views.TextRole::Headline, theme~),
      @views.text_field(
        model.data_filter,
        on_input=value => DataFilterChanged(value),
        placeholder="Filter records",
        width~,
        theme~,
      ),
      @views.stat_card("Visible rows", visible.length().to_string(), caption="State-derived filtering", width~, theme~),
      @views.column(visible.map(record => @views.text(record)), spacing=theme.spacing_scale.xs),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn navigation_pattern(
  model : Model,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  @views.column(
    [
      @views.text("Feature-owned navigation", role=@views.TextRole::Headline, theme~),
      @views.callout(
        "Current child route",
        "patterns/\{model.route}",
        tone=@views.FeedbackTone::Info,
        width~,
        theme~,
      ),
      @views.text("The root router selects a workspace; this package owns navigation inside the workspace."),
    ],
    spacing=theme.spacing_scale.sm,
  )
}

///|
fn workflow_pattern(
  model : Model,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  let labels = ["Profile", "Permissions", "Review"]
  @views.column(
    [
      @views.text("Workflow", role=@views.TextRole::Headline, theme~),
      @views.progress_status(
        labels[model.workflow_step],
        value=(model.workflow_step + 1).to_double() / 3.0,
        message="Step \{model.workflow_step + 1} of 3",
        status="in progress",
        tone=@views.FeedbackTone::Info,
        width~,
        theme~,
      ),
      @views.row([
        @views.button("Back", on_click=WorkflowBack, variant=@views.ButtonVariant::Outline, theme~),
        @views.button("Next", on_click=WorkflowNext, theme~),
      ], spacing=theme.spacing_scale.sm),
    ],
    spacing=theme.spacing_scale.md,
  )
}

///|
fn text_media_pattern(theme : @moui.Theme, width : Double) -> @moui.View[Msg] {
  @views.column(
    [
      @views.text("Text & Media", role=@views.TextRole::Headline, theme~),
      @views.text("# Local Markdown\n\nA **bold** word and an image belong behind app-safe view APIs."),
      @views.callout(
        "Addon boundary",
        "Rich text can be added by this package without changing the root app or platform entrypoints.",
        width~,
        theme~,
      ),
    ],
    spacing=theme.spacing_scale.md,
  )
}
