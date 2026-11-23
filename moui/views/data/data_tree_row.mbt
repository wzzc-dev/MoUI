///|
fn[Msg] tree_row(
  item : TreeItem,
  depth~ : Int32,
  expanded~ : Bool,
  selected~ : Bool,
  active~ : Bool,
  hovered~ : Bool,
  on_select~ : ((String) -> Msg)?,
  on_toggle~ : ((String) -> Msg)?,
  on_secondary_tap~ : ((String) -> Msg)?,
  on_activate~ : ((String) -> Msg)?,
  on_secondary_tap_with_frame~ : ((String, @core.Point, @core.Rect) -> Msg)?,
  on_hover~ : ((String, Bool) -> Msg)?,
  indent_guides~ : Bool,
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
  let icon_width = if item.icon is Some(_) { 22.0 } else { 0.0 }
  let toggle = match on_toggle {
    Some(handler) =>
      @button.button(
        toggle_label,
        on_click=handler(item.id),
        variant=Ghost,
        theme~,
        width=toggle_width,
        height=26.0,
      )
    None =>
      @text.text(
        toggle_label,
        role=Caption,
        theme~,
        width=toggle_width,
        height=26.0,
      )
  }
  // The label is left-aligned and stretches over the rest of the row: a
  // centered label inside a wide box left a gap after the disclosure glyph and
  // made every row's text float, which is what made the tree read as ragged.
  let label_width = @common.view_max_double(
    40.0,
    width - indent - 26.0 - icon_width,
  )
  let icon_view = match item.icon {
    Some(name) =>
      @icon.icon(
        name,
        size=14.0,
        color=item.icon_color.unwrap_or(theme.palette.muted),
      )
    None => @text.text("", width=0.0, height=26.0)
  }
  // Ignored entries (dot-directories and friends) read one step quieter than
  // active rows, Winc-style; a selected row keeps its emphasis.
  let dim_label = item.dimmed && !selected
  let label_view = match on_select {
    Some(handler) if dim_label =>
      // A button paints its label from the control theme (which does not
      // follow palette overrides), so a dimmed row renders its label as
      // muted text with the select handler attached directly.
      @text.text(item.label, role=Body, theme~, width=label_width, height=26.0)
      .foreground(theme.palette.muted)
      .on_tap(handler(item.id))
    Some(handler) =>
      @button.button(
        item.label,
        on_click=handler(item.id),
        variant=if selected { Tonal } else { Ghost },
        theme~,
        width=label_width,
        height=26.0,
        label_align=TextStart,
      )
    None => {
      let label = @text.text(
        item.label,
        role=Body,
        theme~,
        width=label_width,
        height=26.0,
      )
      if dim_label {
        label.foreground(theme.palette.muted)
      } else {
        label
      }
    }
  }
  let content = @layout.row(
    [toggle, icon_view, label_view],
    spacing=2.0,
    align=Center,
  )
  // Depth is either a left padding or, with `indent_guides`, one 1pt vertical
  // guide per ancestor level: the padding version is kept for plain trees, and
  // the guide version reserves the same 16pt per level so labels never move
  // when the option is toggled on.
  let row_body = if indent_guides && depth > 0 {
    let guides : Array[@core.View[Msg]] = []
    for level = 0; level < depth; level = level + 1 {
      guides.push(
        @layout.row(
          [
            @container.spacer(min_length=6.0, weight=0.0),
            @text.text("", width=1.0, height=26.0).background(
              theme.palette.outline_variant,
            ),
            @container.spacer(min_length=9.0, weight=0.0),
          ],
          spacing=0.0,
          align=Center,
        ),
      )
    }
    @layout.row(
      [@layout.row(guides, spacing=0.0, align=Center), content],
      spacing=0.0,
      align=Center,
    )
  } else {
    @layout.padding_edges(content, left=indent)
  }
  // Hover and active paint behind the row's children, so the label button and
  // the disclosure glyph keep their own colors.
  let painted = if hovered {
    row_body.background(theme.palette.surface_variant)
  } else {
    row_body
  }
  let acted = if active {
    painted.border(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(theme.palette.primary),
        width=1.0,
      ),
    )
  } else {
    painted
  }
  // Right-click target coverage spans the whole row (glyph + label), not just
  // the label button: the row modifier only reacts to button 1, so primary
  // taps on the toggle/label children keep working unchanged. When the frame
  // callback is supplied it wins over the plain one so a context menu is not
  // posted twice.
  let with_secondary = match (on_secondary_tap_with_frame, on_secondary_tap) {
    (Some(handler), _) =>
      acted.on_secondary_tap_with_frame((point, frame) => {
        handler(item.id, point, frame)
      })
    (None, Some(handler)) => acted.on_secondary_tap(handler(item.id))
    (None, None) => acted
  }
  let with_hover = match on_hover {
    Some(handler) =>
      with_secondary.on_hover(entered => handler(item.id, entered))
    None => with_secondary
  }
  let with_activate = match on_activate {
    Some(handler) => with_hover.on_double_tap(handler(item.id))
    None => with_hover
  }
  // The row carries the item id as its identity: tree rows come and go with
  // collapse/expand, and without a key the reconciler matches them by position,
  // so focus and selection would follow the slot instead of the item.
  with_activate
  .key("tree-" + item.id)
  .semantics_role(TreeItem)
  .semantics_expanded(expanded~)
  .semantics_selected(selected~)
  .accessibility_label(item.label)
}
