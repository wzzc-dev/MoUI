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
    let line_height = rich_text_block_line_height(block, base_font, text_system)
    let block_height = line_height + block.inset.top + block.inset.bottom
    if rich_text_caret_before_block(source_caret, block) {
      block_index = index
      visual_line = 0
      break
    }
    match block.table {
      Some(_) => {
        block_index = index
        visual_line = 0
        break
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
      last_block, base_font, text_system,
    )
    let last_block_height = last_line_height +
      last_block.inset.top +
      last_block.inset.bottom
    y = y - last_block_height
  }
  let block = document.blocks[block_index]
  let step = rich_text_block_line_step(block, base_font, text_system)
  let line_height = rich_text_block_line_height(block, base_font, text_system)
  let block_top = y
  let frame_top = y + block.inset.top
  let line_center_y = if visual_line >= 0 &&
    visual_line < rich_text_block_visual_line_count(block) {
    frame_top + (visual_line.to_double() + 0.5) * step
  } else {
    caret_rect.origin.y + caret_rect.size.height * 0.5
  }
  let target_y = if up {
    if visual_line == 0 {
      block_top - 1.0
    } else {
      line_center_y - step
    }
  } else {
    let line_count = rich_text_block_visual_line_count(block)
    if visual_line >= line_count - 1 {
      block_top + line_height + block.inset.top + block.inset.bottom + 1.0
    } else {
      line_center_y + step
    }
  }
  let target_point = @core.Point::new(
    x=caret_rect.origin.x + caret_rect.size.width * 0.5,
    y=target_y,
  )
  match
    rich_text_document_source_offset_at_point(
      document, target_point, content, base_font, text_system,
    ) {
    Some(offset) =>
      if offset != source_caret {
        offset
      } else {
        rich_text_vertical_block_boundary_offset(
          document,
          block_index,
          source_caret,
          up~,
        )
      }
    None =>
      rich_text_vertical_block_boundary_offset(
        document,
        block_index,
        source_caret,
        up~,
      )
  }
}

///|
fn rich_text_vertical_block_boundary_offset(
  document : RichTextDocument,
  block_index : Int,
  source_caret : Int,
  up~ : Bool,
) -> Int {
  if up {
    if block_index <= 0 {
      return 0
    }
    let prev_block = document.blocks[block_index - 1]
    match rich_text_block_end_source_offset(prev_block) {
      Some(end) => end
      None => source_caret
    }
  } else {
    if block_index >= document.blocks.length() - 1 {
      return source_caret
    }
    let next_block = document.blocks[block_index + 1]
    match next_block.content_range {
      Some(range) => range.start
      None =>
        match next_block.source_range {
          Some(range) => range.start
          None => source_caret
        }
    }
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
    if record_history && previous != edit.text {
      // The transform API only exposes before/after documents, so the
      // entry falls back to a one-shot prefix/suffix diff at push time.
      let (start, before, after) = @core.text_history_delta(
        previous,
        edit.text,
      )
      rich_text_history_extend_stack(
        undo_stack,
        rich_text_history_record_edit(
          control,
          previous,
          edit.text,
          control.caret,
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
    }
  } else {
    { text: previous, control, changed: false }
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
          block, base_font, text_system,
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
        match rich_text_block_selection_visual_range(block, selection) {
          Some(range) =>
            append_rich_text_block_selection_rect(
              commands, block, range, frame, base_font, text_system,
            )
          None => ()
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
    document, source_caret, content, base_font, text_system,
  )
}

///|
fn rich_text_document_caret_rect(
  document : RichTextDocument,
  source_caret : Int,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
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
    let line_height = rich_text_block_line_height(block, base_font, text_system)
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
      Some(table) =>
        return Some(
          rich_text_block_table_caret_rect(
            block, table, source_caret, frame, base_font, text_system,
          ),
        )
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
    let line_height = rich_text_block_line_height(block, base_font, text_system)
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
    if point.y < y + block_height {
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
    last_block = Some(block)
    last_frame = frame
    last_offset = rich_text_block_end_source_offset(block)
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
    let line_height = rich_text_block_line_height(block, base_font, text_system)
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
  let width = max_double(
    rich_text_width(block.prefix, font, text_system),
    font.size * 1.8,
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
  let width = max_double(
    rich_text_width(block.prefix, font, text_system),
    font.size * 1.8,
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
fn rich_text_block_visual_offset_at_point(
  block : RichTextBlock,
  point : @core.Point,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Int {
  let font = rich_text_block_font(block, base_font)
  let line_step = rich_text_block_line_step(block, base_font, text_system)
  let target_line = @core.clamp_int(
    ((point.y - frame.origin.y) / line_step).floor().to_int(),
    0,
    rich_text_block_visual_line_count(block) - 1,
  )
  let mut origin = frame.origin.x
  let mut visual_offset = 0
  let mut line = 0
  let mut line_end = 0
  if block.prefix != "" {
    let prefix_length = text_length(block.prefix)
    let hit = rich_text_run_visual_offset_at_x(
      block.prefix,
      font,
      point.x,
      origin,
      text_system,
    )
    let width = rich_text_width(block.prefix, font, text_system)
    if target_line == 0 && (hit < prefix_length || point.x <= origin + width) {
      return hit
    }
    visual_offset = visual_offset + prefix_length
    line_end = visual_offset
    origin = origin + width
  }
  for run in block.runs {
    let run_font = run.font.unwrap_or(font)
    let segments = rich_text_split_lines(rich_text_run_visual_text(run))
    for index, segment in segments {
      let segment_length = text_length(segment)
      let segment_width = rich_text_run_segment_width(
        run, segment, run_font, text_system,
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
  let mut remaining = @core.clamp_int(
    visual_offset,
    0,
    rich_text_block_visual_length(block),
  )
  let mut x = frame.origin.x
  let mut y = frame.origin.y
  if block.prefix != "" {
    let prefix_length = text_length(block.prefix)
    if remaining <= prefix_length {
      let prefix = rich_text_prefix(block.prefix, remaining)
      x = x + rich_text_width(prefix, font, text_system)
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
    x = x + rich_text_width(block.prefix, font, text_system)
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
        y = y + line_step
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
      let row_index = @core.clamp_int(
        ((point.y - frame.origin.y) / table.row_height).floor().to_int(),
        0,
        row_count - 1,
      )
      let column_width = frame.size.width / column_count.to_double()
      let column_index = @core.clamp_int(
        ((point.x - frame.origin.x) / column_width).floor().to_int(),
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
          // cell 文本 frame = cell_frame.inset(cell_padding)，按 cell.align 决定 x 起点。
          let cell_x = frame.origin.x + column_width * column_index.to_double()
          let inner_x = cell_x + table.cell_padding.left
          let inner_width = max_double(
            0.0,
            column_width - table.cell_padding.left - table.cell_padding.right,
          )
          // 空 cell 直接钳到 range.start，避免后续除零/无效测量。
          if range.end <= range.start || cell.text == "" {
            return Some(range.start)
          }
          let base_block_font = rich_text_block_font(block, base_font)
          // 渲染端对 header cell 加重 weight=700，body 用 400。
          let cell_font = if cell.header {
            { ..base_block_font, weight: 700 }
          } else {
            { ..base_block_font, weight: 400 }
          }
          let text_width = rich_text_width(cell.text, cell_font, text_system)
          if text_width <= 0.0 {
            return Some(range.start)
          }
          let text_x = match cell.align.unwrap_or(@core.TextAlign::TextStart) {
            TextStart => inner_x
            TextCenter => inner_x + (inner_width - text_width) / 2.0
            TextEnd => inner_x + inner_width - text_width
          }
          let text_x_end = text_x + text_width
          // 点击落在文本左右两侧空白时，clamp 到 range 边界。
          if point.x < text_x {
            return Some(range.start)
          }
          if point.x > text_x_end {
            return Some(range.end)
          }
          // 点击落在文本渲染范围内：按逐字符中点命中，再钳到图形素边界。
          // 参考 rich_text_run_visual_offset_at_x 的 for index in 0..<chars.length() 分支。
          let chars = cell.text.to_array()
          let boundaries = @core.TextGraphemeBoundaries::new(text=cell.text)
          let mut local_offset = chars.length()
          for index in 0..<chars.length() {
            let before = rich_text_width(
              String::from_array(chars[0:index]),
              cell_font,
              text_system,
            )
            let after = rich_text_width(
              String::from_array(chars[0:index + 1]),
              cell_font,
              text_system,
            )
            if point.x < text_x + (before + after) / 2.0 {
              local_offset = boundaries.nearest_boundary(index)
              break
            }
          }
          if local_offset == chars.length() {
            local_offset = boundaries.nearest_boundary(chars.length())
          }
          Some(
            @core.clamp_int(range.start + local_offset, range.start, range.end),
          )
        }
        None => None
      }
    }
    None => None
  }
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
  let column_width = if column_count > 0 {
    frame.size.width / column_count.to_double()
  } else {
    0.0
  }
  // 默认 caret 矩形：表格起点。
  let base_font_resolved = rich_text_block_font(block, base_font)
  let line_step = rich_text_block_line_step(block, base_font, text_system)
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
  // 与渲染端一致的 cell 几何。
  let cell_x = frame.origin.x + column_width * found_col.to_double()
  let row_y = frame.origin.y + table.row_height * found_row.to_double()
  let text_frame = @core.Rect::new(
    x=cell_x + table.cell_padding.left,
    y=row_y + table.cell_padding.top,
    width=max_double(
      0.0,
      column_width - table.cell_padding.left - table.cell_padding.right,
    ),
    height=table.row_height - table.cell_padding.top - table.cell_padding.bottom,
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
      // prefix 宽度。
      let chars = cell.text.to_array()
      let prefix = String::from_array(
        chars[0:@core.clamp_int(local_offset, 0, chars.length())],
      )
      let prefix_width = rich_text_width(prefix, cell_font, text_system)
      // 按 align 计算 text_x（与点击映射对称）。
      let text_width = rich_text_width(cell.text, cell_font, text_system)
      let inner_width = text_frame.size.width
      let text_x = match cell.align.unwrap_or(@core.TextAlign::TextStart) {
        TextStart => text_frame.origin.x
        TextCenter => text_frame.origin.x + (inner_width - text_width) / 2.0
        TextEnd => text_frame.origin.x + inner_width - text_width
      }
      rich_text_cursor_rect_at(text_x + prefix_width, text_frame, cell_font)
    }
    None => rich_text_cursor_rect_at(text_frame.origin.x, text_frame, cell_font)
  }
}
