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
pub fn[Msg] data_filter_bar(
  query~ : String,
  on_query~ : (String) -> Msg,
  filters? : Array[DataFilter[Msg]] = [],
  result_count? : Int = 0,
  on_clear? : Msg? = None,
  placeholder? : String = "Search rows",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
) -> @core.View[Msg] {
  let search_width = views_max_double(160.0, width * 0.46)
  let meta_width = views_max_double(88.0, width - search_width - 96.0)
  let rows : Array[@core.View[Msg]] = [
    row(
      [
        searchbar(
          query~,
          on_input=on_query,
          placeholder~,
          variant=TextFieldVariant::Outline,
          theme~,
        ).frame(width=search_width, height=36.0),
        text(
          data_filter_result_label(result_count),
          role=TextRole::Caption,
          theme~,
          width=meta_width,
          height=28.0,
        ).foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=CrossAlign::Center,
    ),
  ]
  let chips : Array[@core.View[Msg]] = []
  for filter in filters {
    chips.push(data_filter_button(filter, theme))
  }
  match on_clear {
    Some(message) =>
      chips.push(
        data_filter_clear_button(
          message,
          disabled=query == "" && !data_filter_has_selection(filters),
          theme,
        ),
      )
    None => ()
  }
  if chips.length() > 0 {
    rows.push(
      flow(
        chips,
        width=views_max_double(120.0, width - theme.spacing_scale.md * 2.0),
        spacing=theme.spacing_scale.xs,
        row_spacing=theme.spacing_scale.xs,
      ),
    )
  }
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Stretch),
    width~,
    height=data_filter_bar_height(chips.length()),
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.sm,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label("Data filters")
}

///|
fn[Msg] data_filter_button(
  filter : DataFilter[Msg],
  theme : @core.Theme,
) -> @core.View[Msg] {
  button(
    filter.label,
    on_click=filter.message,
    variant=if filter.selected {
      ButtonVariant::Primary
    } else {
      ButtonVariant::Tonal
    },
    theme~,
    width=data_filter_chip_width(filter.label),
    height=32.0,
  )
  .corner_radius(16.0)
  .semantics_selected(selected=filter.selected)
  .disabled(disabled=!filter.enabled)
  .key("data-filter-" + filter.id)
}

///|
fn[Msg] data_filter_clear_button(
  message : Msg,
  disabled~ : Bool,
  theme : @core.Theme,
) -> @core.View[Msg] {
  button(
    "Clear",
    on_click=message,
    variant=ButtonVariant::Ghost,
    theme~,
    width=74.0,
    height=32.0,
  )
  .corner_radius(16.0)
  .disabled(disabled~)
  .key("data-filter-clear")
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
pub fn[Msg] column_visibility_panel(
  columns : Array[TableColumn],
  visible~ : Array[String],
  on_toggle~ : (String, Bool) -> Msg,
  locked? : Array[String] = [],
  title? : String = "Column visibility",
  summary? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 360.0,
) -> @core.View[Msg] {
  let inner_width = views_max_double(
    120.0,
    width - theme.spacing_scale.md * 2.0,
  )
  let visible_count = column_visibility_count(columns, visible)
  let summary_label = if summary == "" {
    column_visibility_summary(visible_count, columns.length())
  } else {
    summary
  }
  let rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=inner_width, height=26.0),
    text(
      summary_label,
      role=TextRole::Caption,
      theme~,
      width=inner_width,
      height=22.0,
    ).foreground(theme.palette.muted),
  ]
  if columns.length() == 0 {
    rows.push(
      text(
        "No columns",
        role=TextRole::Caption,
        theme~,
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
          theme~,
          width=inner_width,
        ),
      )
    }
  }
  surface(
    column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
    width~,
    height=column_visibility_panel_height(columns.length()),
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.md,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_description(summary_label)
  .accessibility_label("Column visibility")
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
pub fn[Msg] table(
  columns : Array[TableColumn],
  rows : Array[Array[String]],
  selected_row? : Int? = None,
  on_row_select? : ((Int) -> Msg)? = None,
  sort_column? : String = "",
  sort_ascending? : Bool = true,
  on_sort? : ((String) -> Msg)? = None,
  sortable_columns? : Array[String] = [],
  cell? : ((Int, TableColumn, String) -> @core.View[Msg])? = None,
  empty? : @core.View[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  row_height? : Double = 38.0,
) -> @core.View[Msg] {
  if rows.length() == 0 {
    match empty {
      Some(view) => view
      None => empty_state("No rows", "There is no table data yet.", theme~)
    }
  } else {
    let table_width = table_columns_width(columns)
    let rendered_rows : Array[@core.View[Msg]] = [
      table_header(
        columns,
        sort_column~,
        sort_ascending~,
        on_sort~,
        sortable_columns~,
        theme~,
        row_height~,
      ),
    ]
    for row_index, row_values in rows {
      rendered_rows.push(
        table_row(
          row_index,
          row_values,
          columns,
          selected=selected_row == Some(row_index),
          on_row_select~,
          cell~,
          theme~,
          row_height~,
        ),
      )
    }
    surface(
      column(rendered_rows, spacing=0.0, align=CrossAlign::Start),
      width=table_width,
      height=row_height * (rows.length() + 1).to_double(),
      variant=SurfaceVariant::Base,
      theme~,
      padding=0.0,
    ).semantics_role(@core.SemanticsRole::Grid)
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
pub fn[Msg] tree_view(
  items : Array[TreeItem],
  expanded~ : Array[String],
  selected? : String = "",
  on_select? : ((String) -> Msg)? = None,
  on_toggle? : ((String) -> Msg)? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 280.0,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    append_tree_rows(
      rows,
      item,
      depth=0,
      expanded~,
      selected~,
      on_select~,
      on_toggle~,
      theme~,
      width~,
    )
  }
  column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start).semantics_role(
    @core.SemanticsRole::Tree,
  )
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
fn[Msg] table_header(
  columns : Array[TableColumn],
  sort_column~ : String,
  sort_ascending~ : Bool,
  on_sort~ : ((String) -> Msg)?,
  sortable_columns~ : Array[String],
  theme~ : @core.Theme,
  row_height~ : Double,
) -> @core.View[Msg] {
  let cells : Array[@core.View[Msg]] = []
  for column in columns {
    let sorted = sort_column == column.id
    let label = table_header_label(column, sorted~, sort_ascending~)
    let content : @core.View[Msg] = match on_sort {
      Some(handler) =>
        if table_column_is_sortable(column, sortable_columns) {
          button(
            label,
            on_click=handler(column.id),
            variant=ButtonVariant::Ghost,
            theme~,
            width=views_max_double(40.0, column.width - 8.0),
            height=views_max_double(24.0, row_height - 8.0),
          )
          .semantics_selected(selected=sorted)
          .accessibility_label(
            table_header_accessibility_label(column, sorted~, sort_ascending~),
          )
        } else {
          text(
            label,
            role=TextRole::Caption,
            theme~,
            width=column.width - 16.0,
            height=row_height - 8.0,
          )
        }
      None =>
        text(
          label,
          role=TextRole::Caption,
          theme~,
          width=column.width - 16.0,
          height=row_height - 8.0,
        )
    }
    cells.push(
      surface(
        content,
        width=column.width,
        height=row_height,
        background=theme.palette.surface_variant.multiply_alpha(0.72),
        corner_radius=0.0,
        theme~,
        padding=4.0,
      ),
    )
  }
  row(cells, spacing=0.0, align=CrossAlign::Start)
}

///|
fn[Msg] table_row(
  row_index : Int,
  row_values : Array[String],
  columns : Array[TableColumn],
  selected~ : Bool,
  on_row_select~ : ((Int) -> Msg)?,
  cell~ : ((Int, TableColumn, String) -> @core.View[Msg])?,
  theme~ : @core.Theme,
  row_height~ : Double,
) -> @core.View[Msg] {
  let cells : Array[@core.View[Msg]] = []
  for column_index, column in columns {
    let value = if column_index < row_values.length() {
      row_values[column_index]
    } else {
      ""
    }
    let content = match cell {
      Some(render) => render(row_index, column, value)
      None =>
        text(
          value,
          role=TextRole::Body,
          theme~,
          width=column.width - 16.0,
          height=row_height - 8.0,
        )
    }
    cells.push(
      surface(
        content,
        width=column.width,
        height=row_height,
        background=if selected {
          theme.palette.primary.multiply_alpha(0.12)
        } else {
          theme.palette.surface.multiply_alpha(0.0)
        },
        corner_radius=0.0,
        theme~,
        padding=4.0,
      ).border(
        @core.BorderStyle::new(
          brush=@core.Brush::solid(theme.palette.outline.multiply_alpha(0.48)),
          width=1.0,
        ),
      ),
    )
  }
  let base = row(cells, spacing=0.0, align=CrossAlign::Start)
    .semantics_role(@core.SemanticsRole::ListItem)
    .semantics_selected(selected~)
  match on_row_select {
    Some(handler) => base.on_tap(handler(row_index))
    None => base
  }
}

///|
fn[Msg] append_tree_rows(
  rows : Array[@core.View[Msg]],
  item : TreeItem,
  depth~ : Int,
  expanded~ : Array[String],
  selected~ : String,
  on_select~ : ((String) -> Msg)?,
  on_toggle~ : ((String) -> Msg)?,
  theme~ : @core.Theme,
  width~ : Double,
) -> Unit {
  let is_expanded = string_array_contains(expanded, item.id)
  let is_selected = selected == item.id
  rows.push(
    tree_row(
      item,
      depth~,
      expanded=is_expanded,
      selected=is_selected,
      on_select~,
      on_toggle~,
      theme~,
      width~,
    ),
  )
  if is_expanded {
    for child in item.children {
      append_tree_rows(
        rows,
        child,
        depth=depth + 1,
        expanded~,
        selected~,
        on_select~,
        on_toggle~,
        theme~,
        width~,
      )
    }
  }
}

///|
fn[Msg] tree_row(
  item : TreeItem,
  depth~ : Int,
  expanded~ : Bool,
  selected~ : Bool,
  on_select~ : ((String) -> Msg)?,
  on_toggle~ : ((String) -> Msg)?,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[Msg] {
  let indent = depth.to_double() * 18.0
  let toggle_label = if item.children.length() == 0 {
    ""
  } else if expanded {
    "v"
  } else {
    ">"
  }
  let toggle = match on_toggle {
    Some(handler) =>
      button(
        toggle_label,
        on_click=handler(item.id),
        variant=ButtonVariant::Ghost,
        theme~,
        width=28.0,
        height=30.0,
      )
    None =>
      text(
        toggle_label,
        role=TextRole::Caption,
        theme~,
        width=28.0,
        height=30.0,
      )
  }
  let label_view = match on_select {
    Some(handler) =>
      button(
        item.label,
        on_click=handler(item.id),
        variant=if selected {
          ButtonVariant::Primary
        } else {
          ButtonVariant::Ghost
        },
        theme~,
        width=views_max_double(80.0, width - indent - 34.0),
        height=30.0,
      )
    None =>
      text(
        item.label,
        role=TextRole::Body,
        theme~,
        width=views_max_double(80.0, width - indent - 34.0),
        height=30.0,
      )
  }
  row(
    [spacer(min_length=indent, weight=0.0), toggle, label_view],
    spacing=3.0,
    align=CrossAlign::Center,
  )
  .semantics_role(@core.SemanticsRole::TreeItem)
  .semantics_expanded(expanded~)
  .semantics_selected(selected~)
  .accessibility_label(item.label)
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
fn table_columns_width(columns : Array[TableColumn]) -> Double {
  let mut width = 0.0
  for column in columns {
    width = width + column.width
  }
  width
}

///|
fn table_header_label(
  column : TableColumn,
  sorted~ : Bool,
  sort_ascending~ : Bool,
) -> String {
  if sorted {
    let marker = if sort_ascending { " ^" } else { " v" }
    column.label + marker
  } else {
    column.label
  }
}

///|
fn table_header_accessibility_label(
  column : TableColumn,
  sorted~ : Bool,
  sort_ascending~ : Bool,
) -> String {
  if sorted {
    let suffix = if sort_ascending {
      ", sorted ascending"
    } else {
      ", sorted descending"
    }
    column.label + suffix
  } else {
    "Sort by " + column.label
  }
}

///|
fn table_column_is_sortable(
  column : TableColumn,
  sortable_columns : Array[String],
) -> Bool {
  sortable_columns.length() == 0 ||
  string_array_contains(sortable_columns, column.id)
}

///|
fn pagination_button_width(label : String) -> Double {
  views_max_double(76.0, label.to_array().length().to_double() * 8.0 + 24.0)
}

///|
fn data_filter_result_label(result_count : Int) -> String {
  if result_count == 1 {
    "1 result"
  } else {
    "\{result_count} results"
  }
}

///|
fn data_filter_chip_width(label : String) -> Double {
  views_max_double(82.0, label.to_array().length().to_double() * 8.0 + 30.0)
}

///|
fn[Msg] data_filter_has_selection(filters : Array[DataFilter[Msg]]) -> Bool {
  filters.any(filter => filter.selected)
}

///|
fn data_filter_bar_height(chip_count : Int) -> Double {
  if chip_count == 0 {
    58.0
  } else {
    102.0
  }
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
