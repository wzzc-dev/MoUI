///|
priv struct SkiaParagraphClusterBox {
  has_rect : Bool
  rtl : Bool
}

///|
priv struct SkiaTextMeasureCacheEntry {
  input : @core.TextLayoutInput
  result : @core.TextLayoutResult
}

///|
fn skia_text_measure_cache_capacity() -> Int {
  512
}

///|
fn skia_cached_measure_text(
  input : @core.TextLayoutInput,
  resolution : SkiaFontResolution,
  cache : Ref[Array[SkiaTextMeasureCacheEntry]],
) -> @core.TextLayoutResult {
  for entry in cache.val {
    if entry.input == input {
      return entry.result
    }
  }
  let result = skia_measure_text_for_resolution(input, resolution)
  let entries = cache.val
  if entries.length() >= skia_text_measure_cache_capacity() {
    ignore(entries.remove(0))
  }
  entries.push({ input, result })
  result
}

///|
pub fn SkiaRasterRenderer::text_system(
  self : SkiaRasterRenderer,
) -> @core.TextSystem {
  skia_text_system(resolution=self.font_resolution)
}

///|
pub fn skia_text_system(
  resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> @core.TextSystem {
  let measure_cache : Ref[Array[SkiaTextMeasureCacheEntry]] = Ref([])
  match resolution {
    SkiaFontResolution::EmptyTypeface =>
      if skia_available() {
        skia_empty_typeface_text_system(measure_cache)
      } else {
        @core.TextSystem::fallback()
      }
    SkiaFontResolution::SystemFontMgr =>
      skia_system_font_mgr_text_system(measure_cache)
  }
}

///|
fn skia_empty_typeface_text_system(
  measure_cache : Ref[Array[SkiaTextMeasureCacheEntry]],
) -> @core.TextSystem {
  @core.TextSystem::new(
    id="skia-raster-empty-typeface-text-system",
    measure=input => {
      skia_cached_measure_text(
        input,
        SkiaFontResolution::EmptyTypeface,
        measure_cache,
      )
    },
    paragraph_layout=Some(input => {
      skia_fallback_paragraph_layout_result(
        input,
        SkiaFontResolution::EmptyTypeface,
        "skia-raster-empty-typeface-text-system",
      )
    }),
  )
}

///|
fn skia_system_font_mgr_text_system(
  measure_cache : Ref[Array[SkiaTextMeasureCacheEntry]],
) -> @core.TextSystem {
  @core.TextSystem::new(
    id="skia-raster-text-system",
    measure=input => {
      skia_cached_measure_text(
        input,
        SkiaFontResolution::SystemFontMgr,
        measure_cache,
      )
    },
    paragraph_layout=Some(input => {
      match skia_native_paragraph_layout_result(input) {
        Some(layout) => layout
        None =>
          skia_fallback_paragraph_layout_result(
            input,
            SkiaFontResolution::SystemFontMgr,
            "skia-raster-text-system",
          )
      }
    }),
    register_font_data=skia_register_font_data,
  )
}

///|
fn skia_measure_text_for_resolution(
  input : @core.TextLayoutInput,
  resolution : SkiaFontResolution,
) -> @core.TextLayoutResult {
  let fallback = @core.TextSystem::fallback().measure_text(input)
  match
    skia_resolved_text_layout_for_resolution(input.font, input.text, resolution) {
    Some(layout) => skia_resolved_text_layout_result(input, fallback, layout~)
    None => fallback
  }
}

///|
fn skia_fallback_paragraph_layout_result(
  input : @core.TextLayoutInput,
  resolution : SkiaFontResolution,
  id : String,
) -> @core.TextParagraphLayoutResult {
  @core.TextSystem::new(id~, measure=measure_input => {
    skia_measure_text_for_resolution(measure_input, resolution)
  }).layout_paragraph(input)
}

///|
fn skia_native_paragraph_layout_result(
  input : @core.TextLayoutInput,
) -> @core.TextParagraphLayoutResult? {
  if input.text == "" || !@skia_native.skia_paragraph_available() {
    return None
  }
  let max_width = input.max_width.unwrap_or(1000000000.0)
  let family_name = skia_primary_paragraph_family(input.font)
  let text_bytes = @utf8.encode(input.text[:], bom=false)
  match
    @skia_native.Paragraph::layout_utf8(
      text_bytes,
      family_name~,
      size=Float::from_double(input.font.size),
      weight=input.font.weight,
      width=5,
      slant=skia_font_slant(input.font.style),
      max_width=Float::from_double(max_width),
      left_to_right=true,
    ) {
    None => None
    Some(paragraph) => {
      let offsets = skia_utf8_char_offsets(input.text)
      let lines = skia_paragraph_line_metrics(
        input.text,
        paragraph,
        skia_utf16_char_offsets(input.text),
      )
      if lines.is_empty() {
        return None
      }
      let caret_rects = skia_paragraph_caret_rects(
        input.text,
        paragraph,
        lines,
        offsets,
      )
      if caret_rects.length() != input.text.to_array().length() + 1 {
        return None
      }
      let all_text_boxes = paragraph.text_boxes_utf8(0, text_bytes.length())
      if all_text_boxes.is_empty() {
        return None
      }
      let probe = skia_paragraph_bidi_probe_ready(input.font)
      let visual_order = skia_paragraph_visual_order_metadata(
        input.text,
        paragraph,
        offsets,
        bidi_ready=probe,
      )
      let hit = paragraph.hit_test_utf8(
        0.0,
        Float::from_double(lines[0].baseline),
      )
      let hit_available = hit.offset >= 0 && hit.offset <= text_bytes.length()
      let selection_rects_available = all_text_boxes.length() > 0
      let line_metrics_available = !lines.is_empty()
      let native_ready = line_metrics_available &&
        selection_rects_available &&
        hit_available &&
        !caret_rects.is_empty()
      Some({
        text: input.text,
        size: @core.Size::new(
          width=paragraph.width().to_double().min(max_width),
          height=paragraph.height().to_double(),
        ),
        baseline: lines[0].baseline,
        lines,
        caret_rects,
        visual_order,
        metadata: {
          text_system_id: "skia-raster-text-system",
          paragraph_layout_available: true,
          line_metrics_available,
          selection_rects_available,
          hit_test_available: hit_available,
          native_paragraph_ready: native_ready,
          bidi_visual_order_ready: native_ready && probe,
        },
      })
    }
  }
}

///|
fn skia_primary_paragraph_family(font : @core.FontSpec) -> Bytes {
  let candidates = skia_preflight_family_candidates(font)
  if candidates.is_empty() {
    b""
  } else {
    @utf8.encode(candidates[0][:], bom=false)
  }
}

///|
fn skia_paragraph_line_metrics(
  text : String,
  paragraph : @skia_native.Paragraph,
  // SkParagraph line metric indices are UTF-16 code units, not the UTF-8
  // byte offsets the rect/hit APIs use; callers must pass
  // `skia_utf16_char_offsets(text)`.
  line_offsets : Array[Int],
) -> Array[@core.TextParagraphLineMetrics] {
  let chars = text.to_array()
  let lines : Array[@core.TextParagraphLineMetrics] = []
  for metric in paragraph.line_metrics() {
    match
      (
        skia_char_index_for_utf16_offset(line_offsets, metric.start),
        skia_char_index_for_utf16_offset(line_offsets, metric.end),
      ) {
      (Some(start), Some(end)) => {
        let start = start.clamp(min=0, max=chars.length())
        let end = end.clamp(min=start, max=chars.length())
        // SkParagraph can emit an empty trailing line whose utf16
        // range still overlaps the real last line (a quirk around
        // trailing hard breaks). Consumers tile ranges, so enforce
        // monotonic non-overlap: a line never starts before the
        // previous line ended.
        let start = if lines.is_empty() {
          start
        } else {
          start.max(lines[lines.length() - 1].text_range.end)
        }
        let end = end.clamp(min=start, max=chars.length())
        let ascent = metric.ascent.to_double().abs()
        let descent = metric.descent.to_double().abs()
        let metric_height = metric.height
          .to_double()
          .max(ascent + descent)
          .max(1.0)
        let top = metric.baseline.to_double() - ascent
        lines.push({
          line_index: lines.length(),
          text_range: @core.TextRange::new(start~, end~),
          origin: @core.Point::new(x=metric.left.to_double(), y=top.max(0.0)),
          size: @core.Size::new(
            width=metric.width.to_double().max(0.0),
            height=metric_height,
          ),
          baseline: metric.baseline.to_double(),
        })
      }
      _ => ()
    }
  }
  lines
}

///|
fn skia_paragraph_caret_rects(
  text : String,
  paragraph : @skia_native.Paragraph,
  lines : Array[@core.TextParagraphLineMetrics],
  offsets : Array[Int],
) -> Array[@core.Rect] {
  let chars = text.to_array()
  let carets : Array[@core.Rect] = []
  for index in 0..<(chars.length() + 1) {
    carets.push(skia_paragraph_caret_rect_at(paragraph, lines, offsets, index))
  }
  carets
}

///|
fn skia_paragraph_caret_rect_at(
  paragraph : @skia_native.Paragraph,
  lines : Array[@core.TextParagraphLineMetrics],
  offsets : Array[Int],
  index : Int,
) -> @core.Rect {
  let line = skia_paragraph_line_for_char_index(lines, index)
  let start_byte = offsets[index.clamp(min=0, max=offsets.length() - 1)]
  let end_byte = if index + 1 < offsets.length() {
    offsets[index + 1]
  } else {
    start_byte
  }
  let boxes = if end_byte > start_byte {
    paragraph.text_boxes_utf8(start_byte, end_byte)
  } else if start_byte > 0 {
    paragraph.text_boxes_utf8(offsets[(index - 1).max(0)], start_byte)
  } else {
    []
  }
  let x = if boxes.is_empty() {
    line.origin.x
  } else if end_byte > start_byte {
    boxes[0].left.to_double()
  } else {
    boxes[boxes.length() - 1].right.to_double()
  }
  @core.Rect::new(
    x~,
    y=line.origin.y,
    width=1.0,
    height=line.size.height.max(1.0),
  )
}

///|
fn skia_paragraph_line_for_char_index(
  lines : Array[@core.TextParagraphLineMetrics],
  index : Int,
) -> @core.TextParagraphLineMetrics {
  if lines.is_empty() {
    return {
      line_index: 0,
      text_range: @core.TextRange::collapsed(0),
      origin: @core.Point::new(x=0.0, y=0.0),
      size: @core.Size::new(width=0.0, height=1.0),
      baseline: 0.0,
    }
  }
  for line in lines {
    if index >= line.text_range.start && index <= line.text_range.end {
      return line
    }
  }
  lines[lines.length() - 1]
}

///|
fn skia_paragraph_visual_order_metadata(
  text : String,
  paragraph : @skia_native.Paragraph,
  offsets : Array[Int],
  bidi_ready~ : Bool,
) -> @core.TextParagraphVisualOrderMetadata {
  let logical_clusters = @render_common.text_grapheme_clusters(text)
  let boxes = skia_paragraph_cluster_boxes(logical_clusters, paragraph, offsets)
  let paragraph_bidi_observed = skia_paragraph_has_bidi_observation(boxes)
  let visual_clusters = if paragraph_bidi_observed {
    @render_common.text_bidi_visual_clusters(text)
  } else {
    logical_clusters
  }
  let visual_order_differs = !@render_common.text_string_arrays_equal(
    logical_clusters, visual_clusters,
  )
  {
    logical_text: @render_common.text_join_clusters(logical_clusters),
    visual_text: @render_common.text_join_clusters(visual_clusters),
    logical_cluster_count: logical_clusters.length(),
    visual_cluster_count: visual_clusters.length(),
    segment_count: boxes.length().max(1),
    glyph_count: logical_clusters.length(),
    visual_order_differs,
    bidi_visual_order_ready: bidi_ready &&
    paragraph_bidi_observed &&
    visual_order_differs,
  }
}

///|
fn skia_paragraph_cluster_boxes(
  clusters : Array[String],
  paragraph : @skia_native.Paragraph,
  offsets : Array[Int],
) -> Array[SkiaParagraphClusterBox] {
  let boxes : Array[SkiaParagraphClusterBox] = []
  let mut char_index = 0
  for cluster in clusters {
    let cluster_length = cluster.to_array().length()
    let end_index = (char_index + cluster_length).min(offsets.length() - 1)
    if end_index > char_index {
      let text_boxes = paragraph.text_boxes_utf8(
        offsets[char_index],
        offsets[end_index],
      )
      let has_rect = !text_boxes.is_empty()
      let native_rtl = if has_rect {
        let directions = paragraph.text_box_directions_utf8(
          offsets[char_index],
          offsets[end_index],
        )
        if directions.is_empty() {
          false
        } else {
          directions[0] == 0
        }
      } else {
        false
      }
      boxes.push({
        has_rect,
        rtl: native_rtl || @render_common.text_segment_class(cluster) == 4,
      })
    }
    char_index = end_index
  }
  boxes
}

///|
fn skia_paragraph_has_bidi_observation(
  boxes : Array[SkiaParagraphClusterBox],
) -> Bool {
  let mut rect_count = 0
  let mut rtl_count = 0
  for box in boxes {
    if box.has_rect {
      rect_count = rect_count + 1
    }
    if box.rtl {
      rtl_count = rtl_count + 1
    }
  }
  rect_count > 0 && rtl_count > 0
}

///|
fn skia_paragraph_bidi_probe_ready(font : @core.FontSpec) -> Bool {
  if !@skia_native.skia_paragraph_available() {
    return false
  }
  let text = "ABC \u{05D0}\u{05D1}\u{05D2} 123"
  let bytes = @utf8.encode(text[:], bom=false)
  match
    @skia_native.Paragraph::layout_utf8(
      bytes,
      family_name=skia_primary_paragraph_family(font),
      size=Float::from_double(font.size),
      weight=font.weight,
      width=5,
      slant=skia_font_slant(font.style),
      max_width=400.0,
      left_to_right=true,
    ) {
    Some(paragraph) => {
      let offsets = skia_utf8_char_offsets(text)
      let logical = @render_common.text_grapheme_clusters(text)
      let visual = skia_paragraph_visual_order_metadata(
        text,
        paragraph,
        offsets,
        bidi_ready=true,
      )
      visual.visual_order_differs &&
      visual.bidi_visual_order_ready &&
      visual.logical_cluster_count == logical.length() &&
      visual.visual_cluster_count == logical.length()
    }
    None => false
  }
}
