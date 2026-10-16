///|
pub fn Model::view(self : Model) -> @moui.View[Msg] {
  let theme = @views.default_theme()
  @views.column(
    [
      self.header_line(theme~),
      @views.expanded(
        @views.row(
          [
            @views.expanded(self.list_pane(theme~)),
            @views.expanded(self.tree_pane(theme~)),
          ],
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
  @views.row(
    [
      @views.text("MoUI TUI split", theme~, width=220.0, height=16.0).title(),
      @views.spacer(),
      @views.text(focus_hint(self.pane), theme~, width=140.0, height=16.0).caption(),
    ],
    spacing=8.0,
  )
}

///|
fn Model::list_pane(self : Model, theme~ : @moui.Theme) -> @moui.View[Msg] {
  let items = self.entries.map(entry => {
    @views.selectable_list_item(
      id=entry.id,
      title=entry.title,
      subtitle=entry.subtitle,
      message=SelectEntry(entry.id),
    )
  })
  pane_frame(
    title="Entries \{self.entries.length()}",
    active=self.pane == ListPane,
    child=@views.scroll_view(
      @views.selectable_list(
        items,
        selected=self.selected_entry,
        theme~,
        width=list_width,
        row_height=list_row_height,
      ).key("entries-list"),
      offset=@geometry.Point::new(x=0.0, y=self.list_scroll),
      on_scroll=Some(point => SetScroll(ListPane, point.y)),
      shows_indicator=true,
    ),
    theme~,
  )
}

///|
fn Model::tree_pane(self : Model, theme~ : @moui.Theme) -> @moui.View[Msg] {
  pane_frame(
    title="Files \{visible_node_ids(self.tree, self.expanded).length()}",
    active=self.pane == TreePane,
    child=@views.scroll_view(
      @views.tree_view(
        to_tree_items(self.tree),
        expanded=self.expanded,
        selected=self.selected_node,
        on_select=Some(id => SelectNode(id)),
        on_toggle=Some(id => ToggleNode(id)),
        theme~,
        width=tree_width,
      ).key("file-tree"),
      offset=@geometry.Point::new(x=0.0, y=self.tree_scroll),
      on_scroll=Some(point => SetScroll(TreePane, point.y)),
      shows_indicator=true,
    ),
    theme~,
  )
}

///|
/// The pane title row and its border box. The border colour is the visible
/// focus state: only the pane holding the keyboard gets the primary edge.
fn pane_frame(
  title~ : String,
  active~ : Bool,
  child~ : @moui.View[Msg],
  theme~ : @moui.Theme,
) -> @moui.View[Msg] {
  let edge = if active { theme.palette.primary } else { theme.palette.outline }
  @views.column(
    [
      @views.text(
        if active {
          "[ \{title} ]"
        } else {
          " \{title}   "
        },
        theme~,
        width=200.0,
        height=16.0,
      ).caption(),
      @views.expanded(
        @views.container(
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
fn Model::status_line(self : Model, theme~ : @moui.Theme) -> @moui.View[Msg] {
  @views.column(
    [
      @views.text(
        "sel=\{selected_entry_title(self)}  node=\{selected_node_label(self)}",
        theme~,
        width=400.0,
        height=16.0,
      ).caption(),
      @views.text(
        "list=\{scroll_cells(self.list_scroll)}  tree=\{scroll_cells(self.tree_scroll)}",
        theme~,
        width=400.0,
        height=16.0,
      ).caption(),
      @views.text(
        "tab/arrow-lr pane   arrow-up/down move   enter fold   n entry   a node   d delete   wheel scroll",
        theme~,
        width=900.0,
        height=16.0,
      ).caption(),
    ],
    spacing=2.0,
  )
}

///|
fn focus_hint(pane : Pane) -> String {
  if pane == ListPane {
    "focus: list"
  } else {
    "focus: tree"
  }
}

///|
fn scroll_cells(offset : Double) -> Int {
  (offset / scroll_line).to_int()
}
