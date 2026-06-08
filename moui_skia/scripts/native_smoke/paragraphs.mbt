///|
fn run_paragraph_smoke() -> Unit {
  if !@native.skia_paragraph_available() {
    println("native smoke paragraph availability")
    println(0)
    return
  }
  println("native smoke paragraph availability")
  println(1)
  smoke_mark(b"skparagraph available")
  guard
    @native.Paragraph::layout_utf8(
      b"alpha beta gamma delta",
      family_name=b"",
      size=16.0,
      max_width=76.0,
    )
    is Some(paragraph)
  else {
    fail_smoke("SkParagraph was available but paragraph layout failed")
  }
  let metrics = paragraph.line_metrics()
  if metrics.length() < 2 {
    fail_smoke("SkParagraph smoke did not wrap to multiple lines")
  }
  let boxes = paragraph.text_boxes_utf8(0, b"alpha beta".length())
  if boxes.length() == 0 || boxes[0].width() <= 0.0 {
    fail_smoke("SkParagraph smoke did not return selection boxes")
  }
  let hit = paragraph.hit_test_utf8(8.0, metrics[0].baseline)
  if hit.offset < 0 {
    fail_smoke("SkParagraph smoke did not return a valid hit-test offset")
  }
  println("native smoke paragraph available")
  println(1)
  println("native smoke paragraph line metrics")
  println(metrics.length())
  println("native smoke paragraph selection boxes")
  println(boxes.length())
  println("native smoke paragraph hit test")
  println(hit.offset)
}
