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
  theme? : @core.Theme = default_theme(),
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
    container(
      column(rendered_rows, spacing=0.0, align=CrossAlign::Start),
      width=table_width,
      height=row_height * (rows.length() + 1).to_double(),
      variant=ContainerVariant::Base,
      theme~,
      padding=0.0,
    ).semantics_role(@core.SemanticsRole::Grid)
  }
}
