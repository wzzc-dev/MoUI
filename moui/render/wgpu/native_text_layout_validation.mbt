///|
fn NativeRasterGlyph::is_valid(self : NativeRasterGlyph) -> Bool {
  if self.width <= 0 || self.height <= 0 {
    return false
  }
  match self.format {
    NativeRasterGlyphFormat::AlphaMask =>
      self.width <= self.pixels.length() / self.height
    NativeRasterGlyphFormat::ColorRgba =>
      self.width <= self.pixels.length() / self.height / 4
  }
}

///|
fn NativeTextLayout::is_valid_for_measure(
  self : NativeTextLayout,
  text : String,
) -> Bool {
  self.has_valid_metrics() &&
  self.caret_positions.length() >= text.to_array().length() + 1 &&
  self.has_monotonic_carets()
}

///|
fn NativeTextLayout::is_valid_for_run(
  self : NativeTextLayout,
  text : String,
) -> Bool {
  self.has_valid_metrics() &&
  (
    self.caret_positions.is_empty() ||
    (
      self.caret_positions.length() >= text.to_array().length() + 1 &&
      self.has_monotonic_carets()
    )
  )
}

///|
fn NativeTextLayout::has_valid_metrics(self : NativeTextLayout) -> Bool {
  self.size.width >= 0.0 &&
  self.size.height > 0.0 &&
  self.baseline >= 0.0 &&
  self.baseline <= self.size.height
}

///|
fn NativeTextLayout::has_monotonic_carets(self : NativeTextLayout) -> Bool {
  if self.caret_positions.is_empty() {
    return false
  }
  let mut last = self.caret_positions[0]
  if last < 0.0 {
    return false
  }
  for index in 1..<self.caret_positions.length() {
    let caret = self.caret_positions[index]
    if caret < last {
      return false
    }
    last = caret
  }
  true
}

///|
fn NativeTextLayout::to_text_layout_result(
  self : NativeTextLayout,
) -> @core.TextLayoutResult {
  {
    size: self.size,
    baseline: self.baseline,
    caret_positions: self.caret_positions,
  }
}
