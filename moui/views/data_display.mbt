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
          text(item.term, role=TextRole::Caption, theme~, width=term_width, height=row_height),
          text(
            item.detail,
            role=TextRole::Body,
            theme~,
            width=views_max_double(80.0, width - term_width - theme.spacing_scale.sm),
            height=row_height,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=CrossAlign::Center,
      ),
    )
  }
  column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start)
  .semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] table(
  columns : Array[TableColumn],
  rows : Array[Array[String]],
  selected_row? : Int? = None,
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
      table_header(columns, theme~, row_height~),
    ]
    for row_index, row_values in rows {
      rendered_rows.push(
        table_row(
          row_index,
          row_values,
          columns,
          selected=selected_row == Some(row_index),
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
    append_tree_rows(rows, item, depth=0, expanded~, selected~, on_select~, on_toggle~, theme~, width~)
  }
  column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start)
  .semantics_role(@core.SemanticsRole::List)
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
      @core.View::image(source~, size=Some(@core.Size::new(width=size, height=size)))
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
    children.push(avatar(labels[index], theme~, size~).key("avatar-" + labels[index]))
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
  theme~ : @core.Theme,
  row_height~ : Double,
) -> @core.View[Msg] {
  let cells : Array[@core.View[Msg]] = []
  for column in columns {
    cells.push(
      surface(
        text(column.label, role=TextRole::Caption, theme~, width=column.width - 16.0, height=row_height - 8.0),
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
  cell~ : ((Int, TableColumn, String) -> @core.View[Msg])?,
  theme~ : @core.Theme,
  row_height~ : Double,
) -> @core.View[Msg] {
  let cells : Array[@core.View[Msg]] = []
  for column_index, column in columns {
    let value = if column_index < row_values.length() { row_values[column_index] } else { "" }
    let content = match cell {
      Some(render) => render(row_index, column, value)
      None => text(value, role=TextRole::Body, theme~, width=column.width - 16.0, height=row_height - 8.0)
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
      ).border(@core.BorderStyle::new(brush=@core.Brush::solid(theme.palette.outline.multiply_alpha(0.48)), width=1.0)),
    )
  }
  row(cells, spacing=0.0, align=CrossAlign::Start)
  .semantics_role(@core.SemanticsRole::ListItem)
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
  rows.push(tree_row(item, depth~, expanded=is_expanded, selected=is_selected, on_select~, on_toggle~, theme~, width~))
  if is_expanded {
    for child in item.children {
      append_tree_rows(rows, child, depth=depth + 1, expanded~, selected~, on_select~, on_toggle~, theme~, width~)
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
      button(toggle_label, on_click=handler(item.id), variant=ButtonVariant::Ghost, theme~, width=28.0, height=30.0)
    None => text(toggle_label, role=TextRole::Caption, theme~, width=28.0, height=30.0)
  }
  let label_view = match on_select {
    Some(handler) =>
      button(item.label, on_click=handler(item.id), variant=if selected { ButtonVariant::Primary } else { ButtonVariant::Ghost }, theme~, width=views_max_double(80.0, width - indent - 34.0), height=30.0)
    None => text(item.label, role=TextRole::Body, theme~, width=views_max_double(80.0, width - indent - 34.0), height=30.0)
  }
  row(
    [spacer(min_length=indent, weight=0.0), toggle, label_view],
    spacing=3.0,
    align=CrossAlign::Center,
  ).semantics_role(@core.SemanticsRole::ListItem)
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
fn avatar_initials(label : String) -> String {
  let chars = label.to_array()
  if chars.length() == 0 {
    "?"
  } else {
    chars[0].to_string()
  }
}

///|
fn views_min_int(a : Int, b : Int) -> Int {
  if a < b { a } else { b }
}
