///|
fn run_text_font_smoke(canvas : @native.Canvas, font : @native.Font) -> Unit {
  smoke_mark(b"font default")
  font.set_size(11.0)
  if font.size() != 11.0 {
    fail_smoke("native font size did not update")
  }
  let invalid_font_scalar : Float = 0.0 / 0.0
  let infinite_font_scalar : Float = 1.0 / 0.0
  if @native.Font::default(size=invalid_font_scalar) is Some(_) ||
    @native.Font::empty(size=infinite_font_scalar) is Some(_) {
    fail_smoke("native font constructors accepted non-finite sizes")
  }
  font.set_size(invalid_font_scalar)
  if font.size() != 11.0 {
    fail_smoke("native font accepted a non-finite size mutation")
  }
  font.set_size(infinite_font_scalar)
  if font.size() != 11.0 {
    fail_smoke("native font accepted an infinite size mutation")
  }
  if font.shape_text_utf8(smoke_text_bytes(), width=infinite_font_scalar)
    is Some(_) ||
    font.shape_text_utf8(smoke_text_bytes(), width=invalid_font_scalar)
    is Some(_) {
    fail_smoke("native font shaped text with a non-finite width")
  }
  let font_metrics = font.metrics()
  if font_metrics.ascent > 0.0 || font_metrics.descent < 0.0 {
    fail_smoke("native font metrics have unexpected ascent/descent signs")
  }
  let font_spacing = font.spacing()
  if font_spacing <= 0.0 {
    fail_smoke("native font spacing is not positive")
  }
  println("native smoke font spacing")
  println(font_spacing)
  let measured_text_width = font.measure_text_utf8(smoke_text_bytes())
  if measured_text_width <= 0.0 {
    fail_smoke("native font did not report a positive text width")
  }
  println("native smoke measured text width")
  println(measured_text_width)
  let measured_text_glyphs = font.count_text_utf8(smoke_text_bytes())
  if measured_text_glyphs != 4 {
    fail_smoke("native font did not report the expected text glyph count")
  }
  println("native smoke text glyph count")
  println(measured_text_glyphs)
  let glyphs = font.text_to_glyphs_utf8(smoke_text_bytes())
  if glyphs.length() != measured_text_glyphs || glyphs[0].to_int() <= 0 {
    fail_smoke("native font did not map text to expected glyph ids")
  }
  println("native smoke first glyph id")
  println(glyphs[0].to_int())
  let glyph_widths = font.glyph_widths(glyphs)
  if glyph_widths.length() != glyphs.length() || glyph_widths[0] <= 0.0 {
    fail_smoke("native font did not report expected glyph widths")
  }
  println("native smoke first glyph width")
  println(glyph_widths[0])
  let glyph_positions = font.text_glyph_positions_utf8(
    smoke_text_bytes(),
    origin=@skia.Point::new(2.0, 3.0),
  )
  if glyph_positions.length() != glyphs.length() ||
    glyph_positions[0] != @skia.Point::new(2.0, 3.0) ||
    glyph_positions[1].x <= glyph_positions[0].x {
    fail_smoke("native font did not report expected glyph positions")
  }
  println("native smoke second glyph position x")
  println(glyph_positions[1].x)
  let glyph_x_positions = font.text_glyph_x_positions_utf8(
    smoke_text_bytes(),
    origin=2.0,
  )
  if glyph_x_positions.length() != glyphs.length() ||
    glyph_x_positions[0] != 2.0 ||
    glyph_x_positions[1] <= glyph_x_positions[0] {
    fail_smoke("native font did not report expected glyph x positions")
  }
  println("native smoke second glyph x position")
  println(glyph_x_positions[1])
  let invalid_glyph_positions = font.text_glyph_positions_utf8(
    smoke_text_bytes(),
    origin=@skia.Point::new(invalid_font_scalar, infinite_font_scalar),
  )
  let invalid_glyph_x_positions = font.text_glyph_x_positions_utf8(
    smoke_text_bytes(),
    origin=invalid_font_scalar,
  )
  if invalid_glyph_positions.length() != glyphs.length() ||
    invalid_glyph_x_positions.length() != glyphs.length() ||
    invalid_glyph_positions[0] != @skia.Point::zero() ||
    invalid_glyph_x_positions[0] != 0.0 ||
    invalid_glyph_positions[1].x <= invalid_glyph_positions[0].x ||
    invalid_glyph_x_positions[1] <= invalid_glyph_x_positions[0] {
    fail_smoke("native font did not sanitize non-finite scalar inputs")
  }
  println("native smoke non-finite font scalars sanitized")
  println(1)
  let glyph_bounds = font.glyph_bounds_many(glyphs)
  if glyph_bounds.length() != glyphs.length() ||
    glyph_bounds[0].width() <= 0.0 ||
    glyph_bounds[0].height() <= 0.0 {
    fail_smoke("native font did not report expected glyph bounds")
  }
  println("native smoke first glyph bounds width")
  println(glyph_bounds[0].width())
  guard font.measure_text_bounds_utf8(smoke_text_bytes()) is Some(text_bounds) else {
    fail_smoke("native font did not report text bounds")
  }
  if text_bounds.width() <= 0.0 || text_bounds.height() < 0.0 {
    fail_smoke("native font text bounds are invalid")
  }
  println("native smoke measured text bounds width")
  println(text_bounds.width())
  let shaper_available = @native.skia_shaper_available()
  println("native smoke shaper availability")
  if shaper_available {
    println(1)
  } else {
    println(0)
  }
  if shaper_available {
    smoke_mark(b"skshaper available")
    guard font.shape_text_utf8(smoke_text_bytes()) is Some(shaped_run) else {
      fail_smoke("native SkShaper was available but did not shape text")
    }
    let shaped_glyph_count = shaped_run.glyph_count()
    let shaped_glyphs = shaped_run.glyphs()
    let shaped_positions = shaped_run.positions()
    let shaped_clusters = shaped_run.clusters()
    if shaped_glyph_count <= 0 ||
      shaped_glyphs.length() != shaped_glyph_count ||
      shaped_positions.length() != shaped_glyph_count ||
      shaped_clusters.length() != shaped_glyph_count ||
      shaped_glyphs[0].to_int() <= 0 ||
      shaped_run.advance().x <= 0.0 {
      fail_smoke("native SkShaper did not produce a valid shaped glyph run")
    }
    let shaped_smoke_shaping = @skia.TextShapingDescriptor::new(
      run=@skia.TextRunDescriptor::new(
        range=@skia.TextRange::new(0, smoke_text_bytes().length()),
      ),
      font_key=@skia.RendererResourceKey::font(b"native-default:11"),
    )
    let shaped_smoke_descriptor = shaped_smoke_shaping.shaped_run_descriptor(
      glyph_count=shaped_glyph_count,
      cluster_count=shaped_clusters.length(),
      advance=shaped_run.advance(),
    )
    let shaped_smoke_plan = shaped_smoke_descriptor.resource_plan(
      smoke_text_bytes(),
    )
    let shaped_smoke_glyph_ids : Array[Int] = Array::new(
      capacity=shaped_glyphs.length(),
    )
    for glyph in shaped_glyphs {
      shaped_smoke_glyph_ids.push(glyph.to_int())
    }
    let shaped_smoke_glyph_run = shaped_smoke_descriptor.glyph_run_descriptor(
      glyph_ids=shaped_smoke_glyph_ids,
      positions=shaped_positions,
      clusters=shaped_clusters,
    )
    let shaped_smoke_glyph_run_plan = shaped_smoke_glyph_run.resource_plan(
      smoke_text_bytes(),
    )
    if !shaped_smoke_descriptor.is_valid() ||
      shaped_smoke_plan.length() != 4 ||
      shaped_smoke_plan.count_kind(@skia.TextRunResource) != 3 ||
      shaped_smoke_plan.count_kind(@skia.FontResource) != 1 ||
      shaped_smoke_plan.count_kind(@skia.TypefaceResource) != 0 ||
      !shaped_smoke_plan.contains_key(
        shaped_smoke_descriptor.resource_key(smoke_text_bytes()),
      ) ||
      !shaped_smoke_plan.contains_key(
        shaped_smoke_shaping.resource_key(smoke_text_bytes()),
      ) {
      fail_smoke(
        "native shaped text run descriptor did not record SkShaper metadata",
      )
    }
    if !shaped_smoke_glyph_run.is_valid() ||
      shaped_smoke_glyph_run.glyph_count() != shaped_glyph_count ||
      shaped_smoke_glyph_run_plan.length() != 5 ||
      shaped_smoke_glyph_run_plan.count_kind(@skia.TextRunResource) != 4 ||
      shaped_smoke_glyph_run_plan.count_kind(@skia.FontResource) != 1 ||
      !shaped_smoke_glyph_run_plan.contains_key(
        shaped_smoke_glyph_run.resource_key(smoke_text_bytes()),
      ) ||
      !shaped_smoke_glyph_run_plan.contains_key(
        shaped_smoke_descriptor.resource_key(smoke_text_bytes()),
      ) {
      fail_smoke(
        "native shaped glyph run descriptor did not record SkShaper metadata",
      )
    }
    guard font.shape_text_run_utf8(smoke_text_bytes(), shaped_smoke_shaping)
      is Some(shaped_smoke_bridge) else {
      fail_smoke("native shaped glyph descriptor bridge did not shape text")
    }
    let shaped_smoke_bridge_plan = shaped_smoke_bridge.resource_plan(
      smoke_text_bytes(),
    )
    if !shaped_smoke_bridge.is_valid() ||
      shaped_smoke_bridge.glyph_count() != shaped_glyph_count ||
      shaped_smoke_bridge.cluster_count() != shaped_clusters.length() ||
      shaped_smoke_bridge.resource_key(smoke_text_bytes()) !=
      shaped_smoke_glyph_run.resource_key(smoke_text_bytes()) ||
      shaped_smoke_bridge_plan.length() != shaped_smoke_glyph_run_plan.length() ||
      shaped_smoke_bridge_plan.count_kind(@skia.TextRunResource) != 4 ||
      shaped_smoke_bridge_plan.count_kind(@skia.FontResource) != 1 {
      fail_smoke("native shaped glyph descriptor bridge metadata is invalid")
    }
    println("native smoke shaped glyph descriptor bridge")
    println(1)
    let shaped_smoke_bridge_cache : @skia.ResourceCache[
      @skia.RendererResourceKey,
      @skia.RendererResourceDescriptor,
    ] = @skia.ResourceCache::new()
    let shaped_smoke_bridge_missing_before = shaped_smoke_bridge_cache.missing_cacheable_resource_plan(
      shaped_smoke_bridge_plan,
    )
    let shaped_smoke_bridge_cache_inserts = shaped_smoke_bridge_cache.insert_resource_plan(
      shaped_smoke_bridge_plan,
    )
    let shaped_smoke_bridge_cached_after = shaped_smoke_bridge_cache.cached_cacheable_resource_plan(
      shaped_smoke_bridge_plan,
    )
    if shaped_smoke_bridge_missing_before.length() !=
      shaped_smoke_bridge_plan.length() ||
      shaped_smoke_bridge_cache_inserts != shaped_smoke_bridge_plan.length() ||
      shaped_smoke_bridge_cached_after.length() !=
      shaped_smoke_bridge_plan.length() ||
      !shaped_smoke_bridge_cache.contains_resource_plan(
        shaped_smoke_bridge_plan,
      ) {
      fail_smoke(
        "native shaped glyph descriptor bridge did not populate the cache",
      )
    }
    println("native smoke shaped glyph descriptor bridge cache resources")
    println(shaped_smoke_bridge_cache_inserts)
    println("native smoke shaped text native resource plan count")
    println(shaped_smoke_plan.length())
    println("native smoke shaped glyph run native resource plan count")
    println(shaped_smoke_glyph_run_plan.length())
    println("native smoke shaped glyph count")
    println(shaped_glyph_count)
    canvas.draw_glyphs(
      shaped_glyphs,
      shaped_positions,
      font,
      @skia.Paint::new(color=@skia.Color::black()),
      origin=@skia.Point::new(0, 23),
    )
    smoke_mark(b"drew shaped text")
  }
  canvas.draw_text_utf8(
    smoke_text_bytes(),
    @skia.Point::new(0, 31),
    font,
    @skia.Paint::new(color=@skia.Color::black()),
  )
  smoke_mark(b"drew default text")
  let default_typeface = @native.Typeface::default()
  println("native smoke default typeface availability")
  if default_typeface is Some(_) {
    println(1)
  } else {
    println(0)
  }
  match default_typeface {
    None => ()
    Some(typeface) => {
      smoke_mark(b"typeface default")
      guard @native.Font::from_typeface(typeface, size=9.0)
        is Some(typeface_font) else {
        fail_smoke("failed to create native font from default typeface")
      }
      smoke_mark(b"font from typeface")
      if typeface_font.spacing() <= 0.0 {
        fail_smoke("native typeface font spacing is not positive")
      }
      if typeface_font.measure_text_utf8(smoke_text_bytes()) <= 0.0 {
        fail_smoke("native typeface font did not report a positive text width")
      }
      if typeface_font.count_text_utf8(smoke_text_bytes()) != 4 {
        fail_smoke(
          "native typeface font did not report the expected glyph count",
        )
      }
      let typeface_glyphs = typeface_font.text_to_glyphs_utf8(
        smoke_text_bytes(),
      )
      if typeface_glyphs.length() != 4 || typeface_glyphs[0].to_int() <= 0 {
        fail_smoke(
          "native typeface font did not map text to expected glyph ids",
        )
      }
      let typeface_glyph_widths = typeface_font.glyph_widths(typeface_glyphs)
      if typeface_glyph_widths.length() != 4 || typeface_glyph_widths[0] <= 0.0 {
        fail_smoke("native typeface font did not report expected glyph widths")
      }
      let typeface_glyph_positions = typeface_font.text_glyph_positions_utf8(
        smoke_text_bytes(),
        origin=@skia.Point::new(2.0, 3.0),
      )
      if typeface_glyph_positions.length() != 4 ||
        typeface_glyph_positions[0] != @skia.Point::new(2.0, 3.0) ||
        typeface_glyph_positions[1].x <= typeface_glyph_positions[0].x {
        fail_smoke(
          "native typeface font did not report expected glyph positions",
        )
      }
      let typeface_glyph_bounds = typeface_font.glyph_bounds_many(
        typeface_glyphs,
      )
      if typeface_glyph_bounds.length() != 4 ||
        typeface_glyph_bounds[0].width() <= 0.0 ||
        typeface_glyph_bounds[0].height() <= 0.0 {
        fail_smoke("native typeface font did not report expected glyph bounds")
      }
      match typeface_font.measure_text_bounds_utf8(smoke_text_bytes()) {
        None => fail_smoke("native typeface font did not report text bounds")
        Some(bounds) =>
          if bounds.width() <= 0.0 || bounds.height() < 0.0 {
            fail_smoke("native typeface font text bounds are invalid")
          }
      }
      canvas.draw_text_utf8(
        smoke_text_bytes(),
        @skia.Point::new(16, 31),
        typeface_font,
        @skia.Paint::new(color=@skia.Color::black()),
      )
      smoke_mark(b"drew typeface text")
    }
  }

  guard @native.FontMgr::default() is Some(font_mgr) else {
    fail_smoke("failed to create native font manager")
  }
  smoke_mark(b"font manager default")
  if !font_mgr.is_available() {
    fail_smoke("native font manager is not available")
  }
  let family_count = font_mgr.count_families()
  if family_count <= 0 {
    fail_smoke("native font manager did not report font families")
  }
  println("native smoke font family count")
  println(family_count)
  guard font_mgr.family_name(0) is Some(first_family) else {
    fail_smoke("native font manager did not report first family name")
  }
  if first_family.is_empty() {
    fail_smoke("native font manager reported an empty first family name")
  }
  println("native smoke first font family bytes")
  println(first_family.length())
  guard font_mgr.match_family_style(first_family) is Some(family_typeface) else {
    fail_smoke("native font manager did not match first family typeface")
  }
  guard family_typeface.family_name() is Some(matched_family) else {
    fail_smoke("native typeface did not report a family name")
  }
  if matched_family.is_empty() {
    fail_smoke("native typeface reported an empty family name")
  }
  println("native smoke typeface family bytes")
  println(matched_family.length())
  guard @native.Font::from_typeface(family_typeface, size=8.0)
    is Some(family_font) else {
    fail_smoke("failed to create native font from font manager family")
  }
  if family_font.measure_text_utf8(smoke_text_bytes()) <= 0.0 {
    fail_smoke("native font manager family font did not measure text")
  }
  smoke_mark(b"font manager family")
  let fallback_request = @skia.FontFallbackRequest::new(
    families=@skia.FontFallbackChain::new(primary_family=first_family),
    bcp47=[b"en"],
    character=0x53,
  )
  let invalid_fallback_request = @skia.FontFallbackRequest::new()
  let invalid_fallback_request_plan = invalid_fallback_request.resource_plan(
    size=8.0,
  )
  if !invalid_fallback_request.is_empty() ||
    !invalid_fallback_request.resource_key().is_empty() ||
    invalid_fallback_request.resource_descriptor().is_cacheable() ||
    invalid_fallback_request_plan.length() != 1 ||
    invalid_fallback_request_plan.cacheable_count != 0 ||
    invalid_fallback_request_plan.uncacheable_count != 1 ||
    invalid_fallback_request_plan.count_kind(@skia.TypefaceResource) != 1 ||
    font_mgr.match_fallback_request(invalid_fallback_request) is Some(_) {
    fail_smoke("empty fallback request resource plan should be uncacheable")
  }
  println("native smoke invalid fallback request resource plan count")
  println(invalid_fallback_request_plan.length())
  let fallback_key = fallback_request.resource_key()
  let fallback_language_key = @skia.FontFallbackRequest::new(
    families=@skia.FontFallbackChain::new(primary_family=first_family),
    bcp47=[b"ja"],
    character=0x53,
  ).resource_key()
  let fallback_character_key = fallback_request
    .with_character(0x4F61)
    .resource_key()
  if fallback_key.is_empty() ||
    fallback_key != fallback_request.resource_key() ||
    fallback_key == fallback_language_key ||
    fallback_key == fallback_character_key {
    fail_smoke(
      "native font fallback resource key did not encode request inputs",
    )
  }
  println("native smoke font fallback key variation")
  println(1)
  let fallback_plan = @skia.RendererResourcePlan::new([
    fallback_request.resource_descriptor(),
  ])
  if fallback_plan.length() != 1 ||
    fallback_plan.cacheable_count != 1 ||
    fallback_plan.uncacheable_count != 0 ||
    fallback_plan.byte_size <= 0L {
    fail_smoke("native font fallback resource plan is invalid")
  }
  println("native smoke font fallback resource plan count")
  println(fallback_plan.length())
  guard font_mgr.match_fallback_request(fallback_request)
    is Some(fallback_typeface) else {
    fail_smoke("native font manager did not match a fallback request")
  }
  guard fallback_typeface.family_name() is Some(fallback_family) else {
    fail_smoke("native fallback typeface did not report a family name")
  }
  if fallback_family.is_empty() {
    fail_smoke("native fallback typeface reported an empty family name")
  }
  println("native smoke font fallback family bytes")
  println(fallback_family.length())
  let fallback_match_descriptor = fallback_request.match_descriptor(
    fallback_family,
  )
  if !fallback_match_descriptor.is_valid() ||
    fallback_match_descriptor.resource_key().is_empty() ||
    fallback_match_descriptor.resource_key() == fallback_key ||
    fallback_match_descriptor.resource_key() ==
    fallback_request
    .match_descriptor(
      fallback_family,
      fallback_index=fallback_match_descriptor.fallback_index,
      synthetic=true,
    )
    .resource_key() {
    fail_smoke("native font fallback match metadata key is invalid")
  }
  println("native smoke font fallback match key variation")
  println(1)
  let fallback_match_plan = fallback_match_descriptor.resource_plan(size=8.0)
  if fallback_match_plan.length() != 2 ||
    fallback_match_plan.count_kind(@skia.TypefaceResource) != 1 ||
    fallback_match_plan.count_kind(@skia.FontResource) != 1 ||
    fallback_match_plan.cacheable_count != 2 ||
    fallback_match_plan.byte_size <= fallback_plan.byte_size {
    fail_smoke("native font fallback match resource plan is invalid")
  }
  println("native smoke font fallback match resource plan count")
  println(fallback_match_plan.length())
  let invalid_fallback_match = fallback_request.match_descriptor(b"")
  let invalid_fallback_match_plan = invalid_fallback_match.resource_plan(
    size=8.0,
  )
  if invalid_fallback_match.is_valid() ||
    invalid_fallback_match_plan.length() != 1 ||
    invalid_fallback_match_plan.cacheable_count != 0 ||
    invalid_fallback_match_plan.uncacheable_count != 1 ||
    invalid_fallback_match_plan.count_kind(@skia.TypefaceResource) != 1 {
    fail_smoke("invalid fallback match resource plan should be uncacheable")
  }
  let fallback_resolution = fallback_request.resolution_descriptor(
    fallback_family,
    fallback_index=fallback_match_descriptor.fallback_index,
  )
  let fallback_resolution_plan = fallback_resolution.resource_plan(size=8.0)
  if !fallback_resolution.is_valid() ||
    fallback_resolution.resource_key().is_empty() ||
    fallback_resolution.resource_key() == fallback_key ||
    fallback_resolution.resource_key() ==
    fallback_match_descriptor.resource_key() ||
    fallback_resolution.resource_key() ==
    fallback_request
    .resolution_descriptor(
      fallback_family,
      fallback_index=fallback_match_descriptor.fallback_index,
      synthetic=true,
    )
    .resource_key() ||
    fallback_resolution_plan.length() != 4 ||
    fallback_resolution_plan.count_kind(@skia.TypefaceResource) != 3 ||
    fallback_resolution_plan.count_kind(@skia.FontResource) != 1 ||
    !fallback_resolution_plan.contains_key(fallback_key) ||
    !fallback_resolution_plan.contains_key(
      fallback_match_descriptor.resource_key(),
    ) ||
    !fallback_resolution_plan.contains_key(fallback_resolution.resource_key()) ||
    fallback_resolution_plan.byte_size <= fallback_match_plan.byte_size {
    fail_smoke(
      "native font fallback resolution metadata resource plan is invalid",
    )
  }
  println("native smoke font fallback resolution key variation")
  println(1)
  println("native smoke font fallback resolution resource plan count")
  println(fallback_resolution_plan.length())
  let invalid_fallback_resolution = fallback_request.resolution_descriptor(b"")
  let invalid_fallback_resolution_plan = invalid_fallback_resolution.resource_plan(
    size=8.0,
  )
  if invalid_fallback_resolution.is_valid() ||
    invalid_fallback_resolution_plan.length() != 1 ||
    invalid_fallback_resolution_plan.cacheable_count != 0 ||
    invalid_fallback_resolution_plan.uncacheable_count != 1 ||
    invalid_fallback_resolution_plan.count_kind(@skia.TypefaceResource) != 1 {
    fail_smoke(
      "invalid fallback resolution resource plan should be uncacheable",
    )
  }
  println("native smoke invalid fallback match resource plan count")
  println(invalid_fallback_match_plan.length())
  println("native smoke invalid fallback resolution resource plan count")
  println(invalid_fallback_resolution_plan.length())
  guard font_mgr.resolve_fallback_request(fallback_request)
    is Some(resolved_fallback) else {
    fail_smoke("native font manager did not resolve fallback metadata")
  }
  let resolved_fallback_plan = resolved_fallback.resource_plan(size=8.0)
  if !resolved_fallback.is_available() ||
    !resolved_fallback.typeface.is_available() ||
    !resolved_fallback.resolution.is_valid() ||
    resolved_fallback.resolution.resource_key() !=
    fallback_resolution.resource_key() ||
    resolved_fallback_plan.length() != 4 ||
    resolved_fallback_plan.count_kind(@skia.TypefaceResource) != 3 ||
    resolved_fallback_plan.count_kind(@skia.FontResource) != 1 ||
    !resolved_fallback_plan.contains_key(fallback_key) ||
    !resolved_fallback_plan.contains_key(
      fallback_match_descriptor.resource_key(),
    ) ||
    !resolved_fallback_plan.contains_key(
      resolved_fallback.resolution.resource_key(),
    ) {
    fail_smoke("native font fallback resolution bridge metadata is invalid")
  }
  println("native smoke font fallback resolution bridge")
  println(1)
  let resolved_fallback_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @skia.RendererResourceDescriptor,
  ] = @skia.ResourceCache::new()
  let resolved_fallback_missing_before = resolved_fallback_cache.missing_cacheable_resource_plan(
    resolved_fallback_plan,
  )
  let resolved_fallback_cache_inserts = resolved_fallback_cache.insert_resource_plan(
    resolved_fallback_plan,
  )
  let resolved_fallback_cached_after = resolved_fallback_cache.cached_cacheable_resource_plan(
    resolved_fallback_plan,
  )
  if resolved_fallback_missing_before.length() != 4 ||
    resolved_fallback_cache_inserts != 4 ||
    resolved_fallback_cached_after.length() != 4 ||
    !resolved_fallback_cache.contains_resource_plan(resolved_fallback_plan) {
    fail_smoke(
      "native font fallback resolution bridge did not populate the cache",
    )
  }
  println("native smoke font fallback resolution bridge cache resources")
  println(resolved_fallback_cache_inserts)
  guard @native.Font::from_typeface(fallback_typeface, size=8.0)
    is Some(fallback_font) else {
    fail_smoke("failed to create native font from fallback request typeface")
  }
  let fallback_font_descriptor = @skia.FontDescriptor::from_typeface(
    fallback_key,
    size=8.0,
  )
  let font_plan = @skia.RendererResourcePlan::new([
    fallback_font_descriptor.resource_descriptor(),
  ])
  if font_plan.length() != 1 ||
    font_plan.cacheable_count != 1 ||
    font_plan.uncacheable_count != 0 ||
    font_plan.byte_size <= 0L {
    fail_smoke("native font resource plan is invalid")
  }
  println("native smoke font resource plan count")
  println(font_plan.length())
  let fallback_font_plan = fallback_request.resource_plan(size=8.0)
  if fallback_font_plan.length() != 2 ||
    fallback_font_plan.count_kind(@skia.TypefaceResource) != 1 ||
    fallback_font_plan.count_kind(@skia.FontResource) != 1 ||
    fallback_font_plan.cacheable_count != 2 ||
    fallback_font_plan.byte_size <= font_plan.byte_size {
    fail_smoke("native fallback font resource plan is invalid")
  }
  println("native smoke font fallback font resource plan count")
  println(fallback_font_plan.length())
  let fallback_width = fallback_font.measure_text_utf8(smoke_text_bytes())
  if fallback_width <= 0.0 {
    fail_smoke("native font fallback request font did not measure text")
  }
  println("native smoke font fallback width")
  println(fallback_width)
  smoke_mark(b"font manager fallback request")
}
