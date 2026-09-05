///|
priv struct TextEditResult {
  text : String
  caret : Int
  selection : @core.TextRange?
  start : Int
  before : String
  after : String
}

///|
/// The committed range/replacement pair of a text-input edit, published to
/// the `on_input_edit` channel so document-backed consumers (the Markdown
/// session) can build their transaction from the edit itself instead of
/// re-deriving it by diffing the two whole-source strings.
priv struct RichTextInputEdit {
  start : Int
  deleted : String
  replacement : String
}

///|
priv struct TextHistoryRestoreResult {
  text : String
  control : @core.TextControlStateContext
  changed : Bool
}

///|
priv struct TextInputApplyResult {
  text : String
  control : @core.TextControlStateContext
  changed : Bool
  // The edit that produced the text, when this result came from a
  // range/replacement application (None for caret/selection/composition
  // and history-restore results).
  edit : RichTextInputEdit?
}

///|
fn restore_text_history(
  control : @core.TextControlStateContext,
  current : String,
  undo~ : Bool,
) -> TextHistoryRestoreResult {
  rich_text_history_reset_group()
  let source = if undo { control.undo_stack } else { control.redo_stack }
  if source.length() == 0 {
    return { text: current, control, changed: false }
  }
  let restored = source[source.length() - 1]
  let restored_text = if undo {
    restored.undo_text(current)
  } else {
    restored.redo_text(current)
  }
  let next_source = source[:source.length() - 1].to_owned()
  let current_entry : @core.TextHistoryEntryContext = {
    ..restored,
    caret: control.caret,
    selection: control.selection,
  }
  let destination = if undo { control.redo_stack } else { control.undo_stack }
  let next_destination = destination + [current_entry]
  let next_control = if undo {
    {
      ..control,
      caret: restored.caret,
      selection: restored.selection,
      composition: None,
      composition_cursor: None,
      undo_stack: next_source,
      redo_stack: next_destination,
    }
  } else {
    {
      ..control,
      caret: restored.caret,
      selection: restored.selection,
      composition: None,
      composition_cursor: None,
      undo_stack: next_destination,
      redo_stack: next_source,
    }
  }
  {
    text: restored_text,
    control: next_control,
    changed: restored_text != current,
  }
}

///|
fn apply_text_input(
  control : @core.TextControlStateContext,
  text : String,
  event : @core.TextInputEvent,
  record_history~ : Bool,
) -> TextInputApplyResult {
  match event {
    @core.TextInputEvent::InsertText(inserted) => {
      if inserted == "" {
        return { text, control, changed: false, edit: None }
      }
      let edit = replace_current_selection(
        text,
        control.caret,
        control.selection,
        inserted,
      )
      apply_text_edit(control, text, edit, record_history~)
    }
    @core.TextInputEvent::ReplaceText(range, replacement) => {
      let (next_text, deleted, start) = @core.replace_text_range_edit(
        text~,
        range,
        replacement,
      )
      let next_edit : TextEditResult = {
        text: next_text,
        caret: start + text_length(replacement),
        selection: None,
        start,
        before: deleted,
        after: replacement,
      }
      apply_text_edit(control, text, next_edit, record_history~)
    }
    @core.TextInputEvent::SetSelection(range) => {
      let normalized = @core.normalize_grapheme_range(
        @core.TextGraphemeBoundaries::new(text~),
        range,
      )
      let next_selection = if normalized.is_collapsed() {
        None
      } else {
        Some(normalized)
      }
      let next_control = {
        ..control,
        caret: normalized.end,
        selection: next_selection,
        composition: None,
        composition_cursor: None,
      }
      {
        text,
        control: next_control,
        changed: next_control.caret != control.caret ||
        next_control.selection != control.selection ||
        control.composition is Some(_) ||
        control.composition_cursor is Some(_),
        edit: None,
      }
    }
    @core.TextInputEvent::CompositionStart => {
      let next_control = {
        ..control,
        composition: Some(""),
        composition_cursor: None,
      }
      { text, control: next_control, changed: true, edit: None }
    }
    @core.TextInputEvent::CompositionUpdate(update) => {
      let next_control = {
        ..control,
        composition: if update.text() == "" {
          None
        } else {
          Some(update.text())
        },
        composition_cursor: match update.cursor() {
          Some(cursor) => {
            let normalized = @core.normalize_grapheme_range(
              @core.TextGraphemeBoundaries::new(text=update.text()),
              cursor,
            )
            let length = text_length(update.text())
            let start = @core.clamp_int(normalized.start, 0, length)
            let end = @core.clamp_int(normalized.end, 0, length)
            Some(@core.TextRange::new(start~, end~))
          }
          None => None
        },
      }
      { text, control: next_control, changed: true, edit: None }
    }
    @core.TextInputEvent::CompositionEnd(inserted) => {
      let next_control = {
        ..control,
        composition: None,
        composition_cursor: None,
      }
      if inserted == "" {
        {
          text,
          control: { ..next_control, selection: None },
          changed: true,
          edit: None,
        }
      } else {
        let edit = replace_current_selection(
          text,
          next_control.caret,
          next_control.selection,
          inserted,
        )
        apply_text_edit(next_control, text, edit, record_history~)
      }
    }
    @core.TextInputEvent::DeleteRange(range) => {
      let next_text = @core.replace_text_range(text, range, "")
      let normalized = range.normalized()
      let chars = text.to_array()
      let edit : TextEditResult = {
        text: next_text,
        caret: normalized.start,
        selection: None,
        start: normalized.start,
        before: String::from_array(chars[normalized.start:normalized.end]),
        after: "",
      }
      apply_text_edit(control, text, edit, record_history~)
    }
    @core.TextInputEvent::DeleteSurrounding(before, after) => {
      let range = @core.surrounding_delete_range(
        text,
        control.caret,
        before,
        after,
      )
      let next_text = @core.replace_text_range(text, range, "")
      let chars = text.to_array()
      let edit : TextEditResult = {
        text: next_text,
        caret: range.start,
        selection: None,
        start: range.start,
        before: String::from_array(chars[range.start:range.end]),
        after: "",
      }
      apply_text_edit(control, text, edit, record_history~)
    }
  }
}

///|
/// Classify the undo-merge shape directly from the applied edit's known
/// range (`start`/`before`/`after`) instead of re-deriving it by scanning
/// the two whole documents: the edit is the exact diff, so classification
/// is O(edit). The range/rescan-based `rich_text_history_single_edit`
/// stays as the fallback for callers without an edit record.
fn rich_text_history_edit_shape_at(
  start : Int,
  before : String,
  after : String,
  caret : Int,
  selection_active~ : Bool,
) -> (Int, Int, Char)? {
  if selection_active {
    return None
  }
  // A single-codepoint string spans at most two UTF-16 units; anything
  // longer (or a replacement on both sides) never merges.
  let single = fn(text : String) -> Char? {
    if text.length() > 2 {
      None
    } else {
      let chars = text.to_array()
      if chars.length() == 1 { Some(chars[0]) } else { None }
    }
  }
  if before == "" {
    match single(after) {
      Some(ch) if ch != '\n' && caret == start => Some((1, start, ch))
      _ => None
    }
  } else if after == "" {
    match single(before) {
      Some(ch) if ch != '\n' =>
        if caret == start + 1 {
          Some((2, start, ch))
        } else if caret == start {
          Some((3, start, ch))
        } else {
          None
        }
      _ => None
    }
  } else {
    None
  }
}

///|
fn apply_text_edit(
  control : @core.TextControlStateContext,
  previous : String,
  edit : TextEditResult,
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
      rich_text_history_extend_stack(
        undo_stack,
        rich_text_history_record_edit(
          control,
          previous,
          edit.text,
          control.caret,
          shape=Some(
            rich_text_history_edit_shape_at(
              edit.start,
              edit.before,
              edit.after,
              control.caret,
              selection_active=(
                @core.active_text_selection(control.selection) is Some(_)
              ),
            ),
          ),
        ),
        {
          start: edit.start,
          before: edit.before,
          after: edit.after,
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
      edit: Some({
        start: edit.start,
        deleted: edit.before,
        replacement: edit.after,
      }),
    }
  } else {
    { text: previous, control, changed: false, edit: None }
  }
}

///|
fn replace_current_selection(
  text : String,
  caret : Int,
  selection : @core.TextRange?,
  replacement : String,
) -> TextEditResult {
  let range = match selection {
    Some(selection) => selection
    None => @core.TextRange::collapsed(caret)
  }
  // One fused core scan yields the next text, the deleted slice, and the
  // normalized start; no full char-array copy just to slice `before`.
  let (next_text, deleted, start) = @core.replace_text_range_edit(
    text~,
    range,
    replacement,
  )
  {
    text: next_text,
    caret: start + text_length(replacement),
    selection: None,
    start,
    before: deleted,
    after: replacement,
  }
}

///|
test {
  let boundaries = @core.TextGraphemeBoundaries::new(text="hello")
  ignore(@core.text_input_grapheme_selection(boundaries, None))
}

///|
test "rich text replace current selection advances caret by unicode scalars" {
  let edit = replace_current_selection(
    "a🤣b",
    1,
    Some(@core.TextRange::new(start=1, end=2)),
    "尾巴",
  )
  inspect(edit.text, content="a尾巴b")
  inspect(edit.caret, content="3")
}

///|
test "markdown image source resolves relative targets against base_dir" {
  let image = markdown_inline("cat.png", Image, target=Some("cat.png"))
  // Without a base_dir, the target is returned verbatim.
  @debug.debug_inspect(
    markdown_inline_image_source(image),
    content="Some(\"cat.png\")",
  )
  // With a base_dir, a relative target is rooted at the document directory.
  @debug.debug_inspect(
    markdown_inline_image_source(image, base_dir=Some("/tmp/docs")),
    content="Some(\"/tmp/docs/cat.png\")",
  )
  // Trailing separators are handled without doubling.
  @debug.debug_inspect(
    markdown_inline_image_source(image, base_dir=Some("/tmp/docs/")),
    content="Some(\"/tmp/docs/cat.png\")",
  )
  // Absolute paths, data: and http: URIs are never re-rooted.
  let abs = markdown_inline("/abs/cat.png", Image, target=Some("/abs/cat.png"))
  @debug.debug_inspect(
    markdown_inline_image_source(abs, base_dir=Some("/tmp/docs")),
    content="Some(\"/abs/cat.png\")",
  )
  let url = markdown_inline("u", Image, target=Some("https://e.com/c.png"))
  @debug.debug_inspect(
    markdown_inline_image_source(url, base_dir=Some("/tmp/docs")),
    content="Some(\"https://e.com/c.png\")",
  )
  let data = markdown_inline(
    "d",
    Image,
    target=Some("data:image/png;base64,AAAA"),
  )
  @debug.debug_inspect(
    markdown_inline_image_source(data, base_dir=Some("/tmp/docs")),
    content="Some(\"data:image/png;base64,AAAA\")",
  )
}

///|
test "code highlight tokenizer classifies moonbit keywords and strings" {
  let spans = code_highlight_tokenize("let x = \"hi\" // note", "moonbit")
  // Expect: keyword(let) plain(x =) string("hi") plain( ) comment(// note)
  let kinds = spans.map(span => span.kind)
  assert_true(kinds.contains(CodeKeyword))
  assert_true(kinds.contains(CodeString))
  assert_true(kinds.contains(CodeComment))
  // Supported languages still classify tokens instead of falling back.
  let python = code_highlight_tokenize(
    "# config\ndef add(a, b):\n    return a + b\n", "python",
  )
  assert_true(
    python.any(span => span.text == "# config" && span.kind == CodeComment),
  )
  assert_true(
    python.any(span => span.text == "def" && span.kind == CodeKeyword),
  )
  assert_true(
    python.any(span => span.text == "return" && span.kind == CodeKeyword),
  )
  assert_true(python.any(span => span.text == "a" && span.kind == CodePlain))
  assert_true(python.any(span => span.text == "+" && span.kind == CodeOperator))
  // Unsupported language falls back to a single plain span.
  let plain = code_highlight_tokenize("let x = 1", "perl")
  assert_eq(plain.length(), 1)
  assert_true(plain[0].kind == CodePlain)
}

///|
fn[Msg] text_input_messages(
  on_input : ((String) -> Msg)?,
  text : String,
) -> Array[Msg] {
  match on_input {
    Some(handler) => [handler(text)]
    None => []
  }
}

///|
fn[Msg] text_input_edit_messages(
  on_input_edit : ((String, Int, @core.TextRange?, RichTextInputEdit?) -> Msg)?,
  text : String,
  control : @core.TextControlStateContext,
  record? : RichTextInputEdit? = None,
) -> Array[Msg] {
  match on_input_edit {
    Some(handler) => [
      handler(text, control.caret, control.selection, record),
    ]
    None => []
  }
}

///|
fn rich_text_exact_channel(
  key : @core.DeclarationKey,
) -> @core.DeclarationChannel {
  @core.DeclarationChannel::Exact(key)
}

///|
fn rich_text_declaration(
  layout? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
  paint? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
  semantics? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
  platform? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
) -> @core.ViewDeclaration {
  @core.ViewDeclaration::channels(layout~, paint~, semantics~, platform~)
}

///|
fn rich_text_record_key(
  type_tag : String,
  fields : Array[(String, @core.DeclarationKey)],
) -> @core.DeclarationKey {
  @core.DeclarationKey::record(type_tag~, fields~)
}

///|
fn declaration_point_key(point : @core.Point) -> @core.DeclarationKey {
  rich_text_record_key("Point", [
    ("x", @core.DeclarationKey::double(point.x)),
    ("y", @core.DeclarationKey::double(point.y)),
  ])
}

///|
fn declaration_size_key(size : @core.Size) -> @core.DeclarationKey {
  rich_text_record_key("Size", [
    ("width", @core.DeclarationKey::double(size.width)),
    ("height", @core.DeclarationKey::double(size.height)),
  ])
}

///|
fn declaration_color_key(color : @core.Color) -> @core.DeclarationKey {
  rich_text_record_key("Color", [
    ("r", @core.DeclarationKey::double(color.r)),
    ("g", @core.DeclarationKey::double(color.g)),
    ("b", @core.DeclarationKey::double(color.b)),
    ("a", @core.DeclarationKey::double(color.a)),
  ])
}

///|
fn declaration_brush_key(value : @core.Brush) -> @core.DeclarationKey {
  match value {
    @core.Brush::Solid(color) =>
      rich_text_record_key("Brush.Solid", [
        ("color", declaration_color_key(color)),
      ])
    @core.Brush::LinearGradient(spec) =>
      rich_text_record_key("Brush.LinearGradient", [
        ("start", declaration_point_key(spec.start)),
        ("end", declaration_point_key(spec.end)),
        ("start_color", declaration_color_key(spec.start_color)),
        ("end_color", declaration_color_key(spec.end_color)),
      ])
    @core.Brush::RadialGradient(spec) =>
      rich_text_record_key("Brush.RadialGradient", [
        ("center", declaration_point_key(spec.center)),
        ("radius", @core.DeclarationKey::double(spec.radius)),
        ("center_color", declaration_color_key(spec.center_color)),
        ("edge_color", declaration_color_key(spec.edge_color)),
      ])
  }
}

///|
fn declaration_border_key(value : @core.BorderStyle) -> @core.DeclarationKey {
  rich_text_record_key("BorderStyle", [
    ("brush", declaration_brush_key(value.brush)),
    ("width", @core.DeclarationKey::double(value.width)),
  ])
}

///|
fn declaration_border_option_key(
  value : @core.BorderStyle?,
) -> @core.DeclarationKey {
  @core.DeclarationKey::option(value.map(declaration_border_key))
}

///|
fn declaration_text_range_key(value : @core.TextRange) -> @core.DeclarationKey {
  rich_text_record_key("TextRange", [
    ("start", @core.DeclarationKey::int(value.start)),
    ("end", @core.DeclarationKey::int(value.end)),
  ])
}

///|
fn declaration_text_range_option_key(
  value : @core.TextRange?,
) -> @core.DeclarationKey {
  @core.DeclarationKey::option(value.map(declaration_text_range_key))
}

///|
fn declaration_font_family_key(
  family : @core.FontFamily,
) -> @core.DeclarationKey {
  match family {
    @core.FontFamily::Name(name) =>
      rich_text_record_key("FontFamily.Name", [
        ("name", @core.DeclarationKey::string(name)),
      ])
    @core.FontFamily::SystemUi => @core.DeclarationKey::int(1)
    @core.FontFamily::UiSansSerif => @core.DeclarationKey::int(2)
    @core.FontFamily::UiSerif => @core.DeclarationKey::int(3)
    @core.FontFamily::UiMonospace => @core.DeclarationKey::int(4)
    @core.FontFamily::SansSerif => @core.DeclarationKey::int(5)
    @core.FontFamily::Serif => @core.DeclarationKey::int(6)
    @core.FontFamily::Monospace => @core.DeclarationKey::int(7)
    @core.FontFamily::Emoji => @core.DeclarationKey::int(8)
    @core.FontFamily::Math => @core.DeclarationKey::int(9)
    @core.FontFamily::FangSong => @core.DeclarationKey::int(10)
  }
}

///|
fn declaration_font_key(font : @core.FontSpec) -> @core.DeclarationKey {
  rich_text_record_key("FontSpec", [
    (
      "families",
      @core.DeclarationKey::array(
        font.families.families.map(declaration_font_family_key),
      ),
    ),
    ("size", @core.DeclarationKey::double(font.size)),
    ("weight", @core.DeclarationKey::int(font.weight)),
    (
      "style",
      @core.DeclarationKey::int(
        match font.style {
          @core.FontStyle::Normal => 0
          @core.FontStyle::Italic => 1
        },
      ),
    ),
  ])
}

///|
fn[Msg] view_event_result(
  changed? : Bool = false,
  activated? : Bool = false,
  focused? : Bool = false,
  captured? : Bool = false,
  state? : @core.ViewStateContext? = None,
  text_control? : @core.TextControlStateContext? = None,
  dirty? : @core.ViewDirtyHint = @core.ViewDirtyHint::ViewClean,
  messages? : Array[Msg] = [],
) -> @core.ViewEventResult[Msg] {
  {
    changed,
    activated,
    focused,
    captured,
    state,
    text_control,
    dirty,
    messages,
  }
}

///|
fn text_length(text : String) -> Int {
  text.char_length()
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a >= b {
    a
  } else {
    b
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a <= b {
    a
  } else {
    b
  }
}

///|
fn clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
pub fn rich_text_editor_content_rect(frame : @core.Rect) -> @core.Rect {
  frame.inset(@core.Insets::symmetric(horizontal=14.0, vertical=12.0))
}

///|
fn string_prefix(text : String, end : Int) -> String {
  let chars = text.to_array()
  String::from_array(chars[:@core.clamp_int(end, 0, chars.length())])
}

///|
pub fn rich_text_document_height(
  document : RichTextDocument,
  base_font : @core.FontSpec,
  text_system? : @core.TextSystem = @core.TextSystem::fallback(),
) -> Double {
  let mut height = 0.0
  for block in document.blocks {
    height = height +
      rich_text_block_line_height(block, base_font, text_system) +
      block.inset.top +
      block.inset.bottom
  }
  height
}

///|
fn rich_text_block_line_height(
  block : RichTextBlock,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  block_width? : Double = 0.0,
) -> Double {
  let available_width = if block_width > 0.0 {
    max_double(0.0, block_width - block.inset.left - block.inset.right)
  } else {
    0.0
  }
  let mut height = 0.0
  for
    line_height in rich_text_block_line_heights(
      block, base_font, text_system, available_width,
    ) {
    height = height + line_height
  }
  match block.table {
    Some(table) =>
      height = max_double(
        height,
        table.row_height * table.rows.length().to_double(),
      )
    None => ()
  }
  height
}

///|
/// Return the height of each explicit visual line. Image galleries use this
/// rather than a single fixed line height so percentage-sized images can grow
/// with their content column without overlapping following rows.
fn rich_text_block_line_heights(
  block : RichTextBlock,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  available_width : Double,
) -> Array[Double] {
  let line_step = rich_text_block_line_step(block, base_font, text_system)
  let heights : Array[Double] = [line_step]
  for _ in 0..<rich_text_text_newline_count(block.prefix) {
    heights.push(line_step)
  }
  for run in block.runs {
    let segment_count = rich_text_split_lines(rich_text_run_visual_text(run)).length()
    for index in 0..<segment_count {
      let line_index = heights.length() - 1
      let segment_height = rich_text_run_segment_height(
        run,
        line_step,
        available_width~,
      )
      heights[line_index] = max_double(heights[line_index], segment_height)
      if index + 1 < segment_count {
        heights.push(line_step)
      }
    }
  }
  heights
}

///|
/// Return the drawn width of each explicit visual line. The result includes a
/// list prefix when one is present, so line alignment remains correct for all
/// block kinds even though galleries normally have no prefix.
fn rich_text_block_line_widths(
  block : RichTextBlock,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  available_width : Double,
) -> Array[Double] {
  let block_font = rich_text_block_font(block, base_font)
  let widths : Array[Double] = [
    rich_text_width(block.prefix, block_font, text_system),
  ]
  for run in block.runs {
    let font = run.font.unwrap_or(block_font)
    let segments = rich_text_split_lines(rich_text_run_visual_text(run))
    for index, segment in segments {
      let line_index = widths.length() - 1
      widths[line_index] = widths[line_index] +
        rich_text_run_segment_width(
          run,
          segment,
          font,
          text_system,
          available_width~,
        )
      if index + 1 < segments.length() {
        widths.push(0.0)
      }
    }
  }
  widths
}

///|
fn rich_text_line_offset(line_heights : Array[Double], line : Int) -> Double {
  let mut offset = 0.0
  for index in 0..<line {
    match line_heights.get(index) {
      Some(height) => offset = offset + height
      None => ()
    }
  }
  offset
}

///|
fn rich_text_block_line_step(
  block : RichTextBlock,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Double {
  block.line_height.unwrap_or(
    text_system.measure_text(
      @core.TextLayoutInput::new(
        text="Mg",
        font=rich_text_block_font(block, base_font),
      ),
    ).size.height,
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
fn rich_text_run_visual_text(run : RichTextRun) -> String {
  run.visual_text.unwrap_or(run.text)
}

///|
fn rich_text_block_font(
  block : RichTextBlock,
  base_font : @core.FontSpec,
) -> @core.FontSpec {
  block.font.unwrap_or(base_font)
}

///|
fn rich_text_block_color(
  block : RichTextBlock,
  foreground : @core.Color,
) -> @core.Color {
  block.color.unwrap_or(foreground)
}

///|
fn rich_text_width(
  text : String,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Double {
  rich_text_run_width_with_cache(text, font, text_system~, measure=(text, font) => {
    text_system.measure_text(@core.TextLayoutInput::new(text~, font~)).size.width
  })
}

///|
fn rich_text_run_segment_width(
  run : RichTextRun,
  text : String,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
  available_width? : Double = 0.0,
) -> Double {
  match rich_text_run_resolved_image_width(run, available_width) {
    Some(width) => width
    None => rich_text_width(text, font, text_system)
  }
}

///|
fn rich_text_run_segment_height(
  run : RichTextRun,
  line_height : Double,
  available_width? : Double = 0.0,
) -> Double {
  match run.image_size {
    Some(size) =>
      match rich_text_run_resolved_image_width(run, available_width) {
        Some(width) if size.width > 0.0 =>
          max_double(line_height, width * size.height / size.width)
        _ => max_double(line_height, size.height)
      }
    None => line_height
  }
}

///|
fn rich_text_run_resolved_image_width(
  run : RichTextRun,
  available_width : Double,
) -> Double? {
  match run.image_size {
    Some(size) =>
      match run.image_width_fraction {
        Some(fraction) if available_width > 0.0 =>
          Some(
            max_double(
              0.0,
              min_double(
                available_width,
                available_width * clamp_double(fraction, 0.0, 1.0),
              ),
            ),
          )
        _ => Some(size.width)
      }
    None => None
  }
}

///|
fn rich_text_run_hit_width(run : RichTextRun, width : Double) -> Double? {
  match run.image_source {
    Some(_) => Some(width)
    _ => None
  }
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
fn rich_text_input_grapheme_selection(
  boundaries : @core.TextGraphemeBoundaries,
  selection : @core.TextRange?,
) -> @core.TextRange? {
  match selection {
    Some(selection) => {
      let start = boundaries.nearest_boundary(selection.start)
      let end = boundaries.nearest_boundary(selection.end)
      if start == end {
        None
      } else {
        Some(@core.TextRange::new(start~, end~))
      }
    }
    _ => None
  }
}

///|
fn select_rich_text_control(
  control : @core.TextControlStateContext,
  text : String,
) -> @core.TextControlStateContext {
  let length = text_length(text)
  {
    ..control,
    caret: length,
    selection: Some(@core.TextRange::new(start=0, end=length)),
    text_selection_anchor: None,
    composition: None,
    composition_cursor: None,
  }
}

///|
fn selected_rich_text(
  text : String,
  document : RichTextDocument,
  selection : @core.TextRange?,
) -> String {
  match @core.active_text_selection(selection) {
    Some(selection) =>
      if rich_text_document_has_source_ranges(document) {
        selected_rich_text_document_text(document, selection)
      } else {
        @core.selected_text(text, Some(selection))
      }
    None => ""
  }
}

///|
fn selected_rich_text_document_text(
  document : RichTextDocument,
  selection : @core.TextRange,
) -> String {
  let lines : Array[String] = []
  for block in document.blocks {
    match selected_rich_text_block_text(block, selection) {
      Some(text) => lines.push(text)
      None => ()
    }
  }
  join_text_lines(lines)
}

///|
fn selected_rich_text_block_text(
  block : RichTextBlock,
  selection : @core.TextRange,
) -> String? {
  match (block.source_range, block.content_range) {
    (Some(source), Some(content)) =>
      if selection.end <= source.start || selection.start >= source.end {
        None
      } else {
        let start = @core.clamp_int(selection.start, content.start, content.end)
        let end = @core.clamp_int(selection.end, content.start, content.end)
        let text = selected_rich_text_runs_text(block, start, end)
        if text == "" && start != end {
          None
        } else {
          Some(text)
        }
      }
    (_, Some(content)) =>
      if selection.end <= content.start || selection.start >= content.end {
        None
      } else {
        let start = @core.clamp_int(selection.start, content.start, content.end)
        let end = @core.clamp_int(selection.end, content.start, content.end)
        let text = selected_rich_text_runs_text(block, start, end)
        if text == "" && start != end {
          None
        } else {
          Some(text)
        }
      }
    _ => None
  }
}

///|
fn selected_rich_text_runs_text(
  block : RichTextBlock,
  start : Int,
  end : Int,
) -> String {
  let parts : Array[String] = []
  for run in block.runs {
    match run.source_range {
      Some(range) =>
        if end > range.start && start < range.end {
          parts.push(
            rich_text_run_copy_range(
              run,
              @core.clamp_int(start - range.start, 0, text_length(run.text)),
              @core.clamp_int(end - range.start, 0, text_length(run.text)),
            ),
          )
        }
      None => ()
    }
  }
  join_text_lines(parts)
}

///|
/// Copy slice for a run between source-text offsets. Wrapped runs carry
/// injected soft-wrap newlines in their visual text; the alignment scan
/// skips exactly those characters so copying a wrapped paragraph yields
/// the canonical source text, matching a plain selection of the same
/// range. Image runs and unwrapped runs keep the existing path: image
/// copy text is alt text, a different string rather than text plus breaks.
fn rich_text_run_copy_range(
  run : RichTextRun,
  start : Int,
  end : Int,
) -> String {
  let copy_text = rich_text_run_copy_text(run)
  if run.image_source is Some(_) || copy_text == run.text {
    let slice_start = rich_text_run_copy_offset(
      start,
      source_text=run.text,
      copy_text~,
    )
    let slice_end = rich_text_run_copy_offset(
      end,
      source_text=run.text,
      copy_text~,
    )
    return rich_text_run_slice(copy_text, slice_start, slice_end)
  }
  let source = run.text.to_array()
  let copy = copy_text.to_array()
  let chars : Array[Char] = []
  let mut source_index = 0
  let mut copy_index = 0
  while source_index < source.length() && copy_index < copy.length() {
    if copy[copy_index] == source[source_index] {
      if source_index >= start && source_index < end {
        chars.push(copy[copy_index])
      }
      source_index = source_index + 1
      copy_index = copy_index + 1
    } else if copy[copy_index] == '\n' {
      copy_index = copy_index + 1
    } else {
      if source_index >= start && source_index < end {
        chars.push(copy[copy_index])
      }
      source_index = source_index + 1
      copy_index = copy_index + 1
    }
  }
  String::from_array(chars)
}

///|
fn rich_text_run_copy_text(run : RichTextRun) -> String {
  match run.visual_text {
    Some(text) => text
    None =>
      match run.image_source {
        Some(_) => rich_text_image_alt_text(run.text).unwrap_or(run.text)
        None => run.text
      }
  }
}

///|
fn rich_text_run_copy_offset(
  source_offset : Int,
  source_text~ : String,
  copy_text~ : String,
) -> Int {
  let source_length = text_length(source_text)
  let copy_length = text_length(copy_text)
  if source_length <= 0 || copy_length <= 0 {
    0
  } else {
    @core.clamp_int(
      (source_offset.to_double() *
      copy_length.to_double() /
      source_length.to_double())
      .round()
      .to_int(),
      0,
      copy_length,
    )
  }
}

///|
fn rich_text_image_alt_text(text : String) -> String? {
  let chars = text.to_array()
  if chars.length() < 5 || chars[0] != '!' || chars[1] != '[' {
    return None
  }
  let mut index = 2
  while index < chars.length() {
    if chars[index] == ']' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '(' {
      return Some(String::from_array(chars[2:index]))
    }
    index = index + 1
  }
  None
}

///|
fn rich_text_run_slice(text : String, start : Int, end : Int) -> String {
  let chars = text.to_array()
  let range = @core.normalize_grapheme_range(
    @core.TextGraphemeBoundaries::new(text~),
    @core.TextRange::new(start~, end~),
  )
  let start = @core.clamp_int(range.start, 0, chars.length())
  let end = @core.clamp_int(range.end, start, chars.length())
  String::from_array(chars[start:end])
}

///|
fn join_text_lines(lines : Array[String]) -> String {
  let chars : Array[Char] = []
  for index in 0..<lines.length() {
    if index > 0 {
      chars.push('\n')
    }
    chars.append(lines[index].to_array())
  }
  String::from_array(chars)
}

///|
fn rich_text_document_has_source_ranges(document : RichTextDocument) -> Bool {
  document.blocks.any(block => {
    block.source_range is Some(_) ||
    block.content_range is Some(_) ||
    block.runs.any(run => run.source_range is Some(_)) ||
    rich_text_block_table_has_source_ranges(block)
  })
}

///|
fn rich_text_block_table_has_source_ranges(block : RichTextBlock) -> Bool {
  match block.table {
    Some(table) =>
      table.rows.any(row => row.any(cell => cell.source_range is Some(_)))
    None => false
  }
}

///|
fn rich_text_table_column_count(table : RichTextTable) -> Int {
  let mut count = 0
  for row in table.rows {
    count = @core.max_int(count, row.length())
  }
  count
}

///|
fn rich_text_block_cache_key(
  index : Int,
  block : RichTextBlock,
  frame : @core.Rect,
) -> String {
  // 注意：不要把 frame.origin 纳入 cache_key。
  // 渲染器在栅格化 cached layer 时会做 translate(-origin.x, -origin.y) 抵消，
  // pixmap 内容只依赖 block 自身 + frame.size，与 origin 无关。
  // origin 仅在 draw_cached_layer_pixmap 贴图阶段用于定位。
  // 滚动时让节点重建拿到新 origin，是通过 facade.mbt 的 paint declaration
  // key 精确编码 scroll_y 实现；该路径不依赖 layer cache 失效，layer 仍可
  // 命中并以新 frame 贴图。
  // 把 origin 编码进 cache_key 反而会导致滚动时所有 block 缓存全 miss，触发
  // 重栅格化与缓存驱逐抖动，造成滚动后明显卡顿。
  "rich-text-block;range=\{rich_text_source_range_key(block.source_range)};index=\{index};w=\{frame.size.width};h=\{frame.size.height}"
}

///|
fn rich_text_block_content_revision(
  block : RichTextBlock,
  index : Int,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  foreground : @core.Color,
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
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_align_optional_key(block.line_align),
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
      rich_text_double_optional_key(run.image_width_fraction),
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
    Some(range) => "len=\{@core.max_int(0, range.end - range.start)}"
    None => "none"
  }
}

///|
fn rich_text_optional_string_key(value : String?) -> String {
  value.unwrap_or("none")
}

///|
fn rich_text_size_optional_key(value : @core.Size?) -> String {
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
fn rich_text_font_optional_key(value : @core.FontSpec?) -> String {
  match value {
    Some(font) => rich_text_font_key(font)
    None => "none"
  }
}

///|
fn rich_text_font_key(font : @core.FontSpec) -> String {
  "\{font.css_family()}|\{font.size}|\{font.weight}|\{font.css_style()}"
}

///|
fn rich_text_color_optional_key(value : @core.Color?) -> String {
  match value {
    Some(color) => rich_text_color_key(color)
    None => "none"
  }
}

///|
fn rich_text_color_key(color : @core.Color) -> String {
  "\{color.r},\{color.g},\{color.b},\{color.a}"
}

///|
fn rich_text_brush_optional_key(value : @core.Brush?) -> String {
  match value {
    Some(brush) => rich_text_brush_key(brush)
    None => "none"
  }
}

///|
fn rich_text_brush_key(brush : @core.Brush) -> String {
  match brush {
    @core.Brush::Solid(color) => "solid:\{rich_text_color_key(color)}"
    @core.Brush::LinearGradient(spec) =>
      "linear:\{spec.start.x},\{spec.start.y},\{spec.end.x},\{spec.end.y},\{rich_text_color_key(spec.start_color)},\{rich_text_color_key(spec.end_color)}"
    @core.Brush::RadialGradient(spec) =>
      "radial:\{spec.center.x},\{spec.center.y},\{spec.radius},\{rich_text_color_key(spec.center_color)},\{rich_text_color_key(spec.edge_color)}"
  }
}

///|
fn rich_text_border_optional_key(value : @core.BorderStyle?) -> String {
  match value {
    Some(border) => "\{rich_text_brush_key(border.brush)}|\{border.width}"
    None => "none"
  }
}

///|
fn rich_text_insets_key(insets : @core.Insets) -> String {
  "\{insets.top},\{insets.right},\{insets.bottom},\{insets.left}"
}

///|
fn rich_text_image_fit_key(fit : @core.ImageFit) -> String {
  match fit {
    @core.ImageFit::Contain => "contain"
    @core.ImageFit::Cover => "cover"
    @core.ImageFit::Stretch => "stretch"
    @core.ImageFit::ScaleDown => "scale-down"
    @core.ImageFit::FitWidth => "fit-width"
    @core.ImageFit::FitHeight => "fit-height"
  }
}

///|
fn rich_text_decoration_key(value : RichTextDecoration?) -> String {
  match value {
    Some(RichTextDecoration::Strikethrough) => "strikethrough"
    None => "none"
  }
}

///|
fn rich_text_align_optional_key(value : @core.TextAlign?) -> String {
  match value {
    Some(@core.TextAlign::TextStart) => "start"
    Some(@core.TextAlign::TextCenter) => "center"
    Some(@core.TextAlign::TextEnd) => "end"
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
/// Exact source↔visual alignment for a run. The visual text is the run's
/// text plus soft-wrap line breaks injected by the shared wrap layout;
/// every injected `'\n'` is flanked by non-newline characters (the viewer
/// wrap refuses to insert before or after a real newline), so aligning
/// the two strings left to right and skipping visual newlines that the
/// source does not have at the same position is exact — no proportional
/// guesswork. Runs without a wrap layer take the equality fast path.
fn rich_text_run_visual_offset_from_source_offset(
  source_offset : Int,
  source_text : String,
  visual_text : String,
) -> Int {
  if source_text == visual_text {
    let clamped = @core.clamp_int(source_offset, 0, text_length(visual_text))
    return clamped
  }
  let source = source_text.to_array()
  let visual = visual_text.to_array()
  let target = @core.clamp_int(source_offset, 0, source.length())
  let mut source_index = 0
  let mut visual_index = 0
  while source_index < target && visual_index < visual.length() {
    if visual[visual_index] == source[source_index] {
      source_index = source_index + 1
      visual_index = visual_index + 1
    } else if visual[visual_index] == '\n' {
      visual_index = visual_index + 1
    } else {
      source_index = source_index + 1
      visual_index = visual_index + 1
    }
  }
  @core.clamp_int(visual_index, 0, visual.length())
}

///|
fn rich_text_run_source_offset_from_visual_offset(
  visual_offset : Int,
  visual_text : String,
  source_text : String,
) -> Int {
  if source_text == visual_text {
    let clamped = @core.clamp_int(visual_offset, 0, text_length(source_text))
    return clamped
  }
  let source = source_text.to_array()
  let visual = visual_text.to_array()
  let target = @core.clamp_int(visual_offset, 0, visual.length())
  let mut source_index = 0
  let mut visual_index = 0
  while visual_index < target &&
        source_index < source.length() &&
        visual_index < visual.length() {
    if visual[visual_index] == source[source_index] {
      source_index = source_index + 1
      visual_index = visual_index + 1
    } else if visual[visual_index] == '\n' {
      visual_index = visual_index + 1
    } else {
      source_index = source_index + 1
      visual_index = visual_index + 1
    }
  }
  @core.clamp_int(source_index, 0, source.length())
}

///|
fn[Msg] selection_messages(
  on_selection_change : ((Int, @core.TextRange?) -> Msg)?,
  caret : Int,
  selection : @core.TextRange?,
) -> Array[Msg] {
  match on_selection_change {
    Some(handler) => [handler(caret, selection)]
    None => []
  }
}
