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
pub struct TextSystem {
  id : String
  measure : (TextLayoutInput) -> TextLayoutResult
  register_font_data : (FontFamily, Bytes) -> Unit
}

///|
pub fn TextLayoutInput::new(
  text~ : String,
  font~ : FontSpec,
  max_width? : Double,
) -> TextLayoutInput {
  { text, font, max_width }
}

///|
pub fn TextSystem::new(
  id~ : String,
  measure~ : (TextLayoutInput) -> TextLayoutResult,
  register_font_data? : (FontFamily, Bytes) -> Unit = (_family, _data) => (),
) -> TextSystem {
  { id, measure, register_font_data }
}

///|
pub fn TextSystem::fallback() -> TextSystem {
  TextSystem::new(
    id="core-fallback-text-system",
    measure=fallback_measure_text_layout,
  )
}

///|
pub fn TextSystem::id(self : TextSystem) -> String {
  self.id
}

///|
pub fn TextSystem::measure_text(
  self : TextSystem,
  input : TextLayoutInput,
) -> TextLayoutResult {
  (self.measure)(input)
}

///|
pub fn TextSystem::register_font_data(
  self : TextSystem,
  family : FontFamily,
  data : Bytes,
) -> Unit {
  (self.register_font_data)(family, data)
}

///|
fn fallback_measure_text_layout(input : TextLayoutInput) -> TextLayoutResult {
  let raw = fallback_text_layout_result(input)
  match input.max_width {
    Some(max_width) => clamp_text_layout_result(raw, max_width)
    None => raw
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
