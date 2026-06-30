///|
fn SkiaRasterRenderer::draw_text(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  run : @core.TextRun,
) -> Unit {
  if !skia_text_frame_can_draw(run.frame) {
    return ()
  }
  match
    skia_resolved_text_layout_for_resolution(
      run.font,
      run.text,
      self.font_resolution,
    ) {
    Some(layout) => {
      let placement = if layout.segments.length() == 1 {
        skia_text_placement(run, layout.segments[0].glyph_run, layout.metrics)
      } else {
        skia_text_placement_for_width(run, layout.width, layout.metrics)
      }
      let saved = canvas.save()
      canvas.clip_rect(skia_rect(placement.clip), anti_alias=true)
      for segment in layout.segments {
        canvas.draw_text_utf8(
          @utf8.encode(segment.text[:], bom=false),
          @moui_skia.Point::new(
            Float::from_double(
              placement.origin.x.to_double() + segment.x_offset,
            ),
            placement.origin.y,
          ),
          segment.font,
          skia_paint(run.color),
        )
      }
      canvas.restore_to_count(saved)
    }
    None =>
      self.record_unsupported_command(
        "DrawText", "Skia text layout unavailable; skipped text run",
      )
  }
}
