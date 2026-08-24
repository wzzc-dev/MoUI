///|
pub fn[Msg] selectable_list(
  items : Array[SelectableListItem[Msg]],
  selected? : String = "",
  empty? : @core.View[Msg]? = None,
  theme? : @core.Theme,
  width? : Double = 360.0,
  row_height? : Double = 64.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  if items.length() == 0 {
    match empty {
      Some(view) => view
      None =>
        empty_state(
          "No items",
          "There are no list items yet.",
          theme=resolved_theme,
        )
    }
  } else {
    let rows : Array[@core.View[Msg]] = []
    for item in items {
      rows.push(
        selectable_list_row(
          item,
          selected=item.id == selected,
          theme=resolved_theme,
          width~,
          row_height~,
        ),
      )
    }
    @container.container(
      @layout.column(
        rows,
        spacing=resolved_theme.spacing_scale.xs,
        align=@style.CrossAlign::Start,
      ),
      width~,
      height=selectable_list_height(
        items.length(),
        row_height,
        spacing=resolved_theme.spacing_scale.xs,
      ),
      variant=@style.ContainerVariant::Base,
      theme=resolved_theme,
      padding=0.0,
    )
    .semantics_role(@core.SemanticsRole::List)
    .accessibility_label("Selectable list")
  }
}

///|
fn[Msg] selectable_list_row(
  item : SelectableListItem[Msg],
  selected~ : Bool,
  theme~ : @core.Theme,
  width~ : Double,
  row_height~ : Double,
) -> @core.View[Msg] {
  let padding = theme.spacing_scale.sm
  let detail_width = if item.detail == "" {
    0.0
  } else {
    @common.view_max_double(72.0, width * 0.24)
  }
  let text_width = @common.view_max_double(
    96.0,
    width - detail_width - padding * 2.0 - theme.spacing_scale.sm,
  )
  let title_rows : Array[@core.View[Msg]] = [
    @text.text(
      item.title,
      role=@style.TextRole::Control,
      theme~,
      width=text_width,
      height=24.0,
    ),
  ]
  if item.subtitle != "" {
    title_rows.push(
      @text.text(
        item.subtitle,
        role=@style.TextRole::Caption,
        theme~,
        width=text_width,
        height=22.0,
      ).foreground(theme.palette.muted),
    )
  }
  let content_children : Array[@core.View[Msg]] = [
    @layout.column(
      title_rows,
      spacing=theme.spacing_scale.xs,
      align=@style.CrossAlign::Start,
    ),
  ]
  if item.detail != "" {
    content_children.push(
      @text.text(
        item.detail,
        role=@style.TextRole::Caption,
        theme~,
        width=detail_width,
        height=24.0,
      ).foreground(theme.palette.muted),
    )
  }
  let content = @container.container(
    @layout.row(
      content_children,
      spacing=theme.spacing_scale.sm,
      justify=@style.MainAlign::Between,
      align=@style.CrossAlign::Center,
    ),
    width~,
    height=row_height,
    background=if selected {
      theme.palette.primary.multiply_alpha(0.12)
    } else {
      theme.palette.surface.multiply_alpha(0.0)
    },
    theme~,
    padding~,
  ).border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(theme.palette.outline.multiply_alpha(0.42)),
      width=1.0,
    ),
  )
  @common.stack_layout(children=[
    @button.button(
      "",
      on_click=item.message,
      variant=@style.ButtonVariant::Ghost,
      theme~,
      width~,
      height=row_height,
    ).disabled(disabled=!item.enabled),
    content,
  ])
  .disabled(disabled=!item.enabled)
  .semantics_role(@core.SemanticsRole::ListItem)
  .semantics_selected(selected~)
  .accessibility_label(selectable_list_item_label(item))
}

///|
fn selectable_list_height(
  row_count : Int,
  row_height : Double,
  spacing~ : Double,
) -> Double {
  if row_count <= 0 {
    0.0
  } else {
    row_height * row_count.to_double() + spacing * (row_count - 1).to_double()
  }
}

///|
fn[Msg] selectable_list_item_label(item : SelectableListItem[Msg]) -> String {
  let mut label = item.title
  if item.subtitle != "" {
    label = label + ", " + item.subtitle
  }
  if item.detail != "" {
    label = label + ", " + item.detail
  }
  label
}
