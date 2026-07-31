///|
pub fn[Msg] tree_view(
  items : Array[TreeItem],
  expanded~ : Array[String],
  selected? : String = "",
  on_select? : ((String) -> Msg)? = None,
  on_toggle? : ((String) -> Msg)? = None,
  theme? : @core.Theme,
  width? : Double = 280.0,
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
      theme=resolved_theme,
      width~,
    )
  }
  column(
    rows,
    spacing=resolved_theme.spacing_scale.xs,
    align=@style.CrossAlign::Start,
  ).semantics_role(@core.SemanticsRole::Tree)
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
      @button.button(
        toggle_label,
        on_click=handler(item.id),
        variant=@style.ButtonVariant::Ghost,
        theme~,
        width=28.0,
        height=30.0,
      )
    None =>
      @text.text(
        toggle_label,
        role=@style.TextRole::Caption,
        theme~,
        width=28.0,
        height=30.0,
      )
  }
  let label_view = match on_select {
    Some(handler) =>
      @button.button(
        item.label,
        on_click=handler(item.id),
        variant=if selected {
          @style.ButtonVariant::Primary
        } else {
          @style.ButtonVariant::Ghost
        },
        theme~,
        width=@common.view_max_double(80.0, width - indent - 34.0),
        height=30.0,
      )
    None =>
      @text.text(
        item.label,
        role=@style.TextRole::Body,
        theme~,
        width=@common.view_max_double(80.0, width - indent - 34.0),
        height=30.0,
      )
  }
  row(
    [@container.spacer(min_length=indent, weight=0.0), toggle, label_view],
    spacing=3.0,
    align=@style.CrossAlign::Center,
  )
  .semantics_role(@core.SemanticsRole::TreeItem)
  .semantics_expanded(expanded~)
  .semantics_selected(selected~)
  .accessibility_label(item.label)
}
