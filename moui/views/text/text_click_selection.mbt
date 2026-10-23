///|
/// Click counting and click-to-select geometry for the text fields.
///
/// A touch-first framework has to derive "word" and "line" from the pointer,
/// not from a shift-drag: the second click of a pair selects the word under it
/// and the third selects the whole hard line. The counter has to survive across
/// pointer events, so it lives in a view-state slot like the gesture
/// recognizers in `moui/core` do.

///|
priv struct TextClickCount {
  count : Int32
  time_ms : Double
  position : @core.Point
}

///|
let text_click_count_window_ms : Double = 300.0

///|
let text_click_slop : Double = 10.0

///|
impl @core.ViewStateValue for TextClickCount with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.text.ClickCount.v1")
}

///|
impl @core.ViewStateValue for TextClickCount with fn encode_view_state(self) {
  let output = Buffer(size_hint=32)
  output.write_double_be(self.count.to_double())
  output.write_double_be(self.time_ms)
  output.write_double_be(self.position.x)
  output.write_double_be(self.position.y)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for TextClickCount with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 32 {
    None
  } else {
    match @common.view_decode_doubles(bytes, from=0, count=4) {
      Some(values) =>
        Some({
          count: @core.clamp_int(values[0].to_int(), 0, 3),
          time_ms: values[1],
          position: @core.Point::new(x=values[2], y=values[3]),
        })
      None => None
    }
  }
}

///|
fn text_click_count_slot() -> @core.ViewStateSlot[TextClickCount] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.text.click-count"),
    initial={
      count: 0,
      time_ms: 0.0,
      position: @core.Point::new(x=0.0, y=0.0),
    },
  )
}

///|
/// The click count for this `Down`: 1 for a fresh press, 2 and 3 for a repeat
/// inside the window and slop. The clock is `ViewEventContext.now_ms`, the same
/// source the gesture recognizers use, so it is only as fresh as the last frame
/// the host pumped. A host that never pumps leaves it at 0.0, where the time
/// window cannot discriminate and repeated clicks at the same point merge.
fn text_click_count_at_down(
  state : @core.ViewStateContext,
  now_ms~ : Double,
  position~ : @core.Point,
) -> TextClickCount {
  let previous = state.read_slot(text_click_count_slot())
  let repeats = previous.count >= 1 &&
    now_ms - previous.time_ms <= text_click_count_window_ms &&
    (position.x - previous.position.x).abs() <= text_click_slop &&
    (position.y - previous.position.y).abs() <= text_click_slop
  {
    count: if repeats {
      @core.min_int(previous.count + 1, 3)
    } else {
      1
    },
    time_ms: now_ms,
    position,
  }
}

///|
/// The hard line under a char offset: everything between the newlines that
/// surround it. Wrapped visual lines are deliberately not used, so a triple
/// click on a reflowed paragraph selects the paragraph the app actually wrote.
fn text_line_range_at(text : String, offset : Int32) -> @core.TextRange {
  let length = text_length(text)
  let mut index : Int32 = 0
  let mut start : Int32 = 0
  for ch in text {
    if index >= offset {
      break
    }
    if ch == '\n' {
      start = index + 1
    }
    index = index + 1
  }
  let mut end = length
  index = 0
  for ch in text {
    if index > offset && ch == '\n' {
      end = index
      break
    }
    index = index + 1
  }
  @core.TextRange::new(start=@core.min_int(start, end), end~)
}

///|
/// What a click selects: the word on the second click, the hard line on the
/// third, nothing on a plain caret placement.
fn text_click_selection(
  text : String,
  offset : Int32,
  count~ : Int32,
) -> @core.TextRange? {
  if count == 2 {
    Some(@core.text_word_range_at(text, offset))
  } else if count >= 3 {
    let line = text_line_range_at(text, offset)
    if line.is_collapsed() {
      None
    } else {
      Some(line)
    }
  } else {
    None
  }
}

///|
/// Whether this `Move` is the press's own event stream rather than pointer
/// travel: it lands on the down point, so the selection must not extend even
/// though the surface may have scrolled or re-laid-out underneath it.
fn text_pointer_is_stationary(
  control : @core.TextControlStateContext,
  position~ : @core.Point,
) -> Bool {
  match control.text_selection_origin {
    Some(origin) =>
      (position.x - origin.x).abs() <= 1.0 &&
      (position.y - origin.y).abs() <= 1.0
    None => false
  }
}
