///|
fn ShowcaseModel::examples_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
  let columns = if metrics.compact || metrics.body_width < 960.0 {
    1
  } else {
    2
  }
  let preview_width = showcase_grid_card_width(
    metrics.body_width,
    columns,
    theme.spacing_scale.md,
  )
  self.section_panel(
    theme,
    "Examples",
    "Counter and Todo are built into Showcase as reusable app patterns.",
    grid(
      [
        example_preview(
          theme,
          "Counter Preview",
          self.counter_preview(theme),
          width=preview_width,
        ),
        example_preview(
          theme,
          "Todo Preview",
          self.todo_preview(theme),
          width=preview_width,
        ),
      ],
      columns~,
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    metrics~,
  )
}

///|
fn ShowcaseModel::counter_preview(
  self : ShowcaseModel,
  theme : @moui.Theme,
) -> @moui.View[ShowcaseMsg] {
  container(
    column(
      [
        text("MoUI Counter")
        .font(theme.typography.title)
        .foreground(theme.palette.foreground),
        text("Count: \{self.counter_count}")
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        button(
          "Increment",
          on_click=CounterIncrement,
          variant=@views.ButtonVariant::Primary,
          theme~,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Center,
    ),
    variant=@views.ContainerVariant::Base,
    theme~,
  )
}

///|
fn ShowcaseModel::todo_preview(
  self : ShowcaseModel,
  theme : @moui.Theme,
) -> @moui.View[ShowcaseMsg] {
  let children : Array[@moui.View[ShowcaseMsg]] = [
    text("MoUI Todo")
    .font(theme.typography.title)
    .foreground(theme.palette.foreground),
    row(
      [
        text_field(
          self.todo_draft,
          on_input=value => TodoDraftChanged(value),
          on_submit=Some(TodoSubmitDraft),
          placeholder="New todo",
          variant=@views.TextFieldVariant::Filled,
          theme~,
          width=220.0,
        ),
        button(
          "Add",
          on_click=TodoSubmitDraft,
          variant=@views.ButtonVariant::Primary,
          theme~,
          width=120.0,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
  ]
  for item in self.todo_items {
    children.push(self.todo_row(item, theme))
  }
  container(
    column(
      children,
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    ),
    variant=@views.ContainerVariant::Base,
    theme~,
  )
}

///|
fn ShowcaseModel::todo_row(
  self : ShowcaseModel,
  item : ShowcaseTodoItem,
  theme : @moui.Theme,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  row(
    [
      checkbox(
        item.text,
        checked=item.completed,
        on_change=value => TodoToggled(item.id, value),
        check_color=theme.palette.primary,
      ).frame(width=220.0, height=36.0),
      button(
        "Remove",
        on_click=TodoRemove(item.id),
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=120.0,
      ),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  ).key("todo-\{item.id}")
}

///|
