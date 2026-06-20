///|
pub fn[Msg] column_visibility_panel(
  columns : Array[TableColumn],
  visible~ : Array[String],
  on_toggle~ : (String, Bool) -> Msg,
  locked? : Array[String] = [],
  title? : String = "Column visibility",
  summary? : String = "",
  theme? : @core.Theme,
  width? : Double = 360.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let inner_width = views_max_double(
    120.0,
    width - resolved_theme.spacing_scale.md * 2.0,
  )
  let visible_count = column_visibility_count(columns, visible)
  let summary_label = if summary == "" {
    column_visibility_summary(visible_count, columns.length())
  } else {
    summary
  }
  let rows : Array[@core.View[Msg]] = [
    text(
      title,
      role=TextRole::Control,
      theme=resolved_theme,
      width=inner_width,
      height=26.0,
    ),
    text(
      summary_label,
      role=TextRole::Caption,
      theme=resolved_theme,
      width=inner_width,
      height=22.0,
    ).foreground(resolved_theme.palette.muted),
  ]
  if columns.length() == 0 {
    rows.push(
      text(
        "No columns",
        role=TextRole::Caption,
        theme=resolved_theme,
        width=inner_width,
        height=28.0,
      ),
    )
  } else {
    for column in columns {
      rows.push(
        column_visibility_row(
          column,
          visible=string_array_contains(visible, column.id),
          locked=string_array_contains(locked, column.id),
          on_toggle~,
          theme=resolved_theme,
          width=inner_width,
        ),
      )
    }
  }
  container(
    column(
      rows,
      spacing=resolved_theme.spacing_scale.xs,
      align=CrossAlign::Start,
    ),
    width~,
    height=column_visibility_panel_height(columns.length()),
    variant=ContainerVariant::Base,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.md,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_description(summary_label)
  .accessibility_label("Column visibility")
}

///|
fn[Msg] column_visibility_row(
  column : TableColumn,
  visible~ : Bool,
  locked~ : Bool,
  on_toggle~ : (String, Bool) -> Msg,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[Msg] {
  let status = if visible { "Shown" } else { "Hidden" }
  let label_width = views_max_double(92.0, width - 84.0)
  row(
    [
      checkbox(
        column.label,
        checked=visible,
        on_change=value => on_toggle(column.id, value),
        font=theme.typography.control,
        foreground=if locked {
          theme.palette.muted
        } else {
          theme.palette.foreground
        },
        check_color=theme.palette.primary,
      )
      .frame(width=label_width, height=32.0)
      .disabled(disabled=locked),
      text(status, role=TextRole::Caption, theme~, width=72.0, height=28.0).foreground(
        if visible {
          theme.palette.foreground
        } else {
          theme.palette.muted
        },
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Center,
  )
  .semantics_role(@core.SemanticsRole::ListItem)
  .semantics_selected(selected=visible)
  .disabled(disabled=locked)
  .accessibility_label(column.label + ", " + status)
}

///|
fn column_visibility_count(
  columns : Array[TableColumn],
  visible : Array[String],
) -> Int {
  let mut count = 0
  for column in columns {
    if string_array_contains(visible, column.id) {
      count = count + 1
    }
  }
  count
}

///|
fn column_visibility_summary(visible_count : Int, column_count : Int) -> String {
  if column_count == 1 {
    "\{visible_count} of 1 column visible"
  } else {
    "\{visible_count} of \{column_count} columns visible"
  }
}

///|
fn column_visibility_panel_height(column_count : Int) -> Double {
  74.0 + views_max_int(1, column_count).to_double() * 38.0
}
