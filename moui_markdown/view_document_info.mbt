///|
/// Msg-generic Markdown document-info inspector, extracted from MoMark's
/// chrome. Follows `@views` composition only (no custom ViewNode).

///|
/// Document info inspector width (MoMark parity).
const MARKDOWN_INFO_PANEL_WIDTH : Double = 240.0

///|
const MARKDOWN_INFO_CONTENT_WIDTH : Double = 212.0

///|
/// A label/value row.
fn[Msg] markdown_info_row(
  label : String,
  value : String,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.row(
    [
      @views.text(label, width=126.0, height=24.0, theme~)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      @views.text(value, width=80.0, height=24.0, theme~)
      .font(theme.typography.caption)
      .foreground(theme.palette.foreground),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
}

///|
/// A full-width hairline divider between metric groups.
fn[Msg] markdown_info_divider(theme : @moui.Theme) -> @moui.View[Msg] {
  @views.frame(
    @views.divider(theme~),
    width=MARKDOWN_INFO_CONTENT_WIDTH,
    height=1.0,
  )
}

///|
/// The document-info inspector. Counts come from
/// `markdown_document_info_from_session`/`_from_snapshot`; word/line/reading
/// values are passed explicitly so snapshot-based hosts work too.
pub fn[Msg] markdown_document_info_panel(
  theme~ : @moui.Theme,
  info~ : MarkdownDocumentInfo,
  word_count~ : Int,
  line_count~ : Int,
  reading_time_label~ : String,
  height~ : Double,
  width? : Double = MARKDOWN_INFO_PANEL_WIDTH,
  title? : String = "Info",
  words_label? : String = "Words",
  characters_label? : String = "Characters",
  lines_label? : String = "Lines",
  reading_label? : String = "Reading",
  headings_label? : String = "Headings",
  paragraphs_label? : String = "Paragraphs",
  list_items_label? : String = "List items",
  tasks_label? : String = "Tasks",
  quotes_label? : String = "Quotes",
  code_blocks_label? : String = "Code blocks",
  tables_label? : String = "Tables",
  links_label? : String = "Links",
  images_label? : String = "Images",
  footnotes_label? : String = "Footnotes",
) -> @moui.View[Msg] {
  let content_width = (width - 28.0).max(96.0)
  let rows = @views.column(
    [
      markdown_info_row(words_label, word_count.to_string(), theme),
      markdown_info_row(
        characters_label,
        info.character_count.to_string(),
        theme,
      ),
      markdown_info_row(lines_label, line_count.to_string(), theme),
      markdown_info_row(reading_label, reading_time_label, theme),
      markdown_info_divider(theme),
      markdown_info_row(headings_label, info.heading_count.to_string(), theme),
      markdown_info_row(
        paragraphs_label,
        info.paragraph_count.to_string(),
        theme,
      ),
      markdown_info_row(
        list_items_label,
        info.list_item_count.to_string(),
        theme,
      ),
      markdown_info_row(
        tasks_label,
        info.checked_task_count.to_string() + "/" + info.task_count.to_string(),
        theme,
      ),
      markdown_info_row(quotes_label, info.quote_count.to_string(), theme),
      markdown_info_divider(theme),
      markdown_info_row(
        code_blocks_label,
        info.code_block_count.to_string(),
        theme,
      ),
      markdown_info_row(tables_label, info.table_count.to_string(), theme),
      markdown_info_row(links_label, info.link_count.to_string(), theme),
      markdown_info_row(images_label, info.image_count.to_string(), theme),
      markdown_info_row(
        footnotes_label,
        info.footnote_reference_count.to_string() +
        "/" +
        info.footnote_definition_count.to_string(),
        theme,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Start,
  )
  @views.container(
    @views.padding_edges(
      @views.column(
        [
          @views.text(title, width=content_width, height=24.0, theme~)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          @views.scroll_view(
            rows,
            width=content_width,
            height=(height - 52.0).max(0.0),
          ),
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
    corner_radius=theme.radius_scale.sm,
    padding=0.0,
  )
}
