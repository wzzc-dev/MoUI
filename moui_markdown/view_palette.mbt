///|
/// Msg-generic "Quick Format" palette view, extracted from MoMark's chrome.
/// Renders the catalog from `markdown_format_palette_items` (or a caller
/// override) filtered by the query, with label/group/shortcut columns.

///|
/// Default overlay width, clamped to the available width.
const MARKDOWN_FORMAT_PALETTE_WIDTH : Double = 540.0

///|
const MARKDOWN_FORMAT_PALETTE_HEIGHT : Double = 240.0

///|
const MARKDOWN_FORMAT_PALETTE_LIST_HEIGHT : Double = 176.0

///|
/// One palette row: command button + group + shortcut columns.
fn[Msg] markdown_format_palette_row(
  item : MarkdownPaletteItem,
  theme : @moui.Theme,
  on_action~ : (String) -> Msg,
  width~ : Double,
) -> @moui.View[Msg] {
  let label_width = (width - 250.0).max(120.0)
  @views.row(
    [
      @views.button(
        item.label,
        on_click=on_action(item.action),
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=label_width,
        height=32.0,
      ),
      @views.text(item.group, width=82.0, height=32.0, theme~)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      @views.text(item.shortcut, width=152.0, height=32.0, theme~)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
}

///|
/// The quick-format palette overlay. `items` is normally
/// `markdown_format_palette_filtered_items(query)`; callers may pass a custom
/// catalog. `on_action` receives the selected action id (see
/// `markdown_command_from_palette_action`).
pub fn[Msg] markdown_format_palette(
  theme~ : @moui.Theme,
  query~ : String,
  items~ : Array[MarkdownPaletteItem],
  on_query_input~ : (String) -> Msg,
  on_submit~ : Msg,
  on_action~ : (String) -> Msg,
  on_done~ : Msg,
  width~ : Double,
  title? : String = "Quick Format",
  filter_placeholder? : String = "Filter",
  done_label? : String = "Done",
  empty_label? : String = "No commands",
  key_prefix? : String = "markdown",
) -> @moui.View[Msg] {
  let panel_width = width.min(MARKDOWN_FORMAT_PALETTE_WIDTH)
  let content_width = (panel_width - theme.spacing_scale.md * 2.0).max(120.0)
  let rows : Array[@moui.View[Msg]] = []
  for item in items {
    rows.push(
      markdown_format_palette_row(item, theme, on_action~, width=content_width),
    )
  }
  if rows.length() == 0 {
    rows.push(
      @views.text(empty_label, width=content_width, height=30.0, theme~)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    )
  }
  @views.container(
    @views.padding_edges(
      @views.column(
        [
          @views.row(
            [
              @views.text(title, width=112.0, height=34.0, theme~)
              .font(theme.typography.caption)
              .foreground(theme.palette.muted),
              @views.text_field(
                query,
                on_input=on_query_input,
                on_submit=Some(on_submit),
                placeholder=filter_placeholder,
                variant=@views.TextFieldVariant::Outline,
                theme~,
                width=(content_width - 190.0).max(120.0),
                height=34.0,
              ).key("\{key_prefix}-format-palette-query"),
              @views.button(
                done_label,
                on_click=on_done,
                variant=@views.ButtonVariant::Ghost,
                theme~,
              ),
            ],
            spacing=theme.spacing_scale.xs,
            align=@views.CrossAlign::Center,
          ),
          @views.scroll_view(
            @views.column(
              rows,
              spacing=theme.spacing_scale.xs,
              align=@views.CrossAlign::Start,
            ),
            width=content_width,
            height=MARKDOWN_FORMAT_PALETTE_LIST_HEIGHT,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.sm,
      right=theme.spacing_scale.md,
      bottom=theme.spacing_scale.sm,
      left=theme.spacing_scale.md,
    ),
    width=panel_width,
    height=MARKDOWN_FORMAT_PALETTE_HEIGHT,
    variant=@views.ContainerVariant::Overlay,
    theme~,
    padding=0.0,
  )
}
