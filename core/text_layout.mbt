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
  let advance = input.font.size * 0.55
  let raw_width = text_length(input.text).to_double() * advance
  let width = match input.max_width {
    Some(max_width) => min_double(raw_width, max_width)
    None => raw_width
  }
  let carets : Array[Double] = []
  let mut index = 0
  let length = text_length(input.text)
  while index <= length {
    carets.push(min_double(index.to_double() * advance, width))
    index = index + 1
  }
  {
    size: Size::new(width~, height=input.font.size * 1.25),
    baseline: input.font.size * 0.8,
    caret_positions: carets,
  }
}
