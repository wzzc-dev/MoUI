///|
fn make_box_glyph() -> SimpleGlyph {
  {
    contours: [
      {
        points: [
          { x: 0, y: 10, on_curve: true },
          { x: 10, y: 10, on_curve: true },
          { x: 10, y: 0, on_curve: true },
          { x: 0, y: 0, on_curve: true },
        ],
      },
    ],
    xmin: 0,
    ymin: 0,
    xmax: 10,
    ymax: 10,
  }
}

///|
fn make_ring_glyph() -> SimpleGlyph {
  {
    contours: [
      {
        points: [
          { x: 0, y: 10, on_curve: true },
          { x: 10, y: 10, on_curve: true },
          { x: 10, y: 0, on_curve: true },
          { x: 0, y: 0, on_curve: true },
        ],
      },
      {
        points: [
          { x: 3, y: 7, on_curve: true },
          { x: 3, y: 3, on_curve: true },
          { x: 7, y: 3, on_curve: true },
          { x: 7, y: 7, on_curve: true },
        ],
      },
    ],
    xmin: 0,
    ymin: 0,
    xmax: 10,
    ymax: 10,
  }
}

///|
fn make_consecutive_off_curve_glyph() -> SimpleGlyph {
  {
    contours: [
      {
        points: [
          { x: 0, y: 0, on_curve: true },
          { x: 4, y: 8, on_curve: false },
          { x: 8, y: 8, on_curve: false },
          { x: 10, y: 4, on_curve: false },
          { x: 10, y: 0, on_curve: true },
        ],
      },
    ],
    xmin: 0,
    ymin: 0,
    xmax: 10,
    ymax: 8,
  }
}

///|
fn make_box_font() -> Font {
  let cmap : Map[Int, Int] = Map([])
  cmap['A'.to_int()] = 1
  cmap['B'.to_int()] = 1
  cmap[' '.to_int()] = 2
  cmap[0x4E00] = 1
  cmap[0x4E8C] = 1
  cmap[0x4E09] = 1
  {
    head: { units_per_em: 10, index_to_loc_format: 0 },
    hhea: { ascent: 10, descent: 0, line_gap: 0, num_h_metrics: 3 },
    hmtx: [
      { advance_width: 0, lsb: 0 },
      { advance_width: 10, lsb: 0 },
      { advance_width: 5, lsb: 0 },
    ],
    cmap,
    glyphs: [
      GlyphData::Empty,
      GlyphData::Simple(make_box_glyph()),
      GlyphData::Empty,
    ],
    glyph_count: 3,
    kern: [],
  }
}

///|
fn make_space_only_font() -> Font {
  let cmap : Map[Int, Int] = Map([])
  cmap[' '.to_int()] = 1
  {
    head: { units_per_em: 10, index_to_loc_format: 0 },
    hhea: { ascent: 10, descent: 0, line_gap: 0, num_h_metrics: 2 },
    hmtx: [{ advance_width: 0, lsb: 0 }, { advance_width: 5, lsb: 0 }],
    cmap,
    glyphs: [GlyphData::Empty, GlyphData::Empty],
    glyph_count: 2,
    kern: [],
  }
}

///|
test "Rasterizer::rasterize_glyph preserves opposite-winding holes" {
  let rasterizer = Rasterizer::new(12, 12)
  rasterizer.rasterize_glyph(make_ring_glyph(), 1.0, 11.0, 1.0)
  let pixels = rasterizer.get_pixels()
  assert_eq(pixels[2 * 12 + 2], 255)
  assert_eq(pixels[5 * 12 + 5], 0)
  assert_eq(pixels[0], 0)
}

///|
test "flatten_contour inserts implicit points for consecutive off-curve controls" {
  let glyph = make_consecutive_off_curve_glyph()
  let segments = flatten_contour(glyph.contours[0], 0.0, 0.0, 1.0)
  assert_true(has_segment_endpoint(segments, 6.0, -8.0))
  assert_true(has_segment_endpoint(segments, 9.0, -6.0))
  assert_true(segments.length() >= 10)
}

///|
fn has_segment_endpoint(
  segments : Array[LineSegment],
  x : Double,
  y : Double,
) -> Bool {
  for segment in segments {
    if close_to(segment.x1, x) && close_to(segment.y1, y) {
      return true
    }
  }
  false
}

///|
fn close_to(a : Double, b : Double) -> Bool {
  (a - b).abs() < 0.000001
}

///|
test "Rasterizer glyph coverage snapshots are stable" {
  let box = Rasterizer::new(12, 12)
  box.rasterize_glyph(make_box_glyph(), 1.0, 11.0, 1.0)
  inspect(
    dump_pixels(box.get_pixels(), 12, 12),
    content="............\n.##########.\n.##########.\n.##########.\n.##########.\n.##########.\n.##########.\n.##########.\n.##########.\n.##########.\n.##########.\n............",
  )

  let ring = Rasterizer::new(12, 12)
  ring.rasterize_glyph(make_ring_glyph(), 1.0, 11.0, 1.0)
  inspect(
    dump_pixels(ring.get_pixels(), 12, 12),
    content="............\n.##########.\n.##########.\n.##########.\n.###....###.\n.###....###.\n.###....###.\n.###....###.\n.##########.\n.##########.\n.##########.\n............",
  )
}

///|
fn dump_pixels(pixels : FixedArray[Byte], width : Int, height : Int) -> String {
  let out = StringBuilder(size_hint=(width + 1) * height)
  for y in 0..<height {
    if y > 0 {
      out.write_char('\n')
    }
    for x in 0..<width {
      out.write_char(coverage_char(pixels[y * width + x].to_int()))
    }
  }
  out.to_string()
}

///|
fn coverage_char(value : Int) -> Char {
  if value == 0 {
    '.'
  } else if value < 96 {
    ':'
  } else if value < 192 {
    '*'
  } else {
    '#'
  }
}

///|
fn string_from_codepoints(codepoints : Array[Int]) -> String {
  let out = StringBuilder(size_hint=codepoints.length())
  for codepoint in codepoints {
    out.write_char(codepoint.unsafe_to_char())
  }
  out.to_string()
}

///|
test "render_text_mask_face rasterizes shaped glyphs" {
  let font = make_box_font()
  let face = FontFace::from_font(font)
  let config = LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let mask = render_text_mask_face(face, "A", 12, 12, 1.0, 1.0, config)
  assert_eq(mask.get_width(), 12)
  assert_eq(mask.get_height(), 12)
  assert_eq(mask.get_pixels()[1 * 12 + 1], 255)
  assert_eq(mask.get_pixels()[0], 0)
}

///|
test "render_glyph_mask rasterizes a single glyph" {
  let mask = render_glyph_mask(make_box_glyph(), 12, 12, 1.0, 11.0, 1.0)
  assert_eq(mask.get_width(), 12)
  assert_eq(mask.get_height(), 12)
  assert_eq(mask.get_pixels()[1 * 12 + 1], 255)
  assert_eq(mask.get_pixels()[0], 0)
}

///|
test "FontFace and TextLayout expose stable text API" {
  let face = FontFace::from_font(make_box_font())
  let metrics = face.get_metrics()
  assert_eq(metrics.units_per_em, 10)
  assert_eq(metrics.line_height(), 10)
  assert_eq(face.char_to_glyph('A'.to_int()), 1)
  assert_true(face.has_glyph_for_char('A'.to_int()))
  assert_true(face.has_glyph_for_char(0x4E00))
  assert_true(face.get_font().has_glyph_for_char(0x4E8C))
  assert_true(!face.has_glyph_for_char('Z'.to_int()))
  assert_true(!face.has_glyph_for_char(-1))

  let config = LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let layout = TextLayout::layout(face, "A", config)
  assert_eq(layout.run_count(), 1)
  assert_eq(layout.get_width(), 10.0)
  assert_eq(layout.get_height(), 10.0)
  assert_eq(layout.get_baseline(), 10.0)
  let runs = layout.get_runs()
  assert_eq(runs[0].glyph_count(), 1)
  assert_eq(runs[0].get_width(), 10.0)
  assert_eq(runs[0].get_baseline_y(), 10.0)
}

///|
test "TextLayout getters return isolated arrays" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    "AB",
    LayoutConfig::new(max_width=30.0, font_size=10.0, line_height=10.0),
  )
  assert_eq(layout.run_count(), 1)

  let runs = layout.get_runs()
  let empty_glyphs : Array[PositionedGlyph] = []
  runs[0] = GlyphRun::new(empty_glyphs, width=0.0, baseline_y=0.0)
  runs.push(GlyphRun::new([], width=3.0, baseline_y=4.0))

  assert_eq(layout.run_count(), 1)
  let fresh_runs = layout.get_runs()
  assert_eq(fresh_runs.length(), 1)
  assert_eq(fresh_runs[0].glyph_count(), 2)
  assert_eq(fresh_runs[0].get_width(), 20.0)
  assert_eq(fresh_runs[0].get_baseline_y(), 10.0)

  let glyphs = fresh_runs[0].get_glyphs()
  glyphs[0] = glyphs[1]
  glyphs.push(glyphs[1])

  let fresh_glyphs = layout.get_runs()[0].get_glyphs()
  assert_eq(fresh_glyphs.length(), 2)
  assert_eq(fresh_glyphs[0].get_x(), 0.0)
  assert_eq(fresh_glyphs[1].get_x(), 10.0)
}

///|
test "font fallback plan segments text by first covering face" {
  let space_face = FontFace::from_font(make_space_only_font())
  let box_face = FontFace::from_font(make_box_font())
  let faces = [space_face, box_face]
  assert_eq(select_font_face_index_for_char(faces, ' '.to_int()), 0)
  assert_eq(select_font_face_index_for_char(faces, 'A'.to_int()), 1)
  assert_eq(select_font_face_index_for_char(faces, 0x4E00), 1)
  assert_eq(select_font_face_index_for_char(faces, 'Z'.to_int()), -1)

  let plan = plan_font_fallback(
    faces,
    string_from_codepoints([' '.to_int(), 'A'.to_int(), 0x4E00, 'Z'.to_int()]),
  )
  assert_eq(plan.get_char_count(), 4)
  assert_eq(plan.get_missing_char_count(), 1)
  assert_true(plan.has_missing_glyphs())
  assert_true(!plan.is_empty())
  assert_eq(plan.span_count(), 3)
  let spans = plan.get_spans()
  assert_eq(spans[0].get_face_index(), 0)
  assert_eq(spans[0].get_text(), " ")
  assert_eq(spans[0].get_char_count(), 1)
  assert_true(!spans[0].is_missing())
  assert_eq(spans[1].get_face_index(), 1)
  assert_eq(spans[1].get_text(), string_from_codepoints(['A'.to_int(), 0x4E00]))
  assert_eq(spans[1].get_char_count(), 2)
  assert_eq(spans[2].get_face_index(), -1)
  assert_eq(spans[2].get_text(), "Z")
  assert_eq(spans[2].get_char_count(), 1)
  assert_true(spans[2].is_missing())
}

///|
test "FontFallbackPlan::get_spans returns an isolated array" {
  let space_face = FontFace::from_font(make_space_only_font())
  let box_face = FontFace::from_font(make_box_font())
  let plan = plan_font_fallback(
    [space_face, box_face],
    string_from_codepoints([' '.to_int(), 'A'.to_int(), 'Z'.to_int()]),
  )
  assert_eq(plan.span_count(), 3)

  let spans = plan.get_spans()
  spans[0] = spans[2]
  spans.push(spans[1])

  assert_eq(plan.span_count(), 3)
  assert_eq(plan.get_char_count(), 3)
  assert_eq(plan.get_missing_char_count(), 1)
  let fresh = plan.get_spans()
  assert_eq(fresh.length(), 3)
  assert_eq(fresh[0].get_face_index(), 0)
  assert_eq(fresh[0].get_text(), " ")
  assert_eq(fresh[1].get_face_index(), 1)
  assert_eq(fresh[1].get_text(), "A")
  assert_eq(fresh[2].get_face_index(), -1)
  assert_eq(fresh[2].get_text(), "Z")
}

///|
test "font fallback plan handles empty and uncovered text" {
  let empty = plan_font_fallback([], "")
  assert_true(empty.is_empty())
  assert_eq(empty.span_count(), 0)
  assert_eq(empty.get_char_count(), 0)
  assert_eq(empty.get_missing_char_count(), 0)
  assert_true(!empty.has_missing_glyphs())

  let uncovered = plan_font_fallback([], "AB")
  assert_eq(uncovered.span_count(), 1)
  assert_eq(uncovered.get_char_count(), 2)
  assert_eq(uncovered.get_missing_char_count(), 2)
  assert_true(uncovered.has_missing_glyphs())
  let spans = uncovered.get_spans()
  assert_true(spans[0].is_missing())
  assert_eq(spans[0].get_face_index(), -1)
  assert_eq(spans[0].get_text(), "AB")
  assert_eq(spans[0].get_char_count(), 2)
}

///|
test "FontFaceCache stores and replaces checked faces" {
  let cache = FontFaceCache::new()
  assert_true(cache.is_empty())
  assert_true(!cache.is_capacity_bounded())
  assert_eq(cache.capacity(), 0)
  let face = FontFace::from_font(make_box_font())
  let inserted = cache.insert("ui", face)
  assert_eq(cache.len(), 1)
  assert_eq(inserted.char_to_glyph('A'.to_int()), 1)
  match cache.get("ui") {
    Some(cached) => assert_eq(cached.char_to_glyph('A'.to_int()), 1)
    None => abort("expected cached font face")
  }

  let replacement = FontFace::from_font(make_space_only_font())
  ignore(cache.insert("ui", replacement))
  assert_eq(cache.len(), 1)
  match cache.get("ui") {
    Some(cached) => {
      assert_eq(cached.char_to_glyph('A'.to_int()), 0)
      assert_eq(cached.char_to_glyph(' '.to_int()), 1)
    }
    None => abort("expected replacement font face")
  }

  cache.remove("ui")
  assert_true(cache.is_empty())
  assert_true(cache.get("ui") is None)
}

///|
test "FontFaceCache::with_capacity evicts least recently used faces" {
  let cache = FontFaceCache::with_capacity(2)
  assert_true(cache.is_capacity_bounded())
  assert_eq(cache.capacity(), 2)
  ignore(cache.insert("first", FontFace::from_font(make_box_font())))
  ignore(cache.insert("second", FontFace::from_font(make_space_only_font())))
  match cache.get("first") {
    Some(face) => assert_eq(face.char_to_glyph('A'.to_int()), 1)
    None => abort("expected first font face")
  }
  ignore(cache.insert("third", FontFace::from_font(make_box_font())))
  assert_eq(cache.len(), 2)
  assert_true(cache.get("second") is None)
  assert_true(cache.get("first") is Some(_))
  assert_true(cache.get("third") is Some(_))
}

///|
test "FontFaceCache::contains reports membership without refreshing LRU" {
  let cache = FontFaceCache::with_capacity(2)
  ignore(cache.insert("first", FontFace::from_font(make_box_font())))
  ignore(cache.insert("second", FontFace::from_font(make_space_only_font())))
  assert_true(cache.contains("first"))
  assert_true(!cache.contains("third"))
  ignore(cache.insert("third", FontFace::from_font(make_box_font())))
  assert_eq(cache.len(), 2)
  assert_true(!cache.contains("first"))
  assert_true(cache.contains("second"))
  assert_true(cache.contains("third"))
}

///|
test "FontFaceCache clamps invalid capacity" {
  let cache = FontFaceCache::with_capacity(0)
  assert_true(cache.is_capacity_bounded())
  assert_eq(cache.capacity(), 1)
  ignore(cache.insert("first", FontFace::from_font(make_box_font())))
  ignore(cache.insert("second", FontFace::from_font(make_space_only_font())))
  assert_eq(cache.len(), 1)
  assert_true(cache.get("first") is None)
  match cache.get("second") {
    Some(face) => assert_eq(face.char_to_glyph(' '.to_int()), 1)
    None => abort("expected second font face")
  }
}

///|
test "FontFaceCache::get_or_parse reuses cached face and preserves errors" {
  let cache = FontFaceCache::new()
  let face = FontFace::from_font(make_box_font())
  ignore(cache.insert("known", face))
  match cache.get_or_parse("known", b"not a font") {
    Ok(cached) => assert_eq(cached.char_to_glyph('A'.to_int()), 1)
    Err(_) => abort("expected cache hit to avoid parsing invalid bytes")
  }
  assert_eq(cache.len(), 1)

  match cache.get_or_parse("bad", b"not a font") {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 10)) => ()
    _ => abort("expected checked parser error")
  }
  assert_eq(cache.len(), 1)

  cache.clear()
  assert_true(cache.is_empty())
}

///|
test "TextMaskCache::get_or_render_face reuses rendered masks" {
  let cache = TextMaskCache::new()
  let config = LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let face = FontFace::from_font(make_box_font())
  let first = cache.get_or_render_face(
    "label", face, "A", 12, 12, 1.0, 1.0, config,
  )
  assert_eq(first.get_width(), 12)
  assert_eq(first.get_height(), 12)
  assert_eq(first.get_pixels()[1 * 12 + 1], 255)
  assert_eq(cache.len(), 1)

  let first_pixels = first.get_pixels()
  first_pixels[1 * 12 + 1] = 0
  match cache.get("label") {
    Some(cached) => assert_eq(cached.get_pixels()[1 * 12 + 1], 255)
    None => abort("expected cached text mask")
  }

  let space_face = FontFace::from_font(make_space_only_font())
  let second = cache.get_or_render_face(
    "label", space_face, " ", 12, 12, 1.0, 1.0, config,
  )
  assert_eq(second.get_pixels()[1 * 12 + 1], 255)
  assert_eq(cache.len(), 1)

  cache.remove("label")
  let rerendered = cache.get_or_render_face(
    "label", space_face, " ", 12, 12, 1.0, 1.0, config,
  )
  assert_eq(rerendered.get_pixels()[1 * 12 + 1], 0)
  assert_eq(cache.len(), 1)
}

///|
test "TextMaskCache::get_or_render_face_result reports cache misses" {
  let cache = TextMaskCache::new()
  let config = LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let face = FontFace::from_font(make_box_font())
  let first = cache.get_or_render_face_result(
    "label", face, "A", 12, 12, 1.0, 1.0, config,
  )
  assert_true(first.did_render())
  assert_eq(first.get_mask().get_pixels()[1 * 12 + 1], 255)
  assert_eq(cache.len(), 1)

  let space_face = FontFace::from_font(make_space_only_font())
  let second = cache.get_or_render_face_result(
    "label", space_face, " ", 12, 12, 1.0, 1.0, config,
  )
  assert_true(!second.did_render())
  assert_eq(second.get_mask().get_pixels()[1 * 12 + 1], 255)
  assert_eq(cache.len(), 1)
}

///|
test "GlyphMaskCache::get_or_rasterize_glyph_result reuses rendered masks" {
  let cache = GlyphMaskCache::new()
  let first_result = cache.get_or_rasterize_glyph_result(
    "glyph:box",
    make_box_glyph(),
    12,
    12,
    1.0,
    11.0,
    1.0,
  )
  assert_true(first_result.did_rasterize())
  let first = first_result.get_mask()
  assert_eq(first.get_width(), 12)
  assert_eq(first.get_height(), 12)
  assert_eq(first.get_pixels()[1 * 12 + 1], 255)
  assert_eq(cache.len(), 1)

  let first_pixels = first.get_pixels()
  first_pixels[1 * 12 + 1] = 0
  match cache.get("glyph:box") {
    Some(cached) => assert_eq(cached.get_pixels()[1 * 12 + 1], 255)
    None => abort("expected cached glyph mask")
  }

  let second_result = cache.get_or_rasterize_glyph_result(
    "glyph:box",
    make_ring_glyph(),
    12,
    12,
    1.0,
    11.0,
    1.0,
  )
  assert_true(!second_result.did_rasterize())
  let second = second_result.get_mask()
  assert_eq(second.get_pixels()[5 * 12 + 5], 255)
  assert_eq(cache.len(), 1)

  cache.remove("glyph:box")
  let rerendered_result = cache.get_or_rasterize_glyph_result(
    "glyph:box",
    make_ring_glyph(),
    12,
    12,
    1.0,
    11.0,
    1.0,
  )
  assert_true(rerendered_result.did_rasterize())
  let rerendered = rerendered_result.get_mask()
  assert_eq(rerendered.get_pixels()[5 * 12 + 5], 0)
  assert_eq(cache.len(), 1)
}

///|
test "GlyphMaskCache::get_or_rasterize_glyph_result reports cache misses" {
  let cache = GlyphMaskCache::new()
  let first = cache.get_or_rasterize_glyph_result(
    "glyph:box",
    make_box_glyph(),
    12,
    12,
    1.0,
    11.0,
    1.0,
  )
  assert_true(first.did_rasterize())
  assert_eq(first.get_mask().get_pixels()[1 * 12 + 1], 255)
  assert_eq(cache.len(), 1)

  let second = cache.get_or_rasterize_glyph_result(
    "glyph:box",
    make_ring_glyph(),
    12,
    12,
    1.0,
    11.0,
    1.0,
  )
  assert_true(!second.did_rasterize())
  assert_eq(second.get_mask().get_pixels()[5 * 12 + 5], 255)
  assert_eq(cache.len(), 1)
}

///|
test "TextLayout aligns center and right lines" {
  let face = FontFace::from_font(make_box_font())
  let center = TextLayout::layout(
    face,
    "A",
    LayoutConfig::new(
      max_width=30.0,
      font_size=10.0,
      line_height=10.0,
      alignment=TextAlign::Center,
    ),
  )
  let center_glyphs = center.get_runs()[0].get_glyphs()
  assert_eq(center_glyphs[0].get_x(), 10.0)

  let right = TextLayout::layout(
    face,
    "A",
    LayoutConfig::new(
      max_width=30.0,
      font_size=10.0,
      line_height=10.0,
      alignment=TextAlign::Right,
    ),
  )
  let right_glyphs = right.get_runs()[0].get_glyphs()
  assert_eq(right_glyphs[0].get_x(), 20.0)
}

///|
test "TextLayout justifies non-final lines" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    "A B A",
    LayoutConfig::new(
      max_width=34.0,
      font_size=10.0,
      line_height=10.0,
      alignment=TextAlign::Justify,
    ),
  )
  assert_eq(layout.run_count(), 2)
  let first_run = layout.get_runs()[0]
  assert_eq(first_run.get_width(), 34.0)
  let first_glyphs = first_run.get_glyphs()
  assert_eq(first_glyphs.length(), 4)
  assert_eq(first_glyphs[0].get_x(), 0.0)
  assert_eq(first_glyphs[1].get_advance_width(), 9.0)
  assert_eq(first_glyphs[2].get_x(), 19.0)
  assert_eq(first_glyphs[3].get_x(), 29.0)
  assert_eq(first_glyphs[3].get_advance_width(), 5.0)

  let last_run = layout.get_runs()[1]
  assert_eq(last_run.get_width(), 10.0)
  assert_eq(last_run.get_glyphs()[0].get_x(), 0.0)
}

///|
test "TextLayout preserves explicit newlines" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    "A\nA",
    LayoutConfig::new(max_width=30.0, font_size=10.0, line_height=10.0),
  )
  assert_eq(layout.run_count(), 2)
  assert_eq(layout.get_width(), 10.0)
  assert_eq(layout.get_height(), 20.0)
  let runs = layout.get_runs()
  assert_eq(runs[0].glyph_count(), 1)
  assert_eq(runs[0].get_baseline_y(), 10.0)
  assert_eq(runs[1].glyph_count(), 1)
  assert_eq(runs[1].get_baseline_y(), 20.0)
}

///|
test "TextLayout preserves empty lines" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    "A\n\nA",
    LayoutConfig::new(max_width=30.0, font_size=10.0, line_height=10.0),
  )
  assert_eq(layout.run_count(), 3)
  assert_eq(layout.get_width(), 10.0)
  assert_eq(layout.get_height(), 30.0)
  let runs = layout.get_runs()
  assert_eq(runs[0].glyph_count(), 1)
  assert_eq(runs[0].get_baseline_y(), 10.0)
  assert_eq(runs[1].glyph_count(), 0)
  assert_eq(runs[1].get_width(), 0.0)
  assert_eq(runs[1].get_baseline_y(), 20.0)
  assert_eq(runs[2].glyph_count(), 1)
  assert_eq(runs[2].get_baseline_y(), 30.0)
}

///|
test "TextLayout does not justify explicit line breaks" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    "A B\nA",
    LayoutConfig::new(
      max_width=30.0,
      font_size=10.0,
      line_height=10.0,
      alignment=TextAlign::Justify,
    ),
  )
  assert_eq(layout.run_count(), 2)
  let first_run = layout.get_runs()[0]
  assert_eq(first_run.get_width(), 25.0)
  let glyphs = first_run.get_glyphs()
  assert_eq(glyphs[1].get_advance_width(), 5.0)
  assert_eq(glyphs[2].get_x(), 15.0)
}

///|
test "TextLayout applies letter spacing" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    "AB",
    LayoutConfig::new(
      max_width=40.0,
      font_size=10.0,
      line_height=10.0,
      letter_spacing=3.0,
    ),
  )
  assert_eq(layout.run_count(), 1)
  assert_eq(layout.get_width(), 23.0)
  let glyphs = layout.get_runs()[0].get_glyphs()
  assert_eq(glyphs.length(), 2)
  assert_eq(glyphs[0].get_x(), 0.0)
  assert_eq(glyphs[0].get_advance_width(), 13.0)
  assert_eq(glyphs[1].get_x(), 13.0)
  assert_eq(glyphs[1].get_advance_width(), 10.0)
}

///|
test "TextLayout applies word spacing" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    "A A",
    LayoutConfig::new(
      max_width=40.0,
      font_size=10.0,
      line_height=10.0,
      word_spacing=4.0,
    ),
  )
  assert_eq(layout.run_count(), 1)
  assert_eq(layout.get_width(), 29.0)
  let glyphs = layout.get_runs()[0].get_glyphs()
  assert_eq(glyphs.length(), 3)
  assert_eq(glyphs[0].get_x(), 0.0)
  assert_eq(glyphs[1].get_x(), 10.0)
  assert_eq(glyphs[1].get_advance_width(), 9.0)
  assert_eq(glyphs[2].get_x(), 19.0)
}

///|
test "TextLayout uses word spacing for wrapping" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    "A A",
    LayoutConfig::new(
      max_width=27.0,
      font_size=10.0,
      line_height=10.0,
      word_spacing=4.0,
    ),
  )
  assert_eq(layout.run_count(), 2)
  let runs = layout.get_runs()
  assert_eq(runs[0].get_width(), 19.0)
  assert_eq(runs[1].get_width(), 10.0)
  assert_eq(runs[1].get_baseline_y(), 20.0)
}

///|
test "TextLayout keeps trailing spaces before wrapped words" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    "A A",
    LayoutConfig::new(max_width=12.0, font_size=10.0, line_height=10.0),
  )
  assert_eq(layout.run_count(), 2)
  let runs = layout.get_runs()
  assert_eq(runs[0].get_width(), 15.0)
  assert_eq(runs[0].glyph_count(), 2)
  assert_eq(runs[1].get_width(), 10.0)
  assert_eq(runs[1].glyph_count(), 1)
  assert_eq(runs[1].get_baseline_y(), 20.0)
}

///|
test "TextLayout keeps explicit trailing spaces" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    "A ",
    LayoutConfig::new(max_width=12.0, font_size=10.0, line_height=10.0),
  )
  assert_eq(layout.run_count(), 1)
  assert_eq(layout.get_width(), 15.0)
  let glyphs = layout.get_runs()[0].get_glyphs()
  assert_eq(glyphs.length(), 2)
  assert_eq(glyphs[1].get_x(), 10.0)
  assert_eq(glyphs[1].get_advance_width(), 5.0)
}

///|
test "TextLayout wraps unspaced CJK at Unicode line break opportunities" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    string_from_codepoints([0x4E00, 0x4E8C, 0x4E09]),
    LayoutConfig::new(max_width=20.0, font_size=10.0, line_height=10.0),
  )
  assert_eq(layout.run_count(), 2)
  assert_eq(layout.get_width(), 20.0)
  assert_eq(layout.get_height(), 20.0)
  let runs = layout.get_runs()
  assert_eq(runs[0].glyph_count(), 2)
  assert_eq(runs[0].get_width(), 20.0)
  assert_eq(runs[1].glyph_count(), 1)
  assert_eq(runs[1].get_width(), 10.0)
  assert_eq(runs[1].get_baseline_y(), 20.0)
}

///|
test "TextLayout does not justify final trailing spaces" {
  let face = FontFace::from_font(make_box_font())
  let layout = TextLayout::layout(
    face,
    "A ",
    LayoutConfig::new(
      max_width=30.0,
      font_size=10.0,
      line_height=10.0,
      alignment=TextAlign::Justify,
    ),
  )
  assert_eq(layout.run_count(), 1)
  let run = layout.get_runs()[0]
  assert_eq(run.get_width(), 15.0)
  let glyphs = run.get_glyphs()
  assert_eq(glyphs[1].get_advance_width(), 5.0)
}

///|
test "render_text_mask_face applies alignment" {
  let face = FontFace::from_font(make_box_font())
  let config = LayoutConfig::new(
    max_width=30.0,
    font_size=10.0,
    line_height=10.0,
    alignment=TextAlign::Right,
  )
  let mask = render_text_mask_face(face, "A", 36, 12, 1.0, 1.0, config)
  assert_eq(mask.get_pixels()[1 * 36 + 20], 0)
  assert_eq(mask.get_pixels()[1 * 36 + 21], 255)
}

///|
test "render_text_mask_face applies explicit newlines" {
  let face = FontFace::from_font(make_box_font())
  let config = LayoutConfig::new(
    max_width=30.0,
    font_size=10.0,
    line_height=10.0,
  )
  let mask = render_text_mask_face(face, "A\nA", 12, 24, 1.0, 1.0, config)
  assert_eq(mask.get_pixels()[1 * 12 + 1], 255)
  assert_eq(mask.get_pixels()[11 * 12 + 1], 255)
  assert_eq(mask.get_pixels()[0], 0)
}

///|
test "render_text_mask_face applies letter spacing" {
  let face = FontFace::from_font(make_box_font())
  let config = LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
    letter_spacing=3.0,
  )
  let mask = render_text_mask_face(face, "AA", 26, 12, 1.0, 1.0, config)
  assert_eq(mask.get_pixels()[1 * 26 + 1], 255)
  assert_eq(mask.get_pixels()[1 * 26 + 11], 0)
  assert_eq(mask.get_pixels()[1 * 26 + 14], 255)
}

///|
test "render_text_mask_face wraps after trailing space" {
  let face = FontFace::from_font(make_box_font())
  let config = LayoutConfig::new(
    max_width=12.0,
    font_size=10.0,
    line_height=10.0,
  )
  let mask = render_text_mask_face(face, "A A", 14, 24, 1.0, 1.0, config)
  assert_eq(mask.get_pixels()[1 * 14 + 1], 255)
  assert_eq(mask.get_pixels()[1 * 14 + 11], 0)
  assert_eq(mask.get_pixels()[11 * 14 + 1], 255)
}

///|
test "FontData::parse reports checked parser errors" {
  let data = FontData::new(b"")
  match data.parse() {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 0)) => ()
    _ => abort("expected checked font-data parse error")
  }
}

///|
test "render_text_mask_face rasterizes through FontFace" {
  let face = FontFace::from_font(make_box_font())
  let config = LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let mask = render_text_mask_face(face, "A", 12, 12, 1.0, 1.0, config)
  assert_eq(mask.get_width(), 12)
  assert_eq(mask.get_height(), 12)
  assert_eq(mask.get_pixels()[1 * 12 + 1], 255)
  assert_eq(mask.get_pixels()[0], 0)
}
