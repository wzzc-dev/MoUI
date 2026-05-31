///|
test "color packs argb channels" {
  let color = @skia_mbt.Color::from_argb(0x80, 0x11, 0x22, 0x33)
  assert_eq(color.argb(), 0x80112233U)
  assert_eq(color.a(), 0x80)
  assert_eq(color.r(), 0x11)
  assert_eq(color.g(), 0x22)
  assert_eq(color.b(), 0x33)
}

///|
test "point and size expose finite and vector helpers" {
  let a = @skia_mbt.Point::new(3, 4)
  let b = @skia_mbt.Point::new(-2, 5)
  assert_true(a.is_finite())
  assert_true(!@skia_mbt.Point::new(1.0 / 0.0, 0).is_finite())
  assert_eq(a.length_squared(), 25.0)
  assert_eq(a.length(), 5.0)
  assert_eq(a.distance_to_origin_squared(), 25.0)
  assert_eq(a.dot(b), 14.0)
  assert_eq(a.cross(b), 23.0)
  assert_eq(a.distance_to_squared(b), 26.0)
  assert_eq(a.distance_to(b), @skia_mbt.Point::new(5, -1).length())
  assert_true(a.normalized() == Some(@skia_mbt.Point::new(0.6, 0.8)))
  assert_true(a.with_length(10) == Some(@skia_mbt.Point::new(6, 8)))
  assert_true(a.with_length(-1) is None)
  assert_true(@skia_mbt.Point::zero().normalized() is None)
  assert_true(a.rotate_cw() == @skia_mbt.Point::new(4, -3))
  assert_true(a.rotate_ccw() == @skia_mbt.Point::new(-4, 3))

  let size = @skia_mbt.Size::new(8, 13)
  assert_true(size.is_finite())
  assert_true(!@skia_mbt.Size::new(0.0 / 0.0, 1).is_finite())
}

///|
test "rect intersection and containment" {
  let outer = @skia_mbt.Rect::from_xywh(0, 0, 10, 10)
  let inner = @skia_mbt.Rect::from_xywh(2, 3, 4, 5)
  let overlap = @skia_mbt.Rect::from_xywh(8, 8, 5, 5)
  assert_true(outer.contains_rect(inner))
  assert_true(
    outer.intersect(overlap) == Some(@skia_mbt.Rect::new(8, 8, 10, 10)),
  )
}

///|
test "rect constructors and immutable offsets mirror skia helpers" {
  let point = @skia_mbt.Point::new(2, 3)
  let size = @skia_mbt.Size::new(4, 5)
  let rect = @skia_mbt.Rect::from_point_and_size(point, size)
  assert_true(rect == @skia_mbt.Rect::from_xywh(2, 3, 4, 5))
  assert_true(rect == @skia_mbt.Rect::from_ltrb(2, 3, 6, 8))
  assert_true(@skia_mbt.Rect::from_wh(4, 5) == @skia_mbt.Rect::from_size(size))
  assert_true(@skia_mbt.Rect::from_iwh(4, 5) == @skia_mbt.Rect::from_wh(4, 5))
  assert_true(
    @skia_mbt.Rect::from_isize(@skia_mbt.ISize::new(4, 5)) ==
    @skia_mbt.Rect::from_wh(4, 5),
  )
  assert_true(
    @skia_mbt.Rect::from_points([
      @skia_mbt.Point::new(5, 4),
      @skia_mbt.Point::new(1, 9),
      @skia_mbt.Point::new(3, -2),
    ]) ==
    Some(@skia_mbt.Rect::new(1, -2, 5, 9)),
  )
  assert_true(
    @skia_mbt.Rect::from_points_or_empty([]) == @skia_mbt.Rect::empty(),
  )
  assert_eq(rect.x(), 2.0)
  assert_eq(rect.y(), 3.0)
  assert_eq(rect.left(), 2.0)
  assert_eq(rect.top(), 3.0)
  assert_eq(rect.right(), 6.0)
  assert_eq(rect.bottom(), 8.0)
  assert_true(rect.intersects(@skia_mbt.Rect::from_xywh(5, 7, 3, 3)))
  assert_true(!rect.intersects(@skia_mbt.Rect::from_xywh(6, 8, 2, 2)))

  let irect = @skia_mbt.IRect::from_point_and_size(
    @skia_mbt.IPoint::new(2, 3),
    @skia_mbt.ISize::new(4, 5),
  )
  assert_true(irect == @skia_mbt.IRect::from_xywh(2, 3, 4, 5))
  assert_true(irect == @skia_mbt.IRect::from_ltrb(2, 3, 6, 8))
  assert_true(
    @skia_mbt.IRect::from_wh(4, 5) ==
    @skia_mbt.IRect::from_size(@skia_mbt.ISize::new(4, 5)),
  )
  assert_true(@skia_mbt.Rect::from_irect(irect) == rect)
  assert_eq(irect.x(), 2)
  assert_eq(irect.y(), 3)
  assert_eq(irect.left(), 2)
  assert_eq(irect.top(), 3)
  assert_eq(irect.right(), 6)
  assert_eq(irect.bottom(), 8)
  assert_eq(irect.width_64(), 4L)
  assert_eq(irect.height_64(), 5L)
  assert_true(!irect.is_empty_64())
  assert_true(irect.intersects(@skia_mbt.IRect::from_xywh(5, 7, 3, 3)))
  assert_true(!irect.intersects(@skia_mbt.IRect::from_xywh(6, 8, 2, 2)))

  assert_true(
    rect.with_offset(@skia_mbt.Point::new(10, -1)) ==
    @skia_mbt.Rect::from_xywh(12, 2, 4, 5),
  )
  assert_true(
    rect.with_offset_to(@skia_mbt.Point::new(10, -1)) ==
    @skia_mbt.Rect::from_xywh(10, -1, 4, 5),
  )
  assert_true(
    rect.with_inset(@skia_mbt.Size::new(1, 2)) ==
    @skia_mbt.Rect::new(3, 5, 5, 6),
  )
  assert_true(
    rect.with_outset(@skia_mbt.Size::new(1, 2)) ==
    @skia_mbt.Rect::new(1, 1, 7, 10),
  )
  assert_true(
    irect.with_offset(@skia_mbt.IPoint::new(10, -1)) ==
    @skia_mbt.IRect::from_xywh(12, 2, 4, 5),
  )
  assert_true(
    irect.with_offset_to(@skia_mbt.IPoint::new(10, -1)) ==
    @skia_mbt.IRect::from_xywh(10, -1, 4, 5),
  )
  assert_true(
    irect.with_inset(@skia_mbt.ISize::new(1, 2)) ==
    @skia_mbt.IRect::new(3, 5, 5, 6),
  )
  assert_true(
    irect.with_outset(@skia_mbt.ISize::new(1, 2)) ==
    @skia_mbt.IRect::new(1, 1, 7, 10),
  )
  assert_true(
    irect.with_adjustment(1, -2, 3, 4) == @skia_mbt.IRect::new(3, 1, 9, 12),
  )

  let wide = @skia_mbt.IRect::new(-2000000000, 0, 2000000000, 1)
  assert_eq(wide.width_64(), 4000000000L)
  assert_true(!wide.is_empty_64())
  assert_true(@skia_mbt.IRect::new(0, 2000000000, 1, -2000000000).is_empty_64())
}

///|
test "rect exposes skia-style sorted center finite and rounding helpers" {
  let unsorted = @skia_mbt.Rect::new(5, 4, 1, 2)
  assert_true(!unsorted.is_sorted())
  assert_true(unsorted.sorted().is_sorted())
  assert_true(unsorted.center() == @skia_mbt.Point::new(3, 3))
  assert_eq(unsorted.center_x(), 3.0)
  assert_eq(unsorted.center_y(), 3.0)
  assert_true(unsorted.is_finite())
  assert_true(!@skia_mbt.Rect::new(0, 0, 1.0 / 0.0, 1).is_finite())

  let fractional = @skia_mbt.Rect::new(1.2, -2.8, 5.7, 3.1)
  assert_true(fractional.round() == @skia_mbt.IRect::new(1, -3, 6, 3))
  assert_true(fractional.to_irect_round() == fractional.round())
  assert_true(fractional.round_in() == @skia_mbt.IRect::new(2, -2, 5, 3))
  assert_true(fractional.round_out() == @skia_mbt.IRect::new(1, -3, 6, 4))

  let unsorted_i = @skia_mbt.IRect::new(4, 5, 1, 2)
  assert_true(!unsorted_i.is_sorted())
  assert_true(unsorted_i.sorted().is_sorted())
}

///|
test "rect exposes corner points and quads" {
  let rect = @skia_mbt.Rect::from_xywh(1, 2, 3, 4)
  assert_true(rect.top_left() == @skia_mbt.Point::new(1, 2))
  assert_true(rect.tl() == rect.top_left())
  assert_true(rect.top_right() == @skia_mbt.Point::new(4, 2))
  assert_true(rect.tr() == rect.top_right())
  assert_true(rect.bottom_right() == @skia_mbt.Point::new(4, 6))
  assert_true(rect.br() == rect.bottom_right())
  assert_true(rect.bottom_left() == @skia_mbt.Point::new(1, 6))
  assert_true(rect.bl() == rect.bottom_left())
  assert_true(
    rect.to_quad() ==
    [
      @skia_mbt.Point::new(1, 2),
      @skia_mbt.Point::new(4, 2),
      @skia_mbt.Point::new(4, 6),
      @skia_mbt.Point::new(1, 6),
    ],
  )
  assert_true(
    rect.to_quad(direction=@skia_mbt.CCW) ==
    [
      @skia_mbt.Point::new(1, 2),
      @skia_mbt.Point::new(1, 6),
      @skia_mbt.Point::new(4, 6),
      @skia_mbt.Point::new(4, 2),
    ],
  )
}

///|
test "matrix maps point" {
  let point = @skia_mbt.Point::new(2, 3)
  let matrix = @skia_mbt.Matrix::scale_translate(2, 4, 10, 20)
  assert_true(matrix.map_point(point) == @skia_mbt.Point::new(14, 32))
  assert_true(matrix.is_scale_translate())
}

///|
test "surface descriptors model raster window and gpu contracts" {
  let size = @skia_mbt.ISize::new(32, 24)
  let raster = @skia_mbt.SurfaceDescriptor::raster_n32_premul(size)
  assert_true(raster.backend == @skia_mbt.Raster)
  assert_true(raster.image_info == @skia_mbt.ImageInfo::n32_premul(size))
  assert_true(raster.origin == @skia_mbt.TopLeft)
  assert_eq(raster.sample_count, 1)
  assert_eq(raster.stencil_bits, 0)
  assert_true(raster.budget == @skia_mbt.Unbudgeted)
  assert_true(raster.is_raster())
  assert_true(!raster.is_window())
  assert_true(!raster.is_gpu())
  assert_true(!raster.is_msaa())
  assert_true(!raster.is_budgeted())
  assert_eq(raster.width(), 32)
  assert_eq(raster.height(), 24)
  assert_true(raster.bounds() == @skia_mbt.IRect::from_wh(32, 24))
  assert_true(raster.resource_key().kind == @skia_mbt.SurfaceResource)
  assert_true(raster.resource_key() == raster.resource_key())
  let raster_resource = raster.resource_descriptor()
  assert_true(raster_resource.is_cacheable())
  assert_true(!raster_resource.is_gpu_backed())
  assert_eq(raster_resource.byte_size, 3072L)

  let window = @skia_mbt.SurfaceDescriptor::window_n32_premul(
    size,
    sample_count=4,
    stencil_bits=8,
  )
  assert_true(window.is_window())
  assert_true(window.is_msaa())
  assert_eq(window.sample_count, 4)
  assert_eq(window.stencil_bits, 8)
  assert_true(window.resource_key().kind == @skia_mbt.SurfaceResource)
  assert_true(window.resource_key() != raster.resource_key())

  let gpu = @skia_mbt.SurfaceDescriptor::gpu_n32_premul(
    size,
    origin=@skia_mbt.BottomLeft,
    sample_count=4,
    stencil_bits=8,
  )
  assert_true(gpu.is_gpu())
  assert_true(gpu.origin == @skia_mbt.BottomLeft)
  assert_true(gpu.is_budgeted())
  assert_true(
    gpu.with_budget(@skia_mbt.Unbudgeted).budget == @skia_mbt.Unbudgeted,
  )
  assert_true(
    gpu.with_dimensions(@skia_mbt.ISize::new(8, 6)).dimensions() ==
    @skia_mbt.ISize::new(8, 6),
  )
  assert_eq(gpu.with_sample_count(-2).sample_count, 1)
  assert_eq(gpu.with_stencil_bits(-2).stencil_bits, 0)
  let gpu_resource = gpu.resource_descriptor()
  assert_true(gpu_resource.key.kind == @skia_mbt.GpuSurfaceResource)
  assert_true(gpu_resource.is_gpu_backed())
  assert_eq(gpu_resource.byte_size, 12288L)

  let empty = @skia_mbt.SurfaceDescriptor::raster_n32_premul(
    @skia_mbt.ISize::empty(),
  )
  assert_true(empty.is_empty())
  assert_true(empty.resource_key().is_empty())
  assert_true(!empty.resource_descriptor().is_cacheable())
}

///|
test "surface target descriptors model present modes and frame pacing" {
  let raster = @skia_mbt.SurfaceTargetDescriptor::raster_n32_premul(
    @skia_mbt.ISize::new(8, 8),
  )
  assert_true(!raster.surface.is_presentable())
  assert_true(!raster.is_presentable())
  assert_true(!raster.needs_present())
  assert_true(raster.present_mode is None)
  assert_eq(raster.max_frames_in_flight, 1)
  assert_true(
    !raster.with_present_mode(@skia_mbt.ImmediatePresent).is_presentable(),
  )

  let window = @skia_mbt.SurfaceTargetDescriptor::window_n32_premul(
    @skia_mbt.ISize::new(32, 24),
    present_mode=@skia_mbt.MailboxPresent,
    max_frames_in_flight=3,
  )
  assert_true(window.surface.is_window())
  assert_true(window.surface.is_presentable())
  assert_true(window.is_presentable())
  assert_true(window.needs_present())
  assert_true(window.is_multibuffered())
  assert_true(window.present_mode == Some(@skia_mbt.MailboxPresent))
  assert_true(window.resource_key().kind == @skia_mbt.SurfaceResource)
  assert_true(window.resource_descriptor().is_cacheable())
  assert_eq(window.resource_descriptor().byte_size, 3072L)
  assert_true(
    window.with_present_mode(@skia_mbt.ImmediatePresent).present_mode ==
    Some(@skia_mbt.ImmediatePresent),
  )
  assert_true(
    window.with_present_mode(@skia_mbt.ImmediatePresent).resource_key() !=
    window.resource_key(),
  )
  match window.with_present_mode(@skia_mbt.ImmediatePresent).present_mode {
    None => fail("window target should retain an immediate present mode")
    Some(mode) => assert_true(mode.allows_tearing())
  }
  assert_true(window.without_present().present_mode is None)
  assert_eq(window.with_max_frames_in_flight(-2).max_frames_in_flight, 1)
  assert_true(
    window.with_dimensions(@skia_mbt.ISize::new(4, 2)).dimensions() ==
    @skia_mbt.ISize::new(4, 2),
  )

  let gpu = @skia_mbt.SurfaceTargetDescriptor::gpu_n32_premul(
    @skia_mbt.ISize::new(64, 48),
    origin=@skia_mbt.BottomLeft,
    present_mode=@skia_mbt.FifoPresent,
  )
  assert_true(gpu.surface.is_gpu())
  assert_true(gpu.surface.origin == @skia_mbt.BottomLeft)
  assert_true(gpu.present_mode == Some(@skia_mbt.FifoPresent))
  assert_true(gpu.resource_key().kind == @skia_mbt.GpuSurfaceResource)
  assert_true(gpu.resource_descriptor().is_gpu_backed())
  match gpu.present_mode {
    None => fail("gpu target should retain a fifo present mode")
    Some(mode) => assert_true(mode.prefers_vsync())
  }
  assert_true(gpu.bounds() == @skia_mbt.IRect::from_wh(64, 48))
}

///|
test "resource cache tracks lru budget and stats" {
  let cache : @skia_mbt.ResourceCache[String, Int] = @skia_mbt.ResourceCache::new(
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
  let cache : @skia_mbt.ResourceCache[String, String] = @skia_mbt.ResourceCache::new()
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
  let image = @skia_mbt.RendererResourceDescriptor::image(b"logo", byte_size=8L)
  let shader = @skia_mbt.RendererResourceDescriptor::shader(
    b"linear-gradient",
    byte_size=8L,
  )
  let path = @skia_mbt.RendererResourceDescriptor::path(
    b"rounded-card",
    byte_size=8L,
  )
  assert_true(image.key == @skia_mbt.RendererResourceKey::image(b"logo"))
  assert_true(!image.is_gpu_backed())
  assert_true(!image.key.kind.is_filter())
  assert_true(shader.is_cacheable())
  assert_true(path.with_byte_size(-9L).byte_size == 0L)

  let empty = @skia_mbt.RendererResourceDescriptor::image(b"")
  assert_true(!empty.is_cacheable())
  assert_true(empty.key.is_empty())
  assert_true(!empty.uncacheable().is_cacheable())

  let text = @skia_mbt.RendererResourceDescriptor::text_run(
    b"latin:hello",
    byte_size=4L,
  )
  assert_true(text.key.kind.is_text())
  let filter = @skia_mbt.RendererResourceDescriptor::filter(
    b"blur:2",
    byte_size=4L,
  )
  assert_true(filter.key.kind.is_filter())
  let gpu_surface = @skia_mbt.RendererResourceDescriptor::gpu_surface(
    b"swapchain",
    byte_size=32L,
  )
  assert_true(gpu_surface.is_gpu_backed())
  assert_true(gpu_surface.key.kind.is_surface())

  let cache : @skia_mbt.ResourceCache[
    @skia_mbt.RendererResourceKey,
    @skia_mbt.RendererResourceDescriptor,
  ] = @skia_mbt.ResourceCache::new(max_bytes=16L)
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
test "render pass descriptor clips clear and present boundaries" {
  let surface = @skia_mbt.SurfaceDescriptor::window_n32_premul(
    @skia_mbt.ISize::new(20, 10),
    sample_count=4,
    stencil_bits=8,
  )
  let pass = @skia_mbt.RenderPassDescriptor::clear(
    surface,
    @skia_mbt.Color::black(),
    bounds=Some(@skia_mbt.IRect::from_xywh(5, -5, 20, 20)),
    store_op=@skia_mbt.PresentPixels,
  )
  assert_true(pass.surface == surface)
  assert_true(pass.bounds == @skia_mbt.IRect::new(5, 0, 20, 10))
  assert_true(pass.load_op == @skia_mbt.ClearBeforeDraw)
  assert_true(pass.clear_color == Some(@skia_mbt.Color::black()))
  assert_true(pass.store_op == @skia_mbt.PresentPixels)
  assert_true(pass.needs_clear())
  assert_true(pass.needs_present())
  assert_true(pass.keeps_pixels())
  assert_true(pass.is_msaa())
  assert_true(pass.resource_descriptor().key.kind == @skia_mbt.SurfaceResource)
  assert_eq(pass.resource_descriptor().byte_size, 3200L)

  let load = @skia_mbt.RenderPassDescriptor::new(surface)
  assert_true(load.load_op == @skia_mbt.LoadExisting)
  assert_true(load.clear_color is None)
  assert_true(load.store_op == @skia_mbt.StorePixels)
  assert_true(load.bounds == surface.bounds())
  assert_true(
    load.with_store_op(@skia_mbt.DiscardPixels).store_op ==
    @skia_mbt.DiscardPixels,
  )
  assert_true(load.with_clear_color(@skia_mbt.Color::red()).needs_clear())
  assert_true(
    load.with_clear_color(@skia_mbt.Color::red()).without_clear().clear_color
    is None,
  )

  let outside = pass.with_bounds(@skia_mbt.IRect::from_xywh(99, 99, 4, 4))
  assert_true(outside.is_empty())
  assert_true(outside.bounds == @skia_mbt.IRect::empty())
}

///|
test "render pass descriptor derives present defaults from surface targets" {
  let raster_target = @skia_mbt.SurfaceTargetDescriptor::raster_n32_premul(
    @skia_mbt.ISize::new(16, 16),
  )
  let raster_pass = @skia_mbt.RenderPassDescriptor::for_target(raster_target)
  assert_true(!raster_pass.needs_present())
  assert_true(raster_pass.keeps_pixels())
  assert_true(raster_pass.store_op == @skia_mbt.StorePixels)

  let window_target = @skia_mbt.SurfaceTargetDescriptor::window_n32_premul(
    @skia_mbt.ISize::new(20, 10),
    sample_count=4,
    stencil_bits=8,
  )
  let present_pass = @skia_mbt.RenderPassDescriptor::for_target(
    window_target,
    bounds=Some(@skia_mbt.IRect::from_xywh(4, 2, 30, 30)),
  )
  assert_true(present_pass.needs_present())
  assert_true(present_pass.keeps_pixels())
  assert_true(present_pass.store_op == @skia_mbt.PresentPixels)
  assert_true(present_pass.bounds == @skia_mbt.IRect::new(4, 2, 20, 10))
  assert_true(present_pass.is_msaa())

  let clear_pass = @skia_mbt.RenderPassDescriptor::clear_target(
    window_target,
    @skia_mbt.Color::blue(),
  )
  assert_true(clear_pass.needs_clear())
  assert_true(clear_pass.needs_present())
  assert_true(clear_pass.clear_color == Some(@skia_mbt.Color::blue()))

  let discard_pass = @skia_mbt.RenderPassDescriptor::for_target(
    window_target.without_present(),
    store_op=Some(@skia_mbt.DiscardPixels),
  )
  assert_true(!discard_pass.needs_present())
  assert_true(!discard_pass.keeps_pixels())
  assert_true(discard_pass.store_op == @skia_mbt.DiscardPixels)
}

///|
test "render command list tracks stats balance and touched bounds" {
  let target = @skia_mbt.SurfaceTargetDescriptor::window_n32_premul(
    @skia_mbt.ISize::new(40, 20),
  )
  let path = @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(5, 5))
    .line_to(@skia_mbt.Point::new(12, 7))
  let commands = @skia_mbt.RenderCommandList::for_target(
      target,
      bounds=Some(@skia_mbt.IRect::from_xywh(0, 0, 30, 10)),
    )
    .save()
    .clip_rect(@skia_mbt.Rect::from_xywh(0, 0, 12, 8))
    .draw_rect(
      @skia_mbt.Rect::from_xywh(2, 2, 8, 4),
      paint=@skia_mbt.Paint::new(color=@skia_mbt.Color::red()),
    )
    .draw_path(path, paint=@skia_mbt.Paint::new(color=@skia_mbt.Color::blue()))
    .draw_text_utf8(
      b"Skia",
      @skia_mbt.Point::new(4, 8),
      paint=@skia_mbt.Paint::new(color=@skia_mbt.Color::black()),
    )
    .restore()
    .finish()
  let stats = commands.stats()
  assert_eq(commands.length(), 7)
  assert_eq(stats.command_count, 7)
  assert_eq(stats.draw_count, 3)
  assert_eq(stats.clip_count, 1)
  assert_eq(stats.state_count, 2)
  assert_eq(stats.present_count, 1)
  assert_eq(stats.text_count, 1)
  assert_eq(stats.max_save_depth, 1)
  assert_true(stats.is_state_balanced())
  assert_true(commands.is_state_balanced())
  assert_true(commands.has_present())
  assert_true(
    commands.touched_bounds() == Some(@skia_mbt.Rect::new(2, 2, 12, 7)),
  )
  assert_true(commands.finish().length() == commands.length())

  let raster_commands = @skia_mbt.RenderCommandList::for_target(
      @skia_mbt.SurfaceTargetDescriptor::raster_n32_premul(
        @skia_mbt.ISize::new(8, 8),
      ),
    )
    .clear(@skia_mbt.Color::white())
    .finish()
  assert_true(!raster_commands.has_present())
  assert_true(
    raster_commands.touched_bounds() == Some(@skia_mbt.Rect::from_iwh(8, 8)),
  )

  let unbalanced = @skia_mbt.RenderCommandList::for_target(target).restore()
  assert_true(!unbalanced.is_state_balanced())
  assert_eq(unbalanced.stats().unbalanced_restore_count, 1)
}

///|
test "render command list exposes text run resource keys" {
  let target = @skia_mbt.SurfaceTargetDescriptor::raster_n32_premul(
    @skia_mbt.ISize::new(32, 16),
  )
  let fallback = @skia_mbt.FontFallbackRequest::new(
    families=@skia_mbt.FontFallbackChain::new(primary_family=b"Inter"),
    bcp47=[b"en"],
    character=0x68,
    style=@skia_mbt.FontStyleRequest::normal(),
  )
  let descriptor = @skia_mbt.TextRunDescriptor::new(
    range=@skia_mbt.TextRange::new(0, 5),
    fallback~,
  )
  let font_key = @skia_mbt.RendererResourceKey::font(b"Inter:16:400")
  let expected_key = descriptor.resource_key(b"hello", font_key~)
  let commands = @skia_mbt.RenderCommandList::for_target(target)
    .draw_text_run_utf8(
      b"hello",
      @skia_mbt.Point::new(2, 12),
      descriptor=Some(descriptor),
      font_key~,
      paint=@skia_mbt.Paint::new(color=@skia_mbt.Color::black()),
    )
    .draw_text_utf8(b"legacy", @skia_mbt.Point::new(2, 8))
  let stats = commands.stats()
  assert_eq(stats.draw_count, 2)
  assert_eq(stats.text_count, 2)
  assert_true(
    commands.commands[0].text_run_resource_key() == Some(expected_key),
  )
  assert_true(commands.commands[1].text_run_resource_key() is None)
  let keys = commands.text_run_resource_keys()
  assert_eq(keys.length(), 1)
  assert_true(keys[0] == expected_key)

  let descriptors = commands
    .draw_path(
      @skia_mbt.Path::new().add_rect(@skia_mbt.Rect::from_xywh(0, 0, 4, 4)),
      paint=@skia_mbt.Paint::new(color=@skia_mbt.Color::blue()),
    )
    .draw_text_run_utf8(
      b"hello",
      @skia_mbt.Point::new(4, 12),
      descriptor=Some(descriptor),
      font_key~,
    )
    .resource_descriptors()
  assert_eq(descriptors.length(), 3)
  assert_true(descriptors[0].key.kind == @skia_mbt.SurfaceResource)
  assert_eq(descriptors[0].byte_size, 2048L)
  let mut path_descriptor_seen = false
  let mut text_descriptor : @skia_mbt.RendererResourceDescriptor? = None
  for descriptor in descriptors {
    if descriptor.key.kind == @skia_mbt.PathResource {
      path_descriptor_seen = descriptor.is_cacheable()
    }
    if descriptor.key == expected_key {
      text_descriptor = Some(descriptor)
    }
  }
  assert_true(path_descriptor_seen)
  guard text_descriptor is Some(text_descriptor) else {
    fail("text run descriptor should be included in resource plan")
  }
  assert_eq(text_descriptor.byte_size, 5L)
  assert_true(text_descriptor.is_cacheable())

  let cache : @skia_mbt.ResourceCache[
    @skia_mbt.RendererResourceKey,
    @skia_mbt.RendererResourceDescriptor,
  ] = @skia_mbt.ResourceCache::new(max_bytes=8L)
  assert_true(
    cache.insert(
      text_descriptor.key,
      text_descriptor,
      byte_size=text_descriptor.byte_size,
    ),
  )
  assert_true(cache.contains(expected_key))
}

///|
test "font fallback contracts normalize style family and language requests" {
  let style = @skia_mbt.FontStyleRequest::new(weight=1200, width=-2, slant=9)
  assert_eq(style.weight, 1000)
  assert_eq(style.width, 1)
  assert_eq(style.slant, 2)
  assert_true(style.is_bold())
  assert_true(style.is_italic())

  let chain = @skia_mbt.FontFallbackChain::new(primary_family=b"Inter", fallback_families=[
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

  let request = @skia_mbt.FontFallbackRequest::new(
    families=extended,
    bcp47=[b"zh-Hans", b"", b"en", b"zh-Hans"],
    character=0x4F60,
    style=@skia_mbt.FontStyleRequest::bold(),
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
}

///|
test "text run descriptor records byte ranges direction and fallback query" {
  let range = @skia_mbt.TextRange::new(-2, 6)
  assert_eq(range.start, 0)
  assert_eq(range.end, 6)
  assert_eq(range.length(), 6)
  assert_true(range.contains_offset(5))
  assert_true(!range.contains_offset(6))
  assert_true(@skia_mbt.TextRange::new(9, 3).is_empty())

  let fallback = @skia_mbt.FontFallbackRequest::new(
    families=@skia_mbt.FontFallbackChain::new(primary_family=b"Inter"),
    character=0x1F642,
  )
  let run = @skia_mbt.TextRunDescriptor::new(
    range~,
    direction=@skia_mbt.RightToLeft,
    fallback~,
  )
  assert_true(run.is_right_to_left())
  assert_true(!run.is_empty())
  assert_true(run.fallback.families.primary_family == b"Inter")
  assert_true(
    run.with_direction(@skia_mbt.LeftToRight).direction.is_left_to_right(),
  )
  assert_true(run.with_range(@skia_mbt.TextRange::new(1, 1)).is_empty())

  let font_key = @skia_mbt.RendererResourceKey::font(b"Inter:16:400")
  let key = run.resource_key(b"hello", font_key~)
  assert_true(key.kind == @skia_mbt.TextRunResource)
  assert_true(!key.is_empty())
  assert_true(key == run.resource_key(b"hello", font_key~))
  assert_true(key != run.resource_key(b"hello!", font_key~))
  assert_true(
    key !=
    run
    .with_range(@skia_mbt.TextRange::new(0, 3))
    .resource_key(b"hello", font_key~),
  )
  assert_true(
    key !=
    run.with_direction(@skia_mbt.LeftToRight).resource_key(b"hello", font_key~),
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
      font_key=@skia_mbt.RendererResourceKey::font(b"Serif:16:400"),
    ),
  )
  let descriptor = run.resource_descriptor(b"hello", font_key~)
  assert_true(descriptor.key == key)
  assert_eq(descriptor.byte_size, 5L)
  assert_true(descriptor.is_cacheable())
}

///|
test "matrix exposes skia-style members and affine conversion" {
  let matrix = @skia_mbt.Matrix::new_all(2, 1, 10, 3, 4, 20, 0, 0, 1)
  assert_eq(matrix.scale_x(), 2.0)
  assert_eq(matrix.skew_x(), 1.0)
  assert_eq(matrix.translate_x(), 10.0)
  assert_eq(matrix.skew_y(), 3.0)
  assert_eq(matrix.scale_y(), 4.0)
  assert_eq(matrix.translate_y(), 20.0)
  assert_eq(matrix.persp_x(), 0.0)
  assert_eq(matrix.persp_y(), 0.0)
  assert_true(matrix.is_finite())
  assert_true(
    matrix.values() == [2.0, 1.0, 10.0, 3.0, 4.0, 20.0, 0.0, 0.0, 1.0],
  )
  assert_true(matrix.to_affine() == Some([2.0, 1.0, 10.0, 3.0, 4.0, 20.0]))
  assert_true(
    @skia_mbt.Matrix::from_affine([2, 1, 10, 3, 4, 20]) == Some(matrix),
  )
  assert_true(@skia_mbt.Matrix::from_affine([1, 2, 3]) is None)

  let perspective = @skia_mbt.Matrix::new_all(1, 0, 0, 0, 1, 0, 0.5, 0, 1)
  assert_true(perspective.to_affine() is None)
}

///|
test "matrix composes, inverts, and maps rect bounds" {
  let scale = @skia_mbt.Matrix::scale(2, 4)
  let translate = @skia_mbt.Matrix::translate(10, 20)
  let matrix = translate.concat(scale)
  assert_true(matrix == @skia_mbt.Matrix::scale_translate(2, 4, 10, 20))
  assert_true(matrix.post_concat(@skia_mbt.Matrix::identity()) == matrix)
  assert_true(@skia_mbt.Matrix::identity().pre_concat(matrix) == matrix)
  assert_eq(matrix.determinant(), 8.0)
  assert_true(matrix.is_invertible())
  guard matrix.invert() is Some(inverse) else { fail("expected inverse") }
  assert_true(
    inverse.map_point(matrix.map_point(@skia_mbt.Point::new(4, 5))) ==
    @skia_mbt.Point::new(4, 5),
  )
  assert_true(
    matrix.concat(inverse).map_point(@skia_mbt.Point::new(7, 9)) ==
    @skia_mbt.Point::new(7, 9),
  )

  let skew = @skia_mbt.Matrix::skew(1, 0)
  assert_true(
    skew.map_rect(@skia_mbt.Rect::from_xywh(0, 0, 2, 3)) ==
    @skia_mbt.Rect::new(0, 0, 5, 3),
  )

  let base = @skia_mbt.Matrix::scale(2, 3)
  assert_true(
    base.pre_translate(10, 20).map_point(@skia_mbt.Point::new(1, 1)) ==
    @skia_mbt.Point::new(12, 23),
  )
  assert_true(
    base.post_translate(10, 20).map_point(@skia_mbt.Point::new(1, 1)) ==
    @skia_mbt.Point::new(22, 63),
  )
  assert_true(
    @skia_mbt.Matrix::identity()
    .pre_scale(2, 3)
    .post_skew(1, 0)
    .map_point(@skia_mbt.Point::new(1, 1)) ==
    @skia_mbt.Point::new(4, 3),
  )
  assert_true(
    @skia_mbt.Matrix::identity()
    .pre_skew(1, 0)
    .post_scale(2, 3)
    .map_point(@skia_mbt.Point::new(1, 1)) ==
    @skia_mbt.Point::new(5, 3),
  )
  assert_true(
    @skia_mbt.Matrix::translate(1, 2).map_points([
      @skia_mbt.Point::new(0, 0),
      @skia_mbt.Point::new(3, 4),
    ]) ==
    [@skia_mbt.Point::new(1, 2), @skia_mbt.Point::new(4, 6)],
  )

  let collapsed = @skia_mbt.Matrix::scale(0, 1)
  assert_eq(collapsed.determinant(), 0.0)
  assert_true(!collapsed.is_invertible())
  assert_true(collapsed.invert() is None)
}

///|
test "matrix maps origins vectors radii and rectangle quads" {
  let matrix = @skia_mbt.Matrix::scale_translate(2, 3, 10, 20)
  let point = @skia_mbt.Point::new(4, 5)
  let rect = @skia_mbt.Rect::from_xywh(1, 2, 3, 4)

  assert_true(matrix.map_xy(4, 5) == @skia_mbt.Point::new(18, 35))
  assert_true(matrix.map_origin() == @skia_mbt.Point::new(10, 20))
  assert_true(
    matrix.map_point_affine(point) == Some(@skia_mbt.Point::new(18, 35)),
  )
  assert_true(matrix.map_vector(point) == @skia_mbt.Point::new(8, 15))
  assert_true(
    matrix.map_vectors([@skia_mbt.Point::new(1, 1), @skia_mbt.Point::new(2, 3)]) ==
    [@skia_mbt.Point::new(2, 3), @skia_mbt.Point::new(4, 9)],
  )
  assert_true(@skia_mbt.Matrix::scale(2, 8).map_radius(3) == Some(12.0))
  assert_true(
    @skia_mbt.Matrix::new_all(1, 0, 0, 0, 1, 0, 0.5, 0, 1).map_point_affine(
      point,
    )
    is None,
  )
  assert_true(
    @skia_mbt.Matrix::new_all(1, 0, 0, 0, 1, 0, 0.5, 0, 1).map_radius(3) is None,
  )

  assert_true(
    matrix.map_rect_to_quad(rect) ==
    [
      @skia_mbt.Point::new(12, 26),
      @skia_mbt.Point::new(18, 26),
      @skia_mbt.Point::new(18, 38),
      @skia_mbt.Point::new(12, 38),
    ],
  )
  assert_true(
    matrix.map_rect_scale_translate(rect) ==
    Some(@skia_mbt.Rect::from_xywh(12, 26, 6, 12)),
  )
  assert_true(
    @skia_mbt.Matrix::skew(1, 0).map_rect_scale_translate(rect) is None,
  )
}

///|
test "image info computes row and byte sizes" {
  let info = @skia_mbt.ImageInfo::n32_premul(@skia_mbt.ISize::new(10, 8))
  assert_eq(info.bytes_per_pixel(), 4)
  assert_eq(info.shift_per_pixel(), 2)
  assert_eq(info.min_row_bytes(), 40)
  assert_eq(info.min_row_bytes64(), 40L)
  assert_eq(info.compute_min_byte_size(), 320)
  assert_eq(info.compute_min_byte_size64(), 320L)
  assert_eq(info.compute_byte_size(48), 384)
  assert_eq(info.compute_byte_size64(48), 384L)
  assert_eq(info.compute_byte_size(39), 0)
  assert_true(info.bounds() == @skia_mbt.IRect::from_xywh(0, 0, 10, 8))
  assert_true(info.valid_pixels(40))

  let unknown = @skia_mbt.ImageInfo::unknown(
    dimensions=@skia_mbt.ISize::new(1, 1),
  )
  assert_eq(unknown.bytes_per_pixel(), 0)
  assert_eq(unknown.shift_per_pixel(), 0)
  assert_true(!unknown.valid_pixels(0))

  let alpha = @skia_mbt.ImageInfo::a8(@skia_mbt.ISize::new(3, 2))
  assert_eq(alpha.bytes_per_pixel(), 1)
  assert_eq(alpha.shift_per_pixel(), 0)
  assert_eq(alpha.min_row_bytes(), 3)
  assert_true(alpha.valid_pixels(3))
}

///|
test "pixmap validates copied pixel layout" {
  let info = @skia_mbt.ImageInfo::n32_premul(@skia_mbt.ISize::new(2, 2))
  let pixmap = @skia_mbt.Pixmap::new(
    info, 8, b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f",
  )
  guard pixmap is Some(pixmap) else { fail("expected pixmap") }
  assert_eq(pixmap.width(), 2)
  assert_eq(pixmap.height(), 2)
  assert_eq(pixmap.row_bytes(), 8)
  assert_true(pixmap.color_type() == @skia_mbt.RGBA8888)
  assert_true(pixmap.alpha_type() == @skia_mbt.Premul)
  assert_eq(pixmap.bytes_per_pixel(), 4)
  assert_eq(pixmap.shift_per_pixel(), 2)
  assert_eq(pixmap.byte_size(), 16)
  assert_eq(pixmap.byte_size64(), 16L)
  assert_true(pixmap.contains(@skia_mbt.IPoint::new(1, 1)))
  assert_true(pixmap.offset(@skia_mbt.IPoint::new(1, 1)) == Some(12))
  assert_true(@skia_mbt.Pixmap::new(info, 4, b"\x00") is None)
}

///|
test "paint builder updates value state" {
  let paint = @skia_mbt.Paint::new()
    .set_anti_alias(true)
    .set_stroke(true)
    .set_stroke_width(2.5)
    .set_color(@skia_mbt.Color::red())
    .set_alpha(0x40)
  assert_true(paint.anti_alias)
  assert_true(paint.style == @skia_mbt.Stroke)
  assert_eq(paint.stroke_width, 2.5)
  assert_true(paint.color == @skia_mbt.Color::red().with_alpha(0x40))
}

///|
test "skia enum ordinals match expected native order" {
  assert_eq(@skia_mbt.SrcOver.to_skia_ordinal(), 3)
  assert_eq(@skia_mbt.Fill.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.Stroke.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.StrokeCap::Round.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.StrokeJoin::Round.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.StrokeJoin::Bevel.to_skia_ordinal(), 2)
  assert_eq(@skia_mbt.Points.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.Lines.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.Polygon.to_skia_ordinal(), 2)
  assert_eq(@skia_mbt.PNG.to_skia_ordinal(), 4)
  assert_eq(@skia_mbt.JPEG.to_skia_ordinal(), 3)
  assert_eq(@skia_mbt.AVIF.to_skia_ordinal(), 12)
  assert_true(@skia_mbt.EncodedImageFormat::from_skia_ordinal(4) == Some(PNG))
  assert_true(@skia_mbt.EncodedImageFormat::from_skia_ordinal(-1) is None)
  assert_eq(@skia_mbt.Clamp.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.Repeat.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.Mirror.to_skia_ordinal(), 2)
  assert_eq(@skia_mbt.Decal.to_skia_ordinal(), 3)
  assert_eq(@skia_mbt.ClipOp::Difference.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.ClipOp::Intersect.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.FilterMode::Nearest.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.FilterMode::Linear.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.MipmapMode::None.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.MipmapMode::Nearest.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.MipmapMode::Linear.to_skia_ordinal(), 2)
}

///|
test "sampling options expose skia-compatible state" {
  let nearest = @skia_mbt.SamplingOptions::new()
  assert_eq(nearest.filter_ordinal(), 0)
  assert_eq(nearest.mipmap_ordinal(), 0)
  assert_true(!nearest.uses_cubic())
  let linear_mipmap = @skia_mbt.SamplingOptions::new(
    filter=@skia_mbt.FilterMode::Linear,
    mipmap=@skia_mbt.MipmapMode::Linear,
  )
  assert_eq(linear_mipmap.filter_ordinal(), 1)
  assert_eq(linear_mipmap.mipmap_ordinal(), 2)
  let cubic = @skia_mbt.SamplingOptions::catmull_rom()
  assert_true(cubic.uses_cubic())
  assert_eq(cubic.cubic_b(), 0.0)
  assert_eq(cubic.cubic_c(), 0.5)
}

///|
test "path value layer records portable verbs" {
  let path = @skia_mbt.Path::new(fill_type=@skia_mbt.EvenOdd)
    .move_to(@skia_mbt.Point::new(0, 0))
    .line_to(@skia_mbt.Point::new(10, 0))
    .quad_to(@skia_mbt.Point::new(12, 5), @skia_mbt.Point::new(10, 10))
    .conic_to(@skia_mbt.Point::new(12, 12), @skia_mbt.Point::new(10, 14), 0.5)
    .cubic_to(
      @skia_mbt.Point::new(7, 12),
      @skia_mbt.Point::new(3, 12),
      @skia_mbt.Point::new(0, 10),
    )
    .close()
  assert_true(!path.is_empty())
  assert_eq(path.verb_count(), 6)
  assert_eq(path.count_verbs(), path.verb_count())
  assert_eq(path.count_points(), 9)
  assert_true(path.is_last_contour_closed())
  assert_true(path.is_finite())
  assert_true(path.fill_type == @skia_mbt.EvenOdd)
  assert_true(path.last_point() == Some(@skia_mbt.Point::new(0, 10)))
  assert_true(path.bounds() == Some(@skia_mbt.Rect::new(0, 0, 12, 14)))
  let segments = path.segment_masks()
  assert_true(segments.contains(@skia_mbt.PathSegmentMask::line()))
  assert_true(segments.contains(@skia_mbt.PathSegmentMask::quad()))
  assert_true(segments.contains(@skia_mbt.PathSegmentMask::conic()))
  assert_true(segments.contains(@skia_mbt.PathSegmentMask::cubic()))
  assert_eq(segments.bits(), 15)
  assert_eq(path.fill_type.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.CW.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.CCW.to_skia_ordinal(), 1)
  assert_true(!path.fill_type.is_inverse())
  assert_true(!path.is_inverse_fill_type())
  assert_true(@skia_mbt.InverseEvenOdd.is_inverse())
  let key = path.resource_key()
  assert_true(key.kind == @skia_mbt.PathResource)
  assert_true(!key.is_empty())
  assert_true(key == path.resource_key())
  assert_true(key != path.with_fill_type(@skia_mbt.Winding).resource_key())
  assert_true(
    key != path.transform(@skia_mbt.Matrix::translate(1, 0)).resource_key(),
  )
  let descriptor = path.resource_descriptor()
  assert_true(descriptor.key == key)
  assert_true(descriptor.byte_size > 0L)
  assert_true(descriptor.is_cacheable())
  assert_true(!@skia_mbt.Path::new().resource_descriptor().is_cacheable())
}

///|
test "path recognizes a single line segment" {
  let line = @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(1, 2))
    .line_to(@skia_mbt.Point::new(3, 4))
  assert_true(
    line.is_line() ==
    Some(
      @skia_mbt.PathLine::new(
        @skia_mbt.Point::new(1, 2),
        @skia_mbt.Point::new(3, 4),
      ),
    ),
  )
  assert_true(@skia_mbt.Path::new().is_line() is None)
  assert_true(
    @skia_mbt.Path::new()
    .add_rect(@skia_mbt.Rect::from_xywh(0, 0, 2, 2))
    .is_line()
    is None,
  )
}

///|
test "path add poly builds open and closed contours" {
  let points = [
    @skia_mbt.Point::new(0, 0),
    @skia_mbt.Point::new(10, 0),
    @skia_mbt.Point::new(10, 10),
  ]
  let open = @skia_mbt.Path::new().add_poly(points)
  assert_eq(open.count_verbs(), 3)
  assert_eq(open.count_points(), 3)
  assert_true(!open.is_last_contour_closed())
  assert_true(open.last_point() == Some(@skia_mbt.Point::new(10, 10)))
  assert_true(open.bounds() == Some(@skia_mbt.Rect::from_xywh(0, 0, 10, 10)))
  assert_true(open.segment_masks().contains(@skia_mbt.PathSegmentMask::line()))

  let closed = @skia_mbt.Path::new(fill_type=@skia_mbt.EvenOdd).add_poly(
    points,
    close=true,
  )
  assert_eq(closed.count_verbs(), 4)
  assert_eq(closed.count_points(), 3)
  assert_true(closed.is_last_contour_closed())
  assert_true(closed.fill_type == @skia_mbt.EvenOdd)
  assert_true(closed.contains(@skia_mbt.Point::new(8, 2)))
  assert_true(!closed.contains(@skia_mbt.Point::new(2, 8)))

  let empty : Array[@skia_mbt.Point] = []
  assert_true(@skia_mbt.Path::new().add_poly(empty).is_empty())
}

///|
test "path add path appends transformed verbs" {
  let base = @skia_mbt.Path::new(fill_type=@skia_mbt.EvenOdd).add_rect(
    @skia_mbt.Rect::from_xywh(0, 0, 2, 2),
  )
  let triangle = @skia_mbt.Path::new().add_poly(
    [
      @skia_mbt.Point::new(0, 0),
      @skia_mbt.Point::new(10, 0),
      @skia_mbt.Point::new(10, 10),
    ],
    close=true,
  )
  let combined = base.add_path(
    triangle,
    matrix=@skia_mbt.Matrix::translate(10, 0),
  )
  assert_true(combined.fill_type == @skia_mbt.EvenOdd)
  assert_eq(combined.count_verbs(), base.count_verbs() + triangle.count_verbs())
  assert_eq(
    combined.count_points(),
    base.count_points() + triangle.count_points(),
  )
  assert_true(combined.bounds() == Some(@skia_mbt.Rect::new(0, 0, 20, 10)))
  assert_true(combined.last_point() == Some(@skia_mbt.Point::new(20, 10)))
  assert_true(combined.contains(@skia_mbt.Point::new(18, 2)))
  assert_true(!combined.contains(@skia_mbt.Point::new(4, 8)))
  assert_true(
    base.add_path_matrix(triangle, @skia_mbt.Matrix::translate(10, 0)) ==
    combined,
  )
  assert_true(
    base.add_path_offset(triangle, @skia_mbt.Point::new(10, 0)) == combined,
  )
  assert_true(base.add_path(@skia_mbt.Path::new()) == base)

  let open = @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(0, 0))
    .line_to(@skia_mbt.Point::new(2, 0))
  let segment = @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(10, 0))
    .line_to(@skia_mbt.Point::new(12, 0))
  let extended = open.add_path(segment, mode=@skia_mbt.Extend)
  assert_true(
    extended.verbs[2] == @skia_mbt.LineTo(@skia_mbt.Point::new(10, 0)),
  )
  assert_true(
    extended.verbs[3] == @skia_mbt.LineTo(@skia_mbt.Point::new(12, 0)),
  )
  assert_eq(extended.count_verbs(), 4)
  assert_true(extended.bounds() == Some(@skia_mbt.Rect::from_xywh(0, 0, 12, 0)))
  assert_true(
    @skia_mbt.Path::new().add_path(segment, mode=@skia_mbt.Extend) == segment,
  )
}

///|
test "path recognizes closed rectangle contours" {
  let rect = @skia_mbt.Rect::from_xywh(1, 2, 3, 4)
  let cw = @skia_mbt.Path::new().add_rect(rect)
  assert_true(
    cw.is_rect() == Some(@skia_mbt.PathRect::new(rect, true, @skia_mbt.CW)),
  )
  let ccw = @skia_mbt.Path::new().add_rect(rect, direction=@skia_mbt.CCW)
  assert_true(
    ccw.is_rect() == Some(@skia_mbt.PathRect::new(rect, true, @skia_mbt.CCW)),
  )
  assert_true(
    @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(1, 2))
    .line_to(@skia_mbt.Point::new(3, 4))
    .is_rect()
    is None,
  )
}

///|
test "path reset returns an empty winding path" {
  let path = @skia_mbt.Path::new(fill_type=@skia_mbt.InverseWinding)
    .move_to(@skia_mbt.Point::new(1, 2))
    .reset()
  assert_true(path.is_empty())
  assert_true(path.is_finite())
  assert_eq(path.count_verbs(), 0)
  assert_eq(path.count_points(), 0)
  assert_true(path.segment_masks() == @skia_mbt.PathSegmentMask::empty())
  assert_true(!path.is_last_contour_closed())
  assert_true(path.fill_type == @skia_mbt.Winding)
  assert_true(path.last_point() is None)
  assert_true(path.bounds() is None)
}

///|
test "path rewind clears path for reuse" {
  let path = @skia_mbt.Path::new(fill_type=@skia_mbt.EvenOdd)
    .add_rect(@skia_mbt.Rect::from_xywh(0, 0, 4, 4))
    .rewind()
  assert_true(path.is_empty())
  assert_eq(path.count_verbs(), 0)
  assert_eq(path.count_points(), 0)
  assert_true(!path.is_last_contour_closed())
  assert_true(path.fill_type == @skia_mbt.Winding)
  assert_true(path.bounds() is None)
}

///|
test "path add rect expands in requested direction" {
  let rect = @skia_mbt.Rect::from_xywh(1, 2, 3, 4)
  let cw = @skia_mbt.Path::new().add_rect(rect)
  assert_eq(cw.verb_count(), 5)
  assert_true(cw.last_point() == Some(@skia_mbt.Point::new(1, 6)))
  assert_true(cw.bounds() == Some(rect))
  assert_true(cw.contains(@skia_mbt.Point::new(2, 3)))
  assert_true(!cw.contains(@skia_mbt.Point::new(9, 9)))
  assert_true(
    cw.verbs ==
    [
      @skia_mbt.MoveTo(@skia_mbt.Point::new(1, 2)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(4, 2)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(4, 6)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(1, 6)),
      @skia_mbt.Close,
    ],
  )
  let ccw = @skia_mbt.Path::new().add_rect(rect, direction=@skia_mbt.CCW)
  assert_true(ccw.contains(@skia_mbt.Point::new(2, 3)))
  let inverse = cw.with_fill_type(@skia_mbt.InverseWinding)
  assert_true(inverse.is_inverse_fill_type())
  assert_true(!inverse.contains(@skia_mbt.Point::new(2, 3)))
  assert_true(inverse.contains(@skia_mbt.Point::new(9, 9)))
  assert_true(
    ccw.verbs ==
    [
      @skia_mbt.MoveTo(@skia_mbt.Point::new(1, 2)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(1, 6)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(4, 6)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(4, 2)),
      @skia_mbt.Close,
    ],
  )
}

///|
test "path add oval and circle expand to conics" {
  let oval = @skia_mbt.Rect::from_xywh(0, 0, 10, 20)
  let cw = @skia_mbt.Path::new().add_oval(oval)
  assert_eq(cw.verb_count(), 6)
  assert_true(cw.bounds() == Some(oval))
  assert_true(cw.is_oval() == Some(oval))
  assert_true(cw.last_point() == Some(@skia_mbt.Point::new(10, 10)))
  assert_true(cw.verbs[0] == @skia_mbt.MoveTo(@skia_mbt.Point::new(10, 10)))
  assert_true(
    cw.verbs[1] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(10, 20),
      @skia_mbt.Point::new(5, 20),
      0.70710677,
    ),
  )
  let ccw = @skia_mbt.Path::new().add_oval(oval, direction=@skia_mbt.CCW)
  assert_true(ccw.is_oval() == Some(oval))
  assert_true(
    ccw.verbs[1] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(10, 0),
      @skia_mbt.Point::new(5, 0),
      0.70710677,
    ),
  )
  let circle = @skia_mbt.Path::new().add_circle(@skia_mbt.Point::new(5, 5), 3)
  assert_true(circle.bounds() == Some(@skia_mbt.Rect::from_xywh(2, 2, 6, 6)))
  assert_true(circle.is_oval() == Some(@skia_mbt.Rect::from_xywh(2, 2, 6, 6)))
  assert_true(
    @skia_mbt.Path::new().add_circle(@skia_mbt.Point::zero(), 0).is_empty(),
  )
  assert_true(
    @skia_mbt.Path::new()
    .add_rect(@skia_mbt.Rect::from_xywh(0, 0, 10, 20))
    .is_oval()
    is None,
  )
}

///|
test "path add round rect expands to lines and conics" {
  let rect = @skia_mbt.Rect::from_xywh(0, 0, 10, 20)
  let cw = @skia_mbt.Path::new().add_round_rect(rect, 2, 3)
  assert_eq(cw.verb_count(), 10)
  assert_true(cw.bounds() == Some(rect))
  assert_true(cw.last_point() == Some(@skia_mbt.Point::new(2, 0)))
  assert_true(cw.verbs[0] == @skia_mbt.MoveTo(@skia_mbt.Point::new(2, 0)))
  assert_true(cw.verbs[1] == @skia_mbt.LineTo(@skia_mbt.Point::new(8, 0)))
  assert_true(
    cw.verbs[2] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(10, 0),
      @skia_mbt.Point::new(10, 3),
      0.70710677,
    ),
  )
  let ccw = @skia_mbt.Path::new().add_round_rect(
    rect,
    2,
    3,
    direction=@skia_mbt.CCW,
  )
  assert_true(
    ccw.verbs[1] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(0, 0),
      @skia_mbt.Point::new(0, 3),
      0.70710677,
    ),
  )
  assert_true(
    @skia_mbt.Path::new().add_round_rect(rect, 0, 3).verb_count() == 5,
  )
}

///|
test "rrect value layer normalizes per-corner radii" {
  let rect = @skia_mbt.Rect::from_xywh(0, 0, 10, 8)
  let rrect = @skia_mbt.RRect::new(
    rect,
    @skia_mbt.Size::new(8, 8),
    @skia_mbt.Size::new(8, 8),
    @skia_mbt.Size::new(2, 2),
    @skia_mbt.Size::new(-1, 4),
  )
  assert_true(rrect.bounds() == rect)
  assert_true(rrect.upper_left == @skia_mbt.Size::new(5, 5))
  assert_true(rrect.upper_right == @skia_mbt.Size::new(5, 5))
  assert_true(rrect.lower_right == @skia_mbt.Size::new(1.25, 1.25))
  assert_true(rrect.lower_left == @skia_mbt.Size::empty())
  assert_true(!rrect.is_rect())
  assert_true(!rrect.is_simple())
  assert_eq(rrect.width(), 10)
  assert_eq(rrect.height(), 8)

  let simple = @skia_mbt.RRect::from_rect_xy(rect, 2, 3)
  assert_true(simple.is_simple())
  assert_true(!simple.is_oval())

  let oval = @skia_mbt.RRect::from_oval(rect)
  assert_true(oval.is_oval())
  assert_true(oval.upper_left == @skia_mbt.Size::new(5, 4))

  let plain = @skia_mbt.RRect::from_rect(rect)
  assert_true(plain.is_rect())
  assert_true(plain.offset(1, 2).bounds() == rect.offset(1, 2))
}

///|
test "rrect immutable geometry helpers preserve value semantics" {
  let rrect = @skia_mbt.RRect::from_rect_xy(
    @skia_mbt.Rect::from_xywh(0, 0, 10, 8),
    2,
    3,
  )

  let shifted = rrect.with_offset(@skia_mbt.Point::new(5, -2))
  assert_true(shifted.bounds() == @skia_mbt.Rect::from_xywh(5, -2, 10, 8))
  assert_true(shifted.upper_left == rrect.upper_left)
  assert_true(
    rrect.with_offset_to(@skia_mbt.Point::new(20, 30)).bounds() ==
    @skia_mbt.Rect::from_xywh(20, 30, 10, 8),
  )

  let inset = rrect.with_inset(@skia_mbt.Size::new(1, 2))
  assert_true(inset.bounds() == @skia_mbt.Rect::from_xywh(1, 2, 8, 4))
  assert_true(inset.upper_left == @skia_mbt.Size::new(1, 1))

  let outset = rrect.with_outset(@skia_mbt.Size::new(1, 2))
  assert_true(outset.bounds() == @skia_mbt.Rect::from_xywh(-1, -2, 12, 12))
  assert_true(outset.upper_left == @skia_mbt.Size::new(3, 5))
}

///|
test "rrect contains rectangles inside rounded corners" {
  let rrect = @skia_mbt.RRect::from_rect_xy(
    @skia_mbt.Rect::from_xywh(0, 0, 10, 10),
    4,
    4,
  )

  assert_true(rrect.contains_rect(@skia_mbt.Rect::from_xywh(4, 4, 2, 2)))
  assert_true(rrect.contains_rect(@skia_mbt.Rect::from_xywh(2, 2, 6, 6)))
  assert_true(!rrect.contains_rect(@skia_mbt.Rect::from_xywh(0, 0, 1, 1)))
  assert_true(!rrect.contains_rect(@skia_mbt.Rect::from_xywh(-1, 4, 2, 2)))
  assert_true(
    @skia_mbt.RRect::from_rect(@skia_mbt.Rect::from_xywh(0, 0, 10, 10)).contains_rect(
      @skia_mbt.Rect::from_xywh(0, 0, 10, 10),
    ),
  )
}

///|
test "path add rrect expands mixed corners" {
  let rect = @skia_mbt.Rect::from_xywh(0, 0, 10, 8)
  let rrect = @skia_mbt.RRect::new(
    rect,
    @skia_mbt.Size::new(2, 2),
    @skia_mbt.Size::new(3, 1),
    @skia_mbt.Size::new(1, 2),
    @skia_mbt.Size::empty(),
  )
  let path = @skia_mbt.Path::new().add_rrect(rrect)
  assert_eq(path.verb_count(), 10)
  assert_true(path.bounds() == Some(rect))
  assert_true(path.last_point() == Some(@skia_mbt.Point::new(2, 0)))
  assert_true(path.verbs[0] == @skia_mbt.MoveTo(@skia_mbt.Point::new(2, 0)))
  assert_true(path.verbs[1] == @skia_mbt.LineTo(@skia_mbt.Point::new(7, 0)))
  assert_true(
    path.verbs[2] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(10, 0),
      @skia_mbt.Point::new(10, 1),
      0.70710677,
    ),
  )
  assert_true(path.verbs[6] == @skia_mbt.LineTo(@skia_mbt.Point::new(0, 8)))

  let ccw = @skia_mbt.Path::new().add_rrect(rrect, direction=@skia_mbt.CCW)
  assert_true(
    ccw.verbs[1] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(0, 0),
      @skia_mbt.Point::new(0, 2),
      0.70710677,
    ),
  )

  let rect_path = @skia_mbt.Path::new().add_rrect(
    @skia_mbt.RRect::from_rect(rect),
  )
  assert_true(rect_path.verbs == @skia_mbt.Path::new().add_rect(rect).verbs)
}

///|
test "path transform maps every verb point" {
  let path = @skia_mbt.Path::new(fill_type=@skia_mbt.EvenOdd)
    .move_to(@skia_mbt.Point::new(1, 2))
    .line_to(@skia_mbt.Point::new(3, 4))
    .quad_to(@skia_mbt.Point::new(5, 6), @skia_mbt.Point::new(7, 8))
    .conic_to(@skia_mbt.Point::new(9, 10), @skia_mbt.Point::new(11, 12), 0.5)
    .cubic_to(
      @skia_mbt.Point::new(13, 14),
      @skia_mbt.Point::new(15, 16),
      @skia_mbt.Point::new(17, 18),
    )
    .close()
  let transformed = path.transform(
    @skia_mbt.Matrix::scale_translate(2, 3, 10, 20),
  )
  assert_true(transformed.fill_type == @skia_mbt.EvenOdd)
  assert_true(transformed.last_point() == Some(@skia_mbt.Point::new(44, 74)))
  assert_true(
    transformed.verbs[0] == @skia_mbt.MoveTo(@skia_mbt.Point::new(12, 26)),
  )
  assert_true(
    transformed.verbs[3] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(28, 50),
      @skia_mbt.Point::new(32, 56),
      0.5,
    ),
  )
  assert_true(transformed.verbs[5] == @skia_mbt.Close)

  let offset = path.offset(2, 3)
  assert_true(offset.bounds() == Some(@skia_mbt.Rect::new(3, 5, 19, 21)))
}

///|
test "path stroke bounds conservatively outsets geometry" {
  let path = @skia_mbt.Path::new().add_rect(
    @skia_mbt.Rect::from_xywh(1, 2, 3, 4),
  )
  let fill = @skia_mbt.Paint::new(style=@skia_mbt.Fill, stroke_width=10)
  assert_true(path.stroke_bounds(fill) == path.bounds())
  let stroke = @skia_mbt.Paint::new(style=@skia_mbt.Stroke, stroke_width=6)
  assert_true(
    path.stroke_bounds(stroke) == Some(@skia_mbt.Rect::new(-2, -1, 7, 9)),
  )
  let stroke_and_fill = @skia_mbt.Paint::new(
    style=@skia_mbt.StrokeAndFill,
    stroke_width=2,
  )
  assert_true(
    path.stroke_bounds(stroke_and_fill) == Some(@skia_mbt.Rect::new(0, 1, 5, 7)),
  )
  assert_true(@skia_mbt.Path::new().stroke_bounds(stroke) is None)
}

///|
test "path compute tight bounds excludes off-curve controls" {
  let quad = @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(0, 0))
    .quad_to(@skia_mbt.Point::new(10, 10), @skia_mbt.Point::new(20, 0))
  assert_true(quad.bounds() == Some(@skia_mbt.Rect::new(0, 0, 20, 10)))
  assert_true(
    quad.compute_tight_bounds() == Some(@skia_mbt.Rect::new(0, 0, 20, 5)),
  )

  let conic = @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(0, 0))
    .conic_to(@skia_mbt.Point::new(10, 10), @skia_mbt.Point::new(20, 0), 1)
  assert_true(conic.bounds() == Some(@skia_mbt.Rect::new(0, 0, 20, 10)))
  assert_true(
    conic.compute_tight_bounds() == Some(@skia_mbt.Rect::new(0, 0, 20, 5)),
  )

  let cubic = @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(0, 0))
    .cubic_to(
      @skia_mbt.Point::new(0, 12),
      @skia_mbt.Point::new(12, 12),
      @skia_mbt.Point::new(12, 0),
    )
  assert_true(cubic.bounds() == Some(@skia_mbt.Rect::new(0, 0, 12, 12)))
  assert_true(
    cubic.compute_tight_bounds() == Some(@skia_mbt.Rect::new(0, 0, 12, 9)),
  )
}
