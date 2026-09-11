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
let rich_text_soft_wrap_cache : Map[String, RichTextBlockCacheEntry] = Map([])

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
  // The key is content identity, so a hit holds the offsets of whichever
  // block built the entry. Two identical paragraphs must not share one
  // source mapping: re-base the wrapped block onto this block's offsets
  // (same contract as the block-conversion cache).
  let source_start = rich_text_block_source_start(block)
  match rich_text_soft_wrap_cache.get(key) {
    Some(entry) => {
      hot_path_block_wrap_cache_hits.val = hot_path_block_wrap_cache_hits.val +
        1
      markdown_editor_rich_block_shift(
        entry.block,
        source_start - entry.source_start,
      )
    }
    None => {
      hot_path_block_wrap_builds.val = hot_path_block_wrap_builds.val + 1
      let wrapped = rich_text_document_view_wrap_block(
        block, width, base_font, text_system,
      )
      if rich_text_soft_wrap_cache.length() >= 4096 {
        rich_text_soft_wrap_cache.clear()
      }
      rich_text_soft_wrap_cache.set(key, { source_start, block: wrapped })
      wrapped
    }
  }
}

///|
/// The absolute source offset a block's own ranges start at. Every run and
/// cell offset inside the block is relative to it, so it is the anchor the
/// content-identity caches re-base on.
fn rich_text_block_source_start(block : RichTextBlock) -> Int {
  match block.source_range {
    Some(range) => range.start
    None =>
      match block.content_range {
        Some(range) => range.start
        None => 0
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
/// not change break positions and is deliberately excluded. Absolute
/// offsets are excluded too — the entry is re-based on a hit — but the
/// content offset inside the block is kept: hidden marker widths shift it
/// independently of the visible text.
fn rich_text_block_soft_wrap_key(
  block : RichTextBlock,
  width : Double,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> String {
  let block_font = rich_text_block_font(block, base_font)
  let content_offset = match (block.source_range, block.content_range) {
    (Some(source), Some(content)) => content.start - source.start
    _ => 0
  }
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
    content_offset.to_string(),
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
