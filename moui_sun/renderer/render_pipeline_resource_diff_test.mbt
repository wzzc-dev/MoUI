///|
fn retained_keyed_resource_previous_pipeline(
  previous_icon : @graphics.Pixmap,
  face : @text.FontFace,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
  insets : @graphics.NinePatchInsets,
) -> RenderPipeline {
  RenderPipeline::new()
  .draw_pixmap_keyed("icon", previous_icon, 1, 1, paint)
  .draw_bmp_bytes_keyed("bmp-icon", previous_icon.to_bmp_bytes(), 5, 1, paint)
  .draw_png_bytes_keyed(
    "png-icon",
    must_renderer_test_png_bytes(previous_icon),
    6,
    1,
    paint,
  )
  .draw_rgba_bytes_keyed(
    "rgba-icon",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    7,
    1,
    paint,
  )
  .draw_rgba_bytes_rect_keyed(
    "rgba-sprite",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    7,
    2,
    paint,
  )
  .draw_sampled_bmp_bytes_keyed(
    "bmp-sampled",
    previous_icon.to_bmp_bytes(),
    0,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_sampled_png_bytes_keyed(
    "png-sampled",
    must_renderer_test_png_bytes(previous_icon),
    2,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_sampled_rgba_bytes_keyed(
    "rgba-sampled",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    4,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_quality_bmp_bytes_keyed(
    "bmp-quality",
    previous_icon.to_bmp_bytes(),
    2,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_quality_bmp_bytes_rect_keyed(
    "bmp-quality-sprite",
    previous_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    4,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_quality_png_bytes_keyed(
    "png-quality",
    must_renderer_test_png_bytes(previous_icon),
    4,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_quality_png_bytes_rect_keyed(
    "png-quality-sprite",
    must_renderer_test_png_bytes(previous_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_quality_rgba_bytes_keyed(
    "rgba-quality",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    4,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_quality_rgba_bytes_rect_keyed(
    "rgba-quality-sprite",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_sampled_bmp_bytes_keyed(
    "bmp-transform",
    previous_icon.to_bmp_bytes(),
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_sampled_bmp_bytes_rect_keyed(
    "bmp-transform-sprite",
    previous_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_sampled_png_bytes_keyed(
    "png-transform",
    must_renderer_test_png_bytes(previous_icon),
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_sampled_png_bytes_rect_keyed(
    "png-transform-sprite",
    must_renderer_test_png_bytes(previous_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_sampled_rgba_bytes_keyed(
    "rgba-transform",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_sampled_rgba_bytes_rect_keyed(
    "rgba-transform-sprite",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_quality_bmp_bytes_keyed(
    "bmp-transform-quality",
    previous_icon.to_bmp_bytes(),
    0.0,
    3.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_quality_bmp_bytes_rect_keyed(
    "bmp-transform-quality-sprite",
    previous_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    2.0,
    3.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_quality_png_bytes_keyed(
    "png-transform-quality",
    must_renderer_test_png_bytes(previous_icon),
    4.0,
    3.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_quality_png_bytes_rect_keyed(
    "png-transform-quality-sprite",
    must_renderer_test_png_bytes(previous_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6.0,
    3.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_quality_rgba_bytes_keyed(
    "rgba-transform-quality",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    0.0,
    4.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_quality_rgba_bytes_rect_keyed(
    "rgba-transform-quality-sprite",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    2.0,
    4.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_sampled_bmp_bytes_rect_keyed(
    "bmp-sampled-sprite",
    previous_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    4,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_sampled_png_bytes_rect_keyed(
    "png-sampled-sprite",
    must_renderer_test_png_bytes(previous_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_sampled_rgba_bytes_rect_keyed(
    "rgba-sampled-sprite",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_bmp_bytes_rect_keyed(
    "bmp-sprite",
    previous_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6,
    2,
    paint,
  )
  .draw_png_bytes_rect_keyed(
    "png-sprite",
    must_renderer_test_png_bytes(previous_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    7,
    2,
    paint,
  )
  .draw_tiled_bmp_bytes_rect_keyed(
    "bmp-pattern",
    previous_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    0,
    3,
    2,
    1,
    paint,
  )
  .draw_tiled_png_bytes_rect_keyed(
    "png-pattern",
    must_renderer_test_png_bytes(previous_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    2,
    3,
    2,
    1,
    paint,
  )
  .draw_tiled_rgba_bytes_rect_keyed(
    "rgba-pattern",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    4,
    3,
    2,
    1,
    paint,
  )
  .draw_nine_patch_bmp_bytes_keyed(
    "bmp-panel",
    previous_icon.to_bmp_bytes(),
    0,
    4,
    2,
    2,
    insets,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_nine_patch_png_bytes_keyed(
    "png-panel",
    must_renderer_test_png_bytes(previous_icon),
    2,
    4,
    2,
    2,
    insets,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_nine_patch_rgba_bytes_keyed(
    "rgba-panel",
    previous_icon.to_rgba_bytes(),
    2,
    2,
    4,
    4,
    2,
    2,
    insets,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_pixmap_rect_keyed(
    "sprite",
    previous_icon,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    4,
    1,
    paint,
  )
  .draw_text_face_keyed("font", face, "A", 1.0, 1.0, config, paint)
  .draw_font_bytes_atlas_keyed(
    "font-bytes",
    make_minimal_ttf(),
    "font-bytes-label",
    "A",
    2.5,
    1.0,
    config,
    paint,
  )
  .draw_font_bytes_fallback_keyed(
    [
      FontBytesFallbackSource::new("primary", make_ttf_for_codes([65])),
      FontBytesFallbackSource::new("fallback", make_ttf_for_codes([66])),
    ],
    "fallback-label",
    "AB",
    3.5,
    1.0,
    config,
    paint,
  )
  .draw_font_bytes_fallback_atlas_keyed(
    [
      FontBytesFallbackSource::new("atlas-primary", make_ttf_for_codes([65])),
      FontBytesFallbackSource::new("atlas-fallback", make_ttf_for_codes([66])),
    ],
    "fallback-atlas-label",
    "AB",
    4.0,
    1.0,
    config,
    paint,
  )
  .draw_loaded_font_keyed(
    "loader-font", "loader-label", "A", 2.0, 1.0, config, paint,
  )
  .draw_loaded_font_fallback_keyed(
    ["loader-primary", "loader-fallback"],
    "loader-fallback-label",
    "AB",
    2.25,
    1.0,
    config,
    paint,
  )
  .draw_loaded_font_fallback_atlas_keyed(
    ["loader-atlas-primary", "loader-atlas-fallback"],
    "loader-fallback-atlas-label",
    "AB",
    2.75,
    1.0,
    config,
    paint,
  )
  .draw_loaded_font_atlas_keyed(
    "atlas-font", "atlas-label", "A", 3.0, 1.0, config, paint,
  )
}

///|
fn retained_keyed_resource_next_pipeline(
  next_icon : @graphics.Pixmap,
  face : @text.FontFace,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
  insets : @graphics.NinePatchInsets,
) -> RenderPipeline {
  RenderPipeline::new()
  .draw_pixmap_keyed("icon", next_icon, 1, 1, paint)
  .draw_bmp_bytes_keyed("bmp-icon", next_icon.to_bmp_bytes(), 5, 1, paint)
  .draw_png_bytes_keyed(
    "png-icon",
    must_renderer_test_png_bytes(next_icon),
    6,
    1,
    paint,
  )
  .draw_rgba_bytes_keyed("rgba-icon", Bytes::from_array([0]), 2, 2, 7, 1, paint)
  .draw_rgba_bytes_rect_keyed(
    "rgba-sprite",
    Bytes::from_array([0]),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    7,
    2,
    paint,
  )
  .draw_sampled_bmp_bytes_keyed(
    "bmp-sampled",
    next_icon.to_bmp_bytes(),
    0,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_sampled_png_bytes_keyed(
    "png-sampled",
    must_renderer_test_png_bytes(next_icon),
    2,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_sampled_rgba_bytes_keyed(
    "rgba-sampled",
    Bytes::from_array([0]),
    2,
    2,
    4,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_quality_bmp_bytes_keyed(
    "bmp-quality",
    next_icon.to_bmp_bytes(),
    2,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_quality_bmp_bytes_rect_keyed(
    "bmp-quality-sprite",
    next_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    4,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_quality_png_bytes_keyed(
    "png-quality",
    must_renderer_test_png_bytes(next_icon),
    4,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_quality_png_bytes_rect_keyed(
    "png-quality-sprite",
    must_renderer_test_png_bytes(next_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_quality_rgba_bytes_keyed(
    "rgba-quality",
    Bytes::from_array([0]),
    2,
    2,
    4,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_quality_rgba_bytes_rect_keyed(
    "rgba-quality-sprite",
    Bytes::from_array([0]),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6,
    2,
    2,
    1,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_sampled_bmp_bytes_keyed(
    "bmp-transform",
    next_icon.to_bmp_bytes(),
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_sampled_bmp_bytes_rect_keyed(
    "bmp-transform-sprite",
    next_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_sampled_png_bytes_keyed(
    "png-transform",
    must_renderer_test_png_bytes(next_icon),
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_sampled_png_bytes_rect_keyed(
    "png-transform-sprite",
    must_renderer_test_png_bytes(next_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_sampled_rgba_bytes_keyed(
    "rgba-transform",
    Bytes::from_array([0]),
    2,
    2,
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_sampled_rgba_bytes_rect_keyed(
    "rgba-transform-sprite",
    Bytes::from_array([0]),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6.0,
    2.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_transformed_quality_bmp_bytes_keyed(
    "bmp-transform-quality",
    next_icon.to_bmp_bytes(),
    0.0,
    3.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_quality_bmp_bytes_rect_keyed(
    "bmp-transform-quality-sprite",
    next_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    2.0,
    3.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_quality_png_bytes_keyed(
    "png-transform-quality",
    must_renderer_test_png_bytes(next_icon),
    4.0,
    3.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_quality_png_bytes_rect_keyed(
    "png-transform-quality-sprite",
    must_renderer_test_png_bytes(next_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6.0,
    3.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_quality_rgba_bytes_keyed(
    "rgba-transform-quality",
    Bytes::from_array([0]),
    2,
    2,
    0.0,
    4.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_transformed_quality_rgba_bytes_rect_keyed(
    "rgba-transform-quality-sprite",
    Bytes::from_array([0]),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    2.0,
    4.0,
    2.0,
    1.0,
    paint,
    @graphics.ImageQuality::Fast,
  )
  .draw_sampled_bmp_bytes_rect_keyed(
    "bmp-sampled-sprite",
    next_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    4,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_sampled_png_bytes_rect_keyed(
    "png-sampled-sprite",
    must_renderer_test_png_bytes(next_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_sampled_rgba_bytes_rect_keyed(
    "rgba-sampled-sprite",
    Bytes::from_array([0]),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6,
    2,
    2,
    1,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_bmp_bytes_rect_keyed(
    "bmp-sprite",
    next_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    6,
    2,
    paint,
  )
  .draw_png_bytes_rect_keyed(
    "png-sprite",
    must_renderer_test_png_bytes(next_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    7,
    2,
    paint,
  )
  .draw_tiled_bmp_bytes_rect_keyed(
    "bmp-pattern",
    next_icon.to_bmp_bytes(),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    0,
    3,
    2,
    1,
    paint,
  )
  .draw_tiled_png_bytes_rect_keyed(
    "png-pattern",
    must_renderer_test_png_bytes(next_icon),
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    2,
    3,
    2,
    1,
    paint,
  )
  .draw_tiled_rgba_bytes_rect_keyed(
    "rgba-pattern",
    Bytes::from_array([0]),
    2,
    2,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    4,
    3,
    2,
    1,
    paint,
  )
  .draw_nine_patch_bmp_bytes_keyed(
    "bmp-panel",
    next_icon.to_bmp_bytes(),
    0,
    4,
    2,
    2,
    insets,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_nine_patch_png_bytes_keyed(
    "png-panel",
    must_renderer_test_png_bytes(next_icon),
    2,
    4,
    2,
    2,
    insets,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_nine_patch_rgba_bytes_keyed(
    "rgba-panel",
    Bytes::from_array([0]),
    2,
    2,
    4,
    4,
    2,
    2,
    insets,
    paint,
    @graphics.ImageSampling::Nearest,
  )
  .draw_pixmap_rect_keyed(
    "sprite",
    next_icon,
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
    4,
    1,
    paint,
  )
  .draw_text_face_keyed("font", face, "A", 1.0, 1.0, config, paint)
  .draw_font_bytes_atlas_keyed(
    "font-bytes", b"not a font", "font-bytes-label", "A", 2.5, 1.0, config, paint,
  )
  .draw_font_bytes_fallback_keyed(
    [
      FontBytesFallbackSource::new("primary", b"not a font"),
      FontBytesFallbackSource::new("fallback", b"also not a font"),
    ],
    "fallback-label",
    "AB",
    3.5,
    1.0,
    config,
    paint,
  )
  .draw_font_bytes_fallback_atlas_keyed(
    [
      FontBytesFallbackSource::new("atlas-primary", b"not a font"),
      FontBytesFallbackSource::new("atlas-fallback", b"also not a font"),
    ],
    "fallback-atlas-label",
    "AB",
    4.0,
    1.0,
    config,
    paint,
  )
  .draw_loaded_font_keyed(
    "loader-font", "loader-label", "A", 2.0, 1.0, config, paint,
  )
  .draw_loaded_font_fallback_keyed(
    ["loader-primary", "loader-fallback"],
    "loader-fallback-label",
    "AB",
    2.25,
    1.0,
    config,
    paint,
  )
  .draw_loaded_font_fallback_atlas_keyed(
    ["loader-atlas-primary", "loader-atlas-fallback"],
    "loader-fallback-atlas-label",
    "AB",
    2.75,
    1.0,
    config,
    paint,
  )
  .draw_loaded_font_atlas_keyed(
    "atlas-font", "atlas-label", "A", 3.0, 1.0, config, paint,
  )
}

///|
test "RenderPipeline diff retains keyed resource commands" {
  let previous_icon = @graphics.Pixmap::new(2, 2)
  let next_icon = @graphics.Pixmap::new(4, 4)
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  let insets = @graphics.NinePatchInsets::new(left=1, top=1, right=1, bottom=1)
  let previous = retained_keyed_resource_previous_pipeline(
    previous_icon, face, config, paint, insets,
  )
  let next = retained_keyed_resource_next_pipeline(
    next_icon, face, config, paint, insets,
  )

  let retained = RenderPipeline::diff(previous, next, 8, 8)
  assert_eq(retained.get_retained_command_count(), 46)
  assert_eq(retained.get_changed_command_count(), 0)
  assert_true(!retained.has_changes())
  assert_true(!retained.has_dirty())

  let moved = RenderPipeline::diff(
    RenderPipeline::new().draw_pixmap_keyed("icon", previous_icon, 1, 1, paint),
    RenderPipeline::new().draw_pixmap_keyed("icon", next_icon, 2, 1, paint),
    8,
    8,
  )
  assert_eq(moved.get_retained_command_count(), 0)
  assert_eq(moved.get_changed_command_count(), 1)
  assert_true(moved.has_dirty())
  assert_true(
    moved.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=1, width=5, height=4)),
  )
}
