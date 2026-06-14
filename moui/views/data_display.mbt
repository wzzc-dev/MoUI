///|
pub fn[Msg] description_list(
  items : Array[DescriptionItem],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 360.0,
  term_width? : Double = 112.0,
  row_height? : Double = 30.0,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    rows.push(
      row(
        [
          text(
            item.term,
            role=TextRole::Caption,
            theme~,
            width=term_width,
            height=row_height,
          ),
          text(
            item.detail,
            role=TextRole::Body,
            theme~,
            width=views_max_double(
              80.0,
              width - term_width - theme.spacing_scale.sm,
            ),
            height=row_height,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=CrossAlign::Center,
      ),
    )
  }
  column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start).semantics_role(
    @core.SemanticsRole::Group,
  )
}

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
pub fn[Msg] detail_panel(
  title : String,
  items : Array[DescriptionItem],
  subtitle? : String = "",
  action? : StateViewAction[Msg]? = None,
  empty? : @core.View[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 280.0,
  height? : Double = 180.0,
) -> @core.View[Msg] {
  let inner_width = views_max_double(96.0, width - theme.spacing_scale.md * 2.0)
  let rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=inner_width, height=26.0),
  ]
  if subtitle != "" {
    rows.push(
      text(
        subtitle,
        role=TextRole::Caption,
        theme~,
        width=inner_width,
        height=22.0,
      ),
    )
  }
  if items.length() == 0 {
    match empty {
      Some(view) => rows.push(view)
      None =>
        rows.push(
          text(
            "No detail selected",
            role=TextRole::Caption,
            theme~,
            width=inner_width,
            height=28.0,
          ),
        )
    }
  } else {
    rows.push(
      description_list(
        items,
        theme~,
        width=inner_width,
        term_width=views_min_double(104.0, inner_width * 0.42),
        row_height=28.0,
      ),
    )
  }
  match action {
    Some(action) =>
      rows.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Tonal,
          theme~,
          width=views_min_double(148.0, inner_width),
          height=36.0,
        ),
      )
    None => ()
  }
  surface(
    column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
    width~,
    height~,
    variant=SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label(title)
}

///|
pub fn[Msg] avatar(
  label : String,
  image? : String? = None,
  theme? : @core.Theme = @core.Theme::default(),
  size? : Double = 40.0,
) -> @core.View[Msg] {
  match image {
    Some(source) =>
      @core.View::image(
        source~,
        size=Some(@core.Size::new(width=size, height=size)),
      )
      .corner_radius(size / 2.0)
      .clip()
      .accessibility_label(label)
    None =>
      surface(
        text(
          avatar_initials(label),
          role=TextRole::Control,
          theme~,
          width=size - 10.0,
          height=size - 10.0,
        ).foreground(theme.palette.primary_foreground),
        width=size,
        height=size,
        background=theme.palette.primary,
        corner_radius=size / 2.0,
        padding=5.0,
      ).accessibility_label(label)
  }
}

///|
pub fn[Msg] avatar_group(
  labels : Array[String],
  theme? : @core.Theme = @core.Theme::default(),
  size? : Double = 36.0,
  max_visible? : Int = 4,
) -> @core.View[Msg] {
  let visible = views_min_int(labels.length(), views_max_int(0, max_visible))
  let children : Array[@core.View[Msg]] = []
  for index in 0..<visible {
    children.push(
      avatar(labels[index], theme~, size~).key("avatar-" + labels[index]),
    )
  }
  let remaining = labels.length() - visible
  if remaining > 0 {
    children.push(
      surface(
        text(
          "+\{remaining}",
          role=TextRole::Caption,
          theme~,
          width=size - 10.0,
          height=size - 10.0,
        ).foreground(theme.palette.foreground),
        width=size,
        height=size,
        background=theme.palette.surface_variant,
        corner_radius=size / 2.0,
        padding=5.0,
      ),
    )
  }
  row(children, spacing=0.0, align=CrossAlign::Center)
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

///|
fn avatar_initials(label : String) -> String {
  let chars = label.to_array()
  if chars.length() == 0 {
    "?"
  } else {
    chars[0].to_string()
  }
}

///|
fn views_min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn views_min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}
