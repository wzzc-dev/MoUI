///|
priv struct TextEditResult {
  text : String
  caret : Int
  selection : @core.TextRange?
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
}

///|
fn restore_text_history(
  control : @core.TextControlStateContext,
  current : String,
  undo~ : Bool,
) -> TextHistoryRestoreResult {
  let source = if undo { control.undo_stack } else { control.redo_stack }
  if source.length() == 0 {
    return { text: current, control, changed: false }
  }
  let restored = source[source.length() - 1]
  let next_source = source[:source.length() - 1].to_owned()
  let current_entry : @core.TextHistoryEntryContext = {
    text: current,
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
    text: restored.text,
    control: next_control,
    changed: restored.text != current,
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
        return { text, control, changed: false }
      }
      let edit = replace_current_selection(
        text,
        control.caret,
        control.selection,
        inserted,
      )
      apply_text_edit(control, text, edit, record_history~)
    }
    @core.TextInputEvent::CompositionStart => {
      let next_control = {
        ..control,
        composition: Some(""),
        composition_cursor: None,
      }
      { text, control: next_control, changed: true }
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
      { text, control: next_control, changed: true }
    }
    @core.TextInputEvent::CompositionEnd(inserted) => {
      let next_control = {
        ..control,
        composition: None,
        composition_cursor: None,
      }
      if inserted == "" {
        { text, control: { ..next_control, selection: None }, changed: true }
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
      let edit : TextEditResult = {
        text: next_text,
        caret: range.normalized().start,
        selection: None,
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
      let edit : TextEditResult = {
        text: next_text,
        caret: range.start,
        selection: None,
      }
      apply_text_edit(control, text, edit, record_history~)
    }
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
      undo_stack.push({
        text: previous,
        caret: control.caret,
        selection: control.selection,
      })
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
  let normalized = range.normalized()
  let next_text = @core.replace_text_range(text, range, replacement)
  let caret = normalized.start + text_length(replacement)
  { text: next_text, caret, selection: None }
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
  on_input_edit : ((String, Int, @core.TextRange?) -> Msg)?,
  text : String,
  control : @core.TextControlStateContext,
) -> Array[Msg] {
  match on_input_edit {
    Some(handler) => [handler(text, control.caret, control.selection)]
    None => []
  }
}

///|
fn view_color_revision(color : @core.Color) -> String {
  "\{color.r},\{color.g},\{color.b},\{color.a}"
}

///|
fn view_brush_revision(value : @core.Brush) -> String {
  match value {
    @core.Brush::Solid(color) => "solid:\{view_color_revision(color)}"
    @core.Brush::LinearGradient(spec) =>
      "linear:\{spec.start.x},\{spec.start.y},\{spec.end.x},\{spec.end.y},\{view_color_revision(spec.start_color)},\{view_color_revision(spec.end_color)}"
    @core.Brush::RadialGradient(spec) =>
      "radial:\{spec.center.x},\{spec.center.y},\{spec.radius},\{view_color_revision(spec.center_color)},\{view_color_revision(spec.edge_color)}"
  }
}

///|
fn view_border_option_revision(value : @core.BorderStyle?) -> String {
  match value {
    Some(value) => "\{view_brush_revision(value.brush)}:\{value.width}"
    None => "none"
  }
}

///|
fn view_text_range_option_revision(value : @core.TextRange?) -> String {
  match value {
    Some(value) => "\{value.start}:\{value.end}"
    None => "none"
  }
}

///|
fn view_font_revision(font : @core.FontSpec) -> String {
  let style = match font.style {
    @core.FontStyle::Normal => "normal"
    @core.FontStyle::Italic => "italic"
  }
  "\{font.size}:\{font.weight}:\{style}"
}

///|
fn view_size_revision(size : @core.Size) -> String {
  "\{size.width}x\{size.height}"
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
