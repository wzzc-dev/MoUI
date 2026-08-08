///|
fn skia_draw_text_segment(
  canvas : @skia_native.Canvas,
  segment : SkiaTextRunSegment,
  origin : @moui_skia.Point,
  paint : @moui_skia.Paint,
) -> Bool {
  let used_glyph_run = canvas.draw_glyphs_checked(
    segment.glyph_run.glyphs,
    segment.glyph_run.positions,
    segment.font,
    paint,
    origin~,
  )
  if !used_glyph_run {
    canvas.draw_text_utf8(
      @utf8.encode(segment.text[:], bom=false),
      origin,
      segment.font,
      paint,
    )
  }
  used_glyph_run
}
