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
