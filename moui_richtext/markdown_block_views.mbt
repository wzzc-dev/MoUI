///|
/// A presentation-projection contribution for source-canonical blocks.
///
/// The block view registry lets display-only renderings (such as the raw
/// HTML container subset) plug into the rich-text conversion without
/// touching the block model: a contribution recognizes a block cheaply,
/// and either projects it into flat rich-text runs or declines so the
/// next contribution — or the raw source fallback — takes over. The
/// canonical block source stays the single editable truth; views may only
/// project it.
///|
pub struct MarkdownBlockViewContext {
  base : @core.FontSpec
  base_dir : String?
}

///|
pub struct MarkdownBlockViewProjection {
  runs : Array[RichTextRun]
  line_align : @core.TextAlign?
}

///|
pub struct MarkdownBlockView {
  name : String
  /// Cheap candidacy check: a prefix/tag-signature scan that must not do
  /// real parsing, so the height walk can probe every block with it.
  matches : (MarkdownBlock) -> Bool
  project : (MarkdownBlock, MarkdownBlockViewContext)
            -> MarkdownBlockViewProjection?
}

///|
/// Ordered contribution registry. Contributions are wired at compile time
/// by passing them into the editor assembly.
pub let markdown_block_views : Array[MarkdownBlockView] = [
  markdown_html_image_gallery_view,
]

///|
/// Project a block through the registry: first contribution whose
/// signature matches and whose projection succeeds wins; `None` means the
/// caller should keep the block raw.
fn markdown_block_view_project(
  block : MarkdownBlock,
  base : @core.FontSpec,
  base_dir~ : String?,
) -> MarkdownBlockViewProjection? {
  let context : MarkdownBlockViewContext = { base, base_dir }
  for view in markdown_block_views {
    if (view.matches)(block) {
      match (view.project)(block, context) {
        Some(projection) => return Some(projection)
        None => ()
      }
    }
  }
  None
}
