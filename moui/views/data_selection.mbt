///|
pub fn[Msg] selection_toolbar(
  selected_count~ : Int,
  total_count? : Int = 0,
  actions? : Array[MenuItem[Msg]] = [],
  on_clear? : Msg? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
) -> @core.View[Msg] {
  let selected = views_max_int(0, selected_count)
  let summary_width = views_max_double(120.0, width * 0.36)
  let action_width = views_max_double(80.0, width - summary_width - 92.0)
  let action_views : Array[@core.View[Msg]] = []
  for action in actions {
    action_views.push(
      button(
        action.label,
        on_click=action.message,
        variant=ButtonVariant::Tonal,
        theme~,
        width=selection_toolbar_action_width(action.label),
        height=32.0,
      ).disabled(disabled=selected == 0 || !action.enabled),
    )
  }
  match on_clear {
    Some(message) =>
      action_views.push(
        button(
          "Clear",
          on_click=message,
          variant=ButtonVariant::Ghost,
          theme~,
          width=70.0,
          height=32.0,
        ).disabled(disabled=selected == 0),
      )
    None => ()
  }
  surface(
    row(
      [
        text(
          selection_toolbar_label(selected, total_count),
          role=TextRole::Caption,
          theme~,
          width=summary_width,
          height=28.0,
        ).foreground(
          if selected == 0 {
            theme.palette.muted
          } else {
            theme.palette.foreground
          },
        ),
        flow(
          action_views,
          width=action_width,
          spacing=theme.spacing_scale.xs,
          row_spacing=theme.spacing_scale.xs,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=CrossAlign::Center,
    ),
    width~,
    height=selection_toolbar_height(action_views.length()),
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.sm,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_selected(selected=selected > 0)
  .semantics_description(selection_toolbar_label(selected, total_count))
  .accessibility_label("Selection toolbar")
}

///|
pub fn[Msg] selectable_list(
  items : Array[SelectableListItem[Msg]],
  selected? : String = "",
  empty? : @core.View[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 360.0,
  row_height? : Double = 64.0,
) -> @core.View[Msg] {
  if items.length() == 0 {
    match empty {
      Some(view) => view
      None => empty_state("No items", "There are no list items yet.", theme~)
    }
  } else {
    let rows : Array[@core.View[Msg]] = []
    for item in items {
      rows.push(
        selectable_list_row(
          item,
          selected=item.id == selected,
          theme~,
          width~,
          row_height~,
        ),
      )
    }
    surface(
      column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
      width~,
      height=selectable_list_height(
        items.length(),
        row_height,
        spacing=theme.spacing_scale.xs,
      ),
      variant=SurfaceVariant::Base,
      theme~,
      padding=0.0,
    )
    .semantics_role(@core.SemanticsRole::List)
    .accessibility_label("Selectable list")
  }
}

///|
pub fn[Msg] pagination(
  page~ : Int,
  page_count~ : Int,
  on_previous~ : Msg,
  on_next~ : Msg,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 360.0,
  previous_label? : String = "Previous",
  next_label? : String = "Next",
) -> @core.View[Msg] {
  let total_pages = views_max_int(1, page_count)
  let current_page = views_min_int(views_max_int(0, page), total_pages - 1)
  let has_previous = current_page > 0
  let has_next = current_page + 1 < total_pages
  let previous_width = pagination_button_width(previous_label)
  let next_width = pagination_button_width(next_label)
  let label_width = views_max_double(
    88.0,
    width - previous_width - next_width - theme.spacing_scale.sm * 2.0,
  )
  row(
    [
      button(
        previous_label,
        on_click=on_previous,
        variant=ButtonVariant::Outline,
        theme~,
        width=previous_width,
        height=36.0,
      ).disabled(disabled=!has_previous),
      text(
        "Page \{current_page + 1} of \{total_pages}",
        role=TextRole::Caption,
        theme~,
        width=label_width,
        height=28.0,
      ),
      button(
        next_label,
        on_click=on_next,
        variant=ButtonVariant::Outline,
        theme~,
        width=next_width,
        height=36.0,
      ).disabled(disabled=!has_next),
    ],
    spacing=theme.spacing_scale.sm,
    align=CrossAlign::Center,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label("Page \{current_page + 1} of \{total_pages}")
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
    views_max_double(72.0, width * 0.24)
  }
  let text_width = views_max_double(
    96.0,
    width - detail_width - padding * 2.0 - theme.spacing_scale.sm,
  )
  let title_rows : Array[@core.View[Msg]] = [
    text(
      item.title,
      role=TextRole::Control,
      theme~,
      width=text_width,
      height=24.0,
    ),
  ]
  if item.subtitle != "" {
    title_rows.push(
      text(
        item.subtitle,
        role=TextRole::Caption,
        theme~,
        width=text_width,
        height=22.0,
      ).foreground(theme.palette.muted),
    )
  }
  let content_children : Array[@core.View[Msg]] = [
    column(title_rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
  ]
  if item.detail != "" {
    content_children.push(
      text(
        item.detail,
        role=TextRole::Caption,
        theme~,
        width=detail_width,
        height=24.0,
      ).foreground(theme.palette.muted),
    )
  }
  let content = surface(
    row(
      content_children,
      spacing=theme.spacing_scale.sm,
      justify=MainAlign::Between,
      align=CrossAlign::Center,
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
  overlay(
    button(
      "",
      on_click=item.message,
      variant=ButtonVariant::Ghost,
      theme~,
      width~,
      height=row_height,
    ).disabled(disabled=!item.enabled),
    content,
  )
  .disabled(disabled=!item.enabled)
  .semantics_role(@core.SemanticsRole::ListItem)
  .semantics_selected(selected~)
  .accessibility_label(selectable_list_item_label(item))
}

///|
fn pagination_button_width(label : String) -> Double {
  views_max_double(76.0, label.to_array().length().to_double() * 8.0 + 24.0)
}

///|
fn selection_toolbar_label(selected_count : Int, total_count : Int) -> String {
  if selected_count == 0 {
    "No rows selected"
  } else if total_count > 0 {
    "\{selected_count} of \{total_count} selected"
  } else if selected_count == 1 {
    "1 row selected"
  } else {
    "\{selected_count} rows selected"
  }
}

///|
fn selection_toolbar_action_width(label : String) -> Double {
  views_max_double(76.0, label.to_array().length().to_double() * 8.0 + 24.0)
}

///|
fn selection_toolbar_height(action_count : Int) -> Double {
  if action_count > 3 {
    86.0
  } else {
    54.0
  }
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
