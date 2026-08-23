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
    skia_resolved_text_layout_for_resolution(
      run.font,
      run.text,
      self.font_resolution,
    ) {
    Some(layout) => {
      let placement = skia_text_placement_for_layout(run, layout)
      let saved = canvas.save()
      canvas.clip_rect(skia_rect(placement.clip), anti_alias=true)
      for segment in layout.segments {
        let origin = skia_text_segment_origin(placement, segment.x_offset)
        ignore(
          skia_draw_text_segment(canvas, segment, origin, skia_paint(run.color)),
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
