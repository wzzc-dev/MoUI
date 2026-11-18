///|
fn SkiaRasterRenderer::draw_text(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  run : @core.TextRun,
) -> Unit {
  if !skia_text_frame_can_draw(run.frame) {
    return ()
  }
  if run.text == "" {
    return ()
  }
  match
    self.text_shaping_cache.resolve(run.font, run.text, self.font_resolution, () => {
      skia_resolved_text_layout_for_resolution(
        run.font,
        run.text,
        self.font_resolution,
      )
    }) {
    Some(layout) => {
      let placement = skia_text_placement_for_layout(run, layout)
      let saved = canvas.save()
      canvas.clip_rect(skia_rect(placement.clip), anti_alias=true)
      // Stroke pass goes under the fill so the outline reads around the
      // glyphs instead of eating into them.
      match run.stroke_color {
        Some(stroke) =>
          if run.stroke_width > 0.0 {
            let stroke_paint = self.skia_stroke_paint_styled(
              stroke,
              run.stroke_width,
              Some(@core.StrokeCap::Round),
              Some(@core.StrokeJoin::Round),
            )
            for segment in layout.segments {
              let origin = skia_text_segment_origin(placement, segment.x_offset)
              ignore(
                skia_draw_text_segment(canvas, segment, origin, stroke_paint),
              )
            }
          }
        None => ()
      }
      let fill_paint = self.skia_paint(run.color)
      for segment in layout.segments {
        let origin = skia_text_segment_origin(placement, segment.x_offset)
        ignore(skia_draw_text_segment(canvas, segment, origin, fill_paint))
      }
      canvas.restore_to_count(saved)
    }
    None =>
      self.record_unsupported_command(
        "DrawText", "Skia text layout unavailable; skipped text run",
      )
  }
}
