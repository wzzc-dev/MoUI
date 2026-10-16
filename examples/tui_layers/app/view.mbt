///|
using @views {
  button,
  checkbox,
  column,
  container,
  expanded,
  row,
  scroll_view,
  selectable_list,
  selectable_list_item,
  spacer,
  text,
  text_field,
  tree_view,
}

///|
pub fn Model::view(self : Model) -> @moui.View[Msg] {
  let theme = @views.default_theme()
  column(
    [
      self.header_line(theme~),
      self.filter_line(theme~),
      expanded(
        row(
          [expanded(self.layer_pane(theme~)), expanded(self.file_pane(theme~))],
          spacing=pane_spacing,
        ),
      ),
      self.status_line(theme~),
    ],
    spacing=4.0,
  )
}

///|
fn Model::header_line(self : Model, theme~ : @moui.Theme) -> @moui.View[Msg] {
  row(
    [
      text("MoUI TUI layers", theme~, width=200.0, height=16.0).title(),
      spacer(),
      text("focus: \{pane_name(self.pane)}", theme~, width=140.0, height=16.0).caption(),
    ],
    spacing=8.0,
  )
}

///|
/// The live filter and the visibility switch. `on_input` fires per keystroke and
/// `on_submit` is deliberately absent: this line is the proof that a terminal key
/// reaches the model without waiting for Enter.
///
/// Keys only land here once the field holds the runtime's focus, which in a
/// terminal means it has been clicked — there is no app-facing focus request.
fn Model::filter_line(self : Model, theme~ : @moui.Theme) -> @moui.View[Msg] {
  row(
    [
      text("filter", theme~, width=48.0, height=16.0).caption(),
      text_field(
        self.filter,
        on_input=text => SetFilter(text),
        placeholder="type to narrow layers",
        theme~,
        width=152.0,
        height=16.0,
      ).key("layer-filter"),
      checkbox(
        "only-visible",
        checked=self.only_visible,
        on_change=value => SetOnlyVisible(value),
        theme~,
      ),
      button("layer", on_click=AddLayer, theme~),
      button("folder", on_click=AddNode, theme~),
    ],
    spacing=8.0,
  )
}

///|
fn Model::layer_pane(self : Model, theme~ : @moui.Theme) -> @moui.View[Msg] {
  let rows = visible_layers(self)
  let items = rows.map(layer => {
    selectable_list_item(
      id=layer.id,
      title="\{layer_marker(self, layer.id)} \{layer.name}",
      message=SelectLayer(layer.id),
    )
  })
  pane_frame(
    title="Layers \{rows.length()}/\{self.layers.length()}",
    active=self.pane == LayersPane,
    child=scroll_view(
      selectable_list(
        items,
        selected=self.selected_layer,
        theme~,
        width=layer_width,
        row_height~,
      ).key("layer-list"),
      offset=@geometry.Point::new(x=0.0, y=self.layer_scroll),
      on_scroll=Some(point => SetScroll(LayersPane, point.y)),
      shows_indicator=true,
    ),
    theme~,
  )
}

///|
fn Model::file_pane(self : Model, theme~ : @moui.Theme) -> @moui.View[Msg] {
  pane_frame(
    title="Files \{visible_node_ids(self.tree, self.expanded).length()}",
    active=self.pane == FilesPane,
    child=scroll_view(
      tree_view(
        to_tree_items(self.tree),
        expanded=self.expanded,
        selected=self.selected_node,
        on_select=Some(id => SelectNode(id)),
        on_toggle=Some(id => ToggleNode(id)),
        on_secondary_tap=Some(id => ToggleNode(id)),
        theme~,
        width=tree_width,
      ).key("file-tree"),
      offset=@geometry.Point::new(x=0.0, y=self.tree_scroll),
      on_scroll=Some(point => SetScroll(FilesPane, point.y)),
      shows_indicator=true,
    ),
    theme~,
  )
}

///|
/// Pane title plus its border box. The border colour is the visible focus state:
/// only the pane holding the keyboard gets the primary edge, which is what makes
/// a Tab press readable in a terminal that has no cursor ring.
fn pane_frame(
  title~ : String,
  active~ : Bool,
  child~ : @moui.View[Msg],
  theme~ : @moui.Theme,
) -> @moui.View[Msg] {
  let edge = if active { theme.palette.primary } else { theme.palette.outline }
  column(
    [
      text(
        if active {
          "[ \{title} ]"
        } else {
          " \{title}   "
        },
        theme~,
        width=176.0,
        height=16.0,
      ).caption(),
      expanded(
        container(
          child,
          theme~,
          padding=4.0,
          border=Some(
            @graphics.BorderStyle::new(
              brush=@graphics.Brush::solid(edge),
              width=1.0,
            ),
          ),
        ),
      ),
    ],
    spacing=4.0,
  )
}

///|
/// Two needles the PTY gate reads: `rows=`/`hide=` prove the filter and the
/// visibility switch reached the model, `sel=`/`node=` prove selection followed
/// the row rather than the slot. The third line is the key map, so a person at a
/// real terminal never has to guess which keys type and which keys command.
fn Model::status_line(self : Model, theme~ : @moui.Theme) -> @moui.View[Msg] {
  let rows = visible_layers(self)
  let counts = "sel=\{selected_layer_name(self)}  node=\{selected_node_label(self)}  filter=\{if self.filter == "" { "-" } else { self.filter }}  rows=\{rows.length()}  hide=\{hidden_count(self)}  only=\{if self.only_visible { "1" } else { "0" }}"
  column(
    [
      text(counts, theme~, width=560.0, height=16.0).caption(),
      text(
        "row=\{scroll_cells(self.layer_scroll)}  file=\{scroll_cells(self.tree_scroll)}",
        theme~,
        width=560.0,
        height=16.0,
      ).caption(),
      text(
        "tab/arrow-lr pane  arrow-ud move  space fold-or-hide  wheel scroll  click row/folder/box/button/field  ctrl-n layer  ctrl-b hide  ctrl-x delete  ctrl-a folder",
        theme~,
        width=920.0,
        height=16.0,
      ).caption(),
    ],
    spacing=2.0,
  )
}

///|
fn scroll_cells(offset : Double) -> Int {
  (offset / scroll_line).to_int()
}
