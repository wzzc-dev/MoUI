///|
/// Shared soft-wrap layer for rich text blocks (ADR 0001).
///
/// One memoized `TextSystem::layout_paragraph` pass per block content,
/// content width, font, and text system produces the visual text with
/// injected soft breaks; paint, block height, selection, caret, and
/// hit-test all consume the same result, so a caret lands exactly where
/// the text was drawn. Keys are content-identity (like the other caches
/// in this package): upstream edits keep entries valid and the cache
/// never needs eviction hooks beyond its size cap.

///|
let rich_text_soft_wrap_cache : Map[String, RichTextBlock] = Map([])

///|
/// Wrap one block for a laid out content width. Blocks whose geometry is
/// custom (rules, tables, image runs) pass through untouched, matching
/// the read-only viewer's policy.
fn rich_text_block_soft_wrap(
  block : RichTextBlock,
  width : Double,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> RichTextBlock {
  if width <= 0.0 ||
    block.rule ||
    block.table is Some(_) ||
    block.runs.is_empty() ||
    block.runs.any(run => run.image_source is Some(_)) {
    return block
  }
  let key = rich_text_block_soft_wrap_key(block, width, base_font, text_system)
  match rich_text_soft_wrap_cache.get(key) {
    Some(wrapped) => {
      hot_path_block_wrap_cache_hits.val = hot_path_block_wrap_cache_hits.val +
        1
      wrapped
    }
    None => {
      hot_path_block_wrap_builds.val = hot_path_block_wrap_builds.val + 1
      let wrapped = rich_text_document_view_wrap_block(
        block, width, base_font, text_system,
      )
      if rich_text_soft_wrap_cache.length() >= 4096 {
        rich_text_soft_wrap_cache.clear()
      }
      rich_text_soft_wrap_cache.set(key, wrapped)
      wrapped
    }
  }
}

///|
fn rich_text_document_soft_wrap(
  document : RichTextDocument,
  width : Double,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> RichTextDocument {
  {
    blocks: document.blocks.map(block => {
      rich_text_block_soft_wrap(block, width, base_font, text_system)
    }),
  }
}

///|
/// Cheap identity for the wrap inputs: the paragraph layout depends on
/// the laid out width, the vertical inset, the block line height, and the
/// visible text with the fonts that may draw it. Inline runs share one
/// layout pass, so per-run styling beyond the font (colors, links) does
/// not change break positions and is deliberately excluded.
fn rich_text_block_soft_wrap_key(
  block : RichTextBlock,
  width : Double,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> String {
  let block_font = rich_text_block_font(block, base_font)
  let parts : Array[String] = [
    "soft-wrap",
    text_system.id(),
    rich_text_cache_font_key(base_font),
    if block_font == base_font {
      ""
    } else {
      rich_text_cache_font_key(block_font)
    },
    width.to_string(),
    block.inset.left.to_string(),
    block.inset.right.to_string(),
    block.line_height.unwrap_or(-1.0).to_string(),
    block.prefix,
  ]
  for run in block.runs {
    parts.push(run.text)
    match run.font {
      Some(font) =>
        parts.push(
          if font == block_font {
            ""
          } else {
            rich_text_cache_font_key(font)
          },
        )
      None => parts.push("")
    }
  }
  rich_text_cache_join_key(parts)
}
