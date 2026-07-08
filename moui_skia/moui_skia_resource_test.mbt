///|
test "resource cache tracks lru budget and stats" {
  let cache : @moui_skia.ResourceCache[String, Int] = @moui_skia.ResourceCache::new(
    max_bytes=10L,
  )
  assert_true(cache.is_empty())
  assert_eq(cache.max_bytes(), 10L)
  assert_true(cache.insert("a", 1, byte_size=4L))
  assert_true(cache.insert("b", 2, byte_size=4L))
  assert_eq(cache.length(), 2)
  assert_eq(cache.byte_size(), 8L)
  assert_true(cache.get("a") == Some(1))
  assert_true(cache.insert("c", 3, byte_size=4L))
  assert_true(cache.contains("a"))
  assert_true(!cache.contains("b"))
  assert_true(cache.contains("c"))
  assert_eq(cache.byte_size(), 8L)
  let after_evict = cache.stats()
  assert_eq(after_evict.hits, 1)
  assert_eq(after_evict.misses, 0)
  assert_eq(after_evict.evictions, 1)
  assert_true(cache.get("missing") is None)
  assert_eq(cache.stats().misses, 1)
  assert_true(!cache.insert("huge", 9, byte_size=99L))
  assert_true(!cache.contains("huge"))
  assert_eq(cache.byte_size(), 8L)
  cache.set_max_bytes(4L)
  assert_eq(cache.length(), 1)
  assert_true(cache.byte_size() <= 4L)
  cache.clear()
  assert_true(cache.is_empty())
  assert_eq(cache.byte_size(), 0L)
}

///|
test "resource cache supports unbounded and zero-byte resources" {
  let cache : @moui_skia.ResourceCache[String, String] = @moui_skia.ResourceCache::new()
  assert_eq(cache.max_bytes(), 0L)
  assert_true(cache.insert("typeface:default", "font", byte_size=-8L))
  assert_eq(cache.byte_size(), 0L)
  assert_true(cache.peek("typeface:default") == Some("font"))
  assert_eq(cache.stats().hits, 0)
  assert_true(cache.get("typeface:default") == Some("font"))
  assert_eq(cache.stats().hits, 1)
  assert_true(cache.remove("typeface:default"))
  assert_true(!cache.remove("typeface:default"))
}

///|
test "renderer resource descriptors provide typed cache keys" {
  let image = @moui_skia.RendererResourceDescriptor::image(
    b"logo",
    byte_size=8L,
  )
  let shader = @moui_skia.RendererResourceDescriptor::shader(
    b"linear-gradient",
    byte_size=8L,
  )
  let path = @moui_skia.RendererResourceDescriptor::path(
    b"rounded-card",
    byte_size=8L,
  )
  assert_true(image.key == @moui_skia.RendererResourceKey::image(b"logo"))
  assert_true(!image.is_gpu_backed())
  assert_true(!image.key.kind.is_filter())
  assert_true(shader.is_cacheable())
  assert_true(path.with_byte_size(-9L).byte_size == 0L)

  let empty = @moui_skia.RendererResourceDescriptor::image(b"")
  assert_true(!empty.is_cacheable())
  assert_true(empty.key.is_empty())
  assert_true(!empty.uncacheable().is_cacheable())

  let text = @moui_skia.RendererResourceDescriptor::text_run(
    b"latin:hello",
    byte_size=4L,
  )
  assert_true(text.key.kind.is_text())
  let font = @moui_skia.RendererResourceDescriptor::font(
    b"Inter:16:400",
    byte_size=4L,
  )
  assert_true(font.key == @moui_skia.RendererResourceKey::font(b"Inter:16:400"))
  assert_true(font.key.kind.is_text())
  let filter = @moui_skia.RendererResourceDescriptor::filter(
    b"blur:2",
    byte_size=4L,
  )
  assert_true(filter.key.kind.is_filter())
  let color_filter = @moui_skia.RendererResourceDescriptor::color_filter(
    b"saturation:0.8",
    byte_size=4L,
  )
  assert_true(
    color_filter.key ==
    @moui_skia.RendererResourceKey::color_filter(b"saturation:0.8"),
  )
  assert_true(color_filter.key.kind.is_filter())
  let image_filter = @moui_skia.RendererResourceDescriptor::image_filter(
    b"blur:2",
    byte_size=4L,
  )
  assert_true(image_filter.key == filter.key)
  let mask_filter = @moui_skia.RendererResourceDescriptor::mask_filter(
    b"mask-blur:2",
    byte_size=4L,
  )
  assert_true(
    mask_filter.key ==
    @moui_skia.RendererResourceKey::mask_filter(b"mask-blur:2"),
  )
  assert_true(mask_filter.key.kind.is_filter())
  let gpu_surface = @moui_skia.RendererResourceDescriptor::gpu_surface(
    b"swapchain",
    byte_size=32L,
  )
  assert_true(gpu_surface.is_gpu_backed())
  assert_true(gpu_surface.key.kind.is_surface())
  let gpu_context = @moui_skia.RendererResourceDescriptor::gpu_context(
    b"metal:main",
    byte_size=0L,
  )
  assert_true(gpu_context.is_gpu_backed())
  assert_true(!gpu_context.key.kind.is_surface())
  assert_true(
    gpu_context.key ==
    @moui_skia.RendererResourceKey::gpu_context(b"metal:main"),
  )
  let scratch = @moui_skia.RendererResourceDescriptor::image(
    b"scratch",
    byte_size=2L,
  ).uncacheable()
  let plan = @moui_skia.RendererResourcePlan::new([
    image, image, gpu_surface, gpu_context, scratch,
  ])
  assert_eq(plan.length(), 4)
  assert_eq(plan.byte_size, 42L)
  assert_eq(plan.cacheable_count, 3)
  assert_eq(plan.uncacheable_count, 1)
  assert_eq(plan.gpu_backed_count, 2)
  assert_true(plan.has_cacheable_resources())
  assert_true(plan.has_uncacheable_resources())
  assert_true(plan.has_gpu_backed_resources())
  assert_true(plan.contains_key(image.key))
  assert_true(!plan.contains_key(shader.key))
  assert_true(plan.descriptor_for_key(gpu_surface.key) == Some(gpu_surface))
  assert_true(plan.descriptor_for_key(shader.key) is None)
  let cacheable_descriptors = plan.cacheable_descriptors()
  assert_eq(cacheable_descriptors.length(), 3)
  assert_true(cacheable_descriptors[0] == image)
  assert_true(cacheable_descriptors[1] == gpu_surface)
  assert_true(cacheable_descriptors[2] == gpu_context)
  let cacheable_plan = plan.cacheable_resource_plan()
  assert_eq(cacheable_plan.length(), 3)
  assert_eq(cacheable_plan.cacheable_count, 3)
  assert_eq(cacheable_plan.uncacheable_count, 0)
  assert_eq(cacheable_plan.gpu_backed_count, 2)
  assert_eq(cacheable_plan.byte_size, 40L)
  assert_true(cacheable_plan.contains_key(image.key))
  assert_true(cacheable_plan.contains_key(gpu_surface.key))
  assert_true(cacheable_plan.contains_key(gpu_context.key))
  assert_true(!cacheable_plan.contains_key(scratch.key))
  let uncacheable_descriptors = plan.uncacheable_descriptors()
  assert_eq(uncacheable_descriptors.length(), 1)
  assert_true(uncacheable_descriptors[0] == scratch)
  let uncacheable_plan = plan.uncacheable_resource_plan()
  assert_eq(uncacheable_plan.length(), 1)
  assert_eq(uncacheable_plan.cacheable_count, 0)
  assert_eq(uncacheable_plan.uncacheable_count, 1)
  assert_eq(uncacheable_plan.gpu_backed_count, 0)
  assert_eq(uncacheable_plan.byte_size, 2L)
  assert_true(!uncacheable_plan.has_cacheable_resources())
  assert_true(uncacheable_plan.has_uncacheable_resources())
  assert_true(uncacheable_plan.contains_key(scratch.key))
  assert_true(!uncacheable_plan.contains_key(image.key))
  let gpu_surface_descriptors = plan.descriptors_of_kind(GpuSurfaceResource)
  assert_eq(gpu_surface_descriptors.length(), 1)
  assert_true(gpu_surface_descriptors[0] == gpu_surface)
  let gpu_backed_descriptors = plan.gpu_backed_descriptors()
  assert_eq(gpu_backed_descriptors.length(), 2)
  assert_true(gpu_backed_descriptors[0] == gpu_surface)
  assert_true(gpu_backed_descriptors[1] == gpu_context)
  let gpu_backed_plan = plan.gpu_backed_resource_plan()
  assert_eq(gpu_backed_plan.length(), 2)
  assert_eq(gpu_backed_plan.gpu_backed_count, 2)
  assert_eq(gpu_backed_plan.cacheable_count, 2)
  assert_eq(gpu_backed_plan.byte_size, 32L)
  assert_true(gpu_backed_plan.contains_key(gpu_surface.key))
  assert_true(gpu_backed_plan.contains_key(gpu_context.key))
  assert_true(!gpu_backed_plan.contains_key(image.key))
  assert_eq(plan.count_kind(ImageResource), 2)
  assert_eq(plan.byte_size_for_kind(ImageResource), 10L)
  assert_eq(plan.byte_size_for_kind(ShaderResource), 0L)
  let empty_plan = @moui_skia.RendererResourcePlan::empty()
  assert_true(empty_plan.is_empty())
  assert_true(!empty_plan.has_cacheable_resources())
  assert_true(!empty_plan.has_uncacheable_resources())

  let cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new(max_bytes=16L)
  assert_true(cache.insert(image.key, image, byte_size=image.byte_size))
  assert_true(cache.insert(shader.key, shader, byte_size=shader.byte_size))
  assert_true(cache.get(image.key) == Some(image))
  assert_true(cache.insert(path.key, path, byte_size=path.byte_size))
  assert_true(cache.contains(image.key))
  assert_true(!cache.contains(shader.key))
  assert_true(cache.contains(path.key))
  assert_eq(cache.byte_size(), 16L)
  assert_eq(cache.stats().evictions, 1)
}

///|
test "resource cache inserts renderer resource plans" {
  let image = @moui_skia.RendererResourceDescriptor::image(
    b"atlas",
    byte_size=6L,
  )
  let path = @moui_skia.RendererResourceDescriptor::path(b"shape", byte_size=4L)
  let scratch = @moui_skia.RendererResourceDescriptor::shader(
    b"scratch",
    byte_size=2L,
  ).uncacheable()
  let plan = @moui_skia.RendererResourcePlan::new([image, path, scratch])
  let cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new(max_bytes=10L)
  assert_true(!cache.contains_resource_plan(plan))
  let cached_before = cache.cached_cacheable_resource_plan(plan)
  let missing_before = cache.missing_cacheable_resource_plan(plan)
  assert_true(cached_before.is_empty())
  assert_eq(missing_before.length(), 2)
  assert_eq(missing_before.byte_size, 10L)
  assert_true(missing_before.contains_key(image.key))
  assert_true(missing_before.contains_key(path.key))
  assert_true(!missing_before.contains_key(scratch.key))
  assert_eq(cache.insert_resource_plan(plan), 2)
  assert_eq(cache.length(), 2)
  assert_eq(cache.byte_size(), 10L)
  assert_true(cache.contains_resource_plan(plan))
  let cached_after = cache.cached_cacheable_resource_plan(plan)
  let missing_after = cache.missing_cacheable_resource_plan(plan)
  assert_eq(cached_after.length(), 2)
  assert_eq(cached_after.byte_size, 10L)
  assert_true(cached_after.contains_key(image.key))
  assert_true(cached_after.contains_key(path.key))
  assert_true(!cached_after.contains_key(scratch.key))
  assert_true(missing_after.is_empty())
  assert_true(cache.contains_resource_descriptor(image))
  assert_true(cache.contains(image.key))
  assert_true(cache.contains(path.key))
  assert_true(!cache.contains(scratch.key))
  assert_true(!cache.contains_resource_descriptor(scratch))
  assert_true(!cache.insert_resource_descriptor(scratch))
  let huge = @moui_skia.RendererResourceDescriptor::image(
    b"huge",
    byte_size=99L,
  )
  assert_true(!cache.insert_resource_descriptor(huge))
  assert_true(!cache.contains(huge.key))
  let huge_plan = @moui_skia.RendererResourcePlan::new([huge])
  assert_eq(cache.missing_cacheable_resource_plan(huge_plan).length(), 1)
  assert_true(!cache.contains_resource_plan(huge_plan))
}

///|
test "shader descriptors produce stable resource keys" {
  let color = @moui_skia.ShaderDescriptor::color(@moui_skia.Color::red())
  let same_color = @moui_skia.ShaderDescriptor::color(@moui_skia.Color::red())
  assert_true(color.is_valid())
  assert_true(color.resource_key() == same_color.resource_key())
  let color_descriptor = color.resource_descriptor()
  assert_true(color_descriptor.key.kind == ShaderResource)
  assert_true(color_descriptor.is_cacheable())
  assert_true(color_descriptor.byte_size > 0L)

  guard @moui_skia.ShaderDescriptor::linear_gradient(
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(12.0, 6.0),
      @moui_skia.Color::red(),
      @moui_skia.Color::blue(),
      tile_mode=Repeat,
    )
    is Some(linear) else {
    fail("finite linear gradient descriptor should be accepted")
  }
  assert_true(linear.is_valid())
  guard @moui_skia.ShaderDescriptor::linear_gradient(
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(12.0, 6.0),
      @moui_skia.Color::red(),
      @moui_skia.Color::blue(),
    )
    is Some(clamp_linear) else {
    fail("default linear gradient descriptor should be accepted")
  }
  assert_true(linear.resource_key() != clamp_linear.resource_key())
  assert_true(
    @moui_skia.ShaderDescriptor::linear_gradient(
      @moui_skia.Point::new(1.0, 1.0),
      @moui_skia.Point::new(1.0, 1.0),
      @moui_skia.Color::red(),
      @moui_skia.Color::blue(),
    )
    is None,
  )
  let invalid_linear = @moui_skia.LinearGradientShader(
    @moui_skia.Point::new(1.0, 1.0),
    @moui_skia.Point::new(1.0, 1.0),
    @moui_skia.Color::red(),
    @moui_skia.Color::blue(),
    Clamp,
  )
  assert_true(!invalid_linear.is_valid())
  assert_true(invalid_linear.resource_key().is_empty())
  assert_true(!invalid_linear.resource_descriptor().is_cacheable())

  guard @moui_skia.ShaderDescriptor::radial_gradient(
      @moui_skia.Point::new(4.0, 5.0),
      8.0,
      @moui_skia.Color::cyan(),
      @moui_skia.Color::magenta(),
    )
    is Some(radial) else {
    fail("positive radial gradient descriptor should be accepted")
  }
  assert_true(
    @moui_skia.ShaderDescriptor::radial_gradient(
      @moui_skia.Point::new(4.0, 5.0),
      0.0,
      @moui_skia.Color::cyan(),
      @moui_skia.Color::magenta(),
    )
    is None,
  )
  let invalid_radial = @moui_skia.RadialGradientShader(
    @moui_skia.Point::new(4.0, 5.0),
    0.0,
    @moui_skia.Color::cyan(),
    @moui_skia.Color::magenta(),
    Clamp,
  )
  assert_true(!invalid_radial.is_valid())
  assert_true(!invalid_radial.resource_descriptor().is_cacheable())

  let plan = @moui_skia.RendererResourcePlan::new([
    color.resource_descriptor(),
    linear.resource_descriptor(),
    radial.resource_descriptor(),
    same_color.resource_descriptor(),
  ])
  assert_eq(plan.length(), 3)
  assert_eq(plan.cacheable_count, 3)
  assert_eq(plan.uncacheable_count, 0)
}

///|
test "filter descriptors produce typed resource keys" {
  let matrix_values : Array[Float] = [
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
  ]
  guard @moui_skia.ColorFilterDescriptor::matrix(matrix_values) is Some(matrix) else {
    fail("20-value color matrix descriptor should be accepted")
  }
  assert_true(matrix.is_valid())
  guard @moui_skia.ColorFilterDescriptor::saturation(0.8) is Some(saturation) else {
    fail("finite saturation descriptor should be accepted")
  }
  assert_true(saturation.is_valid())
  guard @moui_skia.ColorFilterDescriptor::brightness(1.2) is Some(brightness) else {
    fail("finite brightness descriptor should be accepted")
  }
  guard @moui_skia.ColorFilterDescriptor::contrast(1.1) is Some(contrast) else {
    fail("finite contrast descriptor should be accepted")
  }
  assert_true(@moui_skia.ColorFilterDescriptor::matrix([1.0, 0.0]) is None)
  let not_finite : Float = 0.0 / 0.0
  let infinite : Float = 1.0 / 0.0
  assert_true(
    @moui_skia.ColorFilterDescriptor::matrix([
      not_finite, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
      0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
    ])
    is None,
  )
  assert_true(@moui_skia.ColorFilterDescriptor::saturation(not_finite) is None)
  assert_true(@moui_skia.ColorFilterDescriptor::brightness(infinite) is None)
  assert_true(@moui_skia.ColorFilterDescriptor::contrast(not_finite) is None)
  let invalid_matrix = @moui_skia.ColorMatrixFilter([
    not_finite, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
  ])
  assert_true(!invalid_matrix.is_valid())
  assert_true(invalid_matrix.resource_key().is_empty())
  assert_true(!invalid_matrix.resource_descriptor().is_cacheable())
  let invalid_saturation = @moui_skia.SaturationFilter(not_finite)
  assert_true(!invalid_saturation.is_valid())
  assert_true(!invalid_saturation.resource_descriptor().is_cacheable())
  assert_true(matrix.resource_key() != saturation.resource_key())
  assert_true(brightness.resource_key() != contrast.resource_key())

  guard @moui_skia.ImageFilterDescriptor::blur(2.0, 3.0) is Some(image_blur) else {
    fail("positive image blur descriptor should be accepted")
  }
  assert_true(image_blur.is_valid())
  guard @moui_skia.MaskFilterDescriptor::blur(2.0) is Some(mask_blur) else {
    fail("positive mask blur descriptor should be accepted")
  }
  assert_true(mask_blur.is_valid())
  assert_true(@moui_skia.ImageFilterDescriptor::blur(0.0, 3.0) is None)
  assert_true(@moui_skia.ImageFilterDescriptor::blur(infinite, 3.0) is None)
  assert_true(@moui_skia.MaskFilterDescriptor::blur(-1.0) is None)
  assert_true(@moui_skia.MaskFilterDescriptor::blur(not_finite) is None)
  let invalid_image_blur = @moui_skia.BlurImageFilter(infinite, 3.0)
  assert_true(!invalid_image_blur.is_valid())
  assert_true(!invalid_image_blur.resource_descriptor().is_cacheable())
  let invalid_mask_blur = @moui_skia.BlurMaskFilter(not_finite)
  assert_true(!invalid_mask_blur.is_valid())
  assert_true(!invalid_mask_blur.resource_descriptor().is_cacheable())

  let color_descriptor = saturation.resource_descriptor()
  let image_descriptor = image_blur.resource_descriptor()
  let mask_descriptor = mask_blur.resource_descriptor()
  assert_true(color_descriptor.key.kind == ColorFilterResource)
  assert_true(image_descriptor.key.kind == ImageFilterResource)
  assert_true(mask_descriptor.key.kind == MaskFilterResource)
  assert_true(color_descriptor.key.kind.is_filter())
  assert_true(image_descriptor.key.kind.is_filter())
  assert_true(mask_descriptor.key.kind.is_filter())

  let plan = @moui_skia.RendererResourcePlan::new([
    matrix.resource_descriptor(),
    color_descriptor,
    image_descriptor,
    mask_descriptor,
  ])
  assert_eq(plan.length(), 4)
  assert_eq(plan.cacheable_count, 4)
  assert_eq(plan.uncacheable_count, 0)
  assert_true(plan.byte_size > 0L)
}

///|
test "image descriptors produce stable resource keys" {
  assert_true(@moui_skia.ImageDescriptor::encoded(b"") is None)
  let empty_image = @moui_skia.EncodedImage(b"", Some(PNG), None)
  assert_true(empty_image.resource_key().is_empty())
  assert_true(!empty_image.resource_descriptor().is_cacheable())
  assert_eq(empty_image.resource_descriptor().byte_size, 0L)
  guard @moui_skia.ImageDescriptor::encoded(
      b"encoded-image-bytes",
      format=Some(PNG),
      dimensions=Some(@moui_skia.ISize::new(2, 3)),
    )
    is Some(image) else {
    fail("encoded image descriptor should be accepted")
  }
  guard @moui_skia.ImageDescriptor::encoded(
      b"encoded-image-bytes",
      format=Some(PNG),
      dimensions=Some(@moui_skia.ISize::new(2, 3)),
    )
    is Some(same_image) else {
    fail("same encoded image descriptor should be accepted")
  }
  guard @moui_skia.ImageDescriptor::encoded(
      b"encoded-image-bytes",
      format=Some(JPEG),
      dimensions=Some(@moui_skia.ISize::new(2, 3)),
    )
    is Some(other_format) else {
    fail("encoded image descriptor with another format should be accepted")
  }
  guard @moui_skia.ImageDescriptor::encoded(
      b"encoded-image-bytes",
      format=Some(PNG),
      dimensions=Some(@moui_skia.ISize::new(3, 2)),
    )
    is Some(other_dimensions) else {
    fail("encoded image descriptor with another size should be accepted")
  }
  guard @moui_skia.ImageDescriptor::encoded(
      b"encoded-image-bytes",
      dimensions=Some(@moui_skia.ISize::new(0, 3)),
    )
    is Some(unknown_dimensions) else {
    fail("encoded image descriptor should normalize empty dimensions")
  }
  assert_true(image.resource_key() == same_image.resource_key())
  assert_true(image.resource_key() != other_format.resource_key())
  assert_true(image.resource_key() != other_dimensions.resource_key())
  assert_true(unknown_dimensions.dimensions() is None)
  assert_eq(image.byte_size(), 19L)
  assert_eq(image.encoded_bytes(), b"encoded-image-bytes")
  let descriptor = image.resource_descriptor()
  assert_true(descriptor.key.kind == ImageResource)
  assert_true(descriptor.key == image.resource_key())
  assert_true(descriptor.is_cacheable())
  assert_eq(descriptor.byte_size, 19L)
  assert_eq(image.resource_descriptor(byte_size=64L).byte_size, 64L)
}
