///|
pub fn Paragraph::layout_utf8(
  text : Bytes,
  family_name? : Bytes = b"",
  size? : Float = 12.0,
  weight? : Int = 400,
  width? : Int = 5,
  slant? : Int = 0,
  max_width? : Float = 1000000000.0,
  left_to_right? : Bool = true,
) -> Paragraph? {
  ignore(text)
  ignore(family_name)
  ignore(size)
  ignore(weight)
  ignore(width)
  ignore(slant)
  ignore(max_width)
  ignore(left_to_right)
  None
}

///|
pub fn Paragraph::is_available(self : Paragraph) -> Bool {
  ignore(self)
  false
}

///|
pub fn Paragraph::width(self : Paragraph) -> Float {
  ignore(self)
  0.0
}

///|
pub fn Paragraph::height(self : Paragraph) -> Float {
  ignore(self)
  0.0
}

///|
pub fn Paragraph::line_count(self : Paragraph) -> Int {
  ignore(self)
  0
}

///|
pub fn Paragraph::line_metrics(self : Paragraph) -> Array[ParagraphLineMetric] {
  ignore(self)
  []
}

///|
pub fn Paragraph::text_boxes_utf8(
  self : Paragraph,
  start : Int,
  end : Int,
) -> Array[@skia.Rect] {
  ignore(self)
  ignore(start)
  ignore(end)
  []
}

///|
pub fn Paragraph::text_box_directions_utf8(
  self : Paragraph,
  start : Int,
  end : Int,
) -> Array[Int] {
  ignore(self)
  ignore(start)
  ignore(end)
  []
}

///|
pub fn Paragraph::hit_test_utf8(
  self : Paragraph,
  x : Float,
  y : Float,
) -> ParagraphHitTestResult {
  ignore(self)
  ignore(x)
  ignore(y)
  { offset: 0, downstream: true }
}
