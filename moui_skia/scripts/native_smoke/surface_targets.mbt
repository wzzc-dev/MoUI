///|
fn make_smoke_surface(size : @skia.ISize) -> @native.Surface? {
  guard @native.Surface::raster_n32_premul(size) is Some(surface) else {
    fail_smoke("failed to create raster N32 premul surface")
    None
  }
  if surface.dimensions() != size ||
    surface.image_info() != @skia.ImageInfo::n32_premul(size) {
    fail_smoke("surface metadata does not match requested N32 premul size")
  }
  let descriptor = surface.descriptor()
  if !descriptor.is_raster() ||
    descriptor.image_info != surface.image_info() ||
    descriptor.dimensions() != size {
    fail_smoke("surface descriptor does not match the raster surface")
  }
  println("native smoke surface descriptor backend")
  println("raster")
  guard @native.Surface::for_target(
      @skia.SurfaceTargetDescriptor::raster_n32_premul(size),
    )
    is Some(target_surface) else {
    fail_smoke("failed to create raster surface from target descriptor")
    None
  }
  if target_surface.dimensions() != size ||
    target_surface.descriptor() !=
    @skia.SurfaceDescriptor::raster_n32_premul(size) {
    fail_smoke("surface target factory raster metadata mismatch")
  }
  println("native smoke surface target factory raster")
  println(1)

  let unsupported_window_target = @skia.SurfaceTargetDescriptor::window_n32_premul(
    @skia.ISize::new(16, 16),
    target_id=b"native-smoke-window-factory",
  )
  let unsupported_gpu_target = @skia.SurfaceTargetDescriptor::gpu_n32_premul(
    @skia.ISize::new(16, 16),
    gpu_context_key=Some(
      @skia.GpuContextDescriptor::mock(id=b"native-smoke-gpu-factory").resource_key(),
    ),
  )
  if @native.Surface::for_target(unsupported_window_target) is Some(_) ||
    @native.Surface::for_target(unsupported_gpu_target) is Some(_) ||
    @native.Surface::target_support_status(unsupported_window_target) !=
    @native.SurfaceTargetWindowUnsupported ||
    @native.Surface::target_support_status(unsupported_gpu_target) !=
    @native.SurfaceTargetGpuUnsupported ||
    unsupported_window_target.resource_plan().count_kind(@skia.SurfaceResource) !=
    1 ||
    unsupported_gpu_target.resource_plan().count_kind(@skia.GpuSurfaceResource) !=
    1 ||
    unsupported_gpu_target.resource_plan().count_kind(@skia.GpuContextResource) !=
    1 {
    fail_smoke("future window/GPU target surface boundary is not predictable")
  }
  println("native smoke surface target factory unsupported")
  println(1)
  println("native smoke surface target support diagnostics")
  println(2)

  let metal_gpu_context = @skia.GpuContextDescriptor::metal(
    b"native-smoke-metal-gpu-context",
  )
  let metal_gpu_status = @native.Surface::gpu_context_support_status(
    metal_gpu_context,
  )
  if @native.Surface::gpu_context_support_status(
    @skia.GpuContextDescriptor::mock(id=b"native-smoke-mock-gpu-context"),
  ).is_available() {
    fail_smoke("mock GPU context must not report native Skia GPU availability")
  }
  if @native.Surface::metal_gpu_context_runtime_available() {
    if metal_gpu_status != @native.SkiaGpuContextAvailable {
      fail_smoke("Metal GPU runtime probe did not produce an available status")
    }
  } else if metal_gpu_status.is_available() {
    fail_smoke("Metal GPU context must not be available without a runtime probe")
  }
  println("native smoke gpu metal context support status")
  if metal_gpu_status.is_available() {
    println("available")
  } else {
    println("pending")
  }
  println("native smoke gpu metal surface allocation")
  match @native.GpuContext::metal(metal_gpu_context) {
    None =>
      if metal_gpu_status.is_available() {
        fail_smoke("available Metal GPU status did not create a native context")
      } else {
        println("pending")
      }
    Some(native_metal_context) => {
      let metal_gpu_target = @skia.SurfaceTargetDescriptor::gpu_n32_premul(
        @skia.ISize::new(8, 8),
        gpu_context_key=Some(native_metal_context.resource_key()),
      )
      if @native.Surface::target_support_status_with_gpu_context(
        metal_gpu_target, native_metal_context,
      ) != @native.SurfaceTargetSupported {
        fail_smoke("Metal GPU target did not report supported with its context")
      }
      guard @native.Surface::for_target_with_gpu_context(
          metal_gpu_target,
          native_metal_context,
        )
        is Some(gpu_surface) else {
        fail_smoke("failed to allocate Metal GPU-backed surface")
        None
      }
      if !gpu_surface.descriptor().is_gpu() ||
        gpu_surface.descriptor() != metal_gpu_target.surface ||
        !gpu_surface.flush_and_submit() {
        fail_smoke("Metal GPU-backed surface metadata/submit failed")
      }
      println("available")
      println("native smoke gpu metal surface frame finalized")
      let gpu_frame = @skia.RenderFrameDescriptor::empty(metal_gpu_target)
      if !gpu_surface.render_frame(gpu_frame, frame_index=1).is_complete() {
        fail_smoke("Metal GPU-backed surface frame did not finalize")
      }
      println("available")
    }
  }
  if !metal_gpu_status.is_available() {
    println("native smoke gpu metal surface frame finalized")
    println("pending")
  }

  let smoke_gpu_context = @skia.GpuContextDescriptor::mock(
    id=b"native-smoke-gpu-context",
  )
  let smoke_gpu_context_variant = @skia.GpuContextDescriptor::vulkan(
    b"native-smoke-gpu-context",
    adapter_id=b"native-smoke-adapter",
    device_id=b"native-smoke-device",
    queue_family_index=1,
  ).with_protected_context(true)
  let smoke_gpu_target = @skia.SurfaceTargetDescriptor::gpu_n32_premul(
    @skia.ISize::new(16, 16),
    gpu_context_key=Some(smoke_gpu_context.resource_key()),
  )
  let smoke_gpu_target_plan = smoke_gpu_target.resource_plan()
  let smoke_gpu_plan = @skia.RenderCommandList::for_target(smoke_gpu_target).resource_plan()
  let smoke_gpu_finalization = smoke_gpu_target.finalization_descriptor(
    frame_index=2,
  )
  let smoke_gpu_finalization_plan = smoke_gpu_finalization.resource_plan()
  if !smoke_gpu_target.has_gpu_context() ||
    smoke_gpu_target_plan.length() != 2 ||
    smoke_gpu_target_plan.count_kind(@skia.GpuSurfaceResource) != 1 ||
    smoke_gpu_target_plan.count_kind(@skia.GpuContextResource) != 1 ||
    smoke_gpu_plan.length() != 2 ||
    smoke_gpu_plan.gpu_backed_count != 2 ||
    !smoke_gpu_plan.has_gpu_backed_resources() ||
    !smoke_gpu_plan.contains_key(smoke_gpu_target.resource_key()) ||
    smoke_gpu_plan.contains_key(smoke_gpu_target.surface.resource_key()) {
    fail_smoke("gpu context resource plan did not include context and surface")
  }
  if !smoke_gpu_finalization.is_finalizable() ||
    !smoke_gpu_finalization.requires_gpu_context() ||
    smoke_gpu_finalization_plan.length() != 3 ||
    smoke_gpu_finalization_plan.gpu_backed_count != 3 ||
    smoke_gpu_finalization_plan.count_kind(@skia.GpuSurfaceResource) != 2 ||
    smoke_gpu_finalization_plan.count_kind(@skia.GpuContextResource) != 1 ||
    !smoke_gpu_finalization_plan.contains_key(smoke_gpu_target.resource_key()) ||
    !smoke_gpu_finalization_plan.contains_key(smoke_gpu_context.resource_key()) ||
    !smoke_gpu_finalization_plan.contains_key(
      smoke_gpu_finalization.resource_key(),
    ) {
    fail_smoke("gpu finalization descriptor resource plan is invalid")
  }
  let smoke_gpu_frame = @skia.RenderCommandList::for_target(smoke_gpu_target).frame_descriptor(
    smoke_gpu_target,
  )
  let smoke_gpu_missing_context_target = smoke_gpu_target.without_gpu_context()
  let smoke_gpu_missing_context_frame = @skia.RenderCommandList::for_target(
    smoke_gpu_missing_context_target,
  ).frame_descriptor(smoke_gpu_missing_context_target)
  if !smoke_gpu_frame.requires_gpu_context() ||
    !smoke_gpu_frame.has_gpu_context() ||
    !smoke_gpu_frame.is_ready() ||
    smoke_gpu_missing_context_frame.validation_status() !=
    @skia.FrameMissingGpuContext ||
    smoke_gpu_missing_context_frame.is_ready() {
    fail_smoke("gpu frame validation did not require an attached context")
  }
  if smoke_gpu_context.resource_key().is_empty() ||
    smoke_gpu_context_variant.resource_key().is_empty() ||
    smoke_gpu_context.resource_key() == smoke_gpu_context_variant.resource_key() ||
    smoke_gpu_context_variant.resource_descriptor().key !=
    smoke_gpu_context_variant.resource_key() ||
    !smoke_gpu_context_variant.resource_descriptor().is_gpu_backed() {
    fail_smoke("gpu context resource key did not encode identity inputs")
  }
  println("native smoke surface target resource plan count")
  println(smoke_gpu_target_plan.length())
  let smoke_gpu_target_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @skia.RendererResourceDescriptor,
  ] = @skia.ResourceCache::new()
  let smoke_gpu_target_missing_before = smoke_gpu_target_cache.missing_cacheable_resource_plan(
    smoke_gpu_target_plan,
  )
  let smoke_gpu_target_cache_inserts = smoke_gpu_target_cache.insert_resource_plan(
    smoke_gpu_target_plan,
  )
  let smoke_gpu_target_cached_after = smoke_gpu_target_cache.cached_cacheable_resource_plan(
    smoke_gpu_target_plan,
  )
  if smoke_gpu_target_missing_before.length() != 2 ||
    smoke_gpu_target_cache_inserts != 2 ||
    smoke_gpu_target_cached_after.length() != 2 ||
    !smoke_gpu_target_cache.contains_resource_plan(smoke_gpu_target_plan) {
    fail_smoke("surface target resource plan did not populate the cache")
  }
  println("native smoke surface target cache resources")
  println(smoke_gpu_target_cache_inserts)
  println("native smoke gpu context resource plan count")
  println(smoke_gpu_plan.length())
  println("native smoke gpu context key variation")
  println(1)
  println("native smoke gpu frame context validation")
  println(1)
  guard smoke_gpu_frame.present_descriptor(frame_index=2)
    is Some(smoke_gpu_present) else {
    fail_smoke("gpu frame did not expose a present descriptor")
    None
  }
  let smoke_gpu_present_plan = smoke_gpu_present.resource_plan()
  if smoke_gpu_present.buffer_index != 0 ||
    smoke_gpu_present_plan.length() != 3 ||
    smoke_gpu_present_plan.gpu_backed_count != 3 ||
    smoke_gpu_present_plan.cacheable_count != 2 ||
    smoke_gpu_present_plan.uncacheable_count != 1 ||
    !smoke_gpu_present_plan.contains_key(smoke_gpu_target.resource_key()) ||
    !smoke_gpu_present_plan.contains_key(smoke_gpu_context.resource_key()) ||
    !smoke_gpu_present_plan.contains_key(smoke_gpu_present.resource_key()) {
    fail_smoke("gpu present descriptor resource plan is invalid")
  }
  let smoke_gpu_submission = smoke_gpu_frame.submission_descriptor(
    frame_index=2,
  )
  let smoke_gpu_submission_gpu_plan = smoke_gpu_submission.gpu_backed_resource_plan()
  let smoke_gpu_missing_submission = smoke_gpu_missing_context_frame.submission_descriptor(
    frame_index=2,
  )
  let smoke_gpu_frame_finalization = smoke_gpu_frame.finalization_descriptor(
    frame_index=2,
  )
  let smoke_gpu_frame_finalization_gpu_plan = smoke_gpu_frame_finalization.gpu_backed_resource_plan()
  let smoke_gpu_missing_frame_finalization = smoke_gpu_missing_context_frame.finalization_descriptor(
    frame_index=2,
  )
  if !smoke_gpu_submission.is_ready() ||
    !smoke_gpu_submission.has_present() ||
    smoke_gpu_submission.resource_plan.length() != 3 ||
    smoke_gpu_submission.resource_plan.gpu_backed_count != 3 ||
    smoke_gpu_submission_gpu_plan.length() != 3 ||
    smoke_gpu_submission_gpu_plan.count_kind(@skia.GpuSurfaceResource) != 2 ||
    smoke_gpu_submission_gpu_plan.count_kind(@skia.GpuContextResource) != 1 ||
    !smoke_gpu_submission_gpu_plan.contains_key(smoke_gpu_target.resource_key()) ||
    !smoke_gpu_submission_gpu_plan.contains_key(
      smoke_gpu_context.resource_key(),
    ) ||
    !smoke_gpu_submission_gpu_plan.contains_key(
      smoke_gpu_present.resource_key(),
    ) ||
    smoke_gpu_missing_submission.is_ready() ||
    smoke_gpu_missing_submission.has_present() ||
    smoke_gpu_missing_submission
    .gpu_backed_resource_plan()
    .count_kind(@skia.GpuContextResource) !=
    0 {
    fail_smoke("gpu frame submission resource plan is invalid")
  }
  guard smoke_gpu_frame_finalization.finalization
    is Some(smoke_gpu_surface_finalization) else {
    fail_smoke("gpu frame did not expose a finalization descriptor")
    None
  }
  if !smoke_gpu_frame_finalization.is_ready() ||
    !smoke_gpu_frame_finalization.has_finalization() ||
    !smoke_gpu_frame_finalization.requires_gpu_context() ||
    smoke_gpu_frame_finalization.resource_plan.length() != 3 ||
    smoke_gpu_frame_finalization.resource_plan.gpu_backed_count != 3 ||
    smoke_gpu_frame_finalization_gpu_plan.length() != 3 ||
    smoke_gpu_frame_finalization_gpu_plan.count_kind(@skia.GpuSurfaceResource) !=
    2 ||
    smoke_gpu_frame_finalization_gpu_plan.count_kind(@skia.GpuContextResource) !=
    1 ||
    !smoke_gpu_frame_finalization_gpu_plan.contains_key(
      smoke_gpu_target.resource_key(),
    ) ||
    !smoke_gpu_frame_finalization_gpu_plan.contains_key(
      smoke_gpu_context.resource_key(),
    ) ||
    !smoke_gpu_frame_finalization_gpu_plan.contains_key(
      smoke_gpu_surface_finalization.resource_key(),
    ) ||
    smoke_gpu_missing_frame_finalization.is_ready() ||
    smoke_gpu_missing_frame_finalization.has_finalization() ||
    smoke_gpu_missing_frame_finalization
    .gpu_backed_resource_plan()
    .count_kind(@skia.GpuContextResource) !=
    0 {
    fail_smoke("gpu frame finalization resource plan is invalid")
  }
  println("native smoke gpu present resource plan count")
  println(smoke_gpu_present_plan.length())
  println("native smoke gpu finalization resource plan count")
  println(smoke_gpu_finalization_plan.length())
  println("native smoke gpu frame finalization resource plan count")
  println(smoke_gpu_frame_finalization.resource_plan.length())
  println("native smoke gpu frame finalization gpu resource count")
  println(smoke_gpu_frame_finalization_gpu_plan.length())
  println("native smoke gpu frame submission resource plan count")
  println(smoke_gpu_submission.resource_plan.length())
  println("native smoke gpu frame submission gpu resource count")
  println(smoke_gpu_submission_gpu_plan.length())

  let smoke_window = @skia.WindowSurfaceDescriptor::new(
    window_id=b"native-smoke-window",
    logical_size=@skia.Size::new(8, 8),
    device_pixel_ratio=2.0,
    present_mode=@skia.MailboxPresent,
  )
  let smoke_window_target = smoke_window.target_descriptor()
  let smoke_window_plan = smoke_window.resource_plan()
  let smoke_window_finalization = smoke_window_target.finalization_descriptor(
    frame_index=3,
  )
  let smoke_window_next_finalization = smoke_window_target.finalization_descriptor(
    frame_index=4,
  )
  let smoke_window_finalization_plan = smoke_window_finalization.resource_plan()
  let smoke_window_gpu_target = smoke_window.gpu_target_descriptor(
    gpu_context_key=Some(smoke_gpu_context.resource_key()),
  )
  let smoke_window_immediate_target = smoke_window_target.with_present_mode(
    @skia.ImmediatePresent,
  )
  let smoke_window_deeper_pacing_target = smoke_window_target.with_max_frames_in_flight(
    3,
  )
  if smoke_window.dimensions() != @skia.ISize::new(16, 16) ||
    smoke_window.logical_dimensions() != @skia.Size::new(8, 8) ||
    !smoke_window_target.has_target_id() ||
    smoke_window_target.target_id != b"native-smoke-window" ||
    !smoke_window_target.is_presentable() ||
    !smoke_window_target.is_multibuffered() ||
    smoke_window_target.max_frames_in_flight != 2 ||
    smoke_window_target.present_mode != Some(@skia.MailboxPresent) ||
    smoke_window_immediate_target.resource_key() ==
    smoke_window_target.resource_key() ||
    smoke_window_deeper_pacing_target.resource_key() ==
    smoke_window_target.resource_key() ||
    !smoke_window_immediate_target.needs_present() ||
    smoke_window_deeper_pacing_target.max_frames_in_flight != 3 ||
    smoke_window_plan.length() != 1 ||
    !smoke_window_plan.contains_key(smoke_window_target.resource_key()) ||
    !smoke_window_gpu_target.surface.is_gpu() ||
    smoke_window_gpu_target.resource_plan().length() != 2 {
    fail_smoke("window surface descriptor did not derive target resources")
  }
  if !smoke_window_finalization.is_finalizable() ||
    smoke_window_finalization.requires_gpu_context() ||
    smoke_window_finalization_plan.length() != 2 ||
    smoke_window_finalization_plan.cacheable_count != 1 ||
    smoke_window_finalization_plan.uncacheable_count != 1 ||
    !smoke_window_finalization_plan.contains_key(
      smoke_window_target.resource_key(),
    ) ||
    !smoke_window_finalization_plan.contains_key(
      smoke_window_finalization.resource_key(),
    ) ||
    smoke_window_finalization.resource_key() ==
    smoke_window_next_finalization.resource_key() {
    fail_smoke("window finalization descriptor resource plan is invalid")
  }
  println("native smoke window physical width")
  println(smoke_window.dimensions().width)
  println("native smoke window frame pacing")
  println(smoke_window_target.max_frames_in_flight)
  println("native smoke surface finalization resource plan count")
  println(smoke_window_finalization_plan.length())
  println("native smoke surface finalization key variation")
  println(1)
  println("native smoke window present mode key variation")
  println(1)
  println("native smoke window frame pacing key variation")
  println(1)
  println("native smoke window target resource plan count")
  println(smoke_window_plan.length())
  let smoke_window_identity_mismatch_frame = @skia.RenderCommandList::for_target(
    smoke_window_target,
  ).frame_descriptor(smoke_window_target.with_target_id(b"other-native-window"))
  if smoke_window_identity_mismatch_frame.validation_status() !=
    @skia.FrameTargetMismatch ||
    smoke_window_identity_mismatch_frame.is_ready() {
    fail_smoke(
      "render frame validation did not reject target identity mismatch",
    )
  }
  println("native smoke render target identity validation")
  println(1)
  let smoke_window_command_plan = @skia.RenderCommandList::for_target(
    smoke_window_target,
  ).resource_plan()
  if !smoke_window_command_plan.contains_key(smoke_window_target.resource_key()) ||
    smoke_window_command_plan.contains_key(
      smoke_window_target.surface.resource_key(),
    ) {
    fail_smoke("render command resource plan did not bind target identity")
  }
  println("native smoke render target resource binding")
  println(1)
  let smoke_window_frame = @skia.RenderCommandList::for_target(
      smoke_window_target,
    )
    .draw_rect(
      @skia.Rect::from_xywh(0, 0, 4, 4),
      paint=@skia.Paint::new(color=@skia.Color::black()),
    )
    .frame_descriptor(smoke_window_target)
  if !smoke_window_frame.needs_present() ||
    !smoke_window_frame.has_present() ||
    !smoke_window_frame.is_ready() ||
    smoke_window_frame.stats.present_count != 1 {
    fail_smoke(
      "render frame did not finalize a present command for window target",
    )
  }
  guard smoke_window_frame.present_descriptor(frame_index=3)
    is Some(smoke_window_present) else {
    fail_smoke("window frame did not expose a present descriptor")
    None
  }
  let smoke_window_present_plan = smoke_window_frame.present_resource_plan(
    frame_index=3,
  )
  guard smoke_window_frame.present_descriptor(frame_index=4)
    is Some(smoke_window_next_present) else {
    fail_smoke("window frame did not expose the next present descriptor")
    None
  }
  if smoke_window_present.buffer_index != 1 ||
    smoke_window_present.present_mode != Some(@skia.MailboxPresent) ||
    smoke_window_present_plan.length() != 2 ||
    smoke_window_present_plan.cacheable_count != 1 ||
    smoke_window_present_plan.uncacheable_count != 1 ||
    !smoke_window_present_plan.contains_key(smoke_window_target.resource_key()) ||
    !smoke_window_present_plan.contains_key(smoke_window_present.resource_key()) ||
    smoke_window_present.resource_key() ==
    smoke_window_next_present.resource_key() {
    fail_smoke("window present descriptor resource plan is invalid")
  }
  let smoke_window_submission = smoke_window_frame.submission_descriptor(
    frame_index=3,
  )
  let smoke_window_submission_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @skia.RendererResourceDescriptor,
  ] = @skia.ResourceCache::new()
  let smoke_window_submission_cached_before = smoke_window_submission.cached_cacheable_resource_plan(
    smoke_window_submission_cache,
  )
  let smoke_window_submission_missing_before = smoke_window_submission.missing_cacheable_resource_plan(
    smoke_window_submission_cache,
  )
  let smoke_window_submission_cache_inserts = smoke_window_submission.cache_resources(
    smoke_window_submission_cache,
  )
  let smoke_window_submission_cached_after = smoke_window_submission.cached_cacheable_resource_plan(
    smoke_window_submission_cache,
  )
  let smoke_window_submission_missing_after = smoke_window_submission.missing_cacheable_resource_plan(
    smoke_window_submission_cache,
  )
  let smoke_window_submission_cacheable_plan = smoke_window_submission.cacheable_resource_plan()
  let smoke_window_submission_uncacheable_plan = smoke_window_submission.uncacheable_resource_plan()
  if !smoke_window_submission.is_ready() ||
    !smoke_window_submission.has_present() ||
    smoke_window_submission.validation_status != @skia.FrameReady ||
    smoke_window_submission.resource_plan.length() != 2 ||
    smoke_window_submission.resource_plan.cacheable_count != 1 ||
    smoke_window_submission.resource_plan.uncacheable_count != 1 ||
    smoke_window_submission_cacheable_plan.length() != 1 ||
    smoke_window_submission_uncacheable_plan.length() != 1 ||
    !smoke_window_submission_cached_before.is_empty() ||
    smoke_window_submission_missing_before.length() != 1 ||
    smoke_window_submission_cache_inserts != 1 ||
    smoke_window_submission_cache.length() != 1 ||
    smoke_window_submission_cached_after.length() != 1 ||
    !smoke_window_submission_missing_after.is_empty() ||
    !smoke_window_submission.resource_plan.contains_key(
      smoke_window_target.resource_key(),
    ) ||
    !smoke_window_submission.resource_plan.contains_key(
      smoke_window_present.resource_key(),
    ) ||
    !smoke_window_submission_cacheable_plan.contains_key(
      smoke_window_target.resource_key(),
    ) ||
    smoke_window_submission_cacheable_plan.contains_key(
      smoke_window_present.resource_key(),
    ) ||
    !smoke_window_submission_uncacheable_plan.contains_key(
      smoke_window_present.resource_key(),
    ) ||
    smoke_window_submission_uncacheable_plan.contains_key(
      smoke_window_target.resource_key(),
    ) ||
    smoke_window_submission_cache.contains(smoke_window_present.resource_key()) {
    fail_smoke("window frame submission descriptor is invalid")
  }
  let smoke_window_frame_finalization = smoke_window_frame.finalization_descriptor(
    frame_index=3,
  )
  guard smoke_window_frame_finalization.finalization
    is Some(smoke_window_frame_surface_finalization) else {
    fail_smoke("window frame did not expose a finalization descriptor")
    None
  }
  let smoke_window_frame_finalization_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @skia.RendererResourceDescriptor,
  ] = @skia.ResourceCache::new()
  let smoke_window_frame_finalization_cached_before = smoke_window_frame_finalization.cached_cacheable_resource_plan(
    smoke_window_frame_finalization_cache,
  )
  let smoke_window_frame_finalization_missing_before = smoke_window_frame_finalization.missing_cacheable_resource_plan(
    smoke_window_frame_finalization_cache,
  )
  let smoke_window_frame_finalization_cache_inserts = smoke_window_frame_finalization.cache_resources(
    smoke_window_frame_finalization_cache,
  )
  let smoke_window_frame_finalization_cached_after = smoke_window_frame_finalization.cached_cacheable_resource_plan(
    smoke_window_frame_finalization_cache,
  )
  let smoke_window_frame_finalization_missing_after = smoke_window_frame_finalization.missing_cacheable_resource_plan(
    smoke_window_frame_finalization_cache,
  )
  let smoke_window_frame_finalization_cacheable_plan = smoke_window_frame_finalization.cacheable_resource_plan()
  let smoke_window_frame_finalization_uncacheable_plan = smoke_window_frame_finalization.uncacheable_resource_plan()
  if !smoke_window_frame_finalization.is_ready() ||
    !smoke_window_frame_finalization.has_finalization() ||
    smoke_window_frame_finalization.validation_status != @skia.FrameReady ||
    smoke_window_frame_finalization.resource_plan.length() != 2 ||
    smoke_window_frame_finalization.resource_plan.cacheable_count != 1 ||
    smoke_window_frame_finalization.resource_plan.uncacheable_count != 1 ||
    smoke_window_frame_finalization_cacheable_plan.length() != 1 ||
    smoke_window_frame_finalization_uncacheable_plan.length() != 1 ||
    !smoke_window_frame_finalization_cached_before.is_empty() ||
    smoke_window_frame_finalization_missing_before.length() != 1 ||
    smoke_window_frame_finalization_cache_inserts != 1 ||
    smoke_window_frame_finalization_cache.length() != 1 ||
    smoke_window_frame_finalization_cached_after.length() != 1 ||
    !smoke_window_frame_finalization_missing_after.is_empty() ||
    !smoke_window_frame_finalization.resource_plan.contains_key(
      smoke_window_target.resource_key(),
    ) ||
    !smoke_window_frame_finalization.resource_plan.contains_key(
      smoke_window_frame_surface_finalization.resource_key(),
    ) ||
    !smoke_window_frame_finalization_cacheable_plan.contains_key(
      smoke_window_target.resource_key(),
    ) ||
    smoke_window_frame_finalization_cacheable_plan.contains_key(
      smoke_window_frame_surface_finalization.resource_key(),
    ) ||
    !smoke_window_frame_finalization_uncacheable_plan.contains_key(
      smoke_window_frame_surface_finalization.resource_key(),
    ) ||
    smoke_window_frame_finalization_uncacheable_plan.contains_key(
      smoke_window_target.resource_key(),
    ) ||
    smoke_window_frame_finalization_cache.contains(
      smoke_window_frame_surface_finalization.resource_key(),
    ) {
    fail_smoke("window frame finalization descriptor is invalid")
  }
  let smoke_window_unfinished_commands = @skia.RenderCommandList::new(
    @skia.RenderPassDescriptor::for_target(smoke_window_target),
  )
  let smoke_window_missing_present_frame : @skia.RenderFrameDescriptor = {
    target: smoke_window_target,
    command_list: smoke_window_unfinished_commands,
    resource_plan: smoke_window_unfinished_commands.resource_plan(),
    stats: smoke_window_unfinished_commands.stats(),
    touched_bounds: smoke_window_unfinished_commands.touched_bounds(),
  }
  if smoke_window_missing_present_frame.validation_status() !=
    @skia.FrameMissingPresent ||
    smoke_window_missing_present_frame.is_ready() {
    fail_smoke("render frame validation did not reject missing present command")
  }
  if smoke_window_missing_present_frame.present_descriptor(frame_index=3)
    is Some(_) ||
    !smoke_window_missing_present_frame
    .present_resource_plan(frame_index=3)
    .is_empty() {
    fail_smoke("missing-present frame exposed a present descriptor")
  }
  let smoke_window_missing_submission = smoke_window_missing_present_frame.submission_descriptor(
    frame_index=3,
  )
  let smoke_window_missing_submission_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @skia.RendererResourceDescriptor,
  ] = @skia.ResourceCache::new()
  if smoke_window_missing_submission.is_ready() ||
    smoke_window_missing_submission.has_present() ||
    smoke_window_missing_submission.cache_resources(
      smoke_window_missing_submission_cache,
    ) !=
    0 ||
    !smoke_window_missing_submission_cache.is_empty() {
    fail_smoke("missing-present frame submission descriptor was ready")
  }
  let smoke_window_missing_finalization = smoke_window_missing_present_frame.finalization_descriptor(
    frame_index=3,
  )
  let smoke_window_missing_finalization_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @skia.RendererResourceDescriptor,
  ] = @skia.ResourceCache::new()
  if smoke_window_missing_finalization.is_ready() ||
    smoke_window_missing_finalization.has_finalization() ||
    smoke_window_missing_finalization.cache_resources(
      smoke_window_missing_finalization_cache,
    ) !=
    0 ||
    !smoke_window_missing_finalization_cache.is_empty() {
    fail_smoke("missing-present frame finalization descriptor was ready")
  }
  guard surface.canvas() is Some(window_replay_canvas) else {
    fail_smoke("failed to borrow native canvas for present replay")
    None
  }
  let smoke_window_canvas_replay = window_replay_canvas.replay_frame(
    smoke_window_frame,
  )
  if !smoke_window_canvas_replay.is_complete() ||
    smoke_window_canvas_replay.status() != @native.CanvasReplayDeferredPresent ||
    !smoke_window_canvas_replay.status().is_complete() ||
    smoke_window_canvas_replay.present_count != 1 ||
    smoke_window_canvas_replay.skipped_count != 0 {
    fail_smoke("canvas replay did not defer present commands predictably")
  }
  guard smoke_window_frame.touched_bounds is Some(smoke_window_touched_bounds) else {
    fail_smoke("render frame did not record touched bounds for window target")
    None
  }
  if smoke_window_touched_bounds != @skia.Rect::from_xywh(0, 0, 4, 4) {
    fail_smoke("render frame touched bounds did not match window draw")
  }
  println("native smoke render frame present count")
  println(smoke_window_frame.stats.present_count)
  println("native smoke surface present buffer index")
  println(smoke_window_present.buffer_index)
  println("native smoke surface present resource plan count")
  println(smoke_window_present_plan.length())
  println("native smoke render frame present descriptor validation")
  println(1)
  println("native smoke render frame submission resource plan count")
  println(smoke_window_submission.resource_plan.length())
  println("native smoke render frame submission cacheable subplan count")
  println(smoke_window_submission_cacheable_plan.length())
  println("native smoke render frame submission uncacheable subplan count")
  println(smoke_window_submission_uncacheable_plan.length())
  println("native smoke render frame submission preflight missing count")
  println(smoke_window_submission_missing_before.length())
  println("native smoke render frame submission preflight cached count")
  println(smoke_window_submission_cached_after.length())
  println("native smoke render frame submission cache resources")
  println(smoke_window_submission_cache_inserts)
  println("native smoke render frame finalization resource plan count")
  println(smoke_window_frame_finalization.resource_plan.length())
  println("native smoke render frame finalization cacheable subplan count")
  println(smoke_window_frame_finalization_cacheable_plan.length())
  println("native smoke render frame finalization uncacheable subplan count")
  println(smoke_window_frame_finalization_uncacheable_plan.length())
  println("native smoke render frame finalization preflight missing count")
  println(smoke_window_frame_finalization_missing_before.length())
  println("native smoke render frame finalization preflight cached count")
  println(smoke_window_frame_finalization_cached_after.length())
  println("native smoke render frame finalization cache resources")
  println(smoke_window_frame_finalization_cache_inserts)
  println("native smoke render frame missing present validation")
  println(1)
  println("native smoke render frame missing finalization validation")
  println(1)
  println("native smoke render frame touched bounds width")
  println(smoke_window_touched_bounds.width().round().to_int())
  println("native smoke canvas replay deferred present")
  println(smoke_window_canvas_replay.present_count)

  Some(surface)
}
