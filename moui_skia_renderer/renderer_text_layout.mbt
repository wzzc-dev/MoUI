///|
priv struct SkiaTextMetrics {
  baseline : Double
  height : Double
}

///|
priv struct SkiaTextPlacement {
  origin : @moui_skia.Point
  clip : @core.Rect
}

///|
priv struct SkiaTextRunSegment {
  text : String
  font : @skia_native.Font
  glyph_run : SkiaGlyphRun
  x_offset : Double
}

///|
priv struct SkiaResolvedTextLayout {
  segments : Array[SkiaTextRunSegment]
  width : Double
  metrics : SkiaTextMetrics
}

///|
fn skia_text_frame_can_draw(frame : @core.Rect) -> Bool {
  frame.size.width > 0.0 && frame.size.height > 0.0
}

///|
fn skia_text_placement(
  run : @core.TextRun,
  glyph_run : SkiaGlyphRun,
  metrics : SkiaTextMetrics,
) -> SkiaTextPlacement {
  skia_text_placement_for_width(run, glyph_run.width, metrics)
}

///|
fn skia_text_placement_for_layout(
  run : @core.TextRun,
  layout : SkiaResolvedTextLayout,
) -> SkiaTextPlacement {
  if layout.segments.length() == 1 {
    skia_text_placement(run, layout.segments[0].glyph_run, layout.metrics)
  } else {
    skia_text_placement_for_width(run, layout.width, layout.metrics)
  }
}

///|
fn skia_text_placement_for_width(
  run : @core.TextRun,
  text_width : Double,
  metrics : SkiaTextMetrics,
) -> SkiaTextPlacement {
  let x = match run.align {
    @core.TextAlign::TextStart => run.frame.origin.x
    @core.TextAlign::TextCenter =>
      run.frame.origin.x + (run.frame.size.width - text_width) / 2.0
    @core.TextAlign::TextEnd =>
      run.frame.origin.x + run.frame.size.width - text_width
  }
  let y = skia_text_baseline_y(run.frame, metrics)
  {
    origin: @moui_skia.Point::new(Float::from_double(x), Float::from_double(y)),
    clip: run.frame,
  }
}

///|
fn skia_text_segment_origin(
  placement : SkiaTextPlacement,
  x_offset : Double,
) -> @moui_skia.Point {
  @moui_skia.Point::new(
    Float::from_double(placement.origin.x.to_double() + x_offset),
    placement.origin.y,
  )
}

///|
fn skia_text_baseline_y(
  frame : @core.Rect,
  metrics : SkiaTextMetrics,
) -> Double {
  let offset_y = if frame.size.height > metrics.height {
    (frame.size.height - metrics.height) / 2.0
  } else {
    0.0
  }
  frame.origin.y + offset_y + metrics.baseline
}

///|
fn skia_draw_text_payload_for_resolution(
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  match skia_font_with_resolution_for_text(font_spec, text, resolution) {
    Some(font) => {
      let glyph_run = skia_glyph_run_for_resolution(font, text, resolution)
      if
        skia_glyph_run_can_draw_text(glyph_run) &&
        skia_font_covers_text(font, text) {
        Some((font, glyph_run))
      } else {
        skia_fallback_draw_payload(font_spec, text, resolution, glyph_run)
      }
    }
    None => None
  }
}

///|
fn skia_resolved_text_layout_for_resolution(
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> SkiaResolvedTextLayout? {
  if text == "" {
    match skia_draw_text_payload_for_resolution(font_spec, text, resolution) {
      Some((font, glyph_run)) =>
        Some({
          segments: [{ text, font, glyph_run, x_offset: 0.0 }],
          width: glyph_run.width,
          metrics: skia_text_metrics(
            font,
            fallback_baseline=font_spec.size,
            fallback_height=font_spec.size * 1.25,
          ),
        })
      None => None
    }
  } else {
    skia_resolved_text_segments(font_spec, text, resolution)
  }
}

///|
fn skia_resolved_text_segments(
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> SkiaResolvedTextLayout? {
  let text_segments = @render_common.text_mixed_segments(text)
  if text_segments.is_empty() {
    return None
  }
  let segments : Array[SkiaTextRunSegment] = []
  let mut x_offset = 0.0
  let mut baseline = 0.0
  let mut height = 0.0
  for segment_text in text_segments {
    match
      skia_draw_text_payload_for_resolution(font_spec, segment_text, resolution) {
      Some((font, glyph_run)) => {
        let metrics = skia_text_metrics(
          font,
          fallback_baseline=font_spec.size,
          fallback_height=font_spec.size * 1.25,
        )
        baseline = baseline.max(metrics.baseline)
        height = height.max(metrics.height)
        segments.push({ text: segment_text, font, glyph_run, x_offset })
        x_offset = x_offset + glyph_run.width
      }
      None => return None
    }
  }
  if segments.is_empty() {
    None
  } else {
    Some({
      segments,
      width: x_offset,
      metrics: { baseline, height: height.max(baseline) },
    })
  }
}
