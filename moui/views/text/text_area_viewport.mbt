///|
/// Text-area self-owned scroll position. Like the scroll container, the
/// runtime persists this in a `ViewStateSlot` so the offset survives
/// rebuilds; unlike the scroll container, the text area applies the
/// offset inside its own paint (engine wrapping, widget viewport) and
/// keeps the caret revealed, instead of shifting a child view.
priv struct TextAreaScrollState {
  offset_y : Double
}

///|
impl @core.ViewStateValue for TextAreaScrollState with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.TextAreaScrollState.v1")
}

///|
impl @core.ViewStateValue for TextAreaScrollState with fn encode_view_state(
  self,
) {
  let output = Buffer(size_hint=8)
  output.write_double_be(self.offset_y)
  output.to_bytes()
}

///|
impl @core.ViewStateValue for TextAreaScrollState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 8 {
    None
  } else {
    match @core.ViewStateValue::decode_view_state(0.0, bytes) {
      Some(offset_y) => Some({ offset_y, })
      None => None
    }
  }
}

///|
fn text_area_scroll_slot() -> @core.ViewStateSlot[TextAreaScrollState] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.text_area.position"),
    initial={ offset_y: 0.0 },
  )
}

///|
/// Raw stored offset. Callers clamp through
/// `text_area_clamped_scroll_offset` once the paragraph line count is
/// known, so a content shrink (text replaced externally) clamps the
/// stale offset instead of painting blank space.
fn text_area_scroll_offset(state : @core.ViewStateContext) -> Double {
  state.read_slot(text_area_scroll_slot()).offset_y
}

///|
fn text_area_content_height(line_count~ : Int, line_height~ : Double) -> Double {
  @core.max_int(line_count, 1).to_double() * line_height
}

///|
fn text_area_max_scroll_offset(
  line_count~ : Int,
  line_height~ : Double,
  viewport_height~ : Double,
) -> Double {
  (text_area_content_height(line_count~, line_height~) - viewport_height).max(
    0.0,
  )
}

///|
fn text_area_clamped_scroll_offset(
  raw : Double,
  line_count~ : Int,
  line_height~ : Double,
  viewport_height~ : Double,
) -> Double {
  raw.clamp(
    min=0.0,
    max=text_area_max_scroll_offset(line_count~, line_height~, viewport_height~),
  )
}

///|
/// Wheel mapping with the container's sign convention: positive
/// `wheel_delta.y` moves content down, so the offset decreases; the
/// result is clamped to `[0, content − viewport]` so scrolling past
/// either edge is a no-op instead of jitter.
fn text_area_scroll_offset_after_wheel(
  current~ : Double,
  delta_y~ : Double,
  line_count~ : Int,
  line_height~ : Double,
  viewport_height~ : Double,
) -> Double {
  let max_offset = text_area_max_scroll_offset(
    line_count~,
    line_height~,
    viewport_height~,
  )
  (current - delta_y).clamp(min=0.0, max=max_offset)
}

///|
/// Half-open painted line window `[first, last)` covering the scrolled
/// viewport. Wrapping always covers the full text; only painting is
/// restricted to this window.
fn text_area_visible_line_window(
  offset~ : Double,
  viewport_height~ : Double,
  line_count~ : Int,
  line_height~ : Double,
) -> (Int, Int) {
  if line_count == 0 {
    (0, 0)
  } else if line_height <= 0.0 {
    (0, line_count)
  } else {
    let first = (offset / line_height)
      .floor()
      .to_int()
      .clamp(min=0, max=line_count)
    let last = ((offset + viewport_height) / line_height)
      .ceil()
      .to_int()
      .clamp(min=first, max=line_count)
    (first, last)
  }
}

///|
/// Caret-following: the minimal offset change that brings the caret's
/// line slot fully into the viewport — top-align when the caret sits
/// above the window, bottom-align when below, unchanged when already
/// visible. Partially visible rows count as visible so single-line
/// caret nudges do not chase the scroll.
fn text_area_offset_for_caret_reveal(
  current~ : Double,
  caret_line~ : Int,
  line_count~ : Int,
  line_height~ : Double,
  viewport_height~ : Double,
) -> Double {
  let max_offset = text_area_max_scroll_offset(
    line_count~,
    line_height~,
    viewport_height~,
  )
  let clamped = current.clamp(min=0.0, max=max_offset)
  let line_top = caret_line.to_double() * line_height
  let line_bottom = line_top + line_height
  if line_top < clamped {
    line_top.clamp(min=0.0, max=max_offset)
  } else if line_bottom > clamped + viewport_height {
    (line_bottom - viewport_height).clamp(min=0.0, max=max_offset)
  } else {
    clamped
  }
}

///|
/// Drawn row owning a content y in the widget's slot grid. The pointer
/// and the viewport live in slot space (lines are painted every
/// `line_height`), while paragraph metrics use the engine's own line
/// advance, so pointer hits snap to the visible row first.
fn text_area_line_index_for_slot_y(
  line_count : Int,
  slot_y : Double,
  line_height : Double,
) -> Int {
  if line_count == 0 || line_height <= 0.0 {
    0
  } else {
    (slot_y / line_height).floor().to_int().clamp(min=0, max=line_count - 1)
  }
}

///|
/// Resolve a slot-space pointer point to a caret offset: pick the drawn
/// row, then let the engine resolve x within that row's vertical band.
fn text_area_hit_offset_at_slot(
  paragraph : @core.TextParagraphLayoutResult,
  slot_point : @core.Point,
  line_height : Double,
) -> Int {
  if paragraph.lines.is_empty() {
    0
  } else {
    let row = text_area_line_index_for_slot_y(
      paragraph.lines.length(),
      slot_point.y,
      line_height,
    )
    let line = paragraph.lines[row]
    paragraph.hit_test(
      @core.Point::new(x=slot_point.x, y=line.origin.y + line.size.height / 2.0),
    ).offset
  }
}
