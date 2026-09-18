///|
fn rich_text_with_composition(
  text : String,
  control : @core.TextControlStateContext,
  focused~ : Bool,
) -> String {
  if !focused {
    text
  } else {
    match control.composition {
      Some(composition) =>
        replace_current_selection(
          text,
          control.caret,
          control.selection,
          composition,
        ).text
      None => text
    }
  }
}

///|
fn rich_text_visual_caret(
  text : String,
  control : @core.TextControlStateContext,
  focused~ : Bool,
) -> Int {
  let caret = @core.clamp_int(control.caret, 0, text_length(text))
  if !focused {
    caret
  } else {
    match control.composition {
      Some(composition) =>
        @core.composition_start_index(text, control.caret, control.selection) +
        @core.composition_cursor_offset(control, composition)
      None => caret
    }
  }
}

///|
fn rich_text_document_caret_rect_or_plain(
  document : RichTextDocument,
  source_caret : Int,
  content : @core.Rect,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
  display_text : String,
) -> @core.Rect {
  match
    rich_text_document_caret_rect_at_source(
      document,
      source_caret,
      content,
      font,
      text_system~,
    ) {
    Some(rect) => rect
    None =>
      plain_rich_text_caret_rect(
        display_text, source_caret, content, font, text_system,
      )
  }
}

///|
fn plain_rich_text_caret_rect(
  text : String,
  caret : Int,
  content : @core.Rect,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> @core.Rect {
  let prefix = string_prefix(text, caret)
  let width = text_system.measure_text(
      @core.TextLayoutInput::new(
        text=prefix,
        font~,
        max_width=content.size.width,
      ),
    ).size.width
  @core.Rect::new(
    x=content.origin.x + width,
    y=content.origin.y + 4.0,
    width=1.5,
    height=max_double(10.0, font.size * 1.55 - 8.0),
  )
}

///|
fn[Msg] rich_text_line_edge_move_result(
  ctx : @core.ViewEventContext,
  text : String,
  home~ : Bool,
  on_selection_change : ((Int, @core.TextRange?) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let caret = if home {
    multiline_line_start(text, ctx.text_control.caret)
  } else {
    multiline_line_end(text, ctx.text_control.caret)
  }
  let next_control = {
    ..ctx.text_control,
    caret,
    selection: None,
    composition: None,
    composition_cursor: None,
  }
  let changed = next_control.caret != ctx.text_control.caret ||
    ctx.text_control.selection is Some(_) ||
    ctx.text_control.composition is Some(_) ||
    ctx.text_control.composition_cursor is Some(_)
  view_event_result(
    changed~,
    captured=true,
    text_control=Some(next_control),
    dirty=@core.ViewDirtyHint::ViewPaintDirty,
    messages=if changed {
      selection_messages(
        on_selection_change,
        next_control.caret,
        next_control.selection,
      )
    } else {
      []
    },
  )
}

///|
fn rich_text_vertical_target_offset(
  document : RichTextDocument,
  source_caret : Int,
  caret_rect : @core.Rect,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  up~ : Bool,
) -> Int {
  if document.blocks.is_empty() {
    let line_height = if caret_rect.size.height > 0.0 {
      caret_rect.size.height
    } else {
      max_double(10.0, base_font.size * 1.55 - 8.0)
    }
    let target_y = if up {
      caret_rect.origin.y - line_height * 0.5
    } else {
      caret_rect.origin.y + caret_rect.size.height + line_height * 0.5
    }
    let target_point = @core.Point::new(x=caret_rect.origin.x, y=target_y)
    return rich_text_document_source_offset_at_point(
      document, target_point, content, base_font, text_system,
    ).unwrap_or(source_caret)
  }
  let mut block_index = -1
  let mut visual_line = 0
  let mut y = content.origin.y
  for index, block in document.blocks {
    let line_height = rich_text_block_line_height(
      block,
      base_font,
      text_system,
      block_width=content.size.width,
    )
    let block_height = line_height + block.inset.top + block.inset.bottom
    if rich_text_caret_before_block(source_caret, block) {
      block_index = index
      visual_line = 0
      break
    }
    match block.table {
      Some(_) => {
        // Stop on the table only when the caret maps into it; a caret below
        // the table must keep walking to its own block, exactly like the
        // caret rect walk.
        let caret_in_table = match block.source_range {
          Some(range) => source_caret <= range.end
          None => false
        }
        if caret_in_table {
          block_index = index
          visual_line = 0
          break
        }
      }
      None => ()
    }
    match rich_text_block_visual_offset(block, source_caret) {
      Some(vo) => {
        block_index = index
        visual_line = rich_text_visual_offset_to_line(block, vo)
        break
      }
      None => ()
    }
    y = y + block_height
  }
  if block_index < 0 {
    block_index = document.blocks.length() - 1
    let last_block = document.blocks[block_index]
    visual_line = rich_text_block_visual_line_count(last_block) - 1
    let last_line_height = rich_text_block_line_height(
      last_block,
      base_font,
      text_system,
      block_width=content.size.width,
    )
    let last_block_height = last_line_height +
      last_block.inset.top +
      last_block.inset.bottom
    y = y - last_block_height
  }
  let block = document.blocks[block_index]
  let step = rich_text_block_line_step(block, base_font, text_system)
  let frame_top = y + block.inset.top
  let line_count = rich_text_block_visual_line_count(block)
  // Leaving the block: step straight to the neighbouring line, skipping the
  // paragraph separators (blocks with no line box) in between. The pointer hit
  // test is deliberately not used here — its half-band rule answers "which
  // line did I click", not "which way am I travelling".
  if (up && visual_line == 0) || (!up && visual_line >= line_count - 1) {
    return rich_text_vertical_block_boundary_offset(
      document,
      block_index,
      source_caret,
      base_font,
      text_system,
      up~,
    )
  }
  let line_center_y = if visual_line >= 0 && visual_line < line_count {
    frame_top + (visual_line.to_double() + 0.5) * step
  } else {
    caret_rect.origin.y + caret_rect.size.height * 0.5
  }
  // Within the block: keep the caret column and move one visual line.
  let target_point = @core.Point::new(
    x=caret_rect.origin.x + caret_rect.size.width * 0.5,
    y=if up { line_center_y - step } else { line_center_y + step },
  )
  match
    rich_text_document_source_offset_at_point(
      document, target_point, content, base_font, text_system,
    ) {
    Some(offset) => offset
    None =>
      rich_text_vertical_block_boundary_offset(
        document,
        block_index,
        source_caret,
        base_font,
        text_system,
        up~,
      )
  }
}

///|
/// A blank line renders as an empty paragraph with no runs. Vertical caret
/// movement stops on it like on any other line: the caret walks into the
/// blank line and it expands to the writing line while the caret is there.
fn rich_text_block_is_blank_gap(block : RichTextBlock) -> Bool {
  block.runs.is_empty() &&
  block.prefix == "" &&
  block.table is None &&
  !block.rule
}

///|
fn rich_text_vertical_block_boundary_offset(
  document : RichTextDocument,
  block_index : Int,
  source_caret : Int,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  up~ : Bool,
) -> Int {
  // Blocks with no line box are pure spacing — the paragraph separator a
  // blank source line renders as — so the caret steps over them to the
  // neighbouring line, exactly like the pointer hit test does.
  if up {
    let mut index = block_index - 1
    while index >= 0 {
      let prev_block = document.blocks[index]
      if rich_text_block_line_height(prev_block, base_font, text_system) <= 0.0 {
        index = index - 1
        continue
      }
      return match rich_text_block_end_source_offset(prev_block) {
        Some(end) => end
        None => source_caret
      }
    }
    0
  } else {
    let mut index = block_index + 1
    while index < document.blocks.length() {
      let next_block = document.blocks[index]
      if rich_text_block_line_height(next_block, base_font, text_system) <= 0.0 {
        index = index + 1
        continue
      }
      return match next_block.content_range {
        Some(range) => range.start
        None =>
          match next_block.source_range {
            Some(range) => range.start
            None => source_caret
          }
      }
    }
    source_caret
  }
}

///|
fn rich_text_visual_offset_to_line(
  block : RichTextBlock,
  visual_offset : Int,
) -> Int {
  let prefix_len = text_length(block.prefix)
  let mut consumed = prefix_len
  let mut line = 0
  if visual_offset <= prefix_len {
    return 0
  }
  for run in block.runs {
    let segments = rich_text_split_lines(rich_text_run_visual_text(run))
    for index, segment in segments {
      let seg_len = text_length(segment)
      if consumed + seg_len >= visual_offset {
        return line
      }
      consumed = consumed + seg_len
      if index + 1 < segments.length() {
        if consumed == visual_offset {
          return line
        }
        consumed = consumed + 1
        line = line + 1
      }
    }
  }
  line
}

///|
fn[Msg] rich_text_vertical_caret_move_result(
  ctx : @core.ViewEventContext,
  text : String,
  document : RichTextDocument,
  content : @core.Rect,
  font : @core.FontSpec,
  up~ : Bool,
  extend_selection~ : Bool,
  on_selection_change : ((Int, @core.TextRange?) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let display_text = rich_text_with_composition(
    text,
    ctx.text_control,
    focused=true,
  )
  let visual_caret = @core.clamp_int(
    rich_text_visual_caret(text, ctx.text_control, focused=true),
    0,
    text_length(display_text),
  )
  let caret_rect = rich_text_document_caret_rect_or_plain(
    document,
    visual_caret,
    content,
    font,
    ctx.text_system,
    display_text,
  )
  let target_offset = rich_text_vertical_target_offset(
    document,
    visual_caret,
    caret_rect,
    content,
    font,
    ctx.text_system,
    up~,
  )
  if target_offset == ctx.text_control.caret && !extend_selection {
    return @core.ViewEventResult::ignored()
  }
  let next_control = if extend_selection {
    let anchor = match ctx.text_control.text_selection_anchor {
      Some(a) => a
      None => ctx.text_control.caret
    }
    let start = @core.min_int(anchor, target_offset)
    let end = @core.max_int(anchor, target_offset)
    {
      ..ctx.text_control,
      caret: target_offset,
      selection: Some(@core.TextRange::new(start~, end~)),
      text_selection_anchor: Some(anchor),
      composition: None,
      composition_cursor: None,
    }
  } else {
    {
      ..ctx.text_control,
      caret: target_offset,
      selection: None,
      text_selection_anchor: None,
      composition: None,
      composition_cursor: None,
    }
  }
  let changed = next_control.caret != ctx.text_control.caret ||
    next_control.selection != ctx.text_control.selection ||
    ctx.text_control.composition is Some(_) ||
    ctx.text_control.composition_cursor is Some(_)
  view_event_result(
    changed~,
    captured=true,
    text_control=Some(next_control),
    dirty=@core.ViewDirtyHint::ViewPaintDirty,
    messages=if changed {
      selection_messages(
        on_selection_change,
        next_control.caret,
        next_control.selection,
      )
    } else {
      []
    },
  )
}

///|
fn multiline_line_start(text : String, caret : Int) -> Int {
  let chars = text.to_array()
  let mut index = @core.clamp_int(caret, 0, chars.length())
  while index > 0 && chars[index - 1] != '\n' {
    index = index - 1
  }
  index
}

///|
fn multiline_line_end(text : String, caret : Int) -> Int {
  let chars = text.to_array()
  let mut index = @core.clamp_int(caret, 0, chars.length())
  while index < chars.length() && chars[index] != '\n' {
    index = index + 1
  }
  index
}

///|
fn rich_text_transform_insert(
  input_transform : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)?,
  text : String,
  control : @core.TextControlStateContext,
  inserted : String,
) -> RichTextInputTransform? {
  match input_transform {
    Some(transform) =>
      transform(text, control.caret, control.selection, inserted)
    None => None
  }
}

///|
fn apply_rich_text_input_transform(
  control : @core.TextControlStateContext,
  previous : String,
  edit : RichTextInputTransform,
  record_history~ : Bool,
) -> TextInputApplyResult {
  let changed = edit.text != previous ||
    edit.caret != control.caret ||
    edit.selection != control.selection ||
    control.composition is Some(_) ||
    control.composition_cursor is Some(_)
  if changed {
    let undo_stack : Array[@core.TextHistoryEntryContext] = []
    undo_stack.append(control.undo_stack)
    // The transform API only exposes before/after documents, so the edit
    // record and history entry come from a one-shot prefix/suffix diff.
    let (start, before, after) = @core.text_history_delta(previous, edit.text)
    if record_history && previous != edit.text {
      rich_text_history_extend_stack(
        undo_stack,
        rich_text_history_record_edit(
          control,
          previous,
          edit.text,
          control.caret,
          shape=Some(
            rich_text_history_edit_shape_at(
              start,
              before,
              after,
              control.caret,
              selection_active=@core.active_text_selection(control.selection)
                is Some(_),
            ),
          ),
        ),
        {
          start,
          before,
          after,
          caret: control.caret,
          selection: control.selection,
        },
      )
    }
    {
      text: edit.text,
      control: {
        ..control,
        caret: edit.caret,
        selection: edit.selection,
        composition: None,
        composition_cursor: None,
        undo_stack,
        redo_stack: [],
      },
      changed: true,
      edit: Some({ start, deleted: before, replacement: after }),
    }
  } else {
    { text: previous, control, changed: false, edit: None }
  }
}

///|
fn append_rich_text_selection_commands(
  commands : Array[@core.DrawCommand],
  document : RichTextDocument,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  selection : @core.TextRange?,
) -> Unit {
  match @core.active_text_selection(selection) {
    Some(selection) => {
      let mut y = content.origin.y
      for block in document.blocks {
        let line_height = rich_text_block_line_height(
          block,
          base_font,
          text_system,
          block_width=content.size.width,
        )
        let block_height = line_height + block.inset.top + block.inset.bottom
        let frame = @core.Rect::new(
          x=content.origin.x + block.inset.left,
          y=y + block.inset.top,
          width=max_double(
            0.0,
            content.size.width - block.inset.left - block.inset.right,
          ),
          height=line_height,
        )
        match block.table {
          // 表格按单元格几何绘制高亮；文本块仍走行盒路径。
          Some(table) =>
            append_rich_text_table_selection_rects(
              commands, block, table, frame, selection, base_font, text_system,
            )
          None =>
            match rich_text_block_selection_visual_range(block, selection) {
              Some(range) =>
                append_rich_text_block_selection_rect(
                  commands, block, range, frame, base_font, text_system,
                )
              None => ()
            }
        }
        y = y + block_height
      }
    }
    None => ()
  }
}

///|
fn rich_text_block_selection_visual_range(
  block : RichTextBlock,
  selection : @core.TextRange,
) -> @core.TextRange? {
  match (block.source_range, block.content_range) {
    (Some(source), Some(content)) =>
      if selection.end <= source.start || selection.start >= source.end {
        None
      } else {
        let start = rich_text_block_source_offset_to_visual(
          block,
          @core.clamp_int(selection.start, source.start, source.end),
          content,
        )
        let end = rich_text_block_source_offset_to_visual(
          block,
          @core.clamp_int(selection.end, source.start, source.end),
          content,
        )
        if end > start {
          Some(@core.TextRange::new(start~, end~))
        } else {
          None
        }
      }
    (_, Some(content)) =>
      if selection.end <= content.start || selection.start >= content.end {
        None
      } else {
        let start = rich_text_block_source_offset_to_visual(
          block,
          @core.clamp_int(selection.start, content.start, content.end),
          content,
        )
        let end = rich_text_block_source_offset_to_visual(
          block,
          @core.clamp_int(selection.end, content.start, content.end),
          content,
        )
        if end > start {
          Some(@core.TextRange::new(start~, end~))
        } else {
          None
        }
      }
    _ => None
  }
}

///|

///|
/// Table selection highlight: per cell, intersect the selection with the
/// cell's source range and draw one band per covered visual line, matching
/// the table painter's per-line geometry. Cells without source ranges (the
/// read-only viewer) contribute nothing.
fn append_rich_text_table_selection_rects(
  commands : Array[@core.DrawCommand],
  block : RichTextBlock,
  table : RichTextTable,
  frame : @core.Rect,
  selection : @core.TextRange,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Unit {
  let layout = rich_text_table_layout(
    table,
    block,
    base_font,
    frame_width=frame.size.width,
    text_system~,
  )
  for row_index, row_layout in layout.rows {
    if row_index >= table.rows.length() {
      continue
    }
    let table_row = table.rows[row_index]
    let row_y = frame.origin.y + layout.row_top(row_index)
    for column_index, cell_layout in row_layout.cells {
      if column_index >= table_row.length() {
        continue
      }
      let cell = table_row[column_index]
      let range = match cell.source_range {
        Some(range) => range
        None => continue
      }
      if selection.end <= range.start || selection.start >= range.end {
        continue
      }
      let chars = cell.text.to_array()
      let cs = @core.clamp_int(selection.start - range.start, 0, chars.length())
      let ce = @core.clamp_int(selection.end - range.start, 0, chars.length())
      if ce <= cs {
        continue
      }
      let cell_x = frame.origin.x +
        layout.column_width * column_index.to_double()
      let inner_x = cell_x + table.cell_padding.left
      // Styled cell: highlight each segment's selected slice at its
      // laid-out x, skipping marker-only overlaps (no width to show).
      if cell_layout.segments.length() > 0 {
        for segment in cell_layout.segments {
          let s = @core.max_int(cs, segment.start)
          let e = @core.min_int(ce, segment.end)
          if e <= s {
            continue
          }
          let chars = segment.text.to_array()
          let visible_s = @core.clamp_int(s - segment.start, 0, chars.length())
          let visible_e = @core.clamp_int(e - segment.start, 0, chars.length())
          if visible_e <= visible_s {
            continue
          }
          let font = segment.run.font.unwrap_or(cell_layout.font)
          let before = String::from_array(chars[:visible_s])
          let covered = String::from_array(chars[:visible_e])
          let x0 = inner_x +
            segment.x +
            rich_text_width(before, font, text_system)
          let x1 = inner_x +
            segment.x +
            rich_text_width(covered, font, text_system)
          if x1 > x0 {
            commands.push(
              @core.DrawCommand::FillRect(
                @core.Rect::new(
                  x=x0,
                  y=row_y +
                    table.cell_padding.top +
                    layout.line_step * segment.line.to_double() +
                    3.0,
                  width=x1 - x0,
                  height=max_double(10.0, layout.line_step - 6.0),
                ),
                @core.Color::blue().with_alpha(0.18),
              ),
            )
          }
        }
        continue
      }
      for line_index, line in cell_layout.lines {
        let s = @core.max_int(cs, line.start)
        let e = @core.min_int(ce, line.end)
        if e <= s {
          continue
        }
        let line_chars = line.text.to_array()
        let before = String::from_array(line_chars[0:s - line.start])
        let covered = String::from_array(line_chars[0:e - line.start])
        let text_x = match cell.align.unwrap_or(@core.TextAlign::TextStart) {
          TextStart => inner_x
          TextCenter =>
            inner_x +
            max_double(0.0, (layout.cell_inner_width - line.width) / 2.0)
          TextEnd =>
            inner_x + max_double(0.0, layout.cell_inner_width - line.width)
        }
        let x0 = text_x + rich_text_width(before, cell_layout.font, text_system)
        let x1 = text_x +
          rich_text_width(covered, cell_layout.font, text_system)
        if x1 > x0 {
          commands.push(
            @core.DrawCommand::FillRect(
              @core.Rect::new(
                x=x0,
                y=row_y +
                  table.cell_padding.top +
                  layout.line_step * line_index.to_double() +
                  3.0,
                width=x1 - x0,
                height=max_double(10.0, layout.line_step - 6.0),
              ),
              @core.Color::blue().with_alpha(0.18),
            ),
          )
        }
      }
    }
  }
}

///|
/// One highlight band per visual line the range touches. With soft-wrap
/// the selection usually spans several wrapped lines, and a single
/// first-line band would hide most of the selection (and disappear
/// entirely when the end x lands left of the start x on a later line).
fn append_rich_text_block_selection_rect(
  commands : Array[@core.DrawCommand],
  block : RichTextBlock,
  range : @core.TextRange,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Unit {
  let line_heights = rich_text_block_line_heights(
    block,
    base_font,
    text_system,
    frame.size.width,
  )
  let line_widths = rich_text_block_line_widths(
    block,
    base_font,
    text_system,
    frame.size.width,
  )
  let start_line = rich_text_visual_offset_to_line(block, range.start)
  let end_line = rich_text_visual_offset_to_line(block, range.end)
  let start_rect = rich_text_block_caret_rect(
    block,
    range.start,
    frame,
    base_font,
    text_system,
  )
  let end_rect = rich_text_block_caret_rect(
    block,
    range.end,
    frame,
    base_font,
    text_system,
  )
  let last_line = @core.clamp_int(
    end_line,
    0,
    @core.max_int(line_heights.length() - 1, 0),
  )
  let line_step = rich_text_block_line_step(block, base_font, text_system)
  let mut y = frame.origin.y
  for line in 0..<=last_line {
    let height = line_heights.get(line).unwrap_or(line_step)
    if line >= start_line && line <= last_line {
      let left = if line == start_line {
        start_rect.origin.x
      } else {
        frame.origin.x
      }
      let right = if line == end_line {
        end_rect.origin.x
      } else {
        frame.origin.x + line_widths.get(line).unwrap_or(frame.size.width)
      }
      if right > left {
        commands.push(
          @core.DrawCommand::FillRect(
            @core.Rect::new(
              x=left,
              y=y + 4.0,
              width=right - left,
              height=max_double(10.0, height - 8.0),
            ),
            @core.Color::blue().with_alpha(0.18),
          ),
        )
      }
    }
    y = y + height
  }
}

///|
pub fn rich_text_document_caret_rect_at_source(
  document : RichTextDocument,
  source_caret : Int,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system? : @core.TextSystem = @core.TextSystem::fallback(),
) -> @core.Rect? {
  rich_text_document_caret_rect(
    document,
    source_caret,
    content,
    base_font,
    text_system,
    block_width=content.size.width,
  )
}

///|
fn rich_text_document_caret_rect(
  document : RichTextDocument,
  source_caret : Int,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  block_width~ : Double,
) -> @core.Rect? {
  if !rich_text_document_has_source_ranges(document) {
    return None
  }
  let mut y = content.origin.y
  let mut last_rect = @core.Rect::new(
    x=content.origin.x,
    y=content.origin.y + 4.0,
    width=1.5,
    height=max_double(10.0, base_font.size * 1.55 - 8.0),
  )
  for block in document.blocks {
    let line_height = rich_text_block_line_height(
      block,
      base_font,
      text_system,
      block_width~,
    )
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = @core.Rect::new(
      x=content.origin.x + block.inset.left,
      y=y + block.inset.top,
      width=max_double(
        0.0,
        content.size.width - block.inset.left - block.inset.right,
      ),
      height=line_height,
    )
    if rich_text_caret_before_block(source_caret, block) {
      match block.table {
        Some(table) =>
          return Some(
            rich_text_block_table_caret_rect(
              block, table, source_caret, frame, base_font, text_system,
            ),
          )
        None => ()
      }
      return Some(
        rich_text_block_caret_rect(block, 0, frame, base_font, text_system),
      )
    }
    match block.table {
      Some(table) => {
        // Only short-circuit while the caret maps into this table; a caret
        // parked in a block AFTER the table must keep walking, otherwise the
        // caret is drawn at the table's last cell and never shows up where
        // the user clicked.
        let caret_in_table = match block.source_range {
          Some(range) => source_caret <= range.end
          None => false
        }
        if caret_in_table {
          return Some(
            rich_text_block_table_caret_rect(
              block, table, source_caret, frame, base_font, text_system,
            ),
          )
        }
        last_rect = rich_text_block_table_caret_rect(
          block,
          table,
          match block.source_range {
            Some(range) => range.end
            None => source_caret
          },
          frame,
          base_font,
          text_system,
        )
        y = y + block_height
        continue
      }
      None => ()
    }
    match rich_text_block_visual_offset(block, source_caret) {
      Some(visual_offset) =>
        return Some(
          rich_text_block_caret_rect(
            block, visual_offset, frame, base_font, text_system,
          ),
        )
      None => ()
    }
    last_rect = rich_text_block_caret_rect(
      block,
      rich_text_block_visual_length(block),
      frame,
      base_font,
      text_system,
    )
    y = y + block_height
  }
  Some(last_rect)
}

///|
fn rich_text_document_source_offset_at_point(
  document : RichTextDocument,
  point : @core.Point,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Int? {
  if !rich_text_document_has_source_ranges(document) {
    return None
  }
  let mut y = content.origin.y
  let mut last_offset : Int? = None
  let mut last_block : RichTextBlock? = None
  let mut last_frame = @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0)
  for block in document.blocks {
    // Block heights must match the painted layout: percentage-width image
    // runs only reach their drawn height once the content column width is
    // known. A width-blind walk drifts out of sync with the screen and
    // resolves clicks below an image gallery into the wrong block.
    let line_height = rich_text_block_line_height(
      block,
      base_font,
      text_system,
      block_width=content.size.width,
    )
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = @core.Rect::new(
      x=content.origin.x + block.inset.left,
      y=y + block.inset.top,
      width=max_double(
        0.0,
        content.size.width - block.inset.left - block.inset.right,
      ),
      height=line_height,
    )
    // A block with no line box is pure spacing: the paragraph separator a
    // blank source line renders as (see
    // `markdown_editor_collapse_inactive_blank_gaps`). Nothing can park a
    // caret on it, so the pointer resolves to the content on the far side —
    // the paragraph above for the upper half of the band, the next line for
    // the lower half.
    let spacing = line_height <= 0.0
    if point.y < y + block_height {
      if spacing {
        if point.y < y + block_height * 0.5 {
          match last_offset {
            Some(offset) => return Some(offset)
            None => ()
          }
        }
      } else {
        match
          rich_text_block_table_source_offset_at_point(
            block, point, frame, base_font, text_system,
          ) {
          Some(offset) => return Some(offset)
          None => ()
        }
        let offset = rich_text_block_source_offset_at_point(
          block, point, frame, base_font, text_system,
        )
        return Some(offset)
      }
    }
    if !spacing {
      last_block = Some(block)
      last_frame = frame
      last_offset = rich_text_block_end_source_offset(block)
    }
    y = y + block_height
  }
  match last_block {
    Some(block) =>
      Some(
        rich_text_block_source_offset_at_point(
          block, point, last_frame, base_font, text_system,
        ),
      )
    None => last_offset
  }
}

///|
fn rich_text_block_end_source_offset(block : RichTextBlock) -> Int? {
  match block.source_range {
    Some(range) => Some(range.end)
    None =>
      Some(
        rich_text_block_source_offset_from_visual(
          block,
          rich_text_block_visual_length(block),
        ),
      )
  }
}

///|
fn rich_text_caret_before_block(
  source_caret : Int,
  block : RichTextBlock,
) -> Bool {
  match block.source_range {
    Some(range) => source_caret < range.start
    None => false
  }
}

///|
fn rich_text_block_visual_offset(
  block : RichTextBlock,
  source_caret : Int,
) -> Int? {
  match (block.source_range, block.content_range) {
    (Some(source), Some(content)) =>
      if source_caret < source.start || source_caret > source.end {
        None
      } else if source_caret < content.start {
        Some(0)
      } else if source_caret > content.end {
        Some(rich_text_block_visual_length(block))
      } else {
        Some(
          rich_text_block_source_offset_to_visual(block, source_caret, content),
        )
      }
    (_, Some(content)) =>
      if source_caret < content.start || source_caret > content.end {
        None
      } else {
        Some(
          rich_text_block_source_offset_to_visual(block, source_caret, content),
        )
      }
    _ => None
  }
}

///|
fn rich_text_document_prefix_source_offset_at_point(
  document : RichTextDocument,
  point : @core.Point,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Int? {
  if !rich_text_document_has_source_ranges(document) {
    return None
  }
  let mut y = content.origin.y
  let mut fallback : Int? = None
  for block in document.blocks {
    let line_height = rich_text_block_line_height(
      block,
      base_font,
      text_system,
      block_width=content.size.width,
    )
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = @core.Rect::new(
      x=content.origin.x + block.inset.left,
      y=y + block.inset.top,
      width=max_double(
        0.0,
        content.size.width - block.inset.left - block.inset.right,
      ),
      height=line_height,
    )
    if fallback is None &&
      rich_text_point_in_prefix_lane(
        block, point, frame, base_font, text_system,
      ) {
      fallback = match block.content_range {
        Some(range) => Some(range.start)
        None => None
      }
    }
    if point.y < y + block_height {
      return rich_text_block_prefix_source_offset_at_point(
        block, point, frame, base_font, text_system,
      )
    }
    y = y + block_height
  }
  fallback
}

///|
fn rich_text_block_prefix_source_offset_at_point(
  block : RichTextBlock,
  point : @core.Point,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Int? {
  if block.prefix == "" {
    return None
  }
  let font = rich_text_block_font(block, base_font)
  let width = rich_text_block_prefix_hit_width(
    block, font, base_font, text_system,
  )
  if point.x >= frame.origin.x && point.x <= frame.origin.x + width {
    match block.content_range {
      Some(content) => Some(content.start)
      None => None
    }
  } else {
    None
  }
}

///|
/// Hit width of a block's prefix lane. Text prefixes keep the historical
/// `1.8em` floor so a long indented lane stays clickable; a marker lane is
/// already wider than the drawn box and must not swallow the label's caret
/// positions.
fn rich_text_block_prefix_hit_width(
  block : RichTextBlock,
  font : @core.FontSpec,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Double {
  match block.marker {
    Some(_) => rich_text_block_marker_lane(block, font, text_system)
    None =>
      max_double(
        rich_text_width(block.prefix, font, text_system),
        base_font.size * 1.8,
      )
  }
}

///|
fn rich_text_point_in_prefix_lane(
  block : RichTextBlock,
  point : @core.Point,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Bool {
  if block.prefix == "" {
    return false
  }
  let font = rich_text_block_font(block, base_font)
  let width = rich_text_block_prefix_hit_width(
    block, font, base_font, text_system,
  )
  point.x >= frame.origin.x && point.x <= frame.origin.x + width
}

///|
fn rich_text_block_source_offset_at_point(
  block : RichTextBlock,
  point : @core.Point,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Int {
  let visual = rich_text_block_visual_offset_at_point(
    block, point, frame, base_font, text_system,
  )
  rich_text_block_source_offset_from_visual(block, visual)
}

///|
/// Index of the visual line whose band contains `offset_y` within a block.
/// Lines are not uniform when image runs scale with the content column, so
/// this walks the same per-line heights painting uses instead of assuming a
/// fixed `line_step`.
fn rich_text_block_line_index_at_y(
  block : RichTextBlock,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  available_width~ : Double,
  offset_y~ : Double,
) -> Int {
  let mut cursor = 0.0
  for
    index, height in rich_text_block_line_heights(
      block, base_font, text_system, available_width,
    ) {
    if offset_y < cursor + height {
      return index
    }
    cursor = cursor + height
  }
  @core.max_int(rich_text_block_visual_line_count(block) - 1, 0)
}

///|
fn rich_text_block_visual_offset_at_point(
  block : RichTextBlock,
  point : @core.Point,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Int {
  let font = rich_text_block_font(block, base_font)
  let target_line = @core.clamp_int(
    rich_text_block_line_index_at_y(
      block,
      base_font,
      text_system,
      available_width=frame.size.width,
      offset_y=point.y - frame.origin.y,
    ),
    0,
    rich_text_block_visual_line_count(block) - 1,
  )
  let mut origin = frame.origin.x
  let mut visual_offset = 0
  let mut line = 0
  let mut line_end = 0
  if block.prefix != "" {
    let prefix_length = text_length(block.prefix)
    let width = rich_text_block_marker_lane(block, font, text_system)
    // A marker lane is one atomic slot: it has no interior caret position, so
    // the whole lane maps to the offset in front of the label.
    if block.marker is Some(_) {
      if target_line == 0 && point.x <= origin + width {
        return 0
      }
      visual_offset = visual_offset + prefix_length
      line_end = visual_offset
      origin = origin + width
    } else {
      let hit = rich_text_run_visual_offset_at_x(
        block.prefix,
        font,
        point.x,
        origin,
        text_system,
      )
      if target_line == 0 && (hit < prefix_length || point.x <= origin + width) {
        return hit
      }
      visual_offset = visual_offset + prefix_length
      line_end = visual_offset
      origin = origin + width
    }
  }
  for run in block.runs {
    let run_font = run.font.unwrap_or(font)
    let segments = rich_text_split_lines(rich_text_run_visual_text(run))
    for index, segment in segments {
      let segment_length = text_length(segment)
      let segment_width = rich_text_run_segment_width(
        run,
        segment,
        run_font,
        text_system,
        available_width=frame.size.width,
      )
      if line == target_line {
        line_end = visual_offset + segment_length
        if point.x <= origin + segment_width || segment_length == 0 {
          return visual_offset +
            rich_text_run_visual_offset_at_x(
              segment,
              run_font,
              point.x,
              origin,
              text_system,
              width=rich_text_run_hit_width(run, segment_width),
            )
        }
      }
      visual_offset = visual_offset + segment_length
      origin = origin + segment_width
      if index + 1 < segments.length() {
        if line == target_line {
          return line_end
        }
        visual_offset = visual_offset + 1
        line = line + 1
        origin = frame.origin.x
      }
    }
  }
  line_end
}

///|
fn rich_text_run_visual_offset_at_x(
  text : String,
  font : @core.FontSpec,
  x : Double,
  origin_x : Double,
  text_system : @core.TextSystem,
  width? : Double? = None,
) -> Int {
  let chars = text.to_array()
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  if x <= origin_x {
    return 0
  }
  match width {
    Some(width) =>
      if chars.length() <= 1 {
        if x < origin_x + width / 2.0 {
          return 0
        } else {
          return chars.length()
        }
      } else {
        let relative = clamp_double((x - origin_x) / width, 0.0, 1.0)
        return boundaries.nearest_boundary(
          (relative * chars.length().to_double()).round().to_int(),
        )
      }
    None => ()
  }
  for index in 0..<chars.length() {
    let before = rich_text_width(
      String::from_array(chars[0:index]),
      font,
      text_system,
    )
    let after = rich_text_width(
      String::from_array(chars[0:index + 1]),
      font,
      text_system,
    )
    if x < origin_x + (before + after) / 2.0 {
      return boundaries.nearest_boundary(index)
    }
  }
  chars.length()
}

///|
fn rich_text_block_source_offset_from_visual(
  block : RichTextBlock,
  visual_offset : Int,
) -> Int {
  match block.content_range {
    Some(content) => {
      let prefix_length = text_length(block.prefix)
      if visual_offset <= prefix_length {
        content.start
      } else {
        match
          rich_text_block_run_source_offset_from_visual(
            block,
            visual_offset - prefix_length,
          ) {
          Some(offset) => offset
          None =>
            @core.clamp_int(
              content.start + visual_offset - prefix_length,
              content.start,
              content.end,
            )
        }
      }
    }
    None => visual_offset
  }
}

///|
fn rich_text_block_run_source_offset_from_visual(
  block : RichTextBlock,
  visual_offset : Int,
) -> Int? {
  let mut remaining = visual_offset
  let mut fallback = match block.content_range {
    Some(content) => Some(content.start)
    None => None
  }
  for run in block.runs {
    let visual_text = rich_text_run_visual_text(run)
    let visual_length = text_length(visual_text)
    if remaining <= visual_length {
      match run.source_range {
        Some(range) =>
          return Some(
            @core.clamp_int(
              range.start +
              rich_text_run_source_offset_from_visual_offset(
                remaining,
                visual_text,
                run.text,
              ),
              range.start,
              range.end,
            ),
          )
        None => return fallback
      }
    }
    remaining = remaining - visual_length
    match run.source_range {
      Some(range) => fallback = Some(range.end)
      None => ()
    }
  }
  match block.runs.last() {
    Some(run) =>
      match run.source_range {
        Some(range) => Some(range.end)
        None => fallback
      }
    None => None
  }
}

///|
fn rich_text_block_source_offset_to_visual(
  block : RichTextBlock,
  source_offset : Int,
  content : RichTextSourceRange,
) -> Int {
  if source_offset < content.start {
    0
  } else if source_offset > content.end {
    rich_text_block_visual_length(block)
  } else {
    let prefix_length = text_length(block.prefix)
    match rich_text_block_run_visual_offset_from_source(block, source_offset) {
      Some(offset) => prefix_length + offset
      None =>
        @core.clamp_int(
          prefix_length + source_offset - content.start,
          0,
          rich_text_block_visual_length(block),
        )
    }
  }
}

///|
fn rich_text_block_run_visual_offset_from_source(
  block : RichTextBlock,
  source_offset : Int,
) -> Int? {
  let mut visual = 0
  for run in block.runs {
    let visual_text = rich_text_run_visual_text(run)
    let visual_length = text_length(visual_text)
    match run.source_range {
      Some(range) =>
        if source_offset <= range.end {
          return Some(
            visual +
            rich_text_run_visual_offset_from_source_offset(
              source_offset - range.start,
              run.text,
              visual_text,
            ),
          )
        }
      None => ()
    }
    visual = visual + visual_length
  }
  Some(visual)
}

///|
fn rich_text_block_caret_rect(
  block : RichTextBlock,
  visual_offset : Int,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> @core.Rect {
  let font = rich_text_block_font(block, base_font)
  let line_step = rich_text_block_line_step(block, base_font, text_system)
  // Wrapped-line y positions follow the per-line heights painting uses, so a
  // caret below a column-scaled image line lands on the image line's band.
  let line_heights = rich_text_block_line_heights(
    block,
    base_font,
    text_system,
    frame.size.width,
  )
  let mut line_slot = rich_text_text_newline_count(block.prefix)
  let mut remaining = @core.clamp_int(
    visual_offset,
    0,
    rich_text_block_visual_length(block),
  )
  let mut x = frame.origin.x
  let mut y = frame.origin.y
  if block.prefix != "" {
    let prefix_length = text_length(block.prefix)
    let lane = rich_text_block_marker_lane(block, font, text_system)
    if remaining <= prefix_length {
      // The marker lane is atomic, so any offset inside it sits at the lane
      // start; only a text prefix has interior caret stops.
      let advance = match block.marker {
        Some(_) => 0.0
        None =>
          rich_text_width(
            rich_text_prefix(block.prefix, remaining),
            font,
            text_system,
          )
      }
      x = x + advance
      return rich_text_cursor_rect_at(
        x,
        @core.Rect::new(
          x=frame.origin.x,
          y~,
          width=frame.size.width,
          height=frame.size.height,
        ),
        font,
      )
    }
    remaining = remaining - prefix_length
    x = x + lane
  }
  for run in block.runs {
    let run_font = run.font.unwrap_or(font)
    let segments = rich_text_split_lines(rich_text_run_visual_text(run))
    for index, segment in segments {
      let segment_length = text_length(segment)
      if remaining <= segment_length {
        x = x +
          rich_text_run_segment_prefix_width(
            run, segment, remaining, run_font, text_system,
          )
        return rich_text_cursor_rect_at(
          x,
          @core.Rect::new(
            x=frame.origin.x,
            y~,
            width=frame.size.width,
            height=line_step,
          ),
          run_font,
        )
      }
      remaining = remaining - segment_length
      x = x + rich_text_run_segment_width(run, segment, run_font, text_system)
      if index + 1 < segments.length() {
        if remaining == 0 {
          return rich_text_cursor_rect_at(
            x,
            @core.Rect::new(
              x=frame.origin.x,
              y~,
              width=frame.size.width,
              height=line_step,
            ),
            run_font,
          )
        }
        remaining = remaining - 1
        y = y + line_heights.get(line_slot).unwrap_or(line_step)
        line_slot = line_slot + 1
        x = frame.origin.x
      }
    }
  }
  rich_text_cursor_rect_at(
    x,
    @core.Rect::new(
      x=frame.origin.x,
      y~,
      width=frame.size.width,
      height=line_step,
    ),
    font,
  )
}

///|
fn rich_text_run_segment_prefix_width(
  run : RichTextRun,
  text : String,
  visual_offset : Int,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Double {
  let length = text_length(text)
  if length <= 0 || visual_offset <= 0 {
    0.0
  } else if visual_offset >= length {
    rich_text_run_segment_width(run, text, font, text_system)
  } else {
    match run.image_source {
      Some(_) =>
        rich_text_run_segment_width(run, text, font, text_system) *
        visual_offset.to_double() /
        length.to_double()
      None =>
        rich_text_width(
          rich_text_prefix(text, visual_offset),
          font,
          text_system,
        )
    }
  }
}

///|
fn rich_text_prefix(text : String, length : Int) -> String {
  let chars = text.to_array()
  let end = @core.TextGraphemeBoundaries::new(text~).nearest_boundary(length)
  String::from_array(chars[0:end])
}

///|
fn rich_text_cursor_rect_at(
  x : Double,
  frame : @core.Rect,
  font : @core.FontSpec,
) -> @core.Rect {
  @core.Rect::new(
    x~,
    y=frame.origin.y + 4.0,
    width=1.5,
    height=max_double(10.0, font.size * 1.55 - 8.0),
  )
}

///|
fn rich_text_block_visual_length(block : RichTextBlock) -> Int {
  let mut length = text_length(block.prefix)
  for run in block.runs {
    length = length + text_length(rich_text_run_visual_text(run))
  }
  length
}

///|
fn rich_text_block_table_source_offset_at_point(
  block : RichTextBlock,
  point : @core.Point,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Int? {
  match block.table {
    Some(table) => {
      let row_count = table.rows.length()
      let column_count = rich_text_table_column_count(table)
      if row_count == 0 || column_count == 0 || table.row_height <= 0.0 {
        return None
      }
      let layout = rich_text_table_layout(
        table,
        block,
        base_font,
        frame_width=frame.size.width,
        text_system~,
      )
      // Walk the dynamic row heights; a click past the last row clamps into
      // it so dragging below the table keeps editing its final row.
      let mut row_index = row_count - 1
      for index in 0..<row_count {
        let top = frame.origin.y + layout.row_top(index)
        if point.y < top + layout.rows[index].height {
          row_index = index
          break
        }
      }
      let column_index = @core.clamp_int(
        ((point.x - frame.origin.x) / layout.column_width).floor().to_int(),
        0,
        column_count - 1,
      )
      let row = table.rows[row_index]
      if column_index >= row.length() {
        return None
      }
      let cell = row[column_index]
      match cell.source_range {
        Some(range) => {
          // 与渲染端 (append_rich_text_block_table) 保持一致的几何：
          // cell 文本按行绘制，行 frame = cell_frame.inset(cell_padding)，
          // 按 cell.align 决定每行 x 起点。
          let cell_x = frame.origin.x +
            layout.column_width * column_index.to_double()
          let inner_x = cell_x + table.cell_padding.left
          let inner_width = layout.cell_inner_width
          // 空 cell 直接钳到 range.start，避免后续除零/无效测量。
          if range.end <= range.start || cell.text == "" {
            return Some(range.start)
          }
          let row_layout = layout.rows[row_index]
          let cell_layout = row_layout.cells[column_index]
          let cell_font = cell_layout.font
          // Styled cell: map x through the run segments (markers occupy no
          // width; a click over a marker snaps to the adjacent visible
          // character), falling back to the plain path when segments are
          // empty.
          if cell_layout.segments.length() > 0 {
            return rich_text_table_segment_offset_at_point(
              cell,
              cell_layout,
              point,
              range~,
              row_top=frame.origin.y + layout.row_top(row_index),
              inner_x~,
              table,
              layout,
              text_system~,
            )
          }
          // 行按 y 选择；拖到单元格底部时钳在最后一行。
          let cell_top = frame.origin.y + layout.row_top(row_index)
          let line_index = @core.clamp_int(
            ((point.y - cell_top - table.cell_padding.top) / layout.line_step)
            .floor()
            .to_int(),
            0,
            cell_layout.lines.length() - 1,
          )
          let line = cell_layout.lines[line_index]
          if line.end <= line.start {
            return Some(
              @core.clamp_int(range.start + line.start, range.start, range.end),
            )
          }
          let text_x = match cell.align.unwrap_or(@core.TextAlign::TextStart) {
            TextStart => inner_x
            TextCenter =>
              inner_x + max_double(0.0, (inner_width - line.width) / 2.0)
            TextEnd => inner_x + max_double(0.0, inner_width - line.width)
          }
          let text_x_end = text_x + line.width
          // 点击落在文本左右两侧空白时，clamp 到该行文本边界。
          if point.x < text_x {
            return Some(
              @core.clamp_int(range.start + line.start, range.start, range.end),
            )
          }
          if point.x > text_x_end {
            return Some(
              @core.clamp_int(range.start + line.end, range.start, range.end),
            )
          }
          // 点击落在文本渲染范围内：按逐字符中点命中，再钳到图形素边界。
          // 参考 rich_text_run_visual_offset_at_x 的 for index in 0..<chars.length() 分支。
          let chars = cell.text.to_array()
          let line_chars = line.end - line.start
          let mut local_offset = line_chars
          for index in 0..<line_chars {
            let before = rich_text_width(
              String::from_array(chars[line.start:line.start + index]),
              cell_font,
              text_system,
            )
            let after = rich_text_width(
              String::from_array(chars[line.start:line.start + index + 1]),
              cell_font,
              text_system,
            )
            if point.x < text_x + (before + after) / 2.0 {
              local_offset = index
              break
            }
          }
          let line_boundaries = @core.TextGraphemeBoundaries::new(
            text=line.text,
          )
          let char_offset = line.start +
            line_boundaries.nearest_boundary(local_offset)
          Some(
            @core.clamp_int(range.start + char_offset, range.start, range.end),
          )
        }
        None => None
      }
    }
    None => None
  }
}

///|
/// Hit-test a styled cell through its run segments. Each segment covers its
/// visible characters (markers excluded from width); the char midpoints
/// inside a segment decide the offset, and clicks left/right of the whole
/// styled content clamp to its first/last visible char. Marker source chars
/// are never returned directly: they collapse onto the nearest visible
/// boundary so the caret always lands where text was drawn.
fn rich_text_table_segment_offset_at_point(
  _cell : RichTextTableCell,
  cell_layout : RichTextTableCellLayout,
  point : @core.Point,
  range~ : RichTextSourceRange,
  row_top~ : Double,
  inner_x~ : Double,
  table : RichTextTable,
  layout : RichTextTableLayout,
  text_system~ : @core.TextSystem,
) -> Int? {
  ignore(table)
  let first = cell_layout.segments[0]
  let last = cell_layout.segments[cell_layout.segments.length() - 1]
  // y band selects the line; below the last line clamps into it.
  let line_index = @core.clamp_int(
    ((point.y - row_top - table.cell_padding.top) / layout.line_step)
    .floor()
    .to_int(),
    0,
    cell_layout.lines.length() - 1,
  )
  // Segments on the picked line, in x order (the layout walks runs in
  // order and segments carry their x offsets).
  let line_segments : Array[RichTextTableCellSegment] = []
  for segment in cell_layout.segments {
    if segment.line == line_index {
      line_segments.push(segment)
    }
  }
  if line_segments.is_empty() {
    return Some(
      @core.clamp_int(range.start + first.start, range.start, range.end),
    )
  }
  let head = line_segments[0]
  let tail = line_segments[line_segments.length() - 1]
  let text_x = inner_x + head.x
  let text_end = inner_x + tail.x + tail.width
  if point.x <= text_x {
    return Some(
      @core.clamp_int(range.start + head.start, range.start, range.end),
    )
  }
  if point.x >= text_end {
    return Some(@core.clamp_int(range.start + tail.end, range.start, range.end))
  }
  // Inside the styled content: find the segment under the point (a click
  // over a marker gap between segments snaps to the nearer side).
  for index, segment in line_segments {
    let segment_x = inner_x + segment.x
    let segment_end = segment_x + segment.width
    if point.x < segment_end || index == line_segments.length() - 1 {
      let font = segment.run.font.unwrap_or(cell_layout.font)
      let chars = segment.text.to_array()
      let mut chars_local = chars.length()
      for char_index in 0..<chars.length() {
        let before = rich_text_width(
          String::from_array(chars[:char_index]),
          font,
          text_system,
        )
        let after = rich_text_width(
          String::from_array(chars[:char_index + 1]),
          font,
          text_system,
        )
        if point.x < segment_x + (before + after) / 2.0 {
          chars_local = char_index
          break
        }
      }
      return Some(
        @core.clamp_int(
          range.start + segment.start + chars_local,
          range.start,
          range.end,
        ),
      )
    }
  }
  Some(@core.clamp_int(range.start + last.end, range.start, range.end))
}

///|
/// Caret x for a raw cell offset in a styled cell. Offsets inside a hidden
/// marker collapse: before the segment's visible start the caret pins to
/// the segment start; inside the visible span it advances by the measured
/// prefix width with the segment's font; past the last segment it pins to
/// the content end.
fn rich_text_table_segment_caret_x(
  cell_layout : RichTextTableCellLayout,
  local_offset~ : Int,
  text_x : Double,
  text_system~ : @core.TextSystem,
) -> Double {
  for segment in cell_layout.segments {
    if local_offset <= segment.start {
      return text_x + segment.x
    }
    if local_offset <= segment.end {
      let font = segment.run.font.unwrap_or(cell_layout.font)
      let chars = segment.text.to_array()
      let visible = @core.clamp_int(
        local_offset - segment.start,
        0,
        chars.length(),
      )
      let prefix = String::from_array(chars[:visible])
      return text_x + segment.x + rich_text_width(prefix, font, text_system)
    }
  }
  let last = cell_layout.segments[cell_layout.segments.length() - 1]
  text_x + last.x + last.width
}

///|
fn rich_text_block_table_caret_rect(
  block : RichTextBlock,
  table : RichTextTable,
  source_caret : Int,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> @core.Rect {
  let column_count = rich_text_table_column_count(table)
  let row_count = table.rows.length()
  // 与渲染端 (append_rich_text_block_table) 一致的动态行布局。
  let layout = rich_text_table_layout(
    table,
    block,
    base_font,
    frame_width=frame.size.width,
    text_system~,
  )
  let column_width = layout.column_width
  // 默认 caret 矩形：表格起点。
  let base_font_resolved = rich_text_block_font(block, base_font)
  let line_step = layout.line_step
  let caret_rect = rich_text_cursor_rect_at(
    frame.origin.x,
    @core.Rect::new(
      x=frame.origin.x,
      y=frame.origin.y,
      width=frame.size.width,
      height=line_step,
    ),
    base_font_resolved,
  )
  if column_count == 0 || row_count == 0 {
    return caret_rect
  }
  // 查找 source_caret 所在的 cell。
  let mut found_row = -1
  let mut found_col = -1
  let mut found_cell : RichTextTableCell? = None
  for row_index in 0..<row_count {
    let row = table.rows[row_index]
    for col_index in 0..<column_count {
      if col_index >= row.length() {
        continue
      }
      let cell = row[col_index]
      match cell.source_range {
        Some(range) =>
          if source_caret >= range.start && source_caret <= range.end {
            found_row = row_index
            found_col = col_index
            found_cell = Some(cell)
            break
          }
        None => ()
      }
    }
    if found_row >= 0 {
      break
    }
  }
  // 若 source_caret 超出所有 cell 范围：当 source_caret 在第一个 cell 之前
  // （例如 position 0 位于表格 block 起点、但首个 cell 的 source_range 从
  // "| " 之后才开始），定位到首个 cell；否则定位到末尾 cell。
  if found_row < 0 {
    let first_row = table.rows[0]
    let first_col_index = @core.clamp_int(
      first_row.length() - 1,
      0,
      column_count - 1,
    )
    let caret_before_first_cell = match
      first_row[first_col_index].source_range {
      Some(range) => source_caret < range.start
      None => false
    }
    if caret_before_first_cell {
      found_row = 0
      found_col = first_col_index
      found_cell = Some(first_row[first_col_index])
    } else {
      let last_row_index = row_count - 1
      let last_row = table.rows[last_row_index]
      let last_col_index = @core.clamp_int(
        last_row.length() - 1,
        0,
        column_count - 1,
      )
      if last_col_index >= 0 && last_col_index < last_row.length() {
        found_row = last_row_index
        found_col = last_col_index
        found_cell = Some(last_row[last_col_index])
      }
    }
  }
  if found_row < 0 {
    return caret_rect
  }
  let cell = match found_cell {
    Some(c) => c
    None => return caret_rect
  }
  // 与渲染端一致的 cell 几何（行高随换行动态增长）。
  let cell_x = frame.origin.x + column_width * found_col.to_double()
  let row_y = frame.origin.y + layout.row_top(found_row)
  let text_frame = @core.Rect::new(
    x=cell_x + table.cell_padding.left,
    y=row_y + table.cell_padding.top,
    width=max_double(
      0.0,
      column_width - table.cell_padding.left - table.cell_padding.right,
    ),
    height=layout.line_step,
  )
  // cell 字体（header 加重，与渲染端一致）。
  let cell_font = if cell.header {
    { ..base_font_resolved, weight: 700 }
  } else {
    { ..base_font_resolved, weight: 400 }
  }
  // 空 cell 直接返回 cell 文本起点。
  if cell.text == "" {
    return rich_text_cursor_rect_at(text_frame.origin.x, text_frame, cell_font)
  }
  match cell.source_range {
    Some(range) => {
      // local_offset = source_caret 相对 cell.source_range.start 的偏移，钳到 [0, text.length]。
      let local_offset = @core.clamp_int(
        source_caret - range.start,
        0,
        cell.text.to_array().length(),
      )
      let cell_layout = layout.rows[found_row].cells[found_col]
      // Styled cell: fold the raw offset through the run segments so markers
      // collapse onto the adjacent visible char, then place the caret at the
      // segment position the paint drew.
      if cell_layout.segments.length() > 0 {
        let mut line_index = cell_layout.lines.length() - 1
        for index, line in cell_layout.lines {
          if local_offset < line.end {
            line_index = index
            break
          }
        }
        let line_frame = @core.Rect::new(
          x=text_frame.origin.x,
          y=text_frame.origin.y + layout.line_step * line_index.to_double(),
          width=text_frame.size.width,
          height=layout.line_step,
        )
        let caret_x = rich_text_table_segment_caret_x(
          cell_layout,
          local_offset~,
          text_frame.origin.x,
          text_system~,
        )
        return rich_text_cursor_rect_at(caret_x, line_frame, cell_font)
      }
      // 定位 local_offset 所在的视觉行，caret y 随行推进。
      let mut line_index = cell_layout.lines.length() - 1
      for index, line in cell_layout.lines {
        if local_offset < line.end {
          line_index = index
          break
        }
      }
      let line = cell_layout.lines[line_index]
      let line_local = @core.clamp_int(
        local_offset - line.start,
        0,
        line.end - line.start,
      )
      let line_chars = line.text.to_array()
      let prefix = String::from_array(
        line_chars[0:@core.clamp_int(line_local, 0, line_chars.length())],
      )
      let prefix_width = rich_text_width(prefix, cell_font, text_system)
      // 按 align 计算 text_x（与点击映射对称）。
      let inner_width = text_frame.size.width
      let text_x = match cell.align.unwrap_or(@core.TextAlign::TextStart) {
        TextStart => text_frame.origin.x
        TextCenter => text_frame.origin.x + (inner_width - line.width) / 2.0
        TextEnd => text_frame.origin.x + inner_width - line.width
      }
      let line_frame = @core.Rect::new(
        x=text_frame.origin.x,
        y=text_frame.origin.y + layout.line_step * line_index.to_double(),
        width=text_frame.size.width,
        height=layout.line_step,
      )
      rich_text_cursor_rect_at(text_x + prefix_width, line_frame, cell_font)
    }
    None => rich_text_cursor_rect_at(text_frame.origin.x, text_frame, cell_font)
  }
}
