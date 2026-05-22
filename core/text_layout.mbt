///|
pub(all) struct TextLayoutInput {
  text : String
  font : FontSpec
  max_width : Double?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextLayoutResult {
  size : Size
  baseline : Double
  caret_positions : Array[Double]
} derive(Eq, Debug, ToJson)

///|
pub fn TextLayoutInput::new(
  text~ : String,
  font~ : FontSpec,
  max_width? : Double,
) -> TextLayoutInput {
  { text, font, max_width }
}

///|
pub fn measure_text_layout(input : TextLayoutInput) -> TextLayoutResult {
  let metrics = @moon_cosmic.Metrics::new(
    Float::from_double(input.font.size),
    Float::from_double(input.font.size * 1.25),
  )
  let attrs = @moon_cosmic.Attrs::new()
    .family(text_layout_cosmic_family(input.font))
    .weight(@moon_cosmic.Weight::new(input.font.weight))
  let attrs_list = @moon_cosmic.AttrsList::new(attrs)
  let max_width = match input.max_width {
    Some(width) => Some(Float::from_double(width))
    None => None
  }
  let buffer = @moon_cosmic.Buffer::new(metrics)
    .set_wrap(@moon_cosmic.Wrap::None)
    .set_size(max_width, None)
    .set_text(input.text, attrs_list, @moon_cosmic.Shaping::Advanced)
    .layout_all()
  let raw = text_layout_result_from_cosmic(input, buffer)
  match input.max_width {
    Some(max_width) => clamp_text_layout_result(raw, max_width)
    None => raw
  }
}

///|
fn text_layout_cosmic_family(font : FontSpec) -> @moon_cosmic.Family {
  if font.family.contains("monospace") ||
    font.family.contains("Mono") ||
    font.family.contains("Menlo") ||
    font.family.contains("Consolas") {
    @moon_cosmic.Family::UiMonospace
  } else if font.family != "" {
    @moon_cosmic.Family::Name(font.family)
  } else {
    @moon_cosmic.Family::UiSansSerif
  }
}

///|
fn text_layout_result_from_cosmic(
  input : TextLayoutInput,
  buffer : @moon_cosmic.Buffer,
) -> TextLayoutResult {
  let char_count = input.text.to_array().length()
  let carets = Array::make(char_count + 1, 0.0)
  let mut width = 0.0
  let mut height = input.font.size * 1.25
  let mut saw_run = false
  for run in buffer.layout_runs() {
    saw_run = true
    width = max_double(width, run.line_w.to_double())
    height = max_double(height, (run.line_top + run.line_height).to_double())
    for glyph in run.glyphs {
      let start = clamp_int(glyph.start, 0, char_count)
      let end = clamp_int(glyph.end, start, char_count)
      let left = glyph.x.to_double()
      let right = (glyph.x + glyph.w).to_double()
      if start < carets.length() {
        carets[start] = max_double(carets[start], left)
      }
      if end < carets.length() {
        carets[end] = max_double(carets[end], right)
      }
    }
  }
  if !saw_run || (char_count > 0 && carets[char_count] == 0.0) {
    return fallback_text_layout_result(input)
  }
  fill_missing_caret_positions(carets)
  {
    size: Size::new(width~, height~),
    baseline: input.font.size * 0.8,
    caret_positions: carets,
  }
}

///|
fn fill_missing_caret_positions(carets : Array[Double]) -> Unit {
  let mut last = 0.0
  for index in 0..<carets.length() {
    if carets[index] < last {
      carets[index] = last
    } else {
      last = carets[index]
    }
  }
}

///|
fn clamp_text_layout_result(
  result : TextLayoutResult,
  max_width : Double,
) -> TextLayoutResult {
  let carets : Array[Double] = []
  for caret in result.caret_positions {
    carets.push(min_double(caret, max_width))
  }
  {
    size: Size::new(
      width=min_double(result.size.width, max_width),
      height=result.size.height,
    ),
    baseline: result.baseline,
    caret_positions: carets,
  }
}

///|
fn fallback_text_layout_result(input : TextLayoutInput) -> TextLayoutResult {
  let width = input.font.size * input.text.to_array().length().to_double() * 0.5
  let carets : Array[Double] = []
  carets.push(0.0)
  let mut cursor = 0.0
  for _ in input.text {
    cursor = cursor + input.font.size * 0.5
    carets.push(cursor)
  }
  {
    size: Size::new(width~, height=input.font.size * 1.25),
    baseline: input.font.size * 0.8,
    caret_positions: carets,
  }
}
