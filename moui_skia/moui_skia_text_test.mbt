///|
test "font fallback contracts normalize style family and language requests" {
  let style = @moui_skia.FontStyleRequest::new(weight=1200, width=-2, slant=9)
  assert_eq(style.weight, 1000)
  assert_eq(style.width, 1)
  assert_eq(style.slant, 2)
  assert_true(style.is_bold())
  assert_true(style.is_italic())

  let chain = @moui_skia.FontFallbackChain::new(primary_family=b"Inter", fallback_families=[
    b"Noto Sans CJK SC", b"Inter", b"", b"Segoe UI Emoji",
  ])
  assert_eq(chain.length(), 3)
  assert_true(chain.family_at(0) == Some(b"Inter"))
  assert_true(chain.family_at(1) == Some(b"Noto Sans CJK SC"))
  assert_true(chain.family_at(2) == Some(b"Segoe UI Emoji"))
  assert_true(chain.family_at(3) is None)
  assert_true(chain.contains_family(b"Segoe UI Emoji"))
  let extended = chain.with_family(b"Apple Color Emoji").with_family(b"Inter")
  assert_eq(extended.length(), 4)
  assert_true(extended.family_at(3) == Some(b"Apple Color Emoji"))

  let empty_request = @moui_skia.FontFallbackRequest::new()
  assert_true(empty_request.is_empty())
  assert_true(empty_request.resource_key().is_empty())
  assert_true(!empty_request.resource_descriptor().is_cacheable())
  let empty_request_plan = empty_request.resource_plan(size=14.0, scale_x=1.1)
  assert_eq(empty_request_plan.length(), 1)
  assert_eq(empty_request_plan.cacheable_count, 0)
  assert_eq(empty_request_plan.uncacheable_count, 1)
  assert_eq(empty_request_plan.count_kind(TypefaceResource), 1)

  let request = @moui_skia.FontFallbackRequest::new(
    families=extended,
    bcp47=[b"zh-Hans", b"", b"en", b"zh-Hans"],
    character=0x4F60,
    style=@moui_skia.FontStyleRequest::bold(),
  )
  assert_eq(request.language_count(), 2)
  assert_true(request.language_at(0) == Some(b"zh-Hans"))
  assert_true(request.language_at(1) == Some(b"en"))
  assert_true(request.language_at(2) is None)
  assert_true(request.has_character())
  assert_true(
    request.with_character(-1).character == 0 &&
    !request.with_character(-1).has_character(),
  )
  let key = request.resource_key()
  assert_true(key.kind == TypefaceResource)
  assert_true(key == request.resource_key())
  assert_true(key != request.with_character(0x4F61).resource_key())
  assert_true(
    key !=
    request.with_style(@moui_skia.FontStyleRequest::italic()).resource_key(),
  )
  let descriptor = request.resource_descriptor()
  assert_true(descriptor.key == key)
  assert_true(descriptor.is_cacheable())
  assert_true(descriptor.byte_size > 0L)
  let plan = @moui_skia.RendererResourcePlan::new([descriptor, descriptor])
  assert_eq(plan.length(), 1)
  assert_eq(plan.cacheable_count, 1)
  assert_eq(plan.uncacheable_count, 0)

  let fallback_font = request.font_descriptor(size=14.0, scale_x=1.1)
  assert_true(fallback_font.typeface_key == key)
  assert_true(fallback_font.resource_key().kind == FontResource)
  assert_true(fallback_font.resource_descriptor().is_cacheable())
  let fallback_font_plan = request.resource_plan(size=14.0, scale_x=1.1)
  assert_eq(fallback_font_plan.length(), 2)
  assert_eq(fallback_font_plan.count_kind(TypefaceResource), 1)
  assert_eq(fallback_font_plan.count_kind(FontResource), 1)
  assert_true(fallback_font_plan.contains_key(key))
  assert_true(fallback_font_plan.contains_key(fallback_font.resource_key()))
  assert_true(fallback_font_plan.byte_size > descriptor.byte_size)
  assert_true(
    request
    .resource_plan(size=15.0)
    .descriptor_for_key(fallback_font.resource_key())
    is None,
  )

  let match_descriptor = request.match_descriptor(
    b"Noto Sans CJK SC",
    fallback_index=1,
    synthetic=true,
  )
  assert_true(match_descriptor.is_valid())
  assert_true(match_descriptor.source_family() == Some(b"Noto Sans CJK SC"))
  assert_true(match_descriptor.matched_in_request())
  let inferred_match = request.match_descriptor(b"Segoe UI Emoji")
  assert_eq(inferred_match.fallback_index, 2)
  assert_true(inferred_match.source_family() == Some(b"Segoe UI Emoji"))
  let match_key = match_descriptor.resource_key()
  assert_true(match_key.kind == TypefaceResource)
  assert_true(match_key != key)
  assert_true(match_key == match_descriptor.resource_key())
  assert_true(
    match_key !=
    request
    .match_descriptor(b"Noto Sans CJK SC", fallback_index=1, synthetic=false)
    .resource_key(),
  )
  assert_true(
    match_key !=
    request
    .match_descriptor(b"Segoe UI Emoji", fallback_index=2, synthetic=true)
    .resource_key(),
  )
  let match_resource = match_descriptor.resource_descriptor()
  assert_true(match_resource.key == match_key)
  assert_true(match_resource.is_cacheable())
  assert_true(match_resource.byte_size > descriptor.byte_size)
  let match_font = match_descriptor.font_descriptor(size=14.0, scale_x=1.1)
  assert_true(match_font.typeface_key == match_key)
  assert_true(match_font.resource_key().kind == FontResource)
  assert_true(match_font.resource_descriptor().is_cacheable())
  let match_plan = match_descriptor.resource_plan(size=14.0, scale_x=1.1)
  assert_eq(match_plan.length(), 2)
  assert_eq(match_plan.count_kind(TypefaceResource), 1)
  assert_eq(match_plan.count_kind(FontResource), 1)
  assert_true(match_plan.contains_key(match_key))
  assert_true(match_plan.contains_key(match_font.resource_key()))
  assert_true(match_plan.byte_size > match_resource.byte_size)
  let resolution = request.resolution_descriptor(
    b"Noto Sans CJK SC",
    fallback_index=1,
    synthetic=true,
  )
  assert_true(resolution.is_valid())
  assert_true(resolution.matched_in_request())
  assert_true(resolution.source_family() == Some(b"Noto Sans CJK SC"))
  assert_true(resolution.resolved_match == match_descriptor)
  let resolution_key = resolution.resource_key()
  assert_true(resolution_key.kind == TypefaceResource)
  assert_true(resolution_key != key)
  assert_true(resolution_key != match_key)
  assert_true(resolution_key == resolution.resource_key())
  assert_true(
    resolution_key !=
    request
    .resolution_descriptor(
      b"Noto Sans CJK SC",
      fallback_index=1,
      synthetic=false,
    )
    .resource_key(),
  )
  assert_true(
    resolution_key !=
    request
    .with_character(0x4F61)
    .resolution_descriptor(
      b"Noto Sans CJK SC",
      fallback_index=1,
      synthetic=true,
    )
    .resource_key(),
  )
  let resolution_font = resolution.font_descriptor(size=14.0, scale_x=1.1)
  assert_true(resolution_font.typeface_key == resolution_key)
  assert_true(resolution_font.resource_key().kind == FontResource)
  let resolution_plan = resolution.resource_plan(size=14.0, scale_x=1.1)
  assert_eq(resolution_plan.length(), 4)
  assert_eq(resolution_plan.count_kind(TypefaceResource), 3)
  assert_eq(resolution_plan.count_kind(FontResource), 1)
  assert_true(resolution_plan.contains_key(key))
  assert_true(resolution_plan.contains_key(match_key))
  assert_true(resolution_plan.contains_key(resolution_key))
  assert_true(resolution_plan.contains_key(resolution_font.resource_key()))
  assert_true(resolution_plan.byte_size > match_plan.byte_size)
  let normalized_resolution = @moui_skia.FontFallbackResolutionDescriptor::new(
    request=request.with_character(0x4F61),
    resolved_match=match_descriptor,
  )
  assert_true(
    normalized_resolution.resolved_match.request ==
    normalized_resolution.request,
  )
  assert_true(normalized_resolution.resource_key() != resolution_key)
  let platform_match = request.match_descriptor(
    b"Platform Fallback",
    fallback_index=99,
  )
  assert_eq(platform_match.fallback_index, -1)
  assert_true(platform_match.source_family() is None)
  assert_true(!platform_match.matched_in_request())
  let invalid_match = request.match_descriptor(b"")
  assert_true(!invalid_match.is_valid())
  assert_true(!invalid_match.resource_descriptor().is_cacheable())
  let invalid_match_plan = invalid_match.resource_plan(size=14.0, scale_x=1.1)
  assert_eq(invalid_match_plan.length(), 1)
  assert_eq(invalid_match_plan.cacheable_count, 0)
  assert_eq(invalid_match_plan.uncacheable_count, 1)
  assert_true(
    !request.resolution_descriptor(b"").resource_descriptor().is_cacheable(),
  )
  let invalid_resolution_plan = request
    .resolution_descriptor(b"")
    .resource_plan(size=14.0, scale_x=1.1)
  assert_eq(invalid_resolution_plan.length(), 1)
  assert_eq(invalid_resolution_plan.cacheable_count, 0)
  assert_eq(invalid_resolution_plan.uncacheable_count, 1)
}

///|
test "font descriptors derive font resource keys" {
  let typeface_key = @moui_skia.RendererResourceKey::typeface(b"Inter:400:5:0")
  let font = @moui_skia.FontDescriptor::from_typeface(typeface_key, size=16.0)
  let same_font = @moui_skia.FontDescriptor::from_typeface(
    typeface_key,
    size=16.0,
  )
  assert_true(font.is_valid())
  assert_true(font.resource_key() == same_font.resource_key())
  assert_true(font.resource_key().kind == FontResource)
  assert_true(font.resource_key() != font.with_size(18.0).resource_key())
  assert_true(font.resource_key() != font.with_scale_x(1.2).resource_key())
  assert_true(font.resource_key() != font.with_skew_x(0.25).resource_key())
  assert_true(
    font.resource_key() !=
    font
    .with_typeface_key(@moui_skia.RendererResourceKey::typeface(b"Serif"))
    .resource_key(),
  )
  let descriptor = font.resource_descriptor()
  assert_true(descriptor.key == font.resource_key())
  assert_true(descriptor.is_cacheable())
  assert_true(descriptor.byte_size > 0L)

  let default_font = @moui_skia.FontDescriptor::default(size=12.0)
  assert_true(default_font.is_valid())
  assert_true(default_font.resource_key().kind == FontResource)
  assert_true(!font.with_size(-1.0).is_valid())
  assert_true(font.with_size(-1.0).resource_key().is_empty())
  assert_true(!font.with_scale_x(0.0).resource_descriptor().is_cacheable())
  assert_true(
    !font
    .with_typeface_key(@moui_skia.RendererResourceKey::shader(b"not-typeface"))
    .is_valid(),
  )
  let plan = @moui_skia.RendererResourcePlan::new([
    font.resource_descriptor(),
    same_font.resource_descriptor(),
  ])
  assert_eq(plan.length(), 1)
  assert_eq(plan.cacheable_count, 1)
  assert_eq(plan.uncacheable_count, 0)
}

///|
test "text run descriptor records byte ranges direction and fallback query" {
  let range = @moui_skia.TextRange::new(-2, 6)
  assert_eq(range.start, 0)
  assert_eq(range.end, 6)
  assert_eq(range.length(), 6)
  assert_true(range.contains_offset(5))
  assert_true(!range.contains_offset(6))
  assert_true(@moui_skia.TextRange::new(9, 3).is_empty())

  let fallback = @moui_skia.FontFallbackRequest::new(
    families=@moui_skia.FontFallbackChain::new(primary_family=b"Inter"),
    character=0x1F642,
  )
  let run = @moui_skia.TextRunDescriptor::new(
    range~,
    direction=RightToLeft,
    fallback~,
  )
  assert_true(run.is_right_to_left())
  assert_true(!run.is_empty())
  assert_true(run.fallback.families.primary_family == b"Inter")
  assert_true(run.with_direction(LeftToRight).direction.is_left_to_right())
  assert_true(run.with_range(@moui_skia.TextRange::new(1, 1)).is_empty())

  let font_key = @moui_skia.RendererResourceKey::font(b"Inter:16:400")
  let key = run.resource_key(b"hello", font_key~)
  assert_true(key.kind == TextRunResource)
  assert_true(!key.is_empty())
  assert_true(key == run.resource_key(b"hello", font_key~))
  assert_true(key != run.resource_key(b"hello!", font_key~))
  assert_true(
    key !=
    run
    .with_range(@moui_skia.TextRange::new(0, 3))
    .resource_key(b"hello", font_key~),
  )
  assert_true(
    key != run.with_direction(LeftToRight).resource_key(b"hello", font_key~),
  )
  assert_true(
    key !=
    run
    .with_fallback(fallback.with_character(0x4E2D))
    .resource_key(b"hello", font_key~),
  )
  assert_true(
    key !=
    run.resource_key(
      b"hello",
      font_key=@moui_skia.RendererResourceKey::font(b"Serif:16:400"),
    ),
  )
  let descriptor = run.resource_descriptor(b"hello", font_key~)
  assert_true(descriptor.key == key)
  assert_eq(descriptor.byte_size, 5L)
  assert_true(descriptor.is_cacheable())
  let ranged_run = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(2, 5),
  )
  let ranged_key = ranged_run.resource_key(b"--abc++", font_key~)
  assert_true(ranged_key == ranged_run.resource_key(b"XXabcYY", font_key~))
  assert_true(ranged_key != ranged_run.resource_key(b"XXabdYY", font_key~))
  assert_eq(ranged_run.resource_descriptor(b"--abc++", font_key~).byte_size, 3L)
  assert_true(
    @moui_skia.TextRunDescriptor::new(range=@moui_skia.TextRange::new(2, 99)).resource_key(
      b"--abc",
      font_key~,
    ) ==
    ranged_run.resource_key(b"--abc", font_key~),
  )
  let text_plan = run.resource_plan(b"hello", font_key~)
  assert_eq(text_plan.length(), 3)
  assert_eq(text_plan.count_kind(TextRunResource), 1)
  assert_eq(text_plan.count_kind(FontResource), 1)
  assert_eq(text_plan.count_kind(TypefaceResource), 1)
  assert_true(text_plan.contains_key(key))
  assert_true(text_plan.contains_key(font_key))
  assert_true(text_plan.contains_key(fallback.resource_key()))
  assert_true(text_plan.byte_size > descriptor.byte_size)
  let plain_run = @moui_skia.TextRunDescriptor::new(range~)
  let plain_plan = plain_run.resource_plan(b"hello")
  assert_eq(plain_plan.length(), 1)
  assert_eq(plain_plan.count_kind(TextRunResource), 1)
  assert_eq(plain_plan.count_kind(FontResource), 0)
  assert_eq(plain_plan.count_kind(TypefaceResource), 0)
}

///|
test "text measurement descriptors track cache identity and dependencies" {
  let fallback = @moui_skia.FontFallbackRequest::new(
    families=@moui_skia.FontFallbackChain::new(primary_family=b"Inter"),
    bcp47=[b"en"],
    character=0x68,
  )
  let run = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(1, 5),
    direction=LeftToRight,
    fallback~,
  )
  let font_key = @moui_skia.RendererResourceKey::font(b"Inter:14")
  let measurement = @moui_skia.TextMeasurementDescriptor::new(
    run~,
    font_key~,
    width=240.0,
    shape=true,
  )
  let key = measurement.resource_key(b"xhelloz")
  assert_true(key.kind == TextRunResource)
  assert_true(key == measurement.resource_key(b"yhelloq"))
  assert_true(key != measurement.resource_key(b"yhelpq"))
  assert_true(key != measurement.with_width(120.0).resource_key(b"xhelloz"))
  assert_true(
    key != measurement.with_measure_bounds(false).resource_key(b"xhelloz"),
  )
  assert_true(!measurement.with_shape(false).is_shaped())
  assert_true(key != measurement.with_shape(false).resource_key(b"xhelloz"))
  assert_true(
    key !=
    measurement
    .with_font_key(@moui_skia.RendererResourceKey::font(b"Serif:14"))
    .resource_key(b"xhelloz"),
  )
  assert_true(
    key !=
    measurement
    .with_run(run.with_direction(RightToLeft))
    .resource_key(b"xhelloz"),
  )
  assert_eq(
    @moui_skia.TextMeasurementDescriptor::new(width=-1.0).width,
    1000000000.0,
  )

  let descriptor = measurement.resource_descriptor(b"xhelloz")
  assert_true(descriptor.key == key)
  assert_true(descriptor.is_cacheable())
  assert_true(descriptor.byte_size > 0L)
  let plan = measurement.resource_plan(b"xhelloz")
  assert_eq(plan.length(), 4)
  assert_eq(plan.count_kind(TextRunResource), 2)
  assert_eq(plan.count_kind(FontResource), 1)
  assert_eq(plan.count_kind(TypefaceResource), 1)
  assert_true(plan.contains_key(key))
  assert_true(plan.contains_key(run.resource_key(b"xhelloz", font_key~)))
  assert_true(plan.contains_key(font_key))
  assert_true(plan.contains_key(fallback.resource_key()))
  let measured = measurement.measured_run_descriptor(
    advance=18.0,
    bounds=Some(@moui_skia.Rect::new(12.0, -2.0, 2.0, 6.0)),
  )
  assert_true(measured.is_valid())
  assert_true(measured.has_bounds())
  assert_true(
    measured.bounds == Some(@moui_skia.Rect::new(2.0, -2.0, 12.0, 6.0)),
  )
  let measured_key = measured.resource_key(b"xhelloz")
  assert_true(measured_key.kind == TextRunResource)
  assert_true(measured_key != key)
  assert_true(measured_key == measured.resource_key(b"yhelloq"))
  assert_true(
    measured_key !=
    measurement
    .measured_run_descriptor(advance=19.0, bounds=measured.bounds)
    .resource_key(b"xhelloz"),
  )
  assert_true(
    measured_key !=
    measurement.measured_run_descriptor(advance=18.0).resource_key(b"xhelloz"),
  )
  let measured_plan = measured.resource_plan(b"xhelloz")
  assert_eq(measured_plan.length(), 5)
  assert_eq(measured_plan.count_kind(TextRunResource), 3)
  assert_eq(measured_plan.count_kind(FontResource), 1)
  assert_eq(measured_plan.count_kind(TypefaceResource), 1)
  assert_true(measured_plan.contains_key(measured_key))
  assert_true(measured_plan.contains_key(key))
  assert_true(measured_plan.byte_size > plan.byte_size)
  let normalized_measured = measurement.measured_run_descriptor(
    advance=-1.0,
    bounds=Some(@moui_skia.Rect::new(0, 0, 1.0 / 0.0, 1)),
  )
  assert_eq(normalized_measured.advance, 0.0)
  assert_true(!normalized_measured.has_bounds())
  let invalid_measured : @moui_skia.MeasuredTextRunDescriptor = {
    measurement,
    advance: 0.0 / 0.0,
    bounds: None,
  }
  assert_true(!invalid_measured.is_valid())
  assert_true(!invalid_measured.resource_descriptor(b"xhelloz").is_cacheable())
  let invalid_measured_plan = invalid_measured.resource_plan(b"xhelloz")
  assert_eq(invalid_measured_plan.length(), 1)
  assert_eq(invalid_measured_plan.cacheable_count, 0)
  assert_eq(invalid_measured_plan.uncacheable_count, 1)

  let plain = @moui_skia.TextMeasurementDescriptor::new(
    run=@moui_skia.TextRunDescriptor::new(range=@moui_skia.TextRange::new(0, 5)),
  )
  let plain_plan = plain.resource_plan(b"hello")
  assert_eq(plain_plan.length(), 2)
  assert_eq(plain_plan.count_kind(TextRunResource), 2)
  assert_eq(plain_plan.count_kind(FontResource), 0)
  assert_eq(plain_plan.count_kind(TypefaceResource), 0)
}

///|
test "text shaping descriptors track request and shaped run resources" {
  let fallback = @moui_skia.FontFallbackRequest::new(
    families=@moui_skia.FontFallbackChain::new(primary_family=b"Inter"),
    bcp47=[b"en"],
    character=0x68,
  )
  let run = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(1, 5),
    direction=LeftToRight,
    fallback~,
  )
  let font_key = @moui_skia.RendererResourceKey::font(b"Inter:14")
  let shaping = @moui_skia.TextShapingDescriptor::new(
    run~,
    font_key~,
    width=240.0,
  )
  let key = shaping.resource_key(b"xhelloz")
  assert_true(key.kind == TextRunResource)
  assert_true(key == shaping.resource_key(b"yhelloq"))
  assert_true(key != shaping.resource_key(b"yhelpq"))
  assert_true(key != shaping.with_width(120.0).resource_key(b"xhelloz"))
  assert_true(
    key !=
    shaping
    .with_font_key(@moui_skia.RendererResourceKey::font(b"Serif:14"))
    .resource_key(b"xhelloz"),
  )
  assert_true(
    key !=
    shaping.with_run(run.with_direction(RightToLeft)).resource_key(b"xhelloz"),
  )
  assert_eq(
    @moui_skia.TextShapingDescriptor::new(width=-1.0).width,
    1000000000.0,
  )

  let measurement = shaping.measurement_descriptor()
  assert_true(measurement.is_shaped())
  assert_true(!measurement.measure_bounds)
  assert_true(measurement.resource_key(b"xhelloz") != key)

  let descriptor = shaping.resource_descriptor(b"xhelloz")
  assert_true(descriptor.key == key)
  assert_true(descriptor.is_cacheable())
  assert_true(descriptor.byte_size > 0L)
  let plan = shaping.resource_plan(b"xhelloz")
  assert_eq(plan.length(), 4)
  assert_eq(plan.count_kind(TextRunResource), 2)
  assert_eq(plan.count_kind(FontResource), 1)
  assert_eq(plan.count_kind(TypefaceResource), 1)
  assert_true(plan.contains_key(key))
  assert_true(plan.contains_key(run.resource_key(b"xhelloz", font_key~)))
  assert_true(plan.contains_key(font_key))
  assert_true(plan.contains_key(fallback.resource_key()))

  let shaped = shaping.shaped_run_descriptor(
    glyph_count=4,
    cluster_count=4,
    advance=@moui_skia.Point::new(16.0, 0.0),
  )
  assert_true(shaped.is_valid())
  let shaped_key = shaped.resource_key(b"xhelloz")
  assert_true(shaped_key.kind == TextRunResource)
  assert_true(shaped_key != key)
  assert_true(shaped_key == shaped.resource_key(b"yhelloq"))
  assert_true(
    shaped_key !=
    shaping
    .shaped_run_descriptor(
      glyph_count=5,
      cluster_count=4,
      advance=@moui_skia.Point::new(16.0, 0.0),
    )
    .resource_key(b"xhelloz"),
  )
  assert_true(
    shaped_key !=
    shaping
    .shaped_run_descriptor(
      glyph_count=4,
      cluster_count=4,
      advance=@moui_skia.Point::new(17.0, 0.0),
    )
    .resource_key(b"xhelloz"),
  )
  let shaped_plan = shaped.resource_plan(b"xhelloz")
  assert_eq(shaped_plan.length(), 5)
  assert_eq(shaped_plan.count_kind(TextRunResource), 3)
  assert_eq(shaped_plan.count_kind(FontResource), 1)
  assert_eq(shaped_plan.count_kind(TypefaceResource), 1)
  assert_true(shaped_plan.contains_key(shaped_key))
  assert_true(shaped_plan.contains_key(key))
  assert_true(shaped_plan.byte_size > plan.byte_size)
  let glyph_run = shaped.glyph_run_descriptor(
    glyph_ids=[10, 11, 12, 13],
    positions=[
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(4.0, 0.0),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(12.0, 0.0),
    ],
    clusters=[0, 1, 2, 3],
  )
  assert_true(glyph_run.is_valid())
  assert_true(!glyph_run.is_empty())
  assert_eq(glyph_run.glyph_count(), 4)
  assert_eq(glyph_run.cluster_count(), 4)
  assert_true(glyph_run.shaped_run == shaped)
  assert_eq(glyph_run.glyph_ids[0], 10)
  assert_true(glyph_run.positions[1] == @moui_skia.Point::new(4.0, 0.0))
  assert_eq(glyph_run.clusters[2], 2)
  let glyph_run_key = glyph_run.resource_key(b"xhelloz")
  assert_true(glyph_run_key.kind == TextRunResource)
  assert_true(glyph_run_key != shaped_key)
  assert_true(glyph_run_key == glyph_run.resource_key(b"yhelloq"))
  assert_true(
    glyph_run_key !=
    shaped
    .glyph_run_descriptor(
      glyph_ids=[10, 11, 12, 14],
      positions=glyph_run.positions,
      clusters=glyph_run.clusters,
    )
    .resource_key(b"xhelloz"),
  )
  assert_true(
    glyph_run_key !=
    shaped
    .glyph_run_descriptor(
      glyph_ids=glyph_run.glyph_ids,
      positions=[
        @moui_skia.Point::new(0.0, 0.0),
        @moui_skia.Point::new(4.5, 0.0),
        @moui_skia.Point::new(8.0, 0.0),
        @moui_skia.Point::new(12.0, 0.0),
      ],
      clusters=glyph_run.clusters,
    )
    .resource_key(b"xhelloz"),
  )
  assert_true(
    glyph_run_key !=
    shaped
    .glyph_run_descriptor(
      glyph_ids=glyph_run.glyph_ids,
      positions=glyph_run.positions,
      clusters=[0, 1, 1, 3],
    )
    .resource_key(b"xhelloz"),
  )
  let glyph_run_plan = glyph_run.resource_plan(b"xhelloz")
  assert_eq(glyph_run_plan.length(), 6)
  assert_eq(glyph_run_plan.count_kind(TextRunResource), 4)
  assert_eq(glyph_run_plan.count_kind(FontResource), 1)
  assert_eq(glyph_run_plan.count_kind(TypefaceResource), 1)
  assert_true(glyph_run_plan.contains_key(glyph_run_key))
  assert_true(glyph_run_plan.contains_key(shaped_key))
  assert_true(glyph_run_plan.contains_key(key))
  assert_true(glyph_run_plan.byte_size > shaped_plan.byte_size)
  let truncated_glyph_run = shaped.glyph_run_descriptor(
    glyph_ids=[1, 2],
    positions=[@moui_skia.Point::new(1.0, 0.0)],
    clusters=[0, 1, 2],
  )
  assert_eq(truncated_glyph_run.glyph_count(), 1)
  assert_eq(truncated_glyph_run.cluster_count(), 1)
  assert_eq(truncated_glyph_run.shaped_run.glyph_count, 1)
  let normalized_glyph_run = shaped.glyph_run_descriptor(
    glyph_ids=[-1],
    positions=[@moui_skia.Point::new(1.0 / 0.0, 0.0)],
    clusters=[-1],
  )
  assert_eq(normalized_glyph_run.glyph_ids[0], 0)
  assert_true(normalized_glyph_run.positions[0] == @moui_skia.Point::zero())
  assert_eq(normalized_glyph_run.clusters[0], 0)

  let invalid = shaping.shaped_run_descriptor(glyph_count=0)
  assert_true(!invalid.is_valid())
  assert_true(!invalid.resource_descriptor(b"xhelloz").is_cacheable())
  let invalid_plan = invalid.resource_plan(b"xhelloz")
  assert_eq(invalid_plan.length(), 1)
  assert_eq(invalid_plan.cacheable_count, 0)
  assert_eq(invalid_plan.uncacheable_count, 1)
  assert_true(!invalid.glyph_run_descriptor().is_valid())
  let invalid_glyph_plan = invalid
    .glyph_run_descriptor()
    .resource_plan(b"xhelloz")
  assert_eq(invalid_glyph_plan.length(), 1)
  assert_eq(invalid_glyph_plan.cacheable_count, 0)
  assert_eq(invalid_glyph_plan.uncacheable_count, 1)
  assert_true(
    !invalid
    .glyph_run_descriptor()
    .resource_descriptor(b"xhelloz")
    .is_cacheable(),
  )
}
