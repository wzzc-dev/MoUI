///|
fn[Msg] table_header(
  columns : Array[TableColumn],
  sort_column~ : String,
  sort_ascending~ : Bool,
  on_sort~ : ((String) -> Msg)?,
  sortable_columns~ : Array[String],
  theme~ : @core.Theme,
  row_height~ : Double,
  row_count~ : Int,
) -> @core.View[Msg] {
  let cells : Array[@core.View[Msg]] = []
  for column_index, column in columns {
    let sorted = sort_column == column.id
    let label = table_header_label(column, sorted~, sort_ascending~)
    let content : @core.View[Msg] = match on_sort {
      Some(handler) =>
        if table_column_is_sortable(column, sortable_columns) {
          @button.button(
            label,
            on_click=handler(column.id),
            variant=@style.ButtonVariant::Ghost,
            theme~,
            width=@common.view_max_double(40.0, column.width - 8.0),
            height=@common.view_max_double(24.0, row_height - 8.0),
          )
          .semantics_selected(selected=sorted)
          .accessibility_label(
            table_header_accessibility_label(column, sorted~, sort_ascending~),
          )
        } else {
          @text.text(
            label,
            role=@style.TextRole::Caption,
            theme~,
            width=column.width - 16.0,
            height=row_height - 8.0,
          )
        }
      None =>
        @text.text(
          label,
          role=@style.TextRole::Caption,
          theme~,
          width=column.width - 16.0,
          height=row_height - 8.0,
        )
    }
    let cell_view = @container.container(
      content,
      width=column.width,
      height=row_height,
      background=theme.palette.surface_variant.multiply_alpha(0.72),
      corner_radius=0.0,
      theme~,
      padding=4.0,
    )
    cells.push(
      data_grid_cell_semantics(
        cell_view,
        row_index=0,
        column_index~,
        row_count~,
        column_count=columns.length(),
      ),
    )
  }
  data_grid_row_semantics(
    @layout.row(cells, spacing=0.0, align=@style.CrossAlign::Start),
    row_index=0,
    row_count~,
    column_count=columns.length(),
  )
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
  row_count~ : Int,
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
        @text.text(
          value,
          role=@style.TextRole::Body,
          theme~,
          width=column.width - 16.0,
          height=row_height - 8.0,
        )
    }
    let cell_view = @container.container(
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
    )
    cells.push(
      data_grid_cell_semantics(
        cell_view,
        row_index=row_index + 1,
        column_index~,
        row_count~,
        column_count=columns.length(),
        selected~,
      ),
    )
  }
  let base = data_grid_row_semantics(
    @layout.row(cells, spacing=0.0, align=@style.CrossAlign::Start),
    row_index=row_index + 1,
    row_count~,
    column_count=columns.length(),
  ).semantics_selected(selected~)
  match on_row_select {
    Some(handler) => base.on_tap(handler(row_index))
    None => base
  }
}

///|
fn table_columns_width(columns : Array[TableColumn]) -> Double {
  let mut width = 0.0
  for column in columns {
    width = width + column.width
  }
  width
}
