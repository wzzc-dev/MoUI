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
  @layout.column(
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
  let indent = depth.to_double() * 16.0
  // Real disclosure glyphs, not ASCII 'v'/'>': a filled triangle reads as a
  // control at caption size, and the app's other fold buttons use them too.
  let toggle_label = if item.children.length() == 0 {
    ""
  } else if expanded {
    "▾"
  } else {
    "▸"
  }
  let toggle_width = 20.0
  let toggle = match on_toggle {
    Some(handler) =>
      @button.button(
        toggle_label,
        on_click=handler(item.id),
        variant=@style.ButtonVariant::Ghost,
        theme~,
        width=toggle_width,
        height=30.0,
      )
    None =>
      @text.text(
        toggle_label,
        role=@style.TextRole::Caption,
        theme~,
        width=toggle_width,
        height=30.0,
      )
  }
  // The label is left-aligned and stretches over the rest of the row: a
  // centered label inside a wide box left a gap after the disclosure glyph and
  // made every row's text float, which is what made the tree read as ragged.
  let label_width = @common.view_max_double(40.0, width - indent - 26.0)
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
        width=label_width,
        height=30.0,
        label_align=@core.TextAlign::TextStart,
      )
    None =>
      @text.text(
        item.label,
        role=@style.TextRole::Body,
        theme~,
        width=label_width,
        height=30.0,
      )
  }
  // Depth is a left padding, not a spacer child: a spacer with weight 0 still
  // absorbed the row's slack here, which pushed the label to the right edge and
  // left a gap after the disclosure glyph.
  @layout.padding_edges(
    @layout.row([toggle, label_view], spacing=2.0, align=@style.CrossAlign::Center),
    left=indent,
  )
  .semantics_role(@core.SemanticsRole::TreeItem)
  .semantics_expanded(expanded~)
  .semantics_selected(selected~)
  .accessibility_label(item.label)
}
