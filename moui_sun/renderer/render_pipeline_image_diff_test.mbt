///|
test "RenderPipeline diff retains keyed point image commands by identity" {
  let previous_icon = @graphics.Pixmap::new(2, 2)
  previous_icon.set_pixel(0, 0, @graphics.Color::red())
  let next_icon = @graphics.Pixmap::new(2, 2)
  next_icon.set_pixel(0, 0, @graphics.Color::blue())
  let source = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)
  let paint = @graphics.Paint::new()
  let previous = RenderPipeline::new()
    .draw_pixmap_keyed("icon", previous_icon, 0, 0, paint)
    .draw_bmp_bytes_keyed("bmp", previous_icon.to_bmp_bytes(), 1, 0, paint)
    .draw_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(previous_icon),
      2,
      0,
      paint,
    )
    .draw_rgba_bytes_keyed(
      "rgba",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      3,
      0,
      paint,
    )
    .draw_bmp_bytes_rect_keyed(
      "bmp-rect",
      previous_icon.to_bmp_bytes(),
      source,
      4,
      0,
      paint,
    )
    .draw_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(previous_icon),
      source,
      5,
      0,
      paint,
    )
    .draw_rgba_bytes_rect_keyed(
      "rgba-rect",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      source,
      6,
      0,
      paint,
    )
  let next = RenderPipeline::new()
    .draw_pixmap_keyed("icon", next_icon, 0, 0, paint)
    .draw_bmp_bytes_keyed("bmp", next_icon.to_bmp_bytes(), 1, 0, paint)
    .draw_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(next_icon),
      2,
      0,
      paint,
    )
    .draw_rgba_bytes_keyed("rgba", next_icon.to_rgba_bytes(), 2, 2, 3, 0, paint)
    .draw_bmp_bytes_rect_keyed(
      "bmp-rect",
      next_icon.to_bmp_bytes(),
      source,
      4,
      0,
      paint,
    )
    .draw_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(next_icon),
      source,
      5,
      0,
      paint,
    )
    .draw_rgba_bytes_rect_keyed(
      "rgba-rect",
      next_icon.to_rgba_bytes(),
      2,
      2,
      source,
      6,
      0,
      paint,
    )

  let diff = RenderPipeline::diff(previous, next, 8, 4)
  assert_eq(diff.get_retained_command_count(), 7)
  assert_eq(diff.get_changed_command_count(), 0)
  assert_true(!diff.has_changes())
  assert_true(!diff.has_dirty())
}

///|
test "RenderPipeline diff uses canvas dirty fallback for placeholder full byte images" {
  let paint = @graphics.Paint::new()
  let previous = RenderPipeline::new()
    .draw_bmp_bytes_keyed("bmp-full", Bytes::from_array([66, 77]), 1, 1, paint)
    .draw_png_bytes_keyed("png-full", Bytes::from_array([137, 80]), 2, 1, paint)
  let next = RenderPipeline::new()
    .draw_bmp_bytes_keyed("bmp-full", Bytes::from_array([66, 77]), 2, 1, paint)
    .draw_png_bytes_keyed("png-full", Bytes::from_array([137, 80]), 3, 1, paint)

  let diff = RenderPipeline::diff(previous, next, 5, 4)
  assert_eq(diff.get_retained_command_count(), 0)
  assert_eq(diff.get_changed_command_count(), 2)
  assert_true(diff.has_dirty())
  assert_true(
    diff.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=5, height=4)),
  )
  let present_plan = diff.get_present_plan(5, 4, 4)
  assert_eq(present_plan.get_rect_count(), 1)
  assert_eq(present_plan.get_present_pixel_count(), 20)
}

///|
test "RenderPipeline diff retains keyed sampled image commands by identity" {
  let previous_icon = @graphics.Pixmap::new(2, 2)
  previous_icon.set_pixel(0, 0, @graphics.Color::red())
  let next_icon = @graphics.Pixmap::new(2, 2)
  next_icon.set_pixel(0, 0, @graphics.Color::blue())
  let source = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)
  let paint = @graphics.Paint::new()
  let previous = RenderPipeline::new()
    .draw_sampled_bmp_bytes_keyed(
      "bmp",
      previous_icon.to_bmp_bytes(),
      0,
      0,
      3,
      2,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_sampled_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(previous_icon),
      3,
      0,
      3,
      2,
      paint,
      @graphics.ImageSampling::Bilinear,
    )
    .draw_sampled_rgba_bytes_keyed(
      "rgba",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      0,
      2,
      3,
      2,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_sampled_bmp_bytes_rect_keyed(
      "bmp-rect",
      previous_icon.to_bmp_bytes(),
      source,
      3,
      2,
      2,
      2,
      paint,
      @graphics.ImageSampling::Bilinear,
    )
    .draw_sampled_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(previous_icon),
      source,
      5,
      2,
      2,
      2,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_sampled_rgba_bytes_rect_keyed(
      "rgba-rect",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      source,
      0,
      4,
      2,
      2,
      paint,
      @graphics.ImageSampling::Bilinear,
    )
  let next = RenderPipeline::new()
    .draw_sampled_bmp_bytes_keyed(
      "bmp",
      next_icon.to_bmp_bytes(),
      0,
      0,
      3,
      2,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_sampled_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(next_icon),
      3,
      0,
      3,
      2,
      paint,
      @graphics.ImageSampling::Bilinear,
    )
    .draw_sampled_rgba_bytes_keyed(
      "rgba",
      next_icon.to_rgba_bytes(),
      2,
      2,
      0,
      2,
      3,
      2,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_sampled_bmp_bytes_rect_keyed(
      "bmp-rect",
      next_icon.to_bmp_bytes(),
      source,
      3,
      2,
      2,
      2,
      paint,
      @graphics.ImageSampling::Bilinear,
    )
    .draw_sampled_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(next_icon),
      source,
      5,
      2,
      2,
      2,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_sampled_rgba_bytes_rect_keyed(
      "rgba-rect",
      next_icon.to_rgba_bytes(),
      2,
      2,
      source,
      0,
      4,
      2,
      2,
      paint,
      @graphics.ImageSampling::Bilinear,
    )

  let retained = RenderPipeline::diff(previous, next, 8, 7)
  assert_eq(retained.get_retained_command_count(), 6)
  assert_eq(retained.get_changed_command_count(), 0)
  assert_true(!retained.has_changes())
  assert_true(!retained.has_dirty())

  let resampled = RenderPipeline::diff(
    RenderPipeline::new().draw_sampled_bmp_bytes_keyed(
      "bmp",
      previous_icon.to_bmp_bytes(),
      0,
      0,
      3,
      2,
      paint,
      @graphics.ImageSampling::Nearest,
    ),
    RenderPipeline::new().draw_sampled_bmp_bytes_keyed(
      "bmp",
      next_icon.to_bmp_bytes(),
      0,
      0,
      3,
      2,
      paint,
      @graphics.ImageSampling::Bilinear,
    ),
    8,
    5,
  )
  assert_eq(resampled.get_retained_command_count(), 0)
  assert_eq(resampled.get_changed_command_count(), 1)
  assert_true(resampled.has_dirty())
}

///|
test "RenderPipeline diff retains keyed quality image commands by identity" {
  let previous_icon = @graphics.Pixmap::new(2, 2)
  previous_icon.set_pixel(0, 0, @graphics.Color::red())
  let next_icon = @graphics.Pixmap::new(2, 2)
  next_icon.set_pixel(0, 0, @graphics.Color::blue())
  let source = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)
  let paint = @graphics.Paint::new()
  let previous = RenderPipeline::new()
    .draw_quality_bmp_bytes_keyed(
      "bmp",
      previous_icon.to_bmp_bytes(),
      0,
      0,
      3,
      2,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_quality_bmp_bytes_rect_keyed(
      "bmp-rect",
      previous_icon.to_bmp_bytes(),
      source,
      0,
      2,
      2,
      2,
      paint,
      @graphics.ImageQuality::Balanced,
    )
    .draw_quality_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(previous_icon),
      3,
      0,
      3,
      2,
      paint,
      @graphics.ImageQuality::High,
    )
    .draw_quality_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(previous_icon),
      source,
      2,
      2,
      2,
      2,
      paint,
      @graphics.ImageQuality::Balanced,
    )
    .draw_quality_rgba_bytes_keyed(
      "rgba",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      6,
      0,
      2,
      2,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_quality_rgba_bytes_rect_keyed(
      "rgba-rect",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      source,
      4,
      2,
      2,
      2,
      paint,
      @graphics.ImageQuality::High,
    )
  let next = RenderPipeline::new()
    .draw_quality_bmp_bytes_keyed(
      "bmp",
      next_icon.to_bmp_bytes(),
      0,
      0,
      3,
      2,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_quality_bmp_bytes_rect_keyed(
      "bmp-rect",
      next_icon.to_bmp_bytes(),
      source,
      0,
      2,
      2,
      2,
      paint,
      @graphics.ImageQuality::Balanced,
    )
    .draw_quality_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(next_icon),
      3,
      0,
      3,
      2,
      paint,
      @graphics.ImageQuality::High,
    )
    .draw_quality_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(next_icon),
      source,
      2,
      2,
      2,
      2,
      paint,
      @graphics.ImageQuality::Balanced,
    )
    .draw_quality_rgba_bytes_keyed(
      "rgba",
      next_icon.to_rgba_bytes(),
      2,
      2,
      6,
      0,
      2,
      2,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_quality_rgba_bytes_rect_keyed(
      "rgba-rect",
      next_icon.to_rgba_bytes(),
      2,
      2,
      source,
      4,
      2,
      2,
      2,
      paint,
      @graphics.ImageQuality::High,
    )

  let retained = RenderPipeline::diff(previous, next, 8, 5)
  assert_eq(retained.get_retained_command_count(), 6)
  assert_eq(retained.get_changed_command_count(), 0)
  assert_true(!retained.has_changes())
  assert_true(!retained.has_dirty())

  let quality_changed = RenderPipeline::diff(
    RenderPipeline::new().draw_quality_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(previous_icon),
      source,
      2,
      2,
      2,
      2,
      paint,
      @graphics.ImageQuality::Balanced,
    ),
    RenderPipeline::new().draw_quality_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(next_icon),
      source,
      2,
      2,
      2,
      2,
      paint,
      @graphics.ImageQuality::High,
    ),
    8,
    5,
  )
  assert_eq(quality_changed.get_retained_command_count(), 0)
  assert_eq(quality_changed.get_changed_command_count(), 1)
  assert_true(quality_changed.has_dirty())
}

///|
test "RenderPipeline diff retains keyed transformed sampled image commands by identity" {
  let previous_icon = @graphics.Pixmap::new(2, 2)
  previous_icon.set_pixel(0, 0, @graphics.Color::red())
  let next_icon = @graphics.Pixmap::new(2, 2)
  next_icon.set_pixel(0, 0, @graphics.Color::blue())
  let source = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)
  let paint = @graphics.Paint::new()
  let previous = RenderPipeline::new()
    .draw_transformed_sampled_bmp_bytes_keyed(
      "bmp",
      previous_icon.to_bmp_bytes(),
      0.0,
      0.0,
      2.5,
      2.0,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_transformed_sampled_bmp_bytes_rect_keyed(
      "bmp-rect",
      previous_icon.to_bmp_bytes(),
      source,
      0.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageSampling::Bilinear,
    )
    .draw_transformed_sampled_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(previous_icon),
      2.5,
      0.0,
      2.5,
      2.0,
      paint,
      @graphics.ImageSampling::Bicubic,
    )
    .draw_transformed_sampled_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(previous_icon),
      source,
      2.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_transformed_sampled_rgba_bytes_keyed(
      "rgba",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      5.0,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageSampling::Bilinear,
    )
    .draw_transformed_sampled_rgba_bytes_rect_keyed(
      "rgba-rect",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      source,
      4.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageSampling::Bicubic,
    )
  let next = RenderPipeline::new()
    .draw_transformed_sampled_bmp_bytes_keyed(
      "bmp",
      next_icon.to_bmp_bytes(),
      0.0,
      0.0,
      2.5,
      2.0,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_transformed_sampled_bmp_bytes_rect_keyed(
      "bmp-rect",
      next_icon.to_bmp_bytes(),
      source,
      0.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageSampling::Bilinear,
    )
    .draw_transformed_sampled_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(next_icon),
      2.5,
      0.0,
      2.5,
      2.0,
      paint,
      @graphics.ImageSampling::Bicubic,
    )
    .draw_transformed_sampled_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(next_icon),
      source,
      2.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_transformed_sampled_rgba_bytes_keyed(
      "rgba",
      next_icon.to_rgba_bytes(),
      2,
      2,
      5.0,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageSampling::Bilinear,
    )
    .draw_transformed_sampled_rgba_bytes_rect_keyed(
      "rgba-rect",
      next_icon.to_rgba_bytes(),
      2,
      2,
      source,
      4.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageSampling::Bicubic,
    )

  let retained = RenderPipeline::diff(previous, next, 8, 5)
  assert_eq(retained.get_retained_command_count(), 6)
  assert_eq(retained.get_changed_command_count(), 0)
  assert_true(!retained.has_changes())
  assert_true(!retained.has_dirty())

  let sampling_changed = RenderPipeline::diff(
    RenderPipeline::new().draw_transformed_sampled_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(previous_icon),
      source,
      2.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageSampling::Nearest,
    ),
    RenderPipeline::new().draw_transformed_sampled_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(next_icon),
      source,
      2.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageSampling::Bilinear,
    ),
    8,
    5,
  )
  assert_eq(sampling_changed.get_retained_command_count(), 0)
  assert_eq(sampling_changed.get_changed_command_count(), 1)
  assert_true(sampling_changed.has_dirty())
}

///|
test "RenderPipeline diff retains keyed transformed quality image commands by identity" {
  let previous_icon = @graphics.Pixmap::new(2, 2)
  previous_icon.set_pixel(0, 0, @graphics.Color::red())
  let next_icon = @graphics.Pixmap::new(2, 2)
  next_icon.set_pixel(0, 0, @graphics.Color::blue())
  let source = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)
  let changed_source = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let paint = @graphics.Paint::new()
  let previous = RenderPipeline::new()
    .draw_transformed_quality_bmp_bytes_keyed(
      "bmp",
      previous_icon.to_bmp_bytes(),
      0.0,
      0.0,
      2.5,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_bmp_bytes_rect_keyed(
      "bmp-rect",
      previous_icon.to_bmp_bytes(),
      source,
      0.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Balanced,
    )
    .draw_transformed_quality_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(previous_icon),
      0.0,
      0.0,
      2.5,
      2.0,
      paint,
      @graphics.ImageQuality::Balanced,
    )
    .draw_transformed_quality_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(previous_icon),
      source,
      2.5,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::High,
    )
    .draw_transformed_quality_rgba_bytes_keyed(
      "rgba",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      5.0,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_rect_keyed(
      "rgba-rect",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      source,
      4.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Balanced,
    )
  let next = RenderPipeline::new()
    .draw_transformed_quality_bmp_bytes_keyed(
      "bmp",
      next_icon.to_bmp_bytes(),
      0.0,
      0.0,
      2.5,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_bmp_bytes_rect_keyed(
      "bmp-rect",
      next_icon.to_bmp_bytes(),
      source,
      0.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Balanced,
    )
    .draw_transformed_quality_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(next_icon),
      0.0,
      0.0,
      2.5,
      2.0,
      paint,
      @graphics.ImageQuality::Balanced,
    )
    .draw_transformed_quality_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(next_icon),
      source,
      2.5,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::High,
    )
    .draw_transformed_quality_rgba_bytes_keyed(
      "rgba",
      next_icon.to_rgba_bytes(),
      2,
      2,
      5.0,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_rect_keyed(
      "rgba-rect",
      next_icon.to_rgba_bytes(),
      2,
      2,
      source,
      4.0,
      2.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Balanced,
    )

  let retained = RenderPipeline::diff(previous, next, 8, 5)
  assert_eq(retained.get_retained_command_count(), 6)
  assert_eq(retained.get_changed_command_count(), 0)
  assert_true(!retained.has_changes())
  assert_true(!retained.has_dirty())

  let quality_changed = RenderPipeline::diff(
    RenderPipeline::new().draw_transformed_quality_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(previous_icon),
      source,
      2.5,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Balanced,
    ),
    RenderPipeline::new().draw_transformed_quality_png_bytes_rect_keyed(
      "png-rect",
      must_renderer_test_png_bytes(next_icon),
      source,
      2.5,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::High,
    ),
    6,
    3,
  )
  assert_eq(quality_changed.get_retained_command_count(), 0)
  assert_eq(quality_changed.get_changed_command_count(), 1)
  assert_true(quality_changed.has_dirty())
  assert_true(
    quality_changed.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=3, height=2)),
  )
  let quality_changed_present = quality_changed.get_present_plan(6, 3, 4)
  assert_true(!quality_changed_present.uses_bounds_fallback())
  assert_eq(quality_changed_present.get_rect_count(), 1)
  assert_eq(quality_changed_present.get_present_pixel_count(), 6)

  let png_full_quality_changed = RenderPipeline::diff(
    RenderPipeline::new().draw_transformed_quality_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(previous_icon),
      1.0,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Balanced,
    ),
    RenderPipeline::new().draw_transformed_quality_png_bytes_keyed(
      "png",
      must_renderer_test_png_bytes(next_icon),
      1.0,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::High,
    ),
    6,
    3,
  )
  assert_eq(png_full_quality_changed.get_retained_command_count(), 0)
  assert_eq(png_full_quality_changed.get_changed_command_count(), 1)
  assert_true(
    png_full_quality_changed.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=2)),
  )
  let png_full_quality_present = png_full_quality_changed.get_present_plan(
    6, 3, 4,
  )
  assert_true(!png_full_quality_present.uses_bounds_fallback())
  assert_eq(png_full_quality_present.get_rect_count(), 1)
  assert_eq(png_full_quality_present.get_present_pixel_count(), 4)

  let bmp_quality_changed = RenderPipeline::diff(
    RenderPipeline::new().draw_transformed_quality_bmp_bytes_keyed(
      "bmp",
      previous_icon.to_bmp_bytes(),
      0.0,
      0.0,
      2.5,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    ),
    RenderPipeline::new().draw_transformed_quality_bmp_bytes_keyed(
      "bmp",
      next_icon.to_bmp_bytes(),
      0.0,
      0.0,
      2.5,
      2.0,
      paint,
      @graphics.ImageQuality::High,
    ),
    6,
    3,
  )
  assert_eq(bmp_quality_changed.get_retained_command_count(), 0)
  assert_eq(bmp_quality_changed.get_changed_command_count(), 1)
  assert_true(bmp_quality_changed.has_dirty())
  assert_true(
    bmp_quality_changed.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=3, height=2)),
  )
  let bmp_quality_present = bmp_quality_changed.get_present_plan(6, 3, 4)
  assert_true(!bmp_quality_present.uses_bounds_fallback())
  assert_eq(bmp_quality_present.get_rect_count(), 1)
  assert_eq(bmp_quality_present.get_present_pixel_count(), 6)

  let bmp_rect_source_changed = RenderPipeline::diff(
    RenderPipeline::new().draw_transformed_quality_bmp_bytes_rect_keyed(
      "bmp-rect",
      previous_icon.to_bmp_bytes(),
      source,
      0.0,
      1.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Balanced,
    ),
    RenderPipeline::new().draw_transformed_quality_bmp_bytes_rect_keyed(
      "bmp-rect",
      next_icon.to_bmp_bytes(),
      changed_source,
      0.0,
      1.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Balanced,
    ),
    6,
    4,
  )
  assert_eq(bmp_rect_source_changed.get_retained_command_count(), 0)
  assert_eq(bmp_rect_source_changed.get_changed_command_count(), 1)
  assert_true(
    bmp_rect_source_changed.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=1, width=2, height=2)),
  )
  let bmp_rect_source_present = bmp_rect_source_changed.get_present_plan(
    6, 4, 4,
  )
  assert_true(!bmp_rect_source_present.uses_bounds_fallback())
  assert_eq(bmp_rect_source_present.get_rect_count(), 1)
  assert_eq(bmp_rect_source_present.get_present_pixel_count(), 4)

  let rgba_dimensions_changed = RenderPipeline::diff(
    RenderPipeline::new().draw_transformed_quality_rgba_bytes_keyed(
      "rgba",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      2.0,
      1.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    ),
    RenderPipeline::new().draw_transformed_quality_rgba_bytes_keyed(
      "rgba",
      next_icon.to_rgba_bytes(),
      3,
      2,
      2.0,
      1.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    ),
    6,
    4,
  )
  assert_eq(rgba_dimensions_changed.get_retained_command_count(), 0)
  assert_eq(rgba_dimensions_changed.get_changed_command_count(), 1)
  assert_true(
    rgba_dimensions_changed.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=1, width=2, height=2)),
  )
  let rgba_dimensions_present = rgba_dimensions_changed.get_present_plan(
    6, 4, 4,
  )
  assert_true(!rgba_dimensions_present.uses_bounds_fallback())
  assert_eq(rgba_dimensions_present.get_rect_count(), 1)
  assert_eq(rgba_dimensions_present.get_present_pixel_count(), 4)

  let rgba_quality_changed = RenderPipeline::diff(
    RenderPipeline::new().draw_transformed_quality_rgba_bytes_rect_keyed(
      "rgba-rect",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      source,
      2.5,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Balanced,
    ),
    RenderPipeline::new().draw_transformed_quality_rgba_bytes_rect_keyed(
      "rgba-rect",
      next_icon.to_rgba_bytes(),
      2,
      2,
      source,
      2.5,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::High,
    ),
    6,
    3,
  )
  assert_eq(rgba_quality_changed.get_retained_command_count(), 0)
  assert_eq(rgba_quality_changed.get_changed_command_count(), 1)
  assert_true(rgba_quality_changed.has_dirty())
  assert_true(
    rgba_quality_changed.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=3, height=2)),
  )
  let rgba_quality_present = rgba_quality_changed.get_present_plan(6, 3, 4)
  assert_true(!rgba_quality_present.uses_bounds_fallback())
  assert_eq(rgba_quality_present.get_rect_count(), 1)
  assert_eq(rgba_quality_present.get_present_pixel_count(), 6)

  let same_key_format_changed = RenderPipeline::diff(
    RenderPipeline::new().draw_transformed_quality_bmp_bytes_keyed(
      "shared-image",
      previous_icon.to_bmp_bytes(),
      0.0,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    ),
    RenderPipeline::new().draw_transformed_quality_png_bytes_keyed(
      "shared-image",
      must_renderer_test_png_bytes(next_icon),
      0.0,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    ),
    5,
    3,
  )
  assert_eq(same_key_format_changed.get_retained_command_count(), 0)
  assert_eq(same_key_format_changed.get_changed_command_count(), 1)
  assert_true(same_key_format_changed.has_dirty())
  assert_true(
    same_key_format_changed.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=2)),
  )

  let same_key_source_mode_changed = RenderPipeline::diff(
    RenderPipeline::new().draw_transformed_quality_png_bytes_keyed(
      "shared-png",
      must_renderer_test_png_bytes(previous_icon),
      2.0,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    ),
    RenderPipeline::new().draw_transformed_quality_png_bytes_rect_keyed(
      "shared-png",
      must_renderer_test_png_bytes(next_icon),
      source,
      2.0,
      0.0,
      2.0,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    ),
    5,
    3,
  )
  assert_eq(same_key_source_mode_changed.get_retained_command_count(), 0)
  assert_eq(same_key_source_mode_changed.get_changed_command_count(), 1)
  assert_true(same_key_source_mode_changed.has_dirty())
  assert_true(
    same_key_source_mode_changed.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=2, height=2)),
  )
}

///|
test "RenderPipeline diff retains keyed tiled image commands by identity" {
  let previous_icon = @graphics.Pixmap::new(2, 2)
  previous_icon.set_pixel(0, 0, @graphics.Color::red())
  let next_icon = @graphics.Pixmap::new(2, 2)
  next_icon.set_pixel(0, 0, @graphics.Color::blue())
  let source = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)
  let changed_source = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let paint = @graphics.Paint::new()
  let previous = RenderPipeline::new()
    .draw_tiled_bmp_bytes_rect_keyed(
      "bmp",
      previous_icon.to_bmp_bytes(),
      source,
      0,
      0,
      3,
      2,
      paint,
    )
    .draw_tiled_png_bytes_rect_keyed(
      "png",
      must_renderer_test_png_bytes(previous_icon),
      source,
      3,
      0,
      3,
      2,
      paint,
    )
    .draw_tiled_rgba_bytes_rect_keyed(
      "rgba",
      previous_icon.to_rgba_bytes(),
      2,
      2,
      source,
      0,
      2,
      3,
      2,
      paint,
    )
  let next = RenderPipeline::new()
    .draw_tiled_bmp_bytes_rect_keyed(
      "bmp",
      next_icon.to_bmp_bytes(),
      source,
      0,
      0,
      3,
      2,
      paint,
    )
    .draw_tiled_png_bytes_rect_keyed(
      "png",
      must_renderer_test_png_bytes(next_icon),
      source,
      3,
      0,
      3,
      2,
      paint,
    )
    .draw_tiled_rgba_bytes_rect_keyed(
      "rgba",
      next_icon.to_rgba_bytes(),
      2,
      2,
      source,
      0,
      2,
      3,
      2,
      paint,
    )

  let retained = RenderPipeline::diff(previous, next, 8, 5)
  assert_eq(retained.get_retained_command_count(), 3)
  assert_eq(retained.get_changed_command_count(), 0)
  assert_true(!retained.has_changes())
  assert_true(!retained.has_dirty())

  let source_changed = RenderPipeline::diff(
    RenderPipeline::new().draw_tiled_bmp_bytes_rect_keyed(
      "bmp",
      previous_icon.to_bmp_bytes(),
      source,
      0,
      0,
      3,
      2,
      paint,
    ),
    RenderPipeline::new().draw_tiled_bmp_bytes_rect_keyed(
      "bmp",
      next_icon.to_bmp_bytes(),
      changed_source,
      0,
      0,
      3,
      2,
      paint,
    ),
    8,
    5,
  )
  assert_eq(source_changed.get_retained_command_count(), 0)
  assert_eq(source_changed.get_changed_command_count(), 1)
  assert_true(source_changed.has_dirty())
}
