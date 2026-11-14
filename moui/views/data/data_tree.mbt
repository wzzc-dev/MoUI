///|
pub fn[Msg] tree_view(
  items : Array[TreeItem],
  expanded~ : Array[String],
  selected~ : String = "",
  on_select~ : ((String) -> Msg)? = None,
  on_toggle~ : ((String) -> Msg)? = None,
  on_secondary_tap~ : ((String) -> Msg)? = None,
  theme? : @core.Theme,
  width~ : Double = 280.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
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
      on_secondary_tap~,
      theme=resolved_theme,
      width~,
    )
  }
  @layout.column(rows, spacing=resolved_theme.spacing_scale.xs, align=Start).semantics_role(
    Tree,
  )
}

///|
pub fn tree_item(
  id~ : String,
  label~ : String,
  children~ : Array[TreeItem] = [],
  icon~ : @style.IconName? = None,
  icon_color~ : @core.Color? = None,
  dimmed~ : Bool = false,
) -> TreeItem {
  { id, label, children, icon, icon_color, dimmed, }
}

///|
fn[Msg] append_tree_rows(
  rows : Array[@core.View[Msg]],
  item : TreeItem,
  depth~ : Int32,
  expanded~ : Array[String],
  selected~ : String,
  on_select~ : ((String) -> Msg)?,
  on_toggle~ : ((String) -> Msg)?,
  on_secondary_tap~ : ((String) -> Msg)?,
  theme~ : @core.Theme,
  width~ : Double,
) -> Unit {
  let is_expanded = @controls.string_array_contains(expanded, item.id)
  let is_selected = selected == item.id
  rows.push(
    tree_row(
      item,
      depth~,
      expanded=is_expanded,
      selected=is_selected,
      on_select~,
      on_toggle~,
      on_secondary_tap~,
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
        on_secondary_tap~,
        theme~,
        width~,
      )
    }
  }
}
