/// S0 spike: a monospace-cell `TextSystem` installed through the public
/// `AppRuntime::set_text_system`. Measurement stays in the same pixel space as
/// the rest of layout, but every text extent is forced to an exact multiple of
/// the cell box, so any remaining off-grid geometry comes from padding, insets
/// and flex division rather than from font advances.

///|
pub let cell_w : Double = 8.0

///|
pub let cell_h : Double = 16.0

///|
pub fn cell_text_system() -> @core.TextSystem {
  @core.TextSystem::new(id="tui-spike-cell", measure=input => {
    cell_measure(input)
  })
}

///|
priv struct WrapState {
  mut total : Int32
  mut widest : Int32
  mut lines : Int32
  mut line_cols : Int32
  mut word : Int32
  mut started : Bool
}

///|
fn wrap_flush_word(st : WrapState, avail : Int32) -> Unit {
  if st.word > 0 {
    if !st.started {
      st.started = true
      st.line_cols = st.word
    } else if st.line_cols + 1 + st.word <= avail {
      st.line_cols = st.line_cols + 1 + st.word
    } else {
      st.lines = st.lines + 1
      st.line_cols = st.word
    }
    st.word = 0
  }
}

///|
fn wrap_end_paragraph(st : WrapState, avail : Int32) -> Unit {
  while st.line_cols > avail {
    st.line_cols = st.line_cols - avail
    st.lines = st.lines + 1
  }
  st.total = st.total + st.lines
  if st.line_cols > st.widest {
    st.widest = st.line_cols
  }
  st.lines = 1
  st.line_cols = 0
  st.started = false
  st.word = 0
}

///|
/// Greedy word wrap counted in whole characters, scanned manually so the spike
/// does not depend on text-segmentation APIs.
fn wrap_lines(text : String, avail : Int32) -> (Int32, Int32) {
  let st : WrapState = {
    total: 0,
    widest: 0,
    lines: 1,
    line_cols: 0,
    word: 0,
    started: false,
  }
  for ch in text {
    if ch == '\n' {
      wrap_flush_word(st, avail)
      wrap_end_paragraph(st, avail)
    } else if ch == ' ' {
      wrap_flush_word(st, avail)
    } else {
      st.word = st.word + 1
    }
  }
  wrap_flush_word(st, avail)
  wrap_end_paragraph(st, avail)
  if st.total < 1 {
    st.total = 1
  }
  (st.total, st.widest)
}

///|
fn cell_measure(input : @core.TextLayoutInput) -> @core.TextLayoutResult {
  let avail = match input.max_width {
    None => 4096
    Some(width) => {
      let cols = (width / cell_w).floor().to_int()
      if cols < 1 {
        1
      } else {
        cols
      }
    }
  }
  let (lines, widest) = wrap_lines(input.text, avail)
  let mut measured = if widest < 1 { 1 } else { widest }
  if measured > avail {
    measured = avail
  }
  {
    size: @core.Size::new(
      width=measured.to_double() * cell_w,
      height=lines.to_double() * cell_h,
    ),
    baseline: cell_h,
    caret_positions: [],
  }
}
