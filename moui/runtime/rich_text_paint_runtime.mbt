///|
fn append_rich_text_editor_commands(
  commands : Array[DrawCommand],
  children : Array[RenderNode],
  post_commands : Array[DrawCommand],
  overlay_commands : Array[DrawCommand],
  element : ElementNode,
  data : RichTextEditorViewSpec,
  frame : Rect,
  focused : Bool,
  environment : RenderEnvironment,
) -> Unit {
  let border = if focused { data.focused_border } else { data.border }
  let rounded = RoundedRect::new(rect=frame, radius=data.corner_radius)
  commands.push(FillRoundedRectBrush(rounded, data.background))
  match border {
    Some(border) =>
      if border.width > 0.0 {
        commands.push(
          StrokeRoundedRectBrush(rounded, border.brush, border.width),
        )
      }
    None => ()
  }
  let text = data.value.get()
  let display_text = text_with_composition(text, element, focused)
  let content = rich_text_editor_content_rect(frame)
  commands.push(PushClip(content))
  if focused {
    overlay_commands.push(PushClip(content))
  }
  if display_text == "" {
    commands.push(
      DrawText(
        TextRun::new(
          text=data.placeholder,
          frame=content,
          font=environment.font.unwrap_or(data.font),
          color=data.placeholder_color,
          align=TextAlign::TextStart,
        ),
      ),
    )
  } else {
    let document = (data.format)(display_text)
    if focused && element.control.composition is None {
      append_rich_text_selection_commands(
        overlay_commands,
        document,
        content,
        environment.font.unwrap_or(data.font),
        environment.text_system,
        element.control.selection,
      )
    }
    if focused {
      append_rich_text_composition_underline(
        overlay_commands,
        document,
        element,
        text,
        display_text,
        content,
        data.font,
        environment.text_system,
        data.cursor_color,
      )
    }
    append_rich_text_block_layers(
      children,
      element,
      document,
      content,
      environment.font.unwrap_or(data.font),
      environment.foreground.unwrap_or(data.foreground),
      environment.text_system,
    )
  }
  if focused {
    append_rich_text_editor_cursor(
      overlay_commands,
      element,
      data,
      text,
      display_text,
      content,
      environment.text_system,
    )
    overlay_commands.push(PopClip)
  }
  post_commands.push(PopClip)
}

///|
fn append_rich_text_block_layers(
  children : Array[RenderNode],
  element : ElementNode,
  document : RichTextDocument,
  content : Rect,
  base_font : FontSpec,
  foreground : Color,
  text_system : TextSystem,
) -> Unit {
  let mut y = content.origin.y
  for index, block in document.blocks {
    let line_height = rich_text_block_line_height(block, base_font)
    let block_height = line_height + block.inset.top + block.inset.bottom
    if y > content.origin.y + content.size.height {
      return
    }
    let block_frame = Rect::new(
      x=content.origin.x,
      y~,
      width=content.size.width,
      height=block_height,
    )
    let block_commands : Array[DrawCommand] = []
    append_rich_text_block_commands(
      block_commands, block, block_frame, line_height, base_font, foreground, text_system,
    )
    children.push(
      rich_text_block_render_node(
        element.id,
        index,
        block,
        block_frame,
        block_commands,
        base_font,
        foreground,
      ),
    )
    y = y + block_height
  }
}

///|
fn append_rich_text_block_commands(
  commands : Array[DrawCommand],
  block : RichTextBlock,
  block_frame : Rect,
  line_height : Double,
  base_font : FontSpec,
  foreground : Color,
  text_system : TextSystem,
) -> Unit {
  match block.background {
    Some(background) =>
      commands.push(
        FillRoundedRectBrush(
          RoundedRect::new(rect=block_frame, radius=block.corner_radius),
          background,
        ),
      )
    None => ()
  }
  match block.border_left {
    Some(border) =>
      if border.width > 0.0 {
        commands.push(
          FillRoundedRectBrush(
            RoundedRect::new(
              rect=Rect::new(
                x=block_frame.origin.x,
                y=block_frame.origin.y + block.inset.top,
                width=border.width,
                height=line_height,
              ),
              radius=border.width / 2.0,
            ),
            border.brush,
          ),
        )
      }
    None => ()
  }
  if block.rule {
    commands.push(
      FillRect(
        Rect::new(
          x=block_frame.origin.x + block.inset.left,
          y=block_frame.origin.y + block_frame.size.height / 2.0,
          width=max_double(
            0.0,
            block_frame.size.width - block.inset.left - block.inset.right,
          ),
          height=1.5,
        ),
        rich_text_block_color(block, foreground).multiply_alpha(0.25),
      ),
    )
  } else if block.table is Some(_) {
    append_rich_text_block_table(
      commands,
      block,
      Rect::new(
        x=block_frame.origin.x + block.inset.left,
        y=block_frame.origin.y + block.inset.top,
        width=max_double(
          0.0,
          block_frame.size.width - block.inset.left - block.inset.right,
        ),
        height=line_height,
      ),
      base_font,
      foreground,
    )
  } else {
    append_rich_text_block_runs(
      commands,
      block,
      Rect::new(
        x=block_frame.origin.x + block.inset.left,
        y=block_frame.origin.y + block.inset.top,
        width=max_double(
          0.0,
          block_frame.size.width - block.inset.left - block.inset.right,
        ),
        height=line_height,
      ),
      base_font,
      foreground,
      text_system,
    )
  }
}

///|
fn rich_text_block_render_node(
  editor_id : ElementId,
  index : Int,
  block : RichTextBlock,
  frame : Rect,
  commands : Array[DrawCommand],
  base_font : FontSpec,
  foreground : Color,
) -> RenderNode {
  let paint_bounds = render_node_paint_bounds(frame, commands, [], [], [])
  {
    element_id: editor_id,
    frame,
    children: [],
    paint_bounds,
    content_revision: rich_text_block_content_revision(
      block, index, frame, base_font, foreground,
    ),
    is_repaint_boundary: true,
    layer_cache_key: Some(
      rich_text_block_cache_key(editor_id, index, block, frame),
    ),
    paint_commands: commands,
    post_paint_commands: [],
    overlay_paint_commands: [],
    platform_views: [],
    cached_draw_commands: Some(commands),
    cached_overlay_draw_commands: None,
  }
}

///|
fn rich_text_block_cache_key(
  editor_id : ElementId,
  index : Int,
  block : RichTextBlock,
  frame : Rect,
) -> String {
  "rich-text-block;element=\{editor_id.value()};range=\{rich_text_source_range_key(block.source_range)};index=\{index};w=\{frame.size.width};h=\{frame.size.height}"
}

///|
fn rich_text_block_content_revision(
  block : RichTextBlock,
  index : Int,
  frame : Rect,
  base_font : FontSpec,
  foreground : Color,
) -> Int {
  let mut hash = rich_text_hash_mix_int(5381, index)
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_source_range_key(block.source_range),
  )
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_source_range_key(block.content_range),
  )
  hash = rich_text_hash_mix_string(hash, block.prefix)
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_font_key(block.font.unwrap_or(base_font)),
  )
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_color_key(block.color.unwrap_or(foreground)),
  )
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_brush_optional_key(block.background),
  )
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_border_optional_key(block.border_left),
  )
  hash = rich_text_hash_mix_string(hash, rich_text_insets_key(block.inset))
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_double_optional_key(block.line_height),
  )
  hash = rich_text_hash_mix_string(hash, "\{block.corner_radius}")
  hash = rich_text_hash_mix_int(hash, if block.rule { 1 } else { 0 })
  hash = rich_text_hash_mix_string(
    hash,
    "\{frame.size.width}x\{frame.size.height}",
  )
  for run in block.runs {
    hash = rich_text_hash_mix_string(hash, run.text)
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_optional_string_key(run.visual_text),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_optional_string_key(run.image_source),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_size_optional_key(run.image_size),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_image_fit_key(run.image_fit),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_font_optional_key(run.font),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_color_optional_key(run.color),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_brush_optional_key(run.background),
    )
    hash = rich_text_hash_mix_string(hash, "\{run.background_radius}")
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_decoration_key(run.decoration),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_source_range_key(run.source_range),
    )
  }
  match block.table {
    Some(table) => {
      hash = rich_text_hash_mix_string(hash, "\{table.row_height}")
      hash = rich_text_hash_mix_string(
        hash,
        rich_text_insets_key(table.cell_padding),
      )
      hash = rich_text_hash_mix_string(hash, rich_text_color_key(table.border))
      hash = rich_text_hash_mix_string(
        hash,
        rich_text_brush_optional_key(table.header_background),
      )
      for row in table.rows {
        for cell in row {
          hash = rich_text_hash_mix_string(hash, cell.text)
          hash = rich_text_hash_mix_int(hash, if cell.header { 1 } else { 0 })
          hash = rich_text_hash_mix_string(
            hash,
            rich_text_align_optional_key(cell.align),
          )
          hash = rich_text_hash_mix_string(
            hash,
            rich_text_source_range_key(cell.source_range),
          )
        }
      }
    }
    None => ()
  }
  if hash < 0 {
    -hash
  } else {
    hash
  }
}

///|
fn rich_text_source_range_key(range : RichTextSourceRange?) -> String {
  match range {
    Some(range) => "len=\{max_int(0, range.end - range.start)}"
    None => "none"
  }
}

///|
fn rich_text_optional_string_key(value : String?) -> String {
  value.unwrap_or("none")
}

///|
fn rich_text_size_optional_key(value : Size?) -> String {
  match value {
    Some(size) => "\{size.width}x\{size.height}"
    None => "none"
  }
}

///|
fn rich_text_double_optional_key(value : Double?) -> String {
  match value {
    Some(value) => "\{value}"
    None => "none"
  }
}

///|
fn rich_text_font_optional_key(value : FontSpec?) -> String {
  match value {
    Some(font) => rich_text_font_key(font)
    None => "none"
  }
}

///|
fn rich_text_font_key(font : FontSpec) -> String {
  "\{font.css_family()}|\{font.size}|\{font.weight}|\{font.css_style()}"
}

///|
fn rich_text_color_optional_key(value : Color?) -> String {
  match value {
    Some(color) => rich_text_color_key(color)
    None => "none"
  }
}

///|
fn rich_text_color_key(color : Color) -> String {
  "\{color.r},\{color.g},\{color.b},\{color.a}"
}

///|
fn rich_text_brush_optional_key(value : Brush?) -> String {
  match value {
    Some(brush) => rich_text_brush_key(brush)
    None => "none"
  }
}

///|
fn rich_text_brush_key(brush : Brush) -> String {
  match brush {
    Solid(color) => "solid:\{rich_text_color_key(color)}"
    LinearGradient(spec) =>
      "linear:\{spec.start.x},\{spec.start.y},\{spec.end.x},\{spec.end.y},\{rich_text_color_key(spec.start_color)},\{rich_text_color_key(spec.end_color)}"
    RadialGradient(spec) =>
      "radial:\{spec.center.x},\{spec.center.y},\{spec.radius},\{rich_text_color_key(spec.center_color)},\{rich_text_color_key(spec.edge_color)}"
  }
}

///|
fn rich_text_border_optional_key(value : BorderStyle?) -> String {
  match value {
    Some(border) => "\{rich_text_brush_key(border.brush)}|\{border.width}"
    None => "none"
  }
}

///|
fn rich_text_insets_key(insets : Insets) -> String {
  "\{insets.top},\{insets.right},\{insets.bottom},\{insets.left}"
}

///|
fn rich_text_image_fit_key(fit : ImageFit) -> String {
  match fit {
    Contain => "contain"
    Cover => "cover"
    Stretch => "stretch"
    ScaleDown => "scale-down"
    FitWidth => "fit-width"
    FitHeight => "fit-height"
  }
}

///|
fn rich_text_decoration_key(value : RichTextDecoration?) -> String {
  match value {
    Some(Strikethrough) => "strikethrough"
    None => "none"
  }
}

///|
fn rich_text_align_optional_key(value : TextAlign?) -> String {
  match value {
    Some(TextStart) => "start"
    Some(TextCenter) => "center"
    Some(TextEnd) => "end"
    None => "none"
  }
}

///|
fn rich_text_string_hash(value : String) -> Int {
  let mut hash = 5381
  for ch in value.to_array() {
    hash = hash * 33 + ch.to_int()
  }
  hash
}

///|
fn rich_text_hash_mix_int(hash : Int, value : Int) -> Int {
  hash * 33 + value
}

///|
fn rich_text_hash_mix_string(hash : Int, value : String) -> Int {
  hash * 33 + rich_text_string_hash(value)
}

///|
fn append_rich_text_block_table(
  commands : Array[DrawCommand],
  block : RichTextBlock,
  frame : Rect,
  base_font : FontSpec,
  foreground : Color,
) -> Unit {
  match block.table {
    Some(table) => {
      let row_count = table.rows.length()
      let column_count = rich_text_table_column_count(table)
      if row_count == 0 || column_count == 0 {
        return
      }
      let column_width = frame.size.width / column_count.to_double()
      for row_index in 0..<row_count {
        let row_y = frame.origin.y + table.row_height * row_index.to_double()
        if row_index == 0 {
          match table.header_background {
            Some(background) =>
              commands.push(
                FillRoundedRectBrush(
                  RoundedRect::new(
                    rect=Rect::new(
                      x=frame.origin.x,
                      y=row_y,
                      width=frame.size.width,
                      height=table.row_height,
                    ),
                    radius=block.corner_radius,
                  ),
                  background,
                ),
              )
            None => ()
          }
        }
        let row = table.rows[row_index]
        for column_index in 0..<column_count {
          let cell_x = frame.origin.x + column_width * column_index.to_double()
          let cell_frame = Rect::new(
            x=cell_x,
            y=row_y,
            width=column_width,
            height=table.row_height,
          )
          commands.push(StrokeRect(cell_frame, table.border, 1.0))
          if column_index < row.length() {
            let cell = row[column_index]
            commands.push(
              DrawText(
                TextRun::new(
                  text=cell.text,
                  frame=cell_frame.inset(table.cell_padding),
                  font={
                    ..rich_text_block_font(block, base_font),
                    weight: if cell.header {
                      700
                    } else {
                      400
                    },
                  },
                  color=rich_text_block_color(block, foreground),
                  align=cell.align.unwrap_or(TextAlign::TextStart),
                ),
              ),
            )
          }
        }
      }
    }
    None => ()
  }
}

///|
fn append_rich_text_block_runs(
  commands : Array[DrawCommand],
  block : RichTextBlock,
  frame : Rect,
  base_font : FontSpec,
  foreground : Color,
  text_system : TextSystem,
) -> Unit {
  let font = rich_text_block_font(block, base_font)
  let color = rich_text_block_color(block, foreground)
  let line_height = rich_text_block_line_step(block, base_font)
  let mut x = frame.origin.x
  let mut line = 0
  if block.prefix != "" {
    let width = rich_text_width(block.prefix, font, text_system)
    commands.push(
      DrawText(
        TextRun::new(
          text=block.prefix,
          frame=Rect::new(
            x~,
            y=frame.origin.y,
            width~,
            height=frame.size.height,
          ),
          font~,
          color~,
          align=TextAlign::TextStart,
        ),
      ),
    )
    x = x + width
  }
  for run in block.runs {
    let run_font = run.font.unwrap_or(font)
    let run_color = run.color.unwrap_or(color)
    let segments = rich_text_split_lines(rich_text_run_visual_text(run))
    for index, segment in segments {
      let width = rich_text_run_segment_width(
        run, segment, run_font, text_system,
      )
      let line_y = frame.origin.y + line.to_double() * line_height
      let run_frame = Rect::new(
        x~,
        y=line_y,
        width=max_double(
          0.0,
          min_double(width, frame.origin.x + frame.size.width - x),
        ),
        height=rich_text_run_segment_height(run, line_height),
      )
      if segment != "" || run.image_source is Some(_) {
        append_rich_text_run_segment(
          commands, run, segment, run_frame, width, run_font, run_color,
        )
      }
      if index + 1 < segments.length() {
        line = line + 1
        x = frame.origin.x
      } else {
        x = x + width
      }
    }
  }
}

///|
fn append_rich_text_run_segment(
  commands : Array[DrawCommand],
  run : RichTextRun,
  text : String,
  run_frame : Rect,
  width : Double,
  font : FontSpec,
  color : Color,
) -> Unit {
  match run.background {
    Some(background) =>
      commands.push(
        FillRoundedRectBrush(
          RoundedRect::new(
            rect=Rect::new(
              x=run_frame.origin.x - 3.0,
              y=run_frame.origin.y + 4.0,
              width=width + 6.0,
              height=max_double(12.0, run_frame.size.height - 8.0),
            ),
            radius=run.background_radius,
          ),
          background,
        ),
      )
    None => ()
  }
  match run.image_source {
    Some(source) =>
      commands.push(
        DrawImage({ source, frame: run_frame, opacity: 1.0, fit: run.image_fit }),
      )
    None =>
      commands.push(
        DrawText(
          TextRun::new(
            text~,
            frame=run_frame,
            font~,
            color~,
            align=TextAlign::TextStart,
          ),
        ),
      )
  }
  append_rich_text_run_decoration(commands, run, run_frame, width, font, color)
}

///|
fn append_rich_text_run_decoration(
  commands : Array[DrawCommand],
  run : RichTextRun,
  frame : Rect,
  width : Double,
  font : FontSpec,
  color : Color,
) -> Unit {
  match run.decoration {
    Some(Strikethrough) => {
      let thickness = max_double(1.0, font.size / 14.0)
      commands.push(
        FillRect(
          Rect::new(
            x=frame.origin.x,
            y=frame.origin.y + frame.size.height * 0.52,
            width~,
            height=thickness,
          ),
          color.multiply_alpha(0.72),
        ),
      )
    }
    None => ()
  }
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
fn rich_text_document_height(
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
fn rich_text_block_font(
  block : RichTextBlock,
  base_font : FontSpec,
) -> FontSpec {
  block.font.unwrap_or(base_font)
}

///|
fn rich_text_block_color(block : RichTextBlock, foreground : Color) -> Color {
  block.color.unwrap_or(foreground)
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
fn rich_text_run_segment_height(
  run : RichTextRun,
  line_height : Double,
) -> Double {
  match run.image_size {
    Some(size) => max_double(line_height, size.height)
    None => line_height
  }
}

///|
fn rich_text_run_hit_width(run : RichTextRun, width : Double) -> Double? {
  match run.image_source {
    Some(_) => Some(width)
    None => None
  }
}

///|
fn append_rich_text_editor_cursor(
  commands : Array[DrawCommand],
  element : ElementNode,
  data : RichTextEditorViewSpec,
  text : String,
  display_text : String,
  content : Rect,
  text_system : TextSystem,
) -> Unit {
  let document = (data.format)(display_text)
  let caret = clamp_int(
    text_field_visual_caret(text, element, true),
    0,
    text_length(text),
  )
  let rect = rich_text_document_caret_rect(
    document,
    caret,
    content,
    data.font,
    text_system,
  ).unwrap_or(
    rich_text_caret_rect(display_text, caret, content, data.font, text_system),
  )
  commands.push(
    FillRoundedRectBrush(
      RoundedRect::new(rect~, radius=1.0),
      Brush::solid(data.cursor_color),
    ),
  )
}

///|
fn append_rich_text_composition_underline(
  commands : Array[DrawCommand],
  document : RichTextDocument,
  element : ElementNode,
  text : String,
  display_text : String,
  content : Rect,
  font : FontSpec,
  text_system : TextSystem,
  cursor_color : Color,
) -> Unit {
  match element.control.composition {
    Some(composition) =>
      if composition != "" {
        let start = composition_start_index(
          text,
          element.control.caret,
          element.control.selection,
        )
        let end = start + text_length(composition)
        let start_rect = rich_text_document_caret_rect(
          document, start, content, font, text_system,
        ).unwrap_or(
          rich_text_caret_rect(display_text, start, content, font, text_system),
        )
        let end_rect = rich_text_document_caret_rect(
          document, end, content, font, text_system,
        ).unwrap_or(
          rich_text_caret_rect(display_text, end, content, font, text_system),
        )
        if end_rect.origin.x > start_rect.origin.x {
          commands.push(
            FillRect(
              Rect::new(
                x=start_rect.origin.x,
                y=start_rect.origin.y + start_rect.size.height - 5.0,
                width=end_rect.origin.x - start_rect.origin.x,
                height=1.5,
              ),
              cursor_color.with_alpha(0.72),
            ),
          )
        }
      }
    None => ()
  }
}
