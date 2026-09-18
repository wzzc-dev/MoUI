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
    match block.marker {
      Some(RichTextMarker::TaskCheckbox(checked)) =>
        if checked {
          "task-checkbox:checked"
        } else {
          "task-checkbox"
        }
      None => ""
    },
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

///|
priv struct RichTextWrapCluster {
  offset : Int
  text : String
  advance : Double
}

///|
/// A wrap may occur after this cluster. CJK characters and slashes are
/// breakable after (standard Chinese line breaking: any two Han characters
/// may split, and paths break at `/`); Latin words stay whole and only break
/// at whitespace or hyphens.
fn rich_text_wrap_breakable_after(cluster : String) -> Bool {
  let chars = cluster.to_array()
  match chars.get(0) {
    Some(ch) => {
      let code = ch.to_int()
      if ch == ' ' || ch == '\t' || ch == '-' || ch == '/' {
        true
      } else if code >= 0x2E80 {
        // CJK radicals, ideographs, kana, fullwidth forms.
        true
      } else {
        false
      }
    }
    None => false
  }
}

///|
/// A line must not START with these clusters (closing punctuation and
/// slashes that belong to the preceding token).
fn rich_text_wrap_cannot_start_line(cluster : String) -> Bool {
  match cluster {
    "、"
    | "，"
    | "。"
    | "；"
    | "："
    | "）"
    | "！"
    | "？"
    | "》"
    | "」"
    | "』"
    | ")"
    | "%"
    | "."
    | ","
    | ";"
    | ":"
    | "!"
    | "?"
    | "/" => true
    _ => false
  }
}

///|
/// A line must not END with these clusters (opening punctuation).
fn rich_text_wrap_cannot_end_line(cluster : String) -> Bool {
  match cluster {
    "（" | "《" | "「" | "『" | "(" | "[" | "{" => true
    _ => false
  }
}

///|
/// Soft-break offsets derived from `TextSystem::measure_text` — the same
/// measurement the draw pass uses for its glyph runs. The paragraph layout
/// shapes fallback runs differently from the single-run draw path, and the
/// few points of drift per dense line pushed the line's last glyph past the
/// paint frame's clip edge (a half-drawn 绘/宿 at line ends). Breaking on the
/// draw measurement keeps every wrapped line inside the clip by construction.
fn rich_text_measure_based_soft_breaks(
  block : RichTextBlock,
  available_width~ : Double,
  base_font~ : @core.FontSpec,
  text_system~ : @core.TextSystem,
) -> Array[Int] {
  let breaks : Array[Int] = []
  if available_width <= 1.0 {
    return breaks
  }
  let block_font = rich_text_block_font(block, base_font)
  let clusters : Array[RichTextWrapCluster] = []
  // The joined visual text is the prefix followed by each run's visual text;
  // measure every segment once with the font that will draw it.
  let segments : Array[(String, @core.FontSpec, Int)] = []
  segments.push((block.prefix, block_font, 0))
  let mut run_offset = text_length(block.prefix)
  for run in block.runs {
    let run_visual = rich_text_run_visual_text(run)
    segments.push((run_visual, run.font.unwrap_or(block_font), run_offset))
    run_offset = run_offset + text_length(run_visual)
  }
  for segment in segments {
    let (text, font, base_offset) = segment
    if text == "" {
      continue
    }
    let chars = text.to_array()
    let measured = text_system.measure_text(
      @core.TextLayoutInput::new(text~, font~),
    )
    let carets = measured.caret_positions
    let boundaries = @core.TextGraphemeBoundaries::new(text~)
    let mut cursor = 0
    while cursor < chars.length() {
      let next = boundaries.next_boundary(cursor)
      let end = @core.min_int(next, chars.length())
      let advance_start = carets.get(cursor).unwrap_or(0.0)
      let advance_end = carets.get(end).unwrap_or(advance_start)
      clusters.push({
        offset: base_offset + cursor,
        text: String::from_array(chars[cursor:end]),
        advance: max_double(0.0, advance_end - advance_start),
      })
      cursor = end
    }
  }
  // Greedy fill with kinsoku: a line never starts with closing punctuation
  // (or a stray slash) and never ends with opening punctuation. Whitespace
  // and closing punctuation hang at the line end without forcing a break.
  let breaks : Array[Int] = []
  let cluster_count = clusters.length()
  let mut i = 0
  let mut line_width = 0.0
  let mut line_has_content = false
  let mut break_after_offset = -1
  let mut width_since_break = 0.0
  while i < cluster_count {
    let cluster = clusters[i]
    if cluster.text == "\n" {
      // Hard break: reset the line; the run splitter guards double \n.
      line_width = 0.0
      line_has_content = false
      break_after_offset = -1
      width_since_break = 0.0
      i = i + 1
      continue
    }
    let width = cluster.advance
    let overflow = line_has_content && line_width + width > available_width
    if overflow && break_after_offset >= 0 {
      // Break at the recorded opportunity, then apply kinsoku adjustments.
      let mut break_offset = break_after_offset
      // (a) A line may not end with opening punctuation: pull the break back
      // over any opening cluster it would strand at the line end.
      let mut pulled = true
      while pulled {
        pulled = false
        let prev_end = break_offset
        for candidate in clusters {
          if candidate.offset + candidate.text.to_array().length() == prev_end &&
            rich_text_wrap_cannot_end_line(candidate.text) {
            break_offset = candidate.offset
            pulled = true
            break
          }
        }
      }
      // (b) A line may not start with closing punctuation (or a stray slash):
      // push the break past them so they stay with the preceding token.
      let mut pushed = true
      while pushed {
        pushed = false
        for candidate in clusters {
          if candidate.offset == break_offset &&
            rich_text_wrap_cannot_start_line(candidate.text) {
            break_offset = candidate.offset + candidate.text.to_array().length()
            pushed = true
            break
          }
        }
      }
      breaks.push(break_offset)
      // The new line carries every processed cluster from break_offset on.
      line_width = 0.0
      let mut j = i
      while j >= 0 && clusters[j].offset >= break_offset {
        line_width = line_width + clusters[j].advance
        j = j - 1
      }
      if j + 1 > i {
        // The kinsoku push moved the break past the current cluster.
        i = j + 1
        line_width = 0.0
        line_has_content = false
        break_after_offset = -1
        width_since_break = 0.0
        continue
      }
      line_has_content = true
      break_after_offset = -1
      width_since_break = 0.0
      i = i + 1
      continue
    }
    if overflow {
      // No opportunity in the line: break before the current cluster.
      breaks.push(cluster.offset)
      line_width = width
      break_after_offset = -1
      width_since_break = 0.0
      line_has_content = true
      i = i + 1
      continue
    }
    line_width = line_width + width
    line_has_content = true
    if rich_text_wrap_breakable_after(cluster.text) {
      break_after_offset = cluster.offset + cluster.text.to_array().length()
      width_since_break = 0.0
    } else {
      width_since_break = width_since_break + width
    }
    i = i + 1
  }
  breaks
}
