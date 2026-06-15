///|
pub fn rich_text_document_height(
  document : RichTextDocument,
  base_font : FontSpec,
) -> Double {
  let mut height = 0.0
  for block in document.blocks {
    height = height +
      rich_text_block_line_height(block, base_font) +
      block.inset.top +
      block.inset.bottom
  }
  height
}

///|
fn rich_text_block_line_height(
  block : RichTextBlock,
  base_font : FontSpec,
) -> Double {
  let text_height = rich_text_block_line_step(block, base_font)
  let mut height = text_height *
    rich_text_block_visual_line_count(block).to_double()
  match block.table {
    Some(table) =>
      height = max_double(
        height,
        table.row_height * table.rows.length().to_double(),
      )
    None => ()
  }
  for run in block.runs {
    match run.image_size {
      Some(size) => height = max_double(height, size.height)
      None => ()
    }
  }
  height
}

///|
fn rich_text_block_line_step(
  block : RichTextBlock,
  base_font : FontSpec,
) -> Double {
  block.line_height.unwrap_or(
    rich_text_block_font(block, base_font).size * 1.55,
  )
}

///|
fn rich_text_block_visual_line_count(block : RichTextBlock) -> Int {
  let mut line_count = 1
  line_count = line_count + rich_text_text_newline_count(block.prefix)
  for run in block.runs {
    line_count = line_count +
      rich_text_text_newline_count(rich_text_run_visual_text(run))
  }
  line_count
}

///|
fn rich_text_split_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  let current : Array[Char] = []
  for ch in text {
    if ch == '\n' {
      lines.push(String::from_array(current))
      current.clear()
    } else {
      current.push(ch)
    }
  }
  lines.push(String::from_array(current))
  lines
}

///|
fn rich_text_text_newline_count(text : String) -> Int {
  let mut count = 0
  for ch in text {
    if ch == '\n' {
      count = count + 1
    }
  }
  count
}

///|
fn rich_text_block_font(
  block : RichTextBlock,
  base_font : FontSpec,
) -> FontSpec {
  block.font.unwrap_or(base_font)
}

///|
fn rich_text_width(
  text : String,
  font : FontSpec,
  text_system : TextSystem,
) -> Double {
  text_system.measure_text(TextLayoutInput::new(text~, font~)).size.width
}

///|
fn rich_text_run_segment_width(
  run : RichTextRun,
  text : String,
  font : FontSpec,
  text_system : TextSystem,
) -> Double {
  match run.image_size {
    Some(size) => size.width
    None => rich_text_width(text, font, text_system)
  }
}

///|
fn rich_text_run_hit_width(run : RichTextRun, width : Double) -> Double? {
  match run.image_source {
    Some(_) => Some(width)
    None => None
  }
}
