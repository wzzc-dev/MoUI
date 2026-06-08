///|
#borrow(text, family_name)
extern "C" fn native_paragraph_layout_utf8(
  text : Bytes,
  family_name : Bytes,
  size : Float,
  weight : Int,
  width : Int,
  slant : Int,
  max_width : Float,
  left_to_right : Bool,
) -> ParagraphHandle = "moonbit_skia_paragraph_layout_utf8"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_is_null(
  paragraph : ParagraphHandle,
) -> Bool = "moonbit_skia_paragraph_is_null"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_width(
  paragraph : ParagraphHandle,
) -> Float = "moonbit_skia_paragraph_width"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_height(
  paragraph : ParagraphHandle,
) -> Float = "moonbit_skia_paragraph_height"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_count(
  paragraph : ParagraphHandle,
) -> Int = "moonbit_skia_paragraph_line_count"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_start(
  paragraph : ParagraphHandle,
  index : Int,
) -> Int = "moonbit_skia_paragraph_line_start"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_end(
  paragraph : ParagraphHandle,
  index : Int,
) -> Int = "moonbit_skia_paragraph_line_end"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_end_excluding_whitespace(
  paragraph : ParagraphHandle,
  index : Int,
) -> Int = "moonbit_skia_paragraph_line_end_excluding_whitespace"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_end_including_newline(
  paragraph : ParagraphHandle,
  index : Int,
) -> Int = "moonbit_skia_paragraph_line_end_including_newline"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_number(
  paragraph : ParagraphHandle,
  index : Int,
) -> Int = "moonbit_skia_paragraph_line_number"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_hard_break(
  paragraph : ParagraphHandle,
  index : Int,
) -> Bool = "moonbit_skia_paragraph_line_hard_break"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_left(
  paragraph : ParagraphHandle,
  index : Int,
) -> Float = "moonbit_skia_paragraph_line_left"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_width(
  paragraph : ParagraphHandle,
  index : Int,
) -> Float = "moonbit_skia_paragraph_line_width"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_baseline(
  paragraph : ParagraphHandle,
  index : Int,
) -> Float = "moonbit_skia_paragraph_line_baseline"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_ascent(
  paragraph : ParagraphHandle,
  index : Int,
) -> Float = "moonbit_skia_paragraph_line_ascent"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_descent(
  paragraph : ParagraphHandle,
  index : Int,
) -> Float = "moonbit_skia_paragraph_line_descent"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_line_height(
  paragraph : ParagraphHandle,
  index : Int,
) -> Float = "moonbit_skia_paragraph_line_height"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_text_boxes_utf8(
  paragraph : ParagraphHandle,
  start : Int,
  end : Int,
) -> Array[@skia.Rect] = "moonbit_skia_paragraph_text_boxes_utf8"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_hit_test_utf8_offset(
  paragraph : ParagraphHandle,
  x : Float,
  y : Float,
) -> Int = "moonbit_skia_paragraph_hit_test_utf8_offset"

///|
#borrow(paragraph)
extern "C" fn native_paragraph_hit_test_utf8_downstream(
  paragraph : ParagraphHandle,
  x : Float,
  y : Float,
) -> Bool = "moonbit_skia_paragraph_hit_test_utf8_downstream"

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
  if text.is_empty() ||
    !native_paragraph_scalar_is_positive(size) ||
    !native_paragraph_scalar_is_positive(max_width) {
    return None
  }
  let handle = native_paragraph_layout_utf8(
    text,
    family_name,
    size,
    weight.clamp(min=1, max=1000),
    width.clamp(min=1, max=9),
    slant.clamp(min=0, max=2),
    max_width,
    left_to_right,
  )
  if native_paragraph_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Paragraph::is_available(self : Paragraph) -> Bool {
  !native_paragraph_is_null(self.handle)
}

///|
pub fn Paragraph::width(self : Paragraph) -> Float {
  native_paragraph_width(self.handle)
}

///|
pub fn Paragraph::height(self : Paragraph) -> Float {
  native_paragraph_height(self.handle)
}

///|
pub fn Paragraph::line_count(self : Paragraph) -> Int {
  native_paragraph_line_count(self.handle).max(0)
}

///|
pub fn Paragraph::line_metrics(self : Paragraph) -> Array[ParagraphLineMetric] {
  let count = self.line_count()
  let metrics : Array[ParagraphLineMetric] = Array::new(capacity=count)
  for index in 0..<count {
    let metric = ParagraphLineMetric::{
      start: native_paragraph_line_start(self.handle, index),
      end: native_paragraph_line_end(self.handle, index),
      end_excluding_whitespace: native_paragraph_line_end_excluding_whitespace(
        self.handle,
        index,
      ),
      end_including_newline: native_paragraph_line_end_including_newline(
        self.handle,
        index,
      ),
      line_number: native_paragraph_line_number(self.handle, index),
      hard_break: native_paragraph_line_hard_break(self.handle, index),
      left: native_paragraph_line_left(self.handle, index),
      width: native_paragraph_line_width(self.handle, index),
      baseline: native_paragraph_line_baseline(self.handle, index),
      ascent: native_paragraph_line_ascent(self.handle, index),
      descent: native_paragraph_line_descent(self.handle, index),
      height: native_paragraph_line_height(self.handle, index),
    }
    if metric.is_valid() {
      metrics.push(metric)
    }
  }
  metrics
}

///|
pub fn Paragraph::text_boxes_utf8(
  self : Paragraph,
  start : Int,
  end : Int,
) -> Array[@skia.Rect] {
  if end <= start {
    []
  } else {
    native_paragraph_text_boxes_utf8(self.handle, start.max(0), end.max(start))
  }
}

///|
pub fn Paragraph::hit_test_utf8(
  self : Paragraph,
  x : Float,
  y : Float,
) -> ParagraphHitTestResult {
  if !native_paragraph_scalar_is_finite(x) ||
    !native_paragraph_scalar_is_finite(y) {
    { offset: 0, downstream: true }
  } else {
    {
      offset: native_paragraph_hit_test_utf8_offset(self.handle, x, y).max(0),
      downstream: native_paragraph_hit_test_utf8_downstream(self.handle, x, y),
    }
  }
}

///|
fn native_paragraph_scalar_is_finite(value : Float) -> Bool {
  value == value && value - value == 0.0
}

///|
fn native_paragraph_scalar_is_positive(value : Float) -> Bool {
  native_paragraph_scalar_is_finite(value) && value > 0.0
}
