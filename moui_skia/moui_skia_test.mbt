///|
fn test_float_near(a : Float, b : Float) -> Bool {
  (a - b).abs() <= 0.0001
}

///|
fn test_point_near(a : @moui_skia.Point, b : @moui_skia.Point) -> Bool {
  test_float_near(a.x, b.x) && test_float_near(a.y, b.y)
}

///|
fn test_rect_near(a : @moui_skia.Rect, b : @moui_skia.Rect) -> Bool {
  test_float_near(a.left, b.left) &&
  test_float_near(a.top, b.top) &&
  test_float_near(a.right, b.right) &&
  test_float_near(a.bottom, b.bottom)
}

///|
fn test_optional_rect_near(a : @moui_skia.Rect?, b : @moui_skia.Rect) -> Bool {
  match a {
    None => false
    Some(a) => test_rect_near(a, b)
  }
}

///|
test "color packs argb channels" {
  let color = @moui_skia.Color::from_argb(0x80, 0x11, 0x22, 0x33)
  assert_eq(color.argb(), 0x80112233U)
  assert_eq(color.a(), 0x80)
  assert_eq(color.r(), 0x11)
  assert_eq(color.g(), 0x22)
  assert_eq(color.b(), 0x33)
}

///|
test "point and size expose finite and vector helpers" {
  let a = @moui_skia.Point::new(3, 4)
  let b = @moui_skia.Point::new(-2, 5)
  assert_true(a.is_finite())
  assert_true(!@moui_skia.Point::new(1.0 / 0.0, 0).is_finite())
  assert_eq(a.length_squared(), 25.0)
  assert_eq(a.length(), 5.0)
  assert_eq(a.distance_to_origin_squared(), 25.0)
  assert_eq(a.dot(b), 14.0)
  assert_eq(a.cross(b), 23.0)
  assert_eq(a.distance_to_squared(b), 26.0)
  assert_eq(a.distance_to(b), @moui_skia.Point::new(5, -1).length())
  assert_true(a.normalized() == Some(@moui_skia.Point::new(0.6, 0.8)))
  assert_true(a.with_length(10) == Some(@moui_skia.Point::new(6, 8)))
  assert_true(a.with_length(-1) is None)
  assert_true(@moui_skia.Point::zero().normalized() is None)
  assert_true(a.rotate_cw() == @moui_skia.Point::new(4, -3))
  assert_true(a.rotate_ccw() == @moui_skia.Point::new(-4, 3))

  let size = @moui_skia.Size::new(8, 13)
  assert_true(size.is_finite())
  assert_true(!@moui_skia.Size::new(0.0 / 0.0, 1).is_finite())
}

///|
test "rect intersection and containment" {
  let outer = @moui_skia.Rect::from_xywh(0, 0, 10, 10)
  let inner = @moui_skia.Rect::from_xywh(2, 3, 4, 5)
  let overlap = @moui_skia.Rect::from_xywh(8, 8, 5, 5)
  assert_true(outer.contains_rect(inner))
  assert_true(
    outer.intersect(overlap) == Some(@moui_skia.Rect::new(8, 8, 10, 10)),
  )
}

///|
test "rect constructors and immutable offsets mirror skia helpers" {
  let point = @moui_skia.Point::new(2, 3)
  let size = @moui_skia.Size::new(4, 5)
  let rect = @moui_skia.Rect::from_point_and_size(point, size)
  assert_true(rect == @moui_skia.Rect::from_xywh(2, 3, 4, 5))
  assert_true(rect == @moui_skia.Rect::from_ltrb(2, 3, 6, 8))
  assert_true(
    @moui_skia.Rect::from_wh(4, 5) == @moui_skia.Rect::from_size(size),
  )
  assert_true(@moui_skia.Rect::from_iwh(4, 5) == @moui_skia.Rect::from_wh(4, 5))
  assert_true(
    @moui_skia.Rect::from_isize(@moui_skia.ISize::new(4, 5)) ==
    @moui_skia.Rect::from_wh(4, 5),
  )
  assert_true(
    @moui_skia.Rect::from_points([
      @moui_skia.Point::new(5, 4),
      @moui_skia.Point::new(1, 9),
      @moui_skia.Point::new(3, -2),
    ]) ==
    Some(@moui_skia.Rect::new(1, -2, 5, 9)),
  )
  assert_true(
    @moui_skia.Rect::from_points_or_empty([]) == @moui_skia.Rect::empty(),
  )
  assert_eq(rect.x(), 2.0)
  assert_eq(rect.y(), 3.0)
  assert_eq(rect.left(), 2.0)
  assert_eq(rect.top(), 3.0)
  assert_eq(rect.right(), 6.0)
  assert_eq(rect.bottom(), 8.0)
  assert_true(rect.intersects(@moui_skia.Rect::from_xywh(5, 7, 3, 3)))
  assert_true(!rect.intersects(@moui_skia.Rect::from_xywh(6, 8, 2, 2)))

  let irect = @moui_skia.IRect::from_point_and_size(
    @moui_skia.IPoint::new(2, 3),
    @moui_skia.ISize::new(4, 5),
  )
  assert_true(irect == @moui_skia.IRect::from_xywh(2, 3, 4, 5))
  assert_true(irect == @moui_skia.IRect::from_ltrb(2, 3, 6, 8))
  assert_true(
    @moui_skia.IRect::from_wh(4, 5) ==
    @moui_skia.IRect::from_size(@moui_skia.ISize::new(4, 5)),
  )
  assert_true(@moui_skia.Rect::from_irect(irect) == rect)
  assert_eq(irect.x(), 2)
  assert_eq(irect.y(), 3)
  assert_eq(irect.left(), 2)
  assert_eq(irect.top(), 3)
  assert_eq(irect.right(), 6)
  assert_eq(irect.bottom(), 8)
  assert_eq(irect.width_64(), 4L)
  assert_eq(irect.height_64(), 5L)
  assert_true(!irect.is_empty_64())
  assert_true(irect.intersects(@moui_skia.IRect::from_xywh(5, 7, 3, 3)))
  assert_true(!irect.intersects(@moui_skia.IRect::from_xywh(6, 8, 2, 2)))

  assert_true(
    rect.with_offset(@moui_skia.Point::new(10, -1)) ==
    @moui_skia.Rect::from_xywh(12, 2, 4, 5),
  )
  assert_true(
    rect.with_offset_to(@moui_skia.Point::new(10, -1)) ==
    @moui_skia.Rect::from_xywh(10, -1, 4, 5),
  )
  assert_true(
    rect.with_inset(@moui_skia.Size::new(1, 2)) ==
    @moui_skia.Rect::new(3, 5, 5, 6),
  )
  assert_true(
    rect.with_outset(@moui_skia.Size::new(1, 2)) ==
    @moui_skia.Rect::new(1, 1, 7, 10),
  )
  assert_true(
    irect.with_offset(@moui_skia.IPoint::new(10, -1)) ==
    @moui_skia.IRect::from_xywh(12, 2, 4, 5),
  )
  assert_true(
    irect.with_offset_to(@moui_skia.IPoint::new(10, -1)) ==
    @moui_skia.IRect::from_xywh(10, -1, 4, 5),
  )
  assert_true(
    irect.with_inset(@moui_skia.ISize::new(1, 2)) ==
    @moui_skia.IRect::new(3, 5, 5, 6),
  )
  assert_true(
    irect.with_outset(@moui_skia.ISize::new(1, 2)) ==
    @moui_skia.IRect::new(1, 1, 7, 10),
  )
  assert_true(
    irect.with_adjustment(1, -2, 3, 4) == @moui_skia.IRect::new(3, 1, 9, 12),
  )

  let wide = @moui_skia.IRect::new(-2000000000, 0, 2000000000, 1)
  assert_eq(wide.width_64(), 4000000000L)
  assert_true(!wide.is_empty_64())
  assert_true(
    @moui_skia.IRect::new(0, 2000000000, 1, -2000000000).is_empty_64(),
  )
}

///|
test "rect exposes skia-style sorted center finite and rounding helpers" {
  let unsorted = @moui_skia.Rect::new(5, 4, 1, 2)
  assert_true(!unsorted.is_sorted())
  assert_true(unsorted.sorted().is_sorted())
  assert_true(unsorted.center() == @moui_skia.Point::new(3, 3))
  assert_eq(unsorted.center_x(), 3.0)
  assert_eq(unsorted.center_y(), 3.0)
  assert_true(unsorted.is_finite())
  assert_true(!@moui_skia.Rect::new(0, 0, 1.0 / 0.0, 1).is_finite())

  let fractional = @moui_skia.Rect::new(1.2, -2.8, 5.7, 3.1)
  assert_true(fractional.round() == @moui_skia.IRect::new(1, -3, 6, 3))
  assert_true(fractional.to_irect_round() == fractional.round())
  assert_true(fractional.round_in() == @moui_skia.IRect::new(2, -2, 5, 3))
  assert_true(fractional.round_out() == @moui_skia.IRect::new(1, -3, 6, 4))

  let unsorted_i = @moui_skia.IRect::new(4, 5, 1, 2)
  assert_true(!unsorted_i.is_sorted())
  assert_true(unsorted_i.sorted().is_sorted())
}

///|
test "rect exposes corner points and quads" {
  let rect = @moui_skia.Rect::from_xywh(1, 2, 3, 4)
  assert_true(rect.top_left() == @moui_skia.Point::new(1, 2))
  assert_true(rect.tl() == rect.top_left())
  assert_true(rect.top_right() == @moui_skia.Point::new(4, 2))
  assert_true(rect.tr() == rect.top_right())
  assert_true(rect.bottom_right() == @moui_skia.Point::new(4, 6))
  assert_true(rect.br() == rect.bottom_right())
  assert_true(rect.bottom_left() == @moui_skia.Point::new(1, 6))
  assert_true(rect.bl() == rect.bottom_left())
  assert_true(
    rect.to_quad() ==
    [
      @moui_skia.Point::new(1, 2),
      @moui_skia.Point::new(4, 2),
      @moui_skia.Point::new(4, 6),
      @moui_skia.Point::new(1, 6),
    ],
  )
  assert_true(
    rect.to_quad(direction=CCW) ==
    [
      @moui_skia.Point::new(1, 2),
      @moui_skia.Point::new(1, 6),
      @moui_skia.Point::new(4, 6),
      @moui_skia.Point::new(4, 2),
    ],
  )
}

///|
test "matrix maps point" {
  let point = @moui_skia.Point::new(2, 3)
  let matrix = @moui_skia.Matrix::scale_translate(2, 4, 10, 20)
  assert_true(matrix.map_point(point) == @moui_skia.Point::new(14, 32))
  assert_true(matrix.is_scale_translate())
}

///|
test "surface descriptors model raster window and gpu contracts" {
  let size = @moui_skia.ISize::new(32, 24)
  let raster = @moui_skia.SurfaceDescriptor::raster_n32_premul(size)
  assert_true(raster.backend == Raster)
  assert_true(raster.image_info == @moui_skia.ImageInfo::n32_premul(size))
  assert_true(raster.origin == TopLeft)
  assert_eq(raster.sample_count, 1)
  assert_eq(raster.stencil_bits, 0)
  assert_true(raster.budget == Unbudgeted)
  assert_true(raster.is_raster())
  assert_true(!raster.is_window())
  assert_true(!raster.is_gpu())
  assert_true(!raster.is_msaa())
  assert_true(!raster.is_budgeted())
  assert_eq(raster.width(), 32)
  assert_eq(raster.height(), 24)
  assert_true(raster.bounds() == @moui_skia.IRect::from_wh(32, 24))
  assert_true(raster.resource_key().kind == SurfaceResource)
  assert_true(raster.resource_key() == raster.resource_key())
  let raster_resource = raster.resource_descriptor()
  assert_true(raster_resource.is_cacheable())
  assert_true(!raster_resource.is_gpu_backed())
  assert_eq(raster_resource.byte_size, 3072L)

  let window = @moui_skia.SurfaceDescriptor::window_n32_premul(
    size,
    sample_count=4,
    stencil_bits=8,
  )
  assert_true(window.is_window())
  assert_true(window.is_msaa())
  assert_eq(window.sample_count, 4)
  assert_eq(window.stencil_bits, 8)
  assert_true(window.resource_key().kind == SurfaceResource)
  assert_true(window.resource_key() != raster.resource_key())

  let gpu = @moui_skia.SurfaceDescriptor::gpu_n32_premul(
    size,
    origin=BottomLeft,
    sample_count=4,
    stencil_bits=8,
  )
  assert_true(gpu.is_gpu())
  assert_true(gpu.origin == BottomLeft)
  assert_true(gpu.is_budgeted())
  assert_true(gpu.with_budget(Unbudgeted).budget == Unbudgeted)
  assert_true(
    gpu.with_dimensions(@moui_skia.ISize::new(8, 6)).dimensions() ==
    @moui_skia.ISize::new(8, 6),
  )
  assert_eq(gpu.with_sample_count(-2).sample_count, 1)
  assert_eq(gpu.with_stencil_bits(-2).stencil_bits, 0)
  let gpu_resource = gpu.resource_descriptor()
  assert_true(gpu_resource.key.kind == GpuSurfaceResource)
  assert_true(gpu_resource.is_gpu_backed())
  assert_eq(gpu_resource.byte_size, 12288L)

  let empty = @moui_skia.SurfaceDescriptor::raster_n32_premul(
    @moui_skia.ISize::empty(),
  )
  assert_true(empty.is_empty())
  assert_true(empty.resource_key().is_empty())
  assert_true(!empty.resource_descriptor().is_cacheable())
}

///|
test "surface target descriptors model present modes and frame pacing" {
  let raster = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(8, 8),
  )
  assert_true(!raster.surface.is_presentable())
  assert_true(!raster.is_presentable())
  assert_true(!raster.needs_present())
  assert_true(raster.present_mode is None)
  assert_eq(raster.max_frames_in_flight, 1)
  assert_true(!raster.with_present_mode(ImmediatePresent).is_presentable())
  assert_true(!raster.with_target_id(b"ignored-raster").has_target_id())

  let window = @moui_skia.SurfaceTargetDescriptor::window_n32_premul(
    @moui_skia.ISize::new(32, 24),
    present_mode=MailboxPresent,
    max_frames_in_flight=3,
  )
  assert_true(window.surface.is_window())
  assert_true(window.surface.is_presentable())
  assert_true(window.is_presentable())
  assert_true(window.needs_present())
  assert_true(window.is_multibuffered())
  assert_true(window.present_mode == Some(MailboxPresent))
  assert_true(window.resource_key().kind == SurfaceResource)
  assert_true(window.resource_descriptor().is_cacheable())
  assert_eq(window.resource_descriptor().byte_size, 3072L)
  let named_window = window.with_target_id(b"window:main")
  assert_true(named_window.has_target_id())
  assert_true(named_window.target_id == b"window:main")
  assert_true(named_window.resource_key() != window.resource_key())
  assert_true(
    named_window.without_target_id().resource_key() == window.resource_key(),
  )
  assert_true(
    window.with_present_mode(ImmediatePresent).present_mode ==
    Some(ImmediatePresent),
  )
  assert_true(
    window.with_present_mode(ImmediatePresent).resource_key() !=
    window.resource_key(),
  )
  match window.with_present_mode(ImmediatePresent).present_mode {
    None => fail("window target should retain an immediate present mode")
    Some(mode) => assert_true(mode.allows_tearing())
  }
  assert_true(window.without_present().present_mode is None)
  assert_eq(window.with_max_frames_in_flight(-2).max_frames_in_flight, 1)
  assert_true(
    window.with_max_frames_in_flight(4).resource_key() != window.resource_key(),
  )
  assert_true(
    window.with_dimensions(@moui_skia.ISize::new(4, 2)).dimensions() ==
    @moui_skia.ISize::new(4, 2),
  )

  let gpu = @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
    @moui_skia.ISize::new(64, 48),
    origin=BottomLeft,
    present_mode=FifoPresent,
  )
  assert_true(gpu.surface.is_gpu())
  assert_true(gpu.surface.origin == BottomLeft)
  assert_true(gpu.present_mode == Some(FifoPresent))
  assert_true(gpu.resource_key().kind == GpuSurfaceResource)
  assert_true(gpu.resource_descriptor().is_gpu_backed())
  let target_plan = gpu.resource_plan()
  assert_eq(target_plan.length(), 1)
  assert_eq(target_plan.gpu_backed_count, 1)
  assert_true(target_plan.contains_key(gpu.resource_key()))
  assert_eq(target_plan.byte_size_for_kind(GpuSurfaceResource), 12288L)
  let gpu_plan = @moui_skia.RenderCommandList::for_target(gpu).resource_plan()
  assert_true(gpu_plan.has_gpu_backed_resources())
  assert_eq(gpu_plan.gpu_backed_count, 1)
  match gpu.present_mode {
    None => fail("gpu target should retain a fifo present mode")
    Some(mode) => assert_true(mode.prefers_vsync())
  }
  assert_true(gpu.bounds() == @moui_skia.IRect::from_wh(64, 48))
}

///|
test "window surface descriptors derive stable targets and resource plans" {
  let window = @moui_skia.WindowSurfaceDescriptor::new(
    window_id=b"main-window",
    logical_size=@moui_skia.Size::new(320, 200),
    device_pixel_ratio=2.0,
    sample_count=4,
    stencil_bits=8,
    present_mode=MailboxPresent,
    max_frames_in_flight=3,
  )
  assert_true(window.has_window_id())
  assert_true(!window.is_empty())
  assert_true(window.logical_dimensions() == @moui_skia.Size::new(320, 200))
  assert_true(window.dimensions() == @moui_skia.ISize::new(640, 400))
  assert_eq(window.sample_count, 4)
  assert_eq(window.stencil_bits, 8)
  assert_eq(window.max_frames_in_flight, 3)
  let target = window.target_descriptor()
  assert_true(target.surface.is_window())
  assert_true(target.is_presentable())
  assert_true(target.has_target_id())
  assert_true(target.target_id == b"main-window")
  assert_true(target.present_mode == Some(MailboxPresent))
  assert_eq(target.resource_descriptor().byte_size, 4096000L)
  assert_true(window.resource_key() == target.resource_key())
  let plan = window.resource_plan()
  assert_eq(plan.length(), 1)
  assert_true(plan.contains_key(target.resource_key()))
  assert_eq(plan.byte_size, 4096000L)

  let same_size_other_window = window.with_window_id(b"settings-window")
  assert_true(same_size_other_window.resource_key() != window.resource_key())
  assert_true(
    window.with_max_frames_in_flight(4).resource_key() != window.resource_key(),
  )
  let resized = window.with_physical_size(@moui_skia.ISize::new(800, 600))
  assert_true(resized.dimensions() == @moui_skia.ISize::new(800, 600))
  assert_true(resized.logical_dimensions() == @moui_skia.Size::new(400, 300))

  let invalid = @moui_skia.WindowSurfaceDescriptor::new(
    window_id=b"invalid-scale",
    logical_size=@moui_skia.Size::new(10, 10),
    device_pixel_ratio=0.0,
    sample_count=-4,
    stencil_bits=-2,
    max_frames_in_flight=-3,
  )
  assert_eq(invalid.device_pixel_ratio, 1.0)
  assert_true(invalid.dimensions() == @moui_skia.ISize::new(10, 10))
  assert_eq(invalid.sample_count, 1)
  assert_eq(invalid.stencil_bits, 0)
  assert_eq(invalid.max_frames_in_flight, 1)

  let context = @moui_skia.GpuContextDescriptor::vulkan(
    b"window-vulkan",
    adapter_id=b"discrete-gpu",
    device_id=b"queue-0",
  )
  let gpu_target = window.gpu_target_descriptor(
    gpu_context_key=Some(context.resource_key()),
  )
  assert_true(gpu_target.surface.is_gpu())
  assert_true(gpu_target.has_target_id())
  assert_true(gpu_target.target_id == b"main-window")
  assert_true(gpu_target.has_gpu_context())
  let gpu_plan = gpu_target.resource_plan()
  assert_eq(gpu_plan.length(), 2)
  assert_eq(gpu_plan.gpu_backed_count, 2)
  assert_true(gpu_plan.contains_key(gpu_target.resource_key()))
  assert_true(gpu_plan.contains_key(context.resource_key()))
}

///|
test "gpu context descriptors attach to gpu surface targets" {
  let anonymous = @moui_skia.GpuContextDescriptor::new(backend=MetalGpuContext)
  assert_true(anonymous.is_anonymous())
  assert_true(anonymous.resource_key().is_empty())
  assert_true(!anonymous.resource_descriptor().is_cacheable())

  let metal = @moui_skia.GpuContextDescriptor::metal(
    b"main-metal",
    adapter_id=b"apple-gpu",
    device_id=b"m2",
  ).with_protected_context(true)
  let same_metal = @moui_skia.GpuContextDescriptor::metal(
    b"main-metal",
    adapter_id=b"apple-gpu",
    device_id=b"m2",
  ).with_protected_context(true)
  assert_true(metal.backend.is_native_window_backend())
  assert_true(metal.resource_key() == same_metal.resource_key())
  assert_true(metal.resource_key().kind == GpuContextResource)
  assert_true(metal.resource_descriptor().is_gpu_backed())
  assert_true(!metal.resource_descriptor().key.kind.is_surface())

  let vulkan = @moui_skia.GpuContextDescriptor::vulkan(
    b"vk-0",
    adapter_id=b"discrete",
    device_id=b"queue",
    queue_family_index=-4,
  )
  assert_eq(vulkan.queue_family_index, 0)
  assert_true(vulkan.resource_key() != metal.resource_key())
  assert_true(@moui_skia.GpuContextDescriptor::mock().backend.is_mock())

  let gpu = @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
    @moui_skia.ISize::new(64, 48),
    gpu_context_key=Some(metal.resource_key()),
  )
  assert_true(gpu.has_gpu_context())
  assert_true(gpu.gpu_context_key == Some(metal.resource_key()))
  assert_true(gpu.resource_key() != gpu.without_gpu_context().resource_key())
  guard gpu.gpu_context_resource_descriptor() is Some(context_descriptor) else {
    fail("gpu target should expose its context resource descriptor")
  }
  assert_true(context_descriptor.key == metal.resource_key())
  assert_true(context_descriptor.is_gpu_backed())
  let target_plan = gpu.resource_plan()
  assert_eq(target_plan.length(), 2)
  assert_eq(target_plan.gpu_backed_count, 2)
  assert_true(target_plan.contains_key(gpu.resource_key()))
  assert_true(target_plan.contains_key(metal.resource_key()))
  assert_eq(target_plan.count_kind(GpuContextResource), 1)
  assert_eq(target_plan.count_kind(GpuSurfaceResource), 1)

  let gpu_plan = @moui_skia.RenderCommandList::for_target(gpu).resource_plan()
  assert_eq(gpu_plan.length(), 2)
  assert_eq(gpu_plan.gpu_backed_count, 2)
  assert_true(gpu_plan.has_gpu_backed_resources())
  assert_true(
    @moui_skia.RenderCommandList::for_target(gpu).commands[0].is_resource_declaration(),
  )

  let window = @moui_skia.SurfaceTargetDescriptor::window_n32_premul(
    @moui_skia.ISize::new(64, 48),
  ).with_gpu_context(metal)
  assert_true(!window.has_gpu_context())
}

///|
test "surface present descriptors track frame pacing slots and resources" {
  let target = @moui_skia.SurfaceTargetDescriptor::window_n32_premul(
    @moui_skia.ISize::new(64, 48),
    present_mode=MailboxPresent,
    max_frames_in_flight=3,
    target_id=b"main-window",
  )
  let present = target.present_descriptor(frame_index=5)
  assert_true(present.is_presentable())
  assert_eq(present.frame_index, 5)
  assert_eq(present.buffer_index, 2)
  assert_true(present.present_mode == Some(MailboxPresent))
  assert_true(!present.prefers_vsync())
  assert_true(!present.allows_tearing())
  let present_key = present.resource_key()
  assert_true(present_key.kind == SurfaceResource)
  assert_true(present_key == present.resource_key())
  assert_true(
    present_key != target.present_descriptor(frame_index=6).resource_key(),
  )
  assert_true(
    present_key !=
    target.present_descriptor(frame_index=5, buffer_index=1).resource_key(),
  )
  assert_true(
    present_key !=
    target
    .with_present_mode(ImmediatePresent)
    .present_descriptor(frame_index=5)
    .resource_key(),
  )
  let explicit_buffer = target.present_descriptor(frame_index=5, buffer_index=7)
  assert_eq(explicit_buffer.buffer_index, 1)
  let present_resource = present.resource_descriptor()
  assert_true(present_resource.key == present_key)
  assert_true(!present_resource.is_cacheable())
  assert_true(present_resource.byte_size > 0L)
  let plan = present.resource_plan()
  assert_eq(plan.length(), 2)
  assert_eq(plan.cacheable_count, 1)
  assert_eq(plan.uncacheable_count, 1)
  assert_eq(plan.count_kind(SurfaceResource), 2)
  assert_true(plan.contains_key(target.resource_key()))
  assert_true(plan.contains_key(present_key))
  let finalization = target.finalization_descriptor(frame_index=5)
  assert_true(finalization.is_finalizable())
  assert_true(!finalization.requires_gpu_context())
  assert_eq(finalization.frame_index, 5)
  let finalization_key = finalization.resource_key()
  assert_true(finalization_key.kind == SurfaceResource)
  assert_true(finalization_key != present_key)
  assert_true(finalization_key == finalization.resource_key())
  assert_true(
    finalization_key !=
    target.finalization_descriptor(frame_index=6).resource_key(),
  )
  assert_true(
    finalization_key !=
    target
    .with_present_mode(ImmediatePresent)
    .finalization_descriptor(frame_index=5)
    .resource_key(),
  )
  let finalization_resource = finalization.resource_descriptor()
  assert_true(finalization_resource.key == finalization_key)
  assert_true(!finalization_resource.is_cacheable())
  assert_true(finalization_resource.byte_size > 0L)
  let finalization_plan = finalization.resource_plan()
  assert_eq(finalization_plan.length(), 2)
  assert_eq(finalization_plan.cacheable_count, 1)
  assert_eq(finalization_plan.uncacheable_count, 1)
  assert_eq(finalization_plan.count_kind(SurfaceResource), 2)
  assert_true(finalization_plan.contains_key(target.resource_key()))
  assert_true(finalization_plan.contains_key(finalization_key))

  let fifo = target
    .with_present_mode(FifoPresent)
    .present_descriptor(frame_index=0)
  assert_true(fifo.prefers_vsync())
  assert_true(!fifo.allows_tearing())
  let immediate = target
    .with_present_mode(ImmediatePresent)
    .present_descriptor(frame_index=0)
  assert_true(!immediate.prefers_vsync())
  assert_true(immediate.allows_tearing())

  let gpu_context = @moui_skia.GpuContextDescriptor::mock(
    id=b"present-gpu-context",
  )
  let gpu_target = @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
    @moui_skia.ISize::new(64, 48),
    gpu_context_key=Some(gpu_context.resource_key()),
  )
  let gpu_present = gpu_target.present_descriptor(frame_index=2)
  let gpu_plan = gpu_present.resource_plan()
  assert_true(gpu_present.resource_key().kind == GpuSurfaceResource)
  assert_eq(gpu_plan.length(), 3)
  assert_eq(gpu_plan.gpu_backed_count, 3)
  assert_eq(gpu_plan.cacheable_count, 2)
  assert_eq(gpu_plan.uncacheable_count, 1)
  assert_true(gpu_plan.contains_key(gpu_target.resource_key()))
  assert_true(gpu_plan.contains_key(gpu_context.resource_key()))
  assert_true(gpu_plan.contains_key(gpu_present.resource_key()))
  let gpu_finalization = gpu_target.finalization_descriptor(frame_index=2)
  let gpu_finalization_plan = gpu_finalization.resource_plan()
  assert_true(gpu_finalization.requires_gpu_context())
  assert_true(gpu_finalization.resource_key().kind == GpuSurfaceResource)
  assert_eq(gpu_finalization_plan.length(), 3)
  assert_eq(gpu_finalization_plan.gpu_backed_count, 3)
  assert_eq(gpu_finalization_plan.cacheable_count, 2)
  assert_eq(gpu_finalization_plan.uncacheable_count, 1)
  assert_eq(gpu_finalization_plan.count_kind(GpuSurfaceResource), 2)
  assert_eq(gpu_finalization_plan.count_kind(GpuContextResource), 1)
  assert_true(gpu_finalization_plan.contains_key(gpu_target.resource_key()))
  assert_true(gpu_finalization_plan.contains_key(gpu_context.resource_key()))
  assert_true(
    gpu_finalization_plan.contains_key(gpu_finalization.resource_key()),
  )

  let raster_present = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(16, 16),
  ).present_descriptor(frame_index=4)
  assert_true(!raster_present.is_presentable())
  assert_true(raster_present.resource_key().is_empty())
  assert_true(!raster_present.resource_descriptor().is_cacheable())
  assert_true(raster_present.resource_plan().is_empty())
  let empty_finalization = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::empty(),
  ).finalization_descriptor(frame_index=-4)
  assert_eq(empty_finalization.frame_index, 0)
  assert_true(!empty_finalization.is_finalizable())
  assert_true(empty_finalization.resource_key().is_empty())
  assert_true(!empty_finalization.resource_descriptor().is_cacheable())
  assert_true(empty_finalization.resource_plan().is_empty())
}

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

///|
test "render pass descriptor clips clear and present boundaries" {
  let surface = @moui_skia.SurfaceDescriptor::window_n32_premul(
    @moui_skia.ISize::new(20, 10),
    sample_count=4,
    stencil_bits=8,
  )
  let pass = @moui_skia.RenderPassDescriptor::clear(
    surface,
    @moui_skia.Color::black(),
    bounds=Some(@moui_skia.IRect::from_xywh(5, -5, 20, 20)),
    store_op=PresentPixels,
  )
  assert_true(pass.surface == surface)
  assert_true(pass.bounds == @moui_skia.IRect::new(5, 0, 20, 10))
  assert_true(pass.load_op == ClearBeforeDraw)
  assert_true(pass.clear_color == Some(@moui_skia.Color::black()))
  assert_true(pass.store_op == PresentPixels)
  assert_true(pass.needs_clear())
  assert_true(pass.needs_present())
  assert_true(pass.keeps_pixels())
  assert_true(pass.is_msaa())
  assert_true(pass.resource_descriptor().key.kind == SurfaceResource)
  assert_true(pass.resource_descriptor().key == surface.resource_key())
  assert_eq(pass.resource_descriptor().byte_size, 3200L)

  let load = @moui_skia.RenderPassDescriptor::new(surface)
  let unbound_target = @moui_skia.SurfaceTargetDescriptor::window_n32_premul(
    @moui_skia.ISize::new(20, 10),
    sample_count=4,
    stencil_bits=8,
  )
  assert_true(!load.has_target_binding())
  assert_true(load.is_bound_to_target(unbound_target))
  assert_true(load.load_op == LoadExisting)
  assert_true(load.clear_color is None)
  assert_true(load.store_op == StorePixels)
  assert_true(load.bounds == surface.bounds())
  assert_true(load.with_store_op(DiscardPixels).store_op == DiscardPixels)
  assert_true(load.with_clear_color(@moui_skia.Color::red()).needs_clear())
  assert_true(
    load.with_clear_color(@moui_skia.Color::red()).without_clear().clear_color
    is None,
  )

  let outside = pass.with_bounds(@moui_skia.IRect::from_xywh(99, 99, 4, 4))
  assert_true(outside.is_empty())
  assert_true(outside.bounds == @moui_skia.IRect::empty())
}

///|
test "render pass descriptor derives present defaults from surface targets" {
  let raster_target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(16, 16),
  )
  let raster_pass = @moui_skia.RenderPassDescriptor::for_target(raster_target)
  assert_true(raster_pass.has_target_binding())
  assert_true(raster_pass.is_bound_to_target(raster_target))
  assert_true(
    raster_pass.resource_descriptor().key == raster_target.resource_key(),
  )
  assert_true(
    raster_pass.resource_descriptor().key !=
    raster_target.surface.resource_key(),
  )
  assert_true(!raster_pass.needs_present())
  assert_true(raster_pass.keeps_pixels())
  assert_true(raster_pass.store_op == StorePixels)

  let window_target = @moui_skia.SurfaceTargetDescriptor::window_n32_premul(
    @moui_skia.ISize::new(20, 10),
    sample_count=4,
    stencil_bits=8,
  )
  let present_pass = @moui_skia.RenderPassDescriptor::for_target(
    window_target,
    bounds=Some(@moui_skia.IRect::from_xywh(4, 2, 30, 30)),
  )
  assert_true(present_pass.needs_present())
  assert_true(present_pass.has_target_binding())
  assert_true(present_pass.is_bound_to_target(window_target))
  assert_true(
    !present_pass.is_bound_to_target(window_target.with_target_id(b"other")),
  )
  assert_true(
    present_pass.resource_descriptor().key == window_target.resource_key(),
  )
  assert_true(
    present_pass.resource_descriptor().key !=
    window_target.surface.resource_key(),
  )
  assert_true(present_pass.keeps_pixels())
  assert_true(present_pass.store_op == PresentPixels)
  assert_true(present_pass.bounds == @moui_skia.IRect::new(4, 2, 20, 10))
  assert_true(present_pass.is_msaa())

  let clear_pass = @moui_skia.RenderPassDescriptor::clear_target(
    window_target,
    @moui_skia.Color::blue(),
  )
  assert_true(clear_pass.needs_clear())
  assert_true(clear_pass.needs_present())
  assert_true(clear_pass.clear_color == Some(@moui_skia.Color::blue()))
  assert_true(
    clear_pass.resource_descriptor().key == window_target.resource_key(),
  )

  let discard_pass = @moui_skia.RenderPassDescriptor::for_target(
    window_target.without_present(),
    store_op=Some(DiscardPixels),
  )
  assert_true(!discard_pass.needs_present())
  assert_true(!discard_pass.keeps_pixels())
  assert_true(discard_pass.store_op == DiscardPixels)
}

///|
test "render command list tracks stats balance and touched bounds" {
  let target = @moui_skia.SurfaceTargetDescriptor::window_n32_premul(
    @moui_skia.ISize::new(40, 20),
  )
  let path = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(5, 5))
    .line_to(@moui_skia.Point::new(12, 7))
  let commands = @moui_skia.RenderCommandList::for_target(
      target,
      bounds=Some(@moui_skia.IRect::from_xywh(0, 0, 30, 10)),
    )
    .save()
    .clip_rect(@moui_skia.Rect::from_xywh(0, 0, 12, 8))
    .draw_rect(
      @moui_skia.Rect::from_xywh(2, 2, 8, 4),
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::red()),
    )
    .draw_path(
      path,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::blue()),
    )
    .draw_text_utf8(
      b"Skia",
      @moui_skia.Point::new(4, 8),
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::black()),
    )
    .restore()
    .finish()
  let stats = commands.stats()
  assert_eq(commands.length(), 7)
  assert_eq(stats.command_count, 7)
  assert_eq(stats.draw_count, 3)
  assert_eq(stats.clip_count, 1)
  assert_eq(stats.state_count, 2)
  assert_eq(stats.transform_count, 0)
  assert_eq(stats.present_count, 1)
  assert_eq(stats.text_count, 1)
  assert_eq(stats.resource_declaration_count, 0)
  assert_eq(stats.image_resource_count, 0)
  assert_eq(stats.shader_resource_count, 0)
  assert_eq(stats.filter_resource_count, 0)
  assert_eq(stats.path_resource_count, 1)
  assert_eq(stats.text_resource_count, 0)
  assert_eq(stats.max_save_depth, 1)
  assert_true(stats.is_state_balanced())
  assert_true(commands.is_state_balanced())
  assert_true(commands.has_present())
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::new(2, 0, 12, 8)),
  )
  assert_true(commands.finish().length() == commands.length())

  let raster_commands = @moui_skia.RenderCommandList::for_target(
      @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
        @moui_skia.ISize::new(8, 8),
      ),
    )
    .clear(@moui_skia.Color::white())
    .finish()
  assert_true(!raster_commands.has_present())
  assert_true(
    raster_commands.touched_bounds() == Some(@moui_skia.Rect::from_iwh(8, 8)),
  )

  let unbalanced = @moui_skia.RenderCommandList::for_target(target).restore()
  assert_true(!unbalanced.is_state_balanced())
  assert_eq(unbalanced.stats().unbalanced_restore_count, 1)
}

///|
test "render command list records canvas fill commands" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(20, 20),
  )
  let paint = @moui_skia.Paint::new(
    color=@moui_skia.Color::blue(),
    blend_mode=Src,
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(4, 4, 8, 8))
    .draw_color(@moui_skia.Color::red(), blend_mode=Src)
    .draw_paint(paint~)
  let stats = commands.stats()
  assert_eq(commands.length(), 3)
  assert_eq(stats.draw_count, 2)
  assert_eq(stats.clip_count, 1)
  assert_eq(stats.clear_count, 0)
  assert_eq(stats.resource_declaration_count, 0)
  assert_true(commands.commands[1].is_draw())
  assert_true(commands.commands[2].is_draw())
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::from_xywh(4, 4, 8, 8)),
  )

  let unclipped = @moui_skia.RenderCommandList::for_target(target).draw_color(
    @moui_skia.Color::green(),
  )
  assert_true(
    unclipped.touched_bounds() == Some(@moui_skia.Rect::from_iwh(20, 20)),
  )

  let shader = @moui_skia.ShaderDescriptor::color(@moui_skia.Color::cyan())
  let shader_fill = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(5, 5, 6, 6))
    .draw_paint_shader(shader)
  let shader_fill_stats = shader_fill.stats()
  assert_eq(shader_fill.length(), 2)
  assert_eq(shader_fill_stats.draw_count, 1)
  assert_eq(shader_fill_stats.clip_count, 1)
  assert_eq(shader_fill_stats.shader_resource_count, 1)
  assert_true(
    shader_fill.commands[1].resource_descriptor() ==
    Some(shader.resource_descriptor()),
  )
  assert_true(shader_fill.resource_plan().contains_key(shader.resource_key()))
  assert_true(
    shader_fill.touched_bounds() == Some(@moui_skia.Rect::from_xywh(5, 5, 6, 6)),
  )
}

///|
test "render command list estimates text touched bounds" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(80, 40),
  )
  let legacy = @moui_skia.RenderCommandList::for_target(target).draw_text_utf8(
    b"abc",
    @moui_skia.Point::new(4, 20),
  )
  assert_true(
    legacy.touched_bounds() == Some(@moui_skia.Rect::new(4, 8, 28, 24)),
  )

  let ltr_run = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(1, 4),
  )
  let ltr = @moui_skia.RenderCommandList::for_target(target).draw_text_run_utf8(
    b"abcde",
    @moui_skia.Point::new(10, 20),
    descriptor=Some(ltr_run),
  )
  assert_true(ltr.touched_bounds() == Some(@moui_skia.Rect::new(10, 8, 34, 24)))

  let rtl_run = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(1, 4),
    direction=RightToLeft,
  )
  let rtl = @moui_skia.RenderCommandList::for_target(target).draw_text_run_utf8(
    b"abcde",
    @moui_skia.Point::new(30, 20),
    descriptor=Some(rtl_run),
  )
  assert_true(rtl.touched_bounds() == Some(@moui_skia.Rect::new(6, 8, 30, 24)))

  let clipped = @moui_skia.RenderCommandList::for_target(target)
    .translate(@moui_skia.Point::new(10, 0))
    .clip_rect(@moui_skia.Rect::from_xywh(0, 0, 20, 16))
    .draw_text_utf8(b"abcd", @moui_skia.Point::new(0, 12))
  assert_true(
    clipped.touched_bounds() == Some(@moui_skia.Rect::from_xywh(10, 0, 20, 16)),
  )

  let empty = @moui_skia.RenderCommandList::for_target(target)
    .draw_text_utf8(b"", @moui_skia.Point::new(4, 20))
    .draw_text_run_utf8(
      b"abc",
      @moui_skia.Point::new(10, 20),
      descriptor=Some(
        @moui_skia.TextRunDescriptor::new(range=@moui_skia.TextRange::new(3, 3)),
      ),
    )
  assert_true(empty.touched_bounds() is None)
}

///|
test "render command list records transform commands" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(24, 24),
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .save()
    .translate(@moui_skia.Point::new(2, 3))
    .scale(@moui_skia.Size::new(2, 2))
    .rotate(45)
    .skew(@moui_skia.Point::new(0.1, 0.2))
    .concat(@moui_skia.Matrix::translate(1, 2))
    .reset_matrix()
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 4))
    .restore()
  let stats = commands.stats()
  assert_eq(commands.length(), 9)
  assert_eq(stats.command_count, 9)
  assert_eq(stats.state_count, 8)
  assert_eq(stats.transform_count, 6)
  assert_eq(stats.draw_count, 1)
  assert_eq(stats.max_save_depth, 1)
  assert_true(stats.is_state_balanced())
  assert_true(commands.commands[1].is_transform())
  assert_true(commands.commands[6].is_transform())
  assert_true(!commands.commands[7].is_transform())

  let translated = @moui_skia.RenderCommandList::for_target(target)
    .translate(@moui_skia.Point::new(10, 2))
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 4))
  assert_true(
    translated.touched_bounds() == Some(@moui_skia.Rect::from_xywh(11, 3, 4, 4)),
  )

  let restored = @moui_skia.RenderCommandList::for_target(target)
    .save()
    .translate(@moui_skia.Point::new(10, 2))
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 4))
    .restore()
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 4))
  assert_true(
    restored.touched_bounds() == Some(@moui_skia.Rect::new(1, 1, 15, 7)),
  )

  let rotated = @moui_skia.RenderCommandList::for_target(target)
    .rotate(90)
    .draw_rect(@moui_skia.Rect::from_xywh(1, -3, 4, 2))
  assert_true(
    test_optional_rect_near(
      rotated.touched_bounds(),
      @moui_skia.Rect::new(1, 1, 3, 5),
    ),
  )
}

///|
test "render command touched bounds respect rectangular clips" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(32, 32),
  )
  let clipped = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(4, 4, 8, 8))
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 16, 16))
  assert_true(
    clipped.touched_bounds() == Some(@moui_skia.Rect::from_xywh(4, 4, 8, 8)),
  )

  let empty_clip = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(20, 20, 4, 4))
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 4))
  assert_true(empty_clip.touched_bounds() is None)

  let restored_clip = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(4, 4, 8, 8))
    .save()
    .clip_rect(@moui_skia.Rect::from_xywh(6, 6, 2, 2))
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 16, 16))
    .restore()
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 16, 16))
  assert_true(
    restored_clip.touched_bounds() ==
    Some(@moui_skia.Rect::from_xywh(4, 4, 8, 8)),
  )

  let transformed_clip = @moui_skia.RenderCommandList::for_target(target)
    .translate(@moui_skia.Point::new(4, 0))
    .clip_rect(@moui_skia.Rect::from_xywh(0, 0, 4, 4))
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 8, 8))
  assert_true(
    transformed_clip.touched_bounds() ==
    Some(@moui_skia.Rect::from_xywh(4, 0, 4, 4)),
  )

  let rounded_clip = @moui_skia.RRect::from_rect_xy(
    @moui_skia.Rect::from_xywh(4, 4, 12, 12),
    3.0,
    3.0,
  )
  let path_clip = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(6, 6, 6, 6),
  )
  let rounded_path_clip = @moui_skia.RenderCommandList::for_target(target)
    .clip_rrect(rounded_clip)
    .clip_path(path_clip)
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 16, 16))
  let rounded_path_stats = rounded_path_clip.stats()
  assert_eq(rounded_path_stats.clip_count, 2)
  assert_eq(rounded_path_stats.path_resource_count, 1)
  assert_true(rounded_path_clip.commands[0].is_clip())
  assert_true(rounded_path_clip.commands[1].is_clip())
  assert_true(
    rounded_path_clip.commands[1].resource_descriptor() ==
    Some(path_clip.resource_descriptor()),
  )
  assert_true(
    rounded_path_clip.resource_plan().contains_key(path_clip.resource_key()),
  )
  assert_true(
    rounded_path_clip.touched_bounds() ==
    Some(@moui_skia.Rect::from_xywh(6, 6, 6, 6)),
  )

  let difference_clip = @moui_skia.RenderCommandList::for_target(target)
    .clip_rect(@moui_skia.Rect::from_xywh(4, 4, 8, 8), op=Difference)
    .draw_rect(@moui_skia.Rect::from_xywh(0, 0, 16, 16))
  assert_true(
    difference_clip.touched_bounds() ==
    Some(@moui_skia.Rect::from_xywh(0, 0, 16, 16)),
  )
}

///|
test "render command list records rounded geometry draw commands" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(32, 32),
  )
  let rrect = @moui_skia.RRect::from_rect_xy(
    @moui_skia.Rect::from_xywh(12, 3, 8, 5),
    2.0,
    2.0,
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .draw_oval(@moui_skia.Rect::from_xywh(2, 2, 6, 4))
    .draw_circle(@moui_skia.Point::new(12, 12), 3.0)
    .draw_round_rect(@moui_skia.Rect::from_xywh(4, 16, 9, 5), 2.0, 2.0)
    .draw_rrect(rrect)
    .draw_drrect(
      @moui_skia.RRect::from_rect_xy(
        @moui_skia.Rect::from_xywh(18, 18, 10, 10),
        3.0,
        3.0,
      ),
      @moui_skia.RRect::from_rect_xy(
        @moui_skia.Rect::from_xywh(20, 20, 4, 4),
        1.0,
        1.0,
      ),
    )
  let stats = commands.stats()
  assert_eq(commands.length(), 5)
  assert_eq(stats.draw_count, 5)
  assert_eq(stats.text_count, 0)
  assert_true(stats.is_state_balanced())
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::from_xywh(2, 2, 26, 26)),
  )
}

///|
test "render command list records point line and arc draw commands" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(32, 32),
  )
  let stroke = @moui_skia.Paint::new(
    color=@moui_skia.Color::green(),
    style=Stroke,
    stroke_width=2.0,
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .draw_point(@moui_skia.Point::new(2, 2), paint=stroke)
    .draw_line(
      @moui_skia.Point::new(6, 2),
      @moui_skia.Point::new(12, 2),
      paint=stroke,
    )
    .draw_points(
      [
        @moui_skia.Point::new(4, 12),
        @moui_skia.Point::new(10, 12),
        @moui_skia.Point::new(16, 12),
      ],
      paint=stroke,
      mode=Polygon,
    )
    .draw_arc(
      @moui_skia.Rect::from_xywh(18, 18, 6, 6),
      0.0,
      180.0,
      false,
      paint=stroke,
    )
  let stats = commands.stats()
  assert_eq(commands.length(), 4)
  assert_eq(stats.draw_count, 4)
  assert_eq(stats.text_count, 0)
  assert_true(stats.is_state_balanced())
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::from_xywh(1, 1, 24, 24)),
  )

  let line_pairs = @moui_skia.RenderCommandList::for_target(target).draw_points(
    [
      @moui_skia.Point::new(2, 2),
      @moui_skia.Point::new(6, 2),
      @moui_skia.Point::new(30, 30),
    ],
    paint=stroke,
    mode=Lines,
  )
  assert_true(
    line_pairs.touched_bounds() == Some(@moui_skia.Rect::new(1, 1, 7, 3)),
  )
}

///|
test "render command list exposes text run resource keys" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(32, 16),
  )
  let fallback = @moui_skia.FontFallbackRequest::new(
    families=@moui_skia.FontFallbackChain::new(primary_family=b"Inter"),
    bcp47=[b"en"],
    character=0x68,
    style=@moui_skia.FontStyleRequest::normal(),
  )
  let descriptor = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(0, 5),
    fallback~,
  )
  let font_key = @moui_skia.RendererResourceKey::font(b"Inter:16:400")
  let expected_key = descriptor.resource_key(b"hello", font_key~)
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .draw_text_run_utf8(
      b"hello",
      @moui_skia.Point::new(2, 12),
      descriptor=Some(descriptor),
      font_key~,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::black()),
    )
    .draw_text_utf8(b"legacy", @moui_skia.Point::new(2, 8))
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
      @moui_skia.Path::new().add_rect(@moui_skia.Rect::from_xywh(0, 0, 4, 4)),
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::blue()),
    )
    .draw_text_run_utf8(
      b"hello",
      @moui_skia.Point::new(4, 12),
      descriptor=Some(descriptor),
      font_key~,
    )
    .resource_descriptors()
  assert_eq(descriptors.length(), 5)
  assert_true(descriptors[0].key.kind == SurfaceResource)
  assert_true(descriptors[0].key == target.resource_key())
  assert_true(descriptors[0].key != target.surface.resource_key())
  assert_eq(descriptors[0].byte_size, 2048L)
  let mut path_descriptor_seen = false
  let mut text_descriptor : @moui_skia.RendererResourceDescriptor? = None
  let mut font_descriptor_seen = false
  let mut fallback_descriptor_seen = false
  for descriptor in descriptors {
    if descriptor.key.kind == PathResource {
      path_descriptor_seen = descriptor.is_cacheable()
    }
    if descriptor.key == expected_key {
      text_descriptor = Some(descriptor)
    }
    if descriptor.key == font_key {
      font_descriptor_seen = descriptor.is_cacheable()
    }
    if descriptor.key == fallback.resource_key() {
      fallback_descriptor_seen = descriptor.is_cacheable()
    }
  }
  assert_true(path_descriptor_seen)
  assert_true(font_descriptor_seen)
  assert_true(fallback_descriptor_seen)
  guard text_descriptor is Some(text_descriptor) else {
    fail("text run descriptor should be included in resource plan")
  }
  assert_eq(text_descriptor.byte_size, 5L)
  assert_true(text_descriptor.is_cacheable())
  let plan = commands
    .draw_path(
      @moui_skia.Path::new().add_rect(@moui_skia.Rect::from_xywh(0, 0, 4, 4)),
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::blue()),
    )
    .draw_text_run_utf8(
      b"hello",
      @moui_skia.Point::new(4, 12),
      descriptor=Some(descriptor),
      font_key~,
    )
    .resource_plan()
  assert_eq(plan.length(), 5)
  assert_true(plan.byte_size > 2053L)
  assert_eq(plan.cacheable_count, 5)
  assert_eq(plan.uncacheable_count, 0)
  assert_eq(plan.gpu_backed_count, 0)
  assert_eq(plan.count_kind(FontResource), 1)
  assert_eq(plan.count_kind(TypefaceResource), 1)

  let cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new(max_bytes=8L)
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
test "render command list records shaped glyph run resources" {
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(48, 24),
  )
  let fallback = @moui_skia.FontFallbackRequest::new(
    families=@moui_skia.FontFallbackChain::new(primary_family=b"Inter"),
    bcp47=[b"en"],
    character=0x68,
  )
  let run = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(0, 5),
    fallback~,
  )
  let shaping = @moui_skia.TextShapingDescriptor::new(
    run~,
    font_key=@moui_skia.RendererResourceKey::font(b"Inter:14"),
    width=128.0,
  )
  let shaped = shaping.shaped_run_descriptor(
    glyph_count=5,
    cluster_count=5,
    advance=@moui_skia.Point::new(18.0, 6.0),
  )
  let glyph_run = shaped.glyph_run_descriptor(
    glyph_ids=[7, 8, 9, 10, 11],
    positions=[
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(4.0, 0.0),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(12.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters=[0, 1, 2, 3, 4],
  )
  let command = @moui_skia.RenderCommand::draw_shaped_glyph_run_utf8(
    b"hello",
    glyph_run,
    @moui_skia.Point::new(2.0, 3.0),
    paint=@moui_skia.Paint::new(color=@moui_skia.Color::black()),
  )
  assert_true(command.is_draw())
  assert_true(command.is_text())
  assert_true(
    command.text_run_resource_key() == Some(glyph_run.resource_key(b"hello")),
  )
  guard command.resource_descriptor() is Some(glyph_descriptor) else {
    fail("shaped glyph command should expose its primary resource descriptor")
  }
  assert_true(glyph_descriptor.key == glyph_run.resource_key(b"hello"))
  let command_descriptors = command.resource_descriptors()
  assert_eq(command_descriptors.length(), 6)
  assert_true(command_descriptors[0].key == glyph_run.resource_key(b"hello"))
  assert_eq(command.text_resource_count(), 6)

  let commands = @moui_skia.RenderCommandList::for_target(target).draw_shaped_glyph_run_utf8(
    b"hello",
    glyph_run,
    @moui_skia.Point::new(2.0, 3.0),
    paint=@moui_skia.Paint::new(color=@moui_skia.Color::black()),
  )
  let stats = commands.stats()
  assert_eq(stats.command_count, 1)
  assert_eq(stats.draw_count, 1)
  assert_eq(stats.text_count, 1)
  assert_eq(stats.resource_declaration_count, 0)
  assert_eq(stats.image_resource_count, 0)
  assert_eq(stats.shader_resource_count, 0)
  assert_eq(stats.filter_resource_count, 0)
  assert_eq(stats.path_resource_count, 0)
  assert_eq(stats.text_resource_count, 6)
  assert_true(
    commands.text_run_resource_keys() == [glyph_run.resource_key(b"hello")],
  )
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::new(2.0, 3.0, 20.0, 9.0)),
  )
  let descriptors = commands.resource_descriptors()
  assert_eq(descriptors.length(), 7)
  assert_true(descriptors[0].key == target.resource_key())
  let plan = commands.resource_plan()
  assert_eq(plan.length(), 7)
  assert_eq(plan.count_kind(SurfaceResource), 1)
  assert_eq(plan.count_kind(TextRunResource), 4)
  assert_eq(plan.count_kind(FontResource), 1)
  assert_eq(plan.count_kind(TypefaceResource), 1)
  assert_true(plan.contains_key(glyph_run.resource_key(b"hello")))
  assert_true(plan.contains_key(shaped.resource_key(b"hello")))
  assert_true(plan.contains_key(shaping.resource_key(b"hello")))
  assert_true(
    plan.contains_key(run.resource_key(b"hello", font_key=shaping.font_key)),
  )
  let frame = commands.frame_descriptor(target)
  assert_true(frame.is_ready())
  assert_eq(frame.resource_plan.length(), 7)
  assert_true(
    frame.resource_plan.contains_key(glyph_run.resource_key(b"hello")),
  )

  let invalid_glyph_run = shaping
    .shaped_run_descriptor(glyph_count=0)
    .glyph_run_descriptor()
  assert_true(!invalid_glyph_run.is_valid())
  assert_eq(invalid_glyph_run.resource_plan(b"hello").length(), 1)
  assert_eq(invalid_glyph_run.resource_plan(b"hello").cacheable_count, 0)
  assert_eq(invalid_glyph_run.resource_plan(b"hello").uncacheable_count, 1)
  let invalid_commands = @moui_skia.RenderCommandList::for_target(target).draw_shaped_glyph_run_utf8(
    b"hello",
    invalid_glyph_run,
    @moui_skia.Point::new(2.0, 3.0),
  )
  assert_true(invalid_commands.touched_bounds() is None)
  assert_eq(invalid_commands.commands[0].resource_descriptors().length(), 1)
  assert_eq(invalid_commands.resource_plan().length(), 1)
  assert_eq(invalid_commands.resource_plan().count_kind(SurfaceResource), 1)
  assert_eq(invalid_commands.resource_plan().count_kind(TextRunResource), 0)
}

///|
test "render command list includes declared resource descriptors" {
  guard @moui_skia.ShaderDescriptor::linear_gradient(
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(16, 0),
      @moui_skia.Color::red(),
      @moui_skia.Color::blue(),
    )
    is Some(shader) else {
    fail("linear shader descriptor should be accepted")
  }
  guard @moui_skia.ColorFilterDescriptor::saturation(0.8) is Some(color_filter) else {
    fail("color filter descriptor should be accepted")
  }
  guard @moui_skia.ColorFilterDescriptor::brightness(1.1)
    is Some(layer_color_filter) else {
    fail("layer color filter descriptor should be accepted")
  }
  guard @moui_skia.ImageFilterDescriptor::blur(1.0, 2.0) is Some(image_filter) else {
    fail("image filter descriptor should be accepted")
  }
  guard @moui_skia.MaskFilterDescriptor::blur(2.0) is Some(mask_filter) else {
    fail("mask filter descriptor should be accepted")
  }
  let shader_descriptor = shader.resource_descriptor()
  let color_filter_descriptor = color_filter.resource_descriptor()
  let layer_color_filter_descriptor = layer_color_filter.resource_descriptor()
  let image_filter_descriptor = image_filter.resource_descriptor()
  let mask_filter_descriptor = mask_filter.resource_descriptor()
  guard @moui_skia.ImageDescriptor::encoded(
      b"render-command-image",
      format=Some(PNG),
      dimensions=Some(@moui_skia.ISize::new(2, 3)),
    )
    is Some(image) else {
    fail("encoded image descriptor should be accepted")
  }
  let image_descriptor = image.resource_descriptor()
  let shader_path = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(6, 9, 3, 2),
  )
  let shader_path_descriptor = shader_path.resource_descriptor()
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(16, 16),
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .declare_resource(shader_descriptor)
    .declare_resources([
      color_filter_descriptor, image_filter_descriptor, mask_filter_descriptor, shader_descriptor,
    ])
    .declare_resource(@moui_skia.RendererResourceDescriptor::shader(b""))
    .save_layer(
      bounds=Some(@moui_skia.Rect::from_xywh(0, 0, 16, 16)),
      color_filter=Some(layer_color_filter),
      image_filter=Some(image_filter),
      mask_filter=Some(mask_filter),
    )
    .draw_rect_shader(
      @moui_skia.Rect::from_xywh(8, 2, 4, 4),
      shader,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::white()),
    )
    .draw_round_rect_shader(
      @moui_skia.Rect::from_xywh(10, 8, 3, 3),
      1.0,
      1.0,
      shader,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::white()),
    )
    .draw_path_shader(
      shader_path,
      shader,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::white()),
    )
    .draw_image(image, @moui_skia.Point::new(13, 1))
    .draw_image_rect(
      image,
      @moui_skia.Rect::from_xywh(0, 0, 2, 3),
      @moui_skia.Rect::from_xywh(11, 12, 3, 2),
      sampling=@moui_skia.SamplingOptions::linear(),
    )
    .draw_rect(
      @moui_skia.Rect::from_xywh(2, 2, 4, 4),
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::green()),
    )
    .restore()

  assert_true(
    @moui_skia.RenderCommand::declare_resource(shader_descriptor).is_resource_declaration(),
  )
  assert_true(
    @moui_skia.RenderCommand::draw_rect_shader(
      @moui_skia.Rect::from_xywh(8, 2, 4, 4),
      shader,
    ).resource_descriptor() ==
    Some(shader_descriptor),
  )
  assert_true(
    @moui_skia.RenderCommand::draw_round_rect_shader(
      @moui_skia.Rect::from_xywh(10, 8, 3, 3),
      1.0,
      1.0,
      shader,
    ).resource_descriptor() ==
    Some(shader_descriptor),
  )
  let path_shader_command = @moui_skia.RenderCommand::draw_path_shader(
    shader_path, shader,
  )
  let path_shader_descriptors = path_shader_command.resource_descriptors()
  assert_true(path_shader_command.resource_descriptor() is None)
  assert_eq(path_shader_descriptors.length(), 2)
  assert_true(path_shader_descriptors[0].key == shader_path_descriptor.key)
  assert_true(path_shader_descriptors[1].key == shader_descriptor.key)
  assert_eq(path_shader_command.resource_count_for_kind(PathResource), 1)
  assert_eq(path_shader_command.resource_count_for_kind(ShaderResource), 1)
  assert_eq(path_shader_command.filter_resource_count(), 0)
  assert_eq(path_shader_command.text_resource_count(), 0)
  assert_true(
    @moui_skia.RenderCommand::draw_image(image, @moui_skia.Point::new(13, 1)).resource_descriptor() ==
    Some(image_descriptor),
  )
  assert_true(
    @moui_skia.RenderCommand::draw_image_rect(
      image,
      @moui_skia.Rect::from_xywh(0, 0, 2, 3),
      @moui_skia.Rect::from_xywh(11, 12, 3, 2),
    ).resource_descriptor() ==
    Some(image_descriptor),
  )
  assert_eq(commands.length(), 13)
  let stats = commands.stats()
  assert_eq(stats.command_count, 13)
  assert_eq(stats.draw_count, 6)
  assert_eq(stats.state_count, 2)
  assert_eq(stats.text_count, 0)
  assert_eq(stats.resource_declaration_count, 5)
  assert_eq(stats.image_resource_count, 2)
  assert_eq(stats.shader_resource_count, 5)
  assert_eq(stats.filter_resource_count, 6)
  assert_eq(stats.path_resource_count, 1)
  assert_eq(stats.text_resource_count, 0)
  assert_eq(stats.max_save_depth, 1)
  assert_true(stats.is_state_balanced())
  assert_true(
    commands.touched_bounds() == Some(@moui_skia.Rect::from_xywh(2, 1, 13, 13)),
  )
  let descriptors = commands.resource_descriptors()
  assert_eq(descriptors.length(), 8)
  assert_true(descriptors[0].key.kind == SurfaceResource)
  assert_true(descriptors[0].key == target.resource_key())
  assert_true(descriptors[0].key != target.surface.resource_key())
  let plan = commands.resource_plan()
  assert_eq(plan.length(), 8)
  assert_eq(plan.cacheable_count, 8)
  assert_eq(plan.uncacheable_count, 0)
  assert_eq(plan.gpu_backed_count, 0)
  let mut shader_seen = false
  let mut shader_path_seen = false
  let mut image_seen = false
  let mut color_filter_seen = false
  let mut layer_color_filter_seen = false
  let mut image_filter_seen = false
  let mut mask_filter_seen = false
  for descriptor in descriptors {
    if descriptor.key == shader_descriptor.key {
      shader_seen = true
    }
    if descriptor.key == shader_path_descriptor.key {
      shader_path_seen = true
    }
    if descriptor.key == image_descriptor.key {
      image_seen = true
    }
    if descriptor.key == color_filter_descriptor.key {
      color_filter_seen = true
    }
    if descriptor.key == layer_color_filter_descriptor.key {
      layer_color_filter_seen = true
    }
    if descriptor.key == image_filter_descriptor.key {
      image_filter_seen = true
    }
    if descriptor.key == mask_filter_descriptor.key {
      mask_filter_seen = true
    }
  }
  assert_true(shader_seen)
  assert_true(shader_path_seen)
  assert_true(image_seen)
  assert_true(color_filter_seen)
  assert_true(layer_color_filter_seen)
  assert_true(image_filter_seen)
  assert_true(mask_filter_seen)
}

///|
test "render frame descriptor summarizes target commands and resources" {
  let target = @moui_skia.SurfaceTargetDescriptor::window_n32_premul(
    @moui_skia.ISize::new(24, 16),
    present_mode=MailboxPresent,
  )
  let path = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(2, 3, 5, 6),
  )
  let commands = @moui_skia.RenderCommandList::for_target(target)
    .save()
    .draw_path(
      path,
      paint=@moui_skia.Paint::new(color=@moui_skia.Color::blue()),
    )
    .restore()
  let frame = commands.frame_descriptor(target)
  assert_true(frame.is_target_consistent())
  assert_true(frame.needs_present())
  assert_true(frame.has_present())
  assert_true(frame.is_ready())
  assert_true(frame.validation_status() == FrameReady)
  assert_true(frame.validation_status().is_ready())
  assert_eq(frame.stats.command_count, 4)
  assert_eq(frame.stats.present_count, 1)
  assert_true(
    frame.touched_bounds == Some(@moui_skia.Rect::from_xywh(2, 3, 5, 6)),
  )
  assert_true(frame.resource_plan.contains_key(target.resource_key()))
  assert_true(frame.resource_plan.contains_key(path.resource_key()))
  assert_true(
    frame.resource_plan.contains_key(
      frame.command_list.pass.resource_descriptor().key,
    ),
  )
  assert_true(!frame.resource_plan.contains_key(target.surface.resource_key()))
  assert_eq(frame.resource_plan.count_kind(SurfaceResource), 1)
  assert_eq(frame.resource_plan.count_kind(PathResource), 1)
  let frame_cacheable_plan = frame.cacheable_resource_plan()
  let frame_uncacheable_plan = frame.uncacheable_resource_plan()
  assert_true(
    frame_cacheable_plan == frame.resource_plan.cacheable_resource_plan(),
  )
  assert_eq(frame_cacheable_plan.length(), 2)
  assert_eq(frame_cacheable_plan.cacheable_count, 2)
  assert_true(frame_cacheable_plan.contains_key(target.resource_key()))
  assert_true(frame_cacheable_plan.contains_key(path.resource_key()))
  assert_true(frame_uncacheable_plan.is_empty())
  let cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new()
  assert_true(!cache.contains_resource_plan(frame.resource_plan))
  let frame_cached_before = frame.cached_cacheable_resource_plan(cache)
  let frame_missing_before = frame.missing_cacheable_resource_plan(cache)
  assert_true(frame_cached_before.is_empty())
  assert_eq(frame_missing_before.length(), 2)
  assert_true(frame_missing_before.contains_key(target.resource_key()))
  assert_true(frame_missing_before.contains_key(path.resource_key()))
  assert_eq(frame.cache_resources(cache), 2)
  assert_eq(cache.length(), 2)
  let frame_cached_after = frame.cached_cacheable_resource_plan(cache)
  let frame_missing_after = frame.missing_cacheable_resource_plan(cache)
  assert_eq(frame_cached_after.length(), 2)
  assert_true(frame_cached_after.contains_key(target.resource_key()))
  assert_true(frame_cached_after.contains_key(path.resource_key()))
  assert_true(frame_missing_after.is_empty())
  assert_true(cache.contains_resource_plan(frame.resource_plan))
  assert_true(cache.contains(target.resource_key()))
  assert_true(cache.contains(path.resource_key()))
  guard frame.present_descriptor(frame_index=5) is Some(present) else {
    fail("ready window frame should expose a present descriptor")
  }
  assert_eq(present.frame_index, 5)
  assert_eq(present.buffer_index, 1)
  assert_true(present.present_mode == Some(MailboxPresent))
  assert_true(present.resource_key().kind == SurfaceResource)
  assert_true(!present.resource_descriptor().is_cacheable())
  let present_plan = frame.present_resource_plan(frame_index=5)
  assert_eq(present_plan.length(), 2)
  assert_eq(present_plan.cacheable_count, 1)
  assert_eq(present_plan.uncacheable_count, 1)
  assert_true(present_plan.contains_key(target.resource_key()))
  assert_true(present_plan.contains_key(present.resource_key()))
  let submission = frame.submission_descriptor(frame_index=5)
  assert_true(submission.is_ready())
  assert_eq(submission.frame_index, 5)
  assert_true(submission.validation_status == FrameReady)
  assert_true(submission.has_present())
  assert_true(submission.present == Some(present))
  assert_eq(submission.resource_plan.length(), 3)
  assert_eq(submission.resource_plan.cacheable_count, 2)
  assert_eq(submission.resource_plan.uncacheable_count, 1)
  assert_eq(submission.resource_plan.count_kind(SurfaceResource), 2)
  assert_eq(submission.resource_plan.count_kind(PathResource), 1)
  assert_true(submission.resource_plan.contains_key(target.resource_key()))
  assert_true(submission.resource_plan.contains_key(path.resource_key()))
  assert_true(submission.resource_plan.contains_key(present.resource_key()))
  let submission_cacheable_plan = submission.cacheable_resource_plan()
  let submission_uncacheable_plan = submission.uncacheable_resource_plan()
  assert_true(
    submission_cacheable_plan ==
    submission.resource_plan.cacheable_resource_plan(),
  )
  assert_eq(submission_cacheable_plan.length(), 2)
  assert_eq(submission_cacheable_plan.cacheable_count, 2)
  assert_eq(submission_cacheable_plan.uncacheable_count, 0)
  assert_true(submission_cacheable_plan.contains_key(target.resource_key()))
  assert_true(submission_cacheable_plan.contains_key(path.resource_key()))
  assert_true(!submission_cacheable_plan.contains_key(present.resource_key()))
  assert_eq(submission_uncacheable_plan.length(), 1)
  assert_eq(submission_uncacheable_plan.cacheable_count, 0)
  assert_eq(submission_uncacheable_plan.uncacheable_count, 1)
  assert_true(submission_uncacheable_plan.contains_key(present.resource_key()))
  assert_true(!submission_uncacheable_plan.contains_key(target.resource_key()))
  let submission_cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new()
  assert_true(
    submission.cached_cacheable_resource_plan(submission_cache).is_empty(),
  )
  let submission_missing_before = submission.missing_cacheable_resource_plan(
    submission_cache,
  )
  assert_eq(submission_missing_before.length(), 2)
  assert_true(submission_missing_before.contains_key(target.resource_key()))
  assert_true(submission_missing_before.contains_key(path.resource_key()))
  assert_true(!submission_missing_before.contains_key(present.resource_key()))
  assert_eq(submission.cache_resources(submission_cache), 2)
  assert_eq(submission_cache.length(), 2)
  assert_eq(
    submission.cached_cacheable_resource_plan(submission_cache).length(),
    2,
  )
  assert_true(
    submission.missing_cacheable_resource_plan(submission_cache).is_empty(),
  )
  assert_true(submission_cache.contains(target.resource_key()))
  assert_true(submission_cache.contains(path.resource_key()))
  assert_true(!submission_cache.contains(present.resource_key()))
  let finalization = frame.finalization_descriptor(frame_index=5)
  assert_true(finalization.is_ready())
  assert_true(finalization.has_finalization())
  assert_eq(finalization.frame_index, 5)
  assert_true(finalization.validation_status == FrameReady)
  assert_true(!finalization.requires_gpu_context())
  guard finalization.finalization is Some(surface_finalization) else {
    fail("ready window frame should expose a finalization descriptor")
  }
  assert_true(
    surface_finalization == target.finalization_descriptor(frame_index=5),
  )
  assert_true(!surface_finalization.resource_descriptor().is_cacheable())
  assert_true(
    frame.finalization_resource_plan(frame_index=5) ==
    finalization.resource_plan,
  )
  assert_eq(finalization.resource_plan.length(), 3)
  assert_eq(finalization.resource_plan.cacheable_count, 2)
  assert_eq(finalization.resource_plan.uncacheable_count, 1)
  assert_eq(finalization.resource_plan.count_kind(SurfaceResource), 2)
  assert_eq(finalization.resource_plan.count_kind(PathResource), 1)
  assert_true(finalization.resource_plan.contains_key(target.resource_key()))
  assert_true(finalization.resource_plan.contains_key(path.resource_key()))
  assert_true(
    finalization.resource_plan.contains_key(surface_finalization.resource_key()),
  )
  let finalization_cacheable_plan = finalization.cacheable_resource_plan()
  let finalization_uncacheable_plan = finalization.uncacheable_resource_plan()
  assert_true(
    finalization_cacheable_plan ==
    finalization.resource_plan.cacheable_resource_plan(),
  )
  assert_eq(finalization_cacheable_plan.length(), 2)
  assert_eq(finalization_cacheable_plan.cacheable_count, 2)
  assert_eq(finalization_cacheable_plan.uncacheable_count, 0)
  assert_true(finalization_cacheable_plan.contains_key(target.resource_key()))
  assert_true(finalization_cacheable_plan.contains_key(path.resource_key()))
  assert_true(
    !finalization_cacheable_plan.contains_key(
      surface_finalization.resource_key(),
    ),
  )
  assert_eq(finalization_uncacheable_plan.length(), 1)
  assert_eq(finalization_uncacheable_plan.cacheable_count, 0)
  assert_eq(finalization_uncacheable_plan.uncacheable_count, 1)
  assert_true(
    finalization_uncacheable_plan.contains_key(
      surface_finalization.resource_key(),
    ),
  )
  assert_true(
    !finalization_uncacheable_plan.contains_key(target.resource_key()),
  )
  let finalization_cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new()
  assert_true(
    finalization.cached_cacheable_resource_plan(finalization_cache).is_empty(),
  )
  let finalization_missing_before = finalization.missing_cacheable_resource_plan(
    finalization_cache,
  )
  assert_eq(finalization_missing_before.length(), 2)
  assert_true(finalization_missing_before.contains_key(target.resource_key()))
  assert_true(finalization_missing_before.contains_key(path.resource_key()))
  assert_true(
    !finalization_missing_before.contains_key(
      surface_finalization.resource_key(),
    ),
  )
  assert_eq(finalization.cache_resources(finalization_cache), 2)
  assert_eq(finalization_cache.length(), 2)
  assert_eq(
    finalization.cached_cacheable_resource_plan(finalization_cache).length(),
    2,
  )
  assert_true(
    finalization.missing_cacheable_resource_plan(finalization_cache).is_empty(),
  )
  assert_true(finalization_cache.contains(target.resource_key()))
  assert_true(finalization_cache.contains(path.resource_key()))
  assert_true(!finalization_cache.contains(surface_finalization.resource_key()))

  let offscreen_target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(8, 8),
  )
  let offscreen_frame = @moui_skia.RenderCommandList::for_target(
      offscreen_target,
    )
    .draw_rect(@moui_skia.Rect::from_xywh(1, 1, 2, 2))
    .frame_descriptor(offscreen_target)
  let offscreen_finalization = offscreen_frame.finalization_descriptor(
    frame_index=-2,
  )
  assert_true(!offscreen_frame.needs_present())
  assert_true(offscreen_finalization.is_ready())
  assert_true(offscreen_finalization.has_finalization())
  assert_eq(offscreen_finalization.frame_index, 0)
  assert_eq(offscreen_finalization.resource_plan.length(), 2)
  assert_eq(offscreen_finalization.resource_plan.cacheable_count, 1)
  assert_eq(offscreen_finalization.resource_plan.uncacheable_count, 1)
  assert_eq(offscreen_finalization.cacheable_resource_plan().length(), 1)
  assert_eq(offscreen_finalization.uncacheable_resource_plan().length(), 1)
  assert_true(
    offscreen_finalization.resource_plan.contains_key(
      offscreen_target.resource_key(),
    ),
  )

  let mismatch_target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(24, 16),
  )
  let mismatch_frame = @moui_skia.RenderCommandList::for_target(mismatch_target).frame_descriptor(
    target,
  )
  assert_true(!mismatch_frame.is_target_consistent())
  assert_true(mismatch_frame.validation_status() == FrameTargetMismatch)
  assert_true(!mismatch_frame.is_ready())
  assert_true(mismatch_frame.present_descriptor(frame_index=5) is None)
  assert_true(mismatch_frame.present_resource_plan(frame_index=5).is_empty())
  let mismatch_submission = mismatch_frame.submission_descriptor(frame_index=5)
  assert_true(!mismatch_submission.is_ready())
  assert_true(!mismatch_submission.has_present())
  assert_true(mismatch_submission.validation_status == FrameTargetMismatch)
  let mismatch_cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new()
  assert_eq(mismatch_submission.cache_resources(mismatch_cache), 0)
  assert_true(mismatch_cache.is_empty())
  let mismatch_finalization = mismatch_frame.finalization_descriptor(
    frame_index=5,
  )
  assert_true(!mismatch_finalization.is_ready())
  assert_true(!mismatch_finalization.has_finalization())
  assert_true(mismatch_finalization.validation_status == FrameTargetMismatch)
  let mismatch_finalization_cache : @moui_skia.ResourceCache[
    @moui_skia.RendererResourceKey,
    @moui_skia.RendererResourceDescriptor,
  ] = @moui_skia.ResourceCache::new()
  assert_eq(
    mismatch_finalization.cache_resources(mismatch_finalization_cache),
    0,
  )
  assert_true(mismatch_finalization_cache.is_empty())

  let identity_target = target.with_target_id(b"frame-window")
  let identity_mismatch_target = identity_target.with_target_id(
    b"other-frame-window",
  )
  let identity_mismatch_frame = @moui_skia.RenderCommandList::for_target(
    identity_target,
  ).frame_descriptor(identity_mismatch_target)
  assert_true(!identity_mismatch_frame.is_target_consistent())
  assert_true(
    identity_mismatch_frame.validation_status() == FrameTargetMismatch,
  )
  assert_true(!identity_mismatch_frame.is_ready())

  let unbalanced_frame = @moui_skia.RenderCommandList::for_target(target)
    .save()
    .frame_descriptor(target)
  assert_true(unbalanced_frame.validation_status() == FrameUnbalancedState)
  assert_true(!unbalanced_frame.is_ready())

  let gpu_context = @moui_skia.GpuContextDescriptor::mock(
    id=b"frame-gpu-context",
  )
  let gpu_target = @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
    @moui_skia.ISize::new(16, 16),
    gpu_context_key=Some(gpu_context.resource_key()),
  )
  let gpu_frame = @moui_skia.RenderCommandList::for_target(gpu_target).frame_descriptor(
    gpu_target,
  )
  assert_true(gpu_frame.requires_gpu_context())
  assert_true(gpu_frame.has_gpu_context())
  assert_true(gpu_frame.is_ready())
  assert_eq(gpu_frame.resource_plan.gpu_backed_count, 2)
  let gpu_submission = gpu_frame.submission_descriptor(frame_index=2)
  let gpu_submission_plan = gpu_submission.gpu_backed_resource_plan()
  assert_true(gpu_submission.is_ready())
  assert_true(gpu_submission.has_present())
  assert_eq(gpu_submission.resource_plan.length(), 3)
  assert_eq(gpu_submission.resource_plan.gpu_backed_count, 3)
  assert_eq(gpu_submission_plan.length(), 3)
  assert_eq(gpu_submission_plan.gpu_backed_count, 3)
  assert_eq(gpu_submission_plan.cacheable_count, 2)
  assert_eq(gpu_submission_plan.uncacheable_count, 1)
  assert_true(gpu_submission_plan.contains_key(gpu_target.resource_key()))
  assert_true(gpu_submission_plan.contains_key(gpu_context.resource_key()))
  assert_eq(gpu_submission.cacheable_resource_plan().length(), 2)
  assert_eq(gpu_submission.uncacheable_resource_plan().length(), 1)
  guard gpu_submission.present is Some(gpu_present) else {
    fail("gpu frame submission should expose a present descriptor")
  }
  assert_true(gpu_submission_plan.contains_key(gpu_present.resource_key()))
  let gpu_finalization = gpu_frame.finalization_descriptor(frame_index=2)
  let gpu_finalization_plan = gpu_finalization.gpu_backed_resource_plan()
  assert_true(gpu_finalization.is_ready())
  assert_true(gpu_finalization.has_finalization())
  assert_true(gpu_finalization.requires_gpu_context())
  assert_eq(gpu_finalization.resource_plan.length(), 3)
  assert_eq(gpu_finalization.resource_plan.gpu_backed_count, 3)
  assert_eq(gpu_finalization_plan.length(), 3)
  assert_eq(gpu_finalization_plan.gpu_backed_count, 3)
  assert_eq(gpu_finalization_plan.cacheable_count, 2)
  assert_eq(gpu_finalization_plan.uncacheable_count, 1)
  assert_true(gpu_finalization_plan.contains_key(gpu_target.resource_key()))
  assert_true(gpu_finalization_plan.contains_key(gpu_context.resource_key()))
  assert_eq(gpu_finalization.cacheable_resource_plan().length(), 2)
  assert_eq(gpu_finalization.uncacheable_resource_plan().length(), 1)
  guard gpu_finalization.finalization is Some(gpu_surface_finalization) else {
    fail(
      "gpu frame finalization should expose a surface finalization descriptor",
    )
  }
  assert_true(
    gpu_finalization_plan.contains_key(gpu_surface_finalization.resource_key()),
  )

  let missing_context_target = gpu_target.without_gpu_context()
  let missing_context_frame = @moui_skia.RenderCommandList::for_target(
    missing_context_target,
  ).frame_descriptor(missing_context_target)
  assert_true(missing_context_frame.requires_gpu_context())
  assert_true(!missing_context_frame.has_gpu_context())
  assert_true(
    missing_context_frame.validation_status() == FrameMissingGpuContext,
  )
  assert_true(!missing_context_frame.is_ready())
  assert_true(missing_context_frame.present_descriptor(frame_index=1) is None)
  let missing_context_submission = missing_context_frame.submission_descriptor(
    frame_index=1,
  )
  assert_true(!missing_context_submission.is_ready())
  assert_true(!missing_context_submission.has_present())
  assert_eq(
    missing_context_submission
    .gpu_backed_resource_plan()
    .count_kind(GpuContextResource),
    0,
  )
  let missing_context_finalization = missing_context_frame.finalization_descriptor(
    frame_index=1,
  )
  assert_true(!missing_context_finalization.is_ready())
  assert_true(!missing_context_finalization.has_finalization())
  assert_true(missing_context_finalization.requires_gpu_context())
  assert_eq(
    missing_context_finalization
    .gpu_backed_resource_plan()
    .count_kind(GpuContextResource),
    0,
  )
}

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

///|
test "matrix exposes skia-style members and affine conversion" {
  let matrix = @moui_skia.Matrix::new_all(2, 1, 10, 3, 4, 20, 0, 0, 1)
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
    @moui_skia.Matrix::from_affine([2, 1, 10, 3, 4, 20]) == Some(matrix),
  )
  assert_true(@moui_skia.Matrix::from_affine([1, 2, 3]) is None)

  let perspective = @moui_skia.Matrix::new_all(1, 0, 0, 0, 1, 0, 0.5, 0, 1)
  assert_true(perspective.to_affine() is None)
}

///|
test "matrix composes, inverts, and maps rect bounds" {
  let scale = @moui_skia.Matrix::scale(2, 4)
  let translate = @moui_skia.Matrix::translate(10, 20)
  let matrix = translate.concat(scale)
  assert_true(matrix == @moui_skia.Matrix::scale_translate(2, 4, 10, 20))
  assert_true(matrix.post_concat(@moui_skia.Matrix::identity()) == matrix)
  assert_true(@moui_skia.Matrix::identity().pre_concat(matrix) == matrix)
  assert_eq(matrix.determinant(), 8.0)
  assert_true(matrix.is_invertible())
  guard matrix.invert() is Some(inverse) else { fail("expected inverse") }
  assert_true(
    inverse.map_point(matrix.map_point(@moui_skia.Point::new(4, 5))) ==
    @moui_skia.Point::new(4, 5),
  )
  assert_true(
    matrix.concat(inverse).map_point(@moui_skia.Point::new(7, 9)) ==
    @moui_skia.Point::new(7, 9),
  )

  let skew = @moui_skia.Matrix::skew(1, 0)
  assert_true(
    skew.map_rect(@moui_skia.Rect::from_xywh(0, 0, 2, 3)) ==
    @moui_skia.Rect::new(0, 0, 5, 3),
  )

  let base = @moui_skia.Matrix::scale(2, 3)
  assert_true(
    base.pre_translate(10, 20).map_point(@moui_skia.Point::new(1, 1)) ==
    @moui_skia.Point::new(12, 23),
  )
  assert_true(
    base.post_translate(10, 20).map_point(@moui_skia.Point::new(1, 1)) ==
    @moui_skia.Point::new(22, 63),
  )
  assert_true(
    @moui_skia.Matrix::identity()
    .pre_scale(2, 3)
    .post_skew(1, 0)
    .map_point(@moui_skia.Point::new(1, 1)) ==
    @moui_skia.Point::new(4, 3),
  )
  assert_true(
    @moui_skia.Matrix::identity()
    .pre_skew(1, 0)
    .post_scale(2, 3)
    .map_point(@moui_skia.Point::new(1, 1)) ==
    @moui_skia.Point::new(5, 3),
  )
  assert_true(
    test_point_near(
      @moui_skia.Matrix::rotate_degrees(90).map_point(
        @moui_skia.Point::new(2, 0),
      ),
      @moui_skia.Point::new(0, 2),
    ),
  )
  assert_true(
    test_rect_near(
      @moui_skia.Matrix::identity()
      .post_rotate_degrees(90)
      .map_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 2)),
      @moui_skia.Rect::new(-3, 1, -1, 5),
    ),
  )
  assert_true(
    test_point_near(
      @moui_skia.Matrix::translate(10, 0)
      .pre_rotate_degrees(90)
      .map_point(@moui_skia.Point::new(1, 0)),
      @moui_skia.Point::new(0, 11),
    ),
  )
  assert_true(
    @moui_skia.Matrix::translate(1, 2).map_points([
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(3, 4),
    ]) ==
    [@moui_skia.Point::new(1, 2), @moui_skia.Point::new(4, 6)],
  )

  let collapsed = @moui_skia.Matrix::scale(0, 1)
  assert_eq(collapsed.determinant(), 0.0)
  assert_true(!collapsed.is_invertible())
  assert_true(collapsed.invert() is None)
}

///|
test "matrix maps origins vectors radii and rectangle quads" {
  let matrix = @moui_skia.Matrix::scale_translate(2, 3, 10, 20)
  let point = @moui_skia.Point::new(4, 5)
  let rect = @moui_skia.Rect::from_xywh(1, 2, 3, 4)

  assert_true(matrix.map_xy(4, 5) == @moui_skia.Point::new(18, 35))
  assert_true(matrix.map_origin() == @moui_skia.Point::new(10, 20))
  assert_true(
    matrix.map_point_affine(point) == Some(@moui_skia.Point::new(18, 35)),
  )
  assert_true(matrix.map_vector(point) == @moui_skia.Point::new(8, 15))
  assert_true(
    matrix.map_vectors([
      @moui_skia.Point::new(1, 1),
      @moui_skia.Point::new(2, 3),
    ]) ==
    [@moui_skia.Point::new(2, 3), @moui_skia.Point::new(4, 9)],
  )
  assert_true(@moui_skia.Matrix::scale(2, 8).map_radius(3) == Some(12.0))
  assert_true(
    @moui_skia.Matrix::new_all(1, 0, 0, 0, 1, 0, 0.5, 0, 1).map_point_affine(
      point,
    )
    is None,
  )
  assert_true(
    @moui_skia.Matrix::new_all(1, 0, 0, 0, 1, 0, 0.5, 0, 1).map_radius(3)
    is None,
  )

  assert_true(
    matrix.map_rect_to_quad(rect) ==
    [
      @moui_skia.Point::new(12, 26),
      @moui_skia.Point::new(18, 26),
      @moui_skia.Point::new(18, 38),
      @moui_skia.Point::new(12, 38),
    ],
  )
  assert_true(
    matrix.map_rect_scale_translate(rect) ==
    Some(@moui_skia.Rect::from_xywh(12, 26, 6, 12)),
  )
  assert_true(
    @moui_skia.Matrix::skew(1, 0).map_rect_scale_translate(rect) is None,
  )
}

///|
test "image info computes row and byte sizes" {
  let info = @moui_skia.ImageInfo::n32_premul(@moui_skia.ISize::new(10, 8))
  assert_eq(info.bytes_per_pixel(), 4)
  assert_eq(info.shift_per_pixel(), 2)
  assert_eq(info.min_row_bytes(), 40)
  assert_eq(info.min_row_bytes64(), 40L)
  assert_eq(info.compute_min_byte_size(), 320)
  assert_eq(info.compute_min_byte_size64(), 320L)
  assert_eq(info.compute_byte_size(48), 384)
  assert_eq(info.compute_byte_size64(48), 384L)
  assert_eq(info.compute_byte_size(39), 0)
  assert_true(info.bounds() == @moui_skia.IRect::from_xywh(0, 0, 10, 8))
  assert_true(info.valid_pixels(40))

  let unknown = @moui_skia.ImageInfo::unknown(
    dimensions=@moui_skia.ISize::new(1, 1),
  )
  assert_eq(unknown.bytes_per_pixel(), 0)
  assert_eq(unknown.shift_per_pixel(), 0)
  assert_true(!unknown.valid_pixels(0))

  let alpha = @moui_skia.ImageInfo::a8(@moui_skia.ISize::new(3, 2))
  assert_eq(alpha.bytes_per_pixel(), 1)
  assert_eq(alpha.shift_per_pixel(), 0)
  assert_eq(alpha.min_row_bytes(), 3)
  assert_true(alpha.valid_pixels(3))
}

///|
test "pixmap validates copied pixel layout" {
  let info = @moui_skia.ImageInfo::n32_premul(@moui_skia.ISize::new(2, 2))
  let pixmap = @moui_skia.Pixmap::new(
    info, 8, b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f",
  )
  guard pixmap is Some(pixmap) else { fail("expected pixmap") }
  assert_eq(pixmap.width(), 2)
  assert_eq(pixmap.height(), 2)
  assert_eq(pixmap.row_bytes(), 8)
  assert_true(pixmap.color_type() == RGBA8888)
  assert_true(pixmap.alpha_type() == Premul)
  assert_eq(pixmap.bytes_per_pixel(), 4)
  assert_eq(pixmap.shift_per_pixel(), 2)
  assert_eq(pixmap.byte_size(), 16)
  assert_eq(pixmap.byte_size64(), 16L)
  assert_true(pixmap.contains(@moui_skia.IPoint::new(1, 1)))
  assert_true(pixmap.offset(@moui_skia.IPoint::new(1, 1)) == Some(12))
  assert_true(
    pixmap.sample(@moui_skia.IPoint::new(1, 1)) == Some(b"\x0c\x0d\x0e\x0f"),
  )
  assert_true(
    pixmap.matches_sample(@moui_skia.IPoint::new(1, 1), b"\x0c\x0d\x0e\x0f"),
  )
  assert_true(
    !pixmap.matches_sample(@moui_skia.IPoint::new(1, 1), b"\x0c\x0d\x0e\x10"),
  )
  assert_true(pixmap.sample(@moui_skia.IPoint::new(2, 0)) is None)
  assert_true(@moui_skia.Pixmap::new(info, 4, b"\x00") is None)
}

///|
test "paint builder updates value state" {
  let paint = @moui_skia.Paint::new()
    .set_anti_alias(true)
    .set_stroke(true)
    .set_stroke_width(2.5)
    .set_color(@moui_skia.Color::red())
    .set_alpha(0x40)
  assert_true(paint.anti_alias)
  assert_true(paint.style == Stroke)
  assert_eq(paint.stroke_width, 2.5)
  assert_true(paint.color == @moui_skia.Color::red().with_alpha(0x40))
}

///|
test "skia enum ordinals match expected native order" {
  assert_eq(@moui_skia.SrcOver.to_skia_ordinal(), 3)
  assert_eq(@moui_skia.Fill.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.Stroke.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.StrokeCap::Round.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.StrokeJoin::Round.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.StrokeJoin::Bevel.to_skia_ordinal(), 2)
  assert_eq(@moui_skia.Points.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.Lines.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.Polygon.to_skia_ordinal(), 2)
  assert_eq(@moui_skia.PNG.to_skia_ordinal(), 4)
  assert_eq(@moui_skia.JPEG.to_skia_ordinal(), 3)
  assert_eq(@moui_skia.AVIF.to_skia_ordinal(), 12)
  assert_true(@moui_skia.EncodedImageFormat::from_skia_ordinal(4) == Some(PNG))
  assert_true(@moui_skia.EncodedImageFormat::from_skia_ordinal(-1) is None)
  assert_eq(@moui_skia.Clamp.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.Repeat.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.Mirror.to_skia_ordinal(), 2)
  assert_eq(@moui_skia.Decal.to_skia_ordinal(), 3)
  assert_eq(@moui_skia.ClipOp::Difference.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.ClipOp::Intersect.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.FilterMode::Nearest.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.FilterMode::Linear.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.MipmapMode::None.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.MipmapMode::Nearest.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.MipmapMode::Linear.to_skia_ordinal(), 2)
}

///|
test "sampling options expose skia-compatible state" {
  let nearest = @moui_skia.SamplingOptions::new()
  assert_eq(nearest.filter_ordinal(), 0)
  assert_eq(nearest.mipmap_ordinal(), 0)
  assert_true(!nearest.uses_cubic())
  let linear_mipmap = @moui_skia.SamplingOptions::new(
    filter=Linear,
    mipmap=Linear,
  )
  assert_eq(linear_mipmap.filter_ordinal(), 1)
  assert_eq(linear_mipmap.mipmap_ordinal(), 2)
  let cubic = @moui_skia.SamplingOptions::catmull_rom()
  assert_true(cubic.uses_cubic())
  assert_eq(cubic.cubic_b(), 0.0)
  assert_eq(cubic.cubic_c(), 0.5)
}

///|
test "path value layer records portable verbs" {
  let path = @moui_skia.Path::new(fill_type=EvenOdd)
    .move_to(@moui_skia.Point::new(0, 0))
    .line_to(@moui_skia.Point::new(10, 0))
    .quad_to(@moui_skia.Point::new(12, 5), @moui_skia.Point::new(10, 10))
    .conic_to(@moui_skia.Point::new(12, 12), @moui_skia.Point::new(10, 14), 0.5)
    .cubic_to(
      @moui_skia.Point::new(7, 12),
      @moui_skia.Point::new(3, 12),
      @moui_skia.Point::new(0, 10),
    )
    .close()
  assert_true(!path.is_empty())
  assert_eq(path.verb_count(), 6)
  assert_eq(path.count_verbs(), path.verb_count())
  assert_eq(path.count_points(), 9)
  assert_true(path.is_last_contour_closed())
  assert_true(path.is_finite())
  assert_true(path.fill_type == EvenOdd)
  assert_true(path.last_point() == Some(@moui_skia.Point::new(0, 10)))
  assert_true(path.bounds() == Some(@moui_skia.Rect::new(0, 0, 12, 14)))
  let segments = path.segment_masks()
  assert_true(segments.contains(@moui_skia.PathSegmentMask::line()))
  assert_true(segments.contains(@moui_skia.PathSegmentMask::quad()))
  assert_true(segments.contains(@moui_skia.PathSegmentMask::conic()))
  assert_true(segments.contains(@moui_skia.PathSegmentMask::cubic()))
  assert_eq(segments.bits(), 15)
  assert_eq(path.fill_type.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.CW.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.CCW.to_skia_ordinal(), 1)
  assert_true(!path.fill_type.is_inverse())
  assert_true(!path.is_inverse_fill_type())
  assert_true(@moui_skia.InverseEvenOdd.is_inverse())
  let key = path.resource_key()
  assert_true(key.kind == PathResource)
  assert_true(!key.is_empty())
  assert_true(key == path.resource_key())
  assert_true(key != path.with_fill_type(Winding).resource_key())
  assert_true(
    key != path.transform(@moui_skia.Matrix::translate(1, 0)).resource_key(),
  )
  let descriptor = path.resource_descriptor()
  assert_true(descriptor.key == key)
  assert_true(descriptor.byte_size > 0L)
  assert_true(descriptor.is_cacheable())
  assert_true(!@moui_skia.Path::new().resource_descriptor().is_cacheable())
  let non_finite_path = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(0, 0))
    .line_to(@moui_skia.Point::new(1.0 / 0.0, 1))
  assert_true(!non_finite_path.is_finite())
  assert_true(non_finite_path.resource_key().is_empty())
  assert_true(!non_finite_path.resource_descriptor().is_cacheable())
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(16, 16),
  )
  let non_finite_commands = @moui_skia.RenderCommandList::for_target(target)
    .clip_path(non_finite_path)
    .draw_path(non_finite_path)
  let non_finite_plan = non_finite_commands.resource_plan()
  assert_eq(non_finite_plan.count_kind(PathResource), 0)
  assert_eq(non_finite_plan.count_kind(SurfaceResource), 1)
}

///|
test "path recognizes a single line segment" {
  let line = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(1, 2))
    .line_to(@moui_skia.Point::new(3, 4))
  assert_true(
    line.is_line() ==
    Some(
      @moui_skia.PathLine::new(
        @moui_skia.Point::new(1, 2),
        @moui_skia.Point::new(3, 4),
      ),
    ),
  )
  assert_true(@moui_skia.Path::new().is_line() is None)
  assert_true(
    @moui_skia.Path::new()
    .add_rect(@moui_skia.Rect::from_xywh(0, 0, 2, 2))
    .is_line()
    is None,
  )
}

///|
test "path add poly builds open and closed contours" {
  let points = [
    @moui_skia.Point::new(0, 0),
    @moui_skia.Point::new(10, 0),
    @moui_skia.Point::new(10, 10),
  ]
  let open = @moui_skia.Path::new().add_poly(points)
  assert_eq(open.count_verbs(), 3)
  assert_eq(open.count_points(), 3)
  assert_true(!open.is_last_contour_closed())
  assert_true(open.last_point() == Some(@moui_skia.Point::new(10, 10)))
  assert_true(open.bounds() == Some(@moui_skia.Rect::from_xywh(0, 0, 10, 10)))
  assert_true(open.segment_masks().contains(@moui_skia.PathSegmentMask::line()))

  let closed = @moui_skia.Path::new(fill_type=EvenOdd).add_poly(
    points,
    close=true,
  )
  assert_eq(closed.count_verbs(), 4)
  assert_eq(closed.count_points(), 3)
  assert_true(closed.is_last_contour_closed())
  assert_true(closed.fill_type == EvenOdd)
  assert_true(closed.contains(@moui_skia.Point::new(8, 2)))
  assert_true(!closed.contains(@moui_skia.Point::new(2, 8)))

  let empty : Array[@moui_skia.Point] = []
  assert_true(@moui_skia.Path::new().add_poly(empty).is_empty())
}

///|
test "path add path appends transformed verbs" {
  let base = @moui_skia.Path::new(fill_type=EvenOdd).add_rect(
    @moui_skia.Rect::from_xywh(0, 0, 2, 2),
  )
  let triangle = @moui_skia.Path::new().add_poly(
    [
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(10, 10),
    ],
    close=true,
  )
  let combined = base.add_path(
    triangle,
    matrix=@moui_skia.Matrix::translate(10, 0),
  )
  assert_true(combined.fill_type == EvenOdd)
  assert_eq(combined.count_verbs(), base.count_verbs() + triangle.count_verbs())
  assert_eq(
    combined.count_points(),
    base.count_points() + triangle.count_points(),
  )
  assert_true(combined.bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 10)))
  assert_true(combined.last_point() == Some(@moui_skia.Point::new(20, 10)))
  assert_true(combined.contains(@moui_skia.Point::new(18, 2)))
  assert_true(!combined.contains(@moui_skia.Point::new(4, 8)))
  assert_true(
    base.add_path_matrix(triangle, @moui_skia.Matrix::translate(10, 0)) ==
    combined,
  )
  assert_true(
    base.add_path_offset(triangle, @moui_skia.Point::new(10, 0)) == combined,
  )
  assert_true(base.add_path(@moui_skia.Path::new()) == base)

  let open = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(0, 0))
    .line_to(@moui_skia.Point::new(2, 0))
  let segment = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(10, 0))
    .line_to(@moui_skia.Point::new(12, 0))
  let extended = open.add_path(segment, mode=Extend)
  assert_true(extended.verbs[2] == LineTo(@moui_skia.Point::new(10, 0)))
  assert_true(extended.verbs[3] == LineTo(@moui_skia.Point::new(12, 0)))
  assert_eq(extended.count_verbs(), 4)
  assert_true(
    extended.bounds() == Some(@moui_skia.Rect::from_xywh(0, 0, 12, 0)),
  )
  assert_true(@moui_skia.Path::new().add_path(segment, mode=Extend) == segment)
}

///|
test "path recognizes closed rectangle contours" {
  let rect = @moui_skia.Rect::from_xywh(1, 2, 3, 4)
  let cw = @moui_skia.Path::new().add_rect(rect)
  assert_true(cw.is_rect() == Some(@moui_skia.PathRect::new(rect, true, CW)))
  let ccw = @moui_skia.Path::new().add_rect(rect, direction=CCW)
  assert_true(ccw.is_rect() == Some(@moui_skia.PathRect::new(rect, true, CCW)))
  assert_true(
    @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(1, 2))
    .line_to(@moui_skia.Point::new(3, 4))
    .is_rect()
    is None,
  )
}

///|
test "path reset returns an empty winding path" {
  let path = @moui_skia.Path::new(fill_type=InverseWinding)
    .move_to(@moui_skia.Point::new(1, 2))
    .reset()
  assert_true(path.is_empty())
  assert_true(path.is_finite())
  assert_eq(path.count_verbs(), 0)
  assert_eq(path.count_points(), 0)
  assert_true(path.segment_masks() == @moui_skia.PathSegmentMask::empty())
  assert_true(!path.is_last_contour_closed())
  assert_true(path.fill_type == Winding)
  assert_true(path.last_point() is None)
  assert_true(path.bounds() is None)
}

///|
test "path rewind clears path for reuse" {
  let path = @moui_skia.Path::new(fill_type=EvenOdd)
    .add_rect(@moui_skia.Rect::from_xywh(0, 0, 4, 4))
    .rewind()
  assert_true(path.is_empty())
  assert_eq(path.count_verbs(), 0)
  assert_eq(path.count_points(), 0)
  assert_true(!path.is_last_contour_closed())
  assert_true(path.fill_type == Winding)
  assert_true(path.bounds() is None)
}

///|
test "path add rect expands in requested direction" {
  let rect = @moui_skia.Rect::from_xywh(1, 2, 3, 4)
  let cw = @moui_skia.Path::new().add_rect(rect)
  assert_eq(cw.verb_count(), 5)
  assert_true(cw.last_point() == Some(@moui_skia.Point::new(1, 6)))
  assert_true(cw.bounds() == Some(rect))
  assert_true(cw.contains(@moui_skia.Point::new(2, 3)))
  assert_true(!cw.contains(@moui_skia.Point::new(9, 9)))
  assert_true(
    cw.verbs ==
    [
      MoveTo(@moui_skia.Point::new(1, 2)),
      LineTo(@moui_skia.Point::new(4, 2)),
      LineTo(@moui_skia.Point::new(4, 6)),
      LineTo(@moui_skia.Point::new(1, 6)),
      Close,
    ],
  )
  let ccw = @moui_skia.Path::new().add_rect(rect, direction=CCW)
  assert_true(ccw.contains(@moui_skia.Point::new(2, 3)))
  let inverse = cw.with_fill_type(InverseWinding)
  assert_true(inverse.is_inverse_fill_type())
  assert_true(!inverse.contains(@moui_skia.Point::new(2, 3)))
  assert_true(inverse.contains(@moui_skia.Point::new(9, 9)))
  assert_true(
    ccw.verbs ==
    [
      MoveTo(@moui_skia.Point::new(1, 2)),
      LineTo(@moui_skia.Point::new(1, 6)),
      LineTo(@moui_skia.Point::new(4, 6)),
      LineTo(@moui_skia.Point::new(4, 2)),
      Close,
    ],
  )
}

///|
test "path add oval and circle expand to conics" {
  let oval = @moui_skia.Rect::from_xywh(0, 0, 10, 20)
  let cw = @moui_skia.Path::new().add_oval(oval)
  assert_eq(cw.verb_count(), 6)
  assert_true(cw.bounds() == Some(oval))
  assert_true(cw.is_oval() == Some(oval))
  assert_true(cw.last_point() == Some(@moui_skia.Point::new(10, 10)))
  assert_true(cw.verbs[0] == MoveTo(@moui_skia.Point::new(10, 10)))
  assert_true(
    cw.verbs[1] ==
    ConicTo(
      @moui_skia.Point::new(10, 20),
      @moui_skia.Point::new(5, 20),
      0.70710677,
    ),
  )
  let ccw = @moui_skia.Path::new().add_oval(oval, direction=CCW)
  assert_true(ccw.is_oval() == Some(oval))
  assert_true(
    ccw.verbs[1] ==
    ConicTo(
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(5, 0),
      0.70710677,
    ),
  )
  let circle = @moui_skia.Path::new().add_circle(@moui_skia.Point::new(5, 5), 3)
  assert_true(circle.bounds() == Some(@moui_skia.Rect::from_xywh(2, 2, 6, 6)))
  assert_true(circle.is_oval() == Some(@moui_skia.Rect::from_xywh(2, 2, 6, 6)))
  assert_true(
    @moui_skia.Path::new().add_circle(@moui_skia.Point::zero(), 0).is_empty(),
  )
  assert_true(
    @moui_skia.Path::new()
    .add_rect(@moui_skia.Rect::from_xywh(0, 0, 10, 20))
    .is_oval()
    is None,
  )
}

///|
test "path add round rect expands to lines and conics" {
  let rect = @moui_skia.Rect::from_xywh(0, 0, 10, 20)
  let cw = @moui_skia.Path::new().add_round_rect(rect, 2, 3)
  assert_eq(cw.verb_count(), 10)
  assert_true(cw.bounds() == Some(rect))
  assert_true(cw.last_point() == Some(@moui_skia.Point::new(2, 0)))
  assert_true(cw.verbs[0] == MoveTo(@moui_skia.Point::new(2, 0)))
  assert_true(cw.verbs[1] == LineTo(@moui_skia.Point::new(8, 0)))
  assert_true(
    cw.verbs[2] ==
    ConicTo(
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(10, 3),
      0.70710677,
    ),
  )
  let ccw = @moui_skia.Path::new().add_round_rect(rect, 2, 3, direction=CCW)
  assert_true(
    ccw.verbs[1] ==
    ConicTo(
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(0, 3),
      0.70710677,
    ),
  )
  assert_true(
    @moui_skia.Path::new().add_round_rect(rect, 0, 3).verb_count() == 5,
  )
}

///|
test "rrect value layer normalizes per-corner radii" {
  let rect = @moui_skia.Rect::from_xywh(0, 0, 10, 8)
  let rrect = @moui_skia.RRect::new(
    rect,
    @moui_skia.Size::new(8, 8),
    @moui_skia.Size::new(8, 8),
    @moui_skia.Size::new(2, 2),
    @moui_skia.Size::new(-1, 4),
  )
  assert_true(rrect.bounds() == rect)
  assert_true(rrect.upper_left == @moui_skia.Size::new(5, 5))
  assert_true(rrect.upper_right == @moui_skia.Size::new(5, 5))
  assert_true(rrect.lower_right == @moui_skia.Size::new(1.25, 1.25))
  assert_true(rrect.lower_left == @moui_skia.Size::empty())
  assert_true(!rrect.is_rect())
  assert_true(!rrect.is_simple())
  assert_eq(rrect.width(), 10)
  assert_eq(rrect.height(), 8)

  let simple = @moui_skia.RRect::from_rect_xy(rect, 2, 3)
  assert_true(simple.is_simple())
  assert_true(!simple.is_oval())

  let oval = @moui_skia.RRect::from_oval(rect)
  assert_true(oval.is_oval())
  assert_true(oval.upper_left == @moui_skia.Size::new(5, 4))

  let plain = @moui_skia.RRect::from_rect(rect)
  assert_true(plain.is_rect())
  assert_true(plain.offset(1, 2).bounds() == rect.offset(1, 2))
}

///|
test "rrect immutable geometry helpers preserve value semantics" {
  let rrect = @moui_skia.RRect::from_rect_xy(
    @moui_skia.Rect::from_xywh(0, 0, 10, 8),
    2,
    3,
  )

  let shifted = rrect.with_offset(@moui_skia.Point::new(5, -2))
  assert_true(shifted.bounds() == @moui_skia.Rect::from_xywh(5, -2, 10, 8))
  assert_true(shifted.upper_left == rrect.upper_left)
  assert_true(
    rrect.with_offset_to(@moui_skia.Point::new(20, 30)).bounds() ==
    @moui_skia.Rect::from_xywh(20, 30, 10, 8),
  )

  let inset = rrect.with_inset(@moui_skia.Size::new(1, 2))
  assert_true(inset.bounds() == @moui_skia.Rect::from_xywh(1, 2, 8, 4))
  assert_true(inset.upper_left == @moui_skia.Size::new(1, 1))

  let outset = rrect.with_outset(@moui_skia.Size::new(1, 2))
  assert_true(outset.bounds() == @moui_skia.Rect::from_xywh(-1, -2, 12, 12))
  assert_true(outset.upper_left == @moui_skia.Size::new(3, 5))
}

///|
test "rrect contains rectangles inside rounded corners" {
  let rrect = @moui_skia.RRect::from_rect_xy(
    @moui_skia.Rect::from_xywh(0, 0, 10, 10),
    4,
    4,
  )

  assert_true(rrect.contains_rect(@moui_skia.Rect::from_xywh(4, 4, 2, 2)))
  assert_true(rrect.contains_rect(@moui_skia.Rect::from_xywh(2, 2, 6, 6)))
  assert_true(!rrect.contains_rect(@moui_skia.Rect::from_xywh(0, 0, 1, 1)))
  assert_true(!rrect.contains_rect(@moui_skia.Rect::from_xywh(-1, 4, 2, 2)))
  assert_true(
    @moui_skia.RRect::from_rect(@moui_skia.Rect::from_xywh(0, 0, 10, 10)).contains_rect(
      @moui_skia.Rect::from_xywh(0, 0, 10, 10),
    ),
  )
}

///|
test "path add rrect expands mixed corners" {
  let rect = @moui_skia.Rect::from_xywh(0, 0, 10, 8)
  let rrect = @moui_skia.RRect::new(
    rect,
    @moui_skia.Size::new(2, 2),
    @moui_skia.Size::new(3, 1),
    @moui_skia.Size::new(1, 2),
    @moui_skia.Size::empty(),
  )
  let path = @moui_skia.Path::new().add_rrect(rrect)
  assert_eq(path.verb_count(), 10)
  assert_true(path.bounds() == Some(rect))
  assert_true(path.last_point() == Some(@moui_skia.Point::new(2, 0)))
  assert_true(path.verbs[0] == MoveTo(@moui_skia.Point::new(2, 0)))
  assert_true(path.verbs[1] == LineTo(@moui_skia.Point::new(7, 0)))
  assert_true(
    path.verbs[2] ==
    ConicTo(
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(10, 1),
      0.70710677,
    ),
  )
  assert_true(path.verbs[6] == LineTo(@moui_skia.Point::new(0, 8)))

  let ccw = @moui_skia.Path::new().add_rrect(rrect, direction=CCW)
  assert_true(
    ccw.verbs[1] ==
    ConicTo(
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(0, 2),
      0.70710677,
    ),
  )

  let rect_path = @moui_skia.Path::new().add_rrect(
    @moui_skia.RRect::from_rect(rect),
  )
  assert_true(rect_path.verbs == @moui_skia.Path::new().add_rect(rect).verbs)
}

///|
test "path transform maps every verb point" {
  let path = @moui_skia.Path::new(fill_type=EvenOdd)
    .move_to(@moui_skia.Point::new(1, 2))
    .line_to(@moui_skia.Point::new(3, 4))
    .quad_to(@moui_skia.Point::new(5, 6), @moui_skia.Point::new(7, 8))
    .conic_to(@moui_skia.Point::new(9, 10), @moui_skia.Point::new(11, 12), 0.5)
    .cubic_to(
      @moui_skia.Point::new(13, 14),
      @moui_skia.Point::new(15, 16),
      @moui_skia.Point::new(17, 18),
    )
    .close()
  let transformed = path.transform(
    @moui_skia.Matrix::scale_translate(2, 3, 10, 20),
  )
  assert_true(transformed.fill_type == EvenOdd)
  assert_true(transformed.last_point() == Some(@moui_skia.Point::new(44, 74)))
  assert_true(transformed.verbs[0] == MoveTo(@moui_skia.Point::new(12, 26)))
  assert_true(
    transformed.verbs[3] ==
    ConicTo(@moui_skia.Point::new(28, 50), @moui_skia.Point::new(32, 56), 0.5),
  )
  assert_true(transformed.verbs[5] == Close)

  let offset = path.offset(2, 3)
  assert_true(offset.bounds() == Some(@moui_skia.Rect::new(3, 5, 19, 21)))
}

///|
test "path stroke bounds conservatively outsets geometry" {
  let path = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(1, 2, 3, 4),
  )
  let fill = @moui_skia.Paint::new(style=Fill, stroke_width=10)
  assert_true(path.stroke_bounds(fill) == path.bounds())
  let stroke = @moui_skia.Paint::new(style=Stroke, stroke_width=6)
  assert_true(
    path.stroke_bounds(stroke) == Some(@moui_skia.Rect::new(-2, -1, 7, 9)),
  )
  let stroke_and_fill = @moui_skia.Paint::new(
    style=StrokeAndFill,
    stroke_width=2,
  )
  assert_true(
    path.stroke_bounds(stroke_and_fill) ==
    Some(@moui_skia.Rect::new(0, 1, 5, 7)),
  )
  assert_true(@moui_skia.Path::new().stroke_bounds(stroke) is None)
}

///|
test "path compute tight bounds excludes off-curve controls" {
  let quad = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(0, 0))
    .quad_to(@moui_skia.Point::new(10, 10), @moui_skia.Point::new(20, 0))
  assert_true(quad.bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 10)))
  assert_true(
    quad.compute_tight_bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 5)),
  )

  let conic = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(0, 0))
    .conic_to(@moui_skia.Point::new(10, 10), @moui_skia.Point::new(20, 0), 1)
  assert_true(conic.bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 10)))
  assert_true(
    conic.compute_tight_bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 5)),
  )

  let cubic = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(0, 0))
    .cubic_to(
      @moui_skia.Point::new(0, 12),
      @moui_skia.Point::new(12, 12),
      @moui_skia.Point::new(12, 0),
    )
  assert_true(cubic.bounds() == Some(@moui_skia.Rect::new(0, 0, 12, 12)))
  assert_true(
    cubic.compute_tight_bounds() == Some(@moui_skia.Rect::new(0, 0, 12, 9)),
  )
}
