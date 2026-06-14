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
