///|
/// Msg-generic Markdown outline inspector, extracted from MoMark's chrome.
/// The caller owns folding state and receives jump/fold intents; the panel
/// renders the same 240pt inspector with heading rows indented by level.

///|
/// Outline inspector width (MoMark parity).
const MARKDOWN_OUTLINE_PANEL_WIDTH : Double = 240.0

///|
const MARKDOWN_OUTLINE_CONTENT_WIDTH : Double = 212.0

///|
/// One outline row: indented label button, Tonal when it is the active
/// heading, with a long-press affordance for folding.
fn[Msg] markdown_outline_row(
  item : @richtext.MarkdownEditorOutlineItem,
  folded : Bool,
  active : Bool,
  on_jump~ : (Int) -> Msg,
  on_toggle_fold~ : (Int) -> Msg,
  theme~ : @moui.Theme,
) -> @moui.View[Msg] {
  let indent = markdown_outline_indent_width(item.level)
  let label = if folded {
    "▸ " + markdown_outline_label(item)
  } else {
    markdown_outline_label(item)
  }
  let variant = if active {
    @views.ButtonVariant::Tonal
  } else {
    @views.ButtonVariant::Ghost
  }
  @views.padding_edges(
    @views.button(
      label,
      on_click=on_jump(item.source_start),
      variant~,
      theme~,
      width=(MARKDOWN_OUTLINE_CONTENT_WIDTH - indent).max(96.0),
      height=30.0,
    ).on_long_press(on_toggle_fold(item.source_start)),
    left=indent,
  )
}

///|
/// The outline inspector for a live session. `folded_starts` lists heading
/// `source_start`s whose children are hidden; rows jump via `on_jump` and
/// toggle folding via `on_toggle_fold`.
pub fn[Msg] markdown_outline_panel(
  theme~ : @moui.Theme,
  outline~ : Array[@richtext.MarkdownEditorOutlineItem],
  folded_starts~ : Array[Int],
  caret~ : Int,
  on_jump~ : (Int) -> Msg,
  on_toggle_fold~ : (Int) -> Msg,
  height~ : Double,
  width? : Double = MARKDOWN_OUTLINE_PANEL_WIDTH,
  title? : String = "Outline",
  empty_label? : String = "No headings",
) -> @moui.View[Msg] {
  let content_width = (width - 28.0).max(96.0)
  let visible_outline = markdown_folded_outline(outline, folded_starts)
  let active_index = markdown_active_outline_index(outline, caret)
  let content = if visible_outline.length() == 0 {
    @views.text(empty_label, width=content_width, height=28.0, theme~)
    .font(theme.typography.caption)
    .foreground(theme.palette.muted)
  } else {
    let rows : Array[@moui.View[Msg]] = []
    for item in visible_outline {
      let active = markdown_outline_item_is_active(outline, item, active_index)
      rows.push(
        markdown_outline_row(
          item,
          folded_starts.contains(item.source_start),
          active,
          on_jump~,
          on_toggle_fold~,
          theme~,
        ),
      )
    }
    @views.scroll_view(
      @views.column(
        rows,
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Start,
      ),
      width=content_width,
      height=(height - 52.0).max(0.0),
    )
  }
  @views.container(
    @views.padding_edges(
      @views.column(
        [
          @views.text(title, width=content_width, height=24.0, theme~)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          content,
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.sm,
      bottom=theme.spacing_scale.md,
      left=theme.spacing_scale.sm,
    ),
    width~,
    height~,
    variant=@views.ContainerVariant::Base,
    theme~,
    background=theme.palette.surface,
    corner_radius=0.0,
    padding=0.0,
  )
}
