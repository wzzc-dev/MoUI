///|
#cfg(any(target="native", target="llvm"))
#borrow(message)
extern "c" fn smoke_mark(message : Bytes) -> Unit = "skia_mbt_native_smoke_mark"

///|
#cfg(not(any(target="native", target="llvm")))
fn smoke_mark(message : Bytes) -> Unit {
  ignore(message)
}

///|
fn fail_smoke(message : String) -> Unit {
  println(message)
  abort("native smoke test failed")
}

///|
fn assert_pixel(
  pixmap : @skia.Pixmap,
  point : @skia.IPoint,
  b0 : Byte,
  b1 : Byte,
  b2 : Byte,
  b3 : Byte,
) -> Unit {
  guard pixmap.offset(point) is Some(offset) else {
    fail_smoke("pixel is outside the smoke-test pixmap")
  }
  if pixmap.pixels[offset] != b0 ||
    pixmap.pixels[offset + 1] != b1 ||
    pixmap.pixels[offset + 2] != b2 ||
    pixmap.pixels[offset + 3] != b3 {
    println(
      "unexpected pixel at " + point.x.to_string() + "," + point.y.to_string(),
    )
    println("expected")
    println(
      b0.to_hex() + " " + b1.to_hex() + " " + b2.to_hex() + " " + b3.to_hex(),
    )
    println("actual")
    println(
      pixmap.pixels[offset].to_hex() +
      " " +
      pixmap.pixels[offset + 1].to_hex() +
      " " +
      pixmap.pixels[offset + 2].to_hex() +
      " " +
      pixmap.pixels[offset + 3].to_hex(),
    )
    fail_smoke("unexpected pixel value in native smoke test")
  }
}

///|
fn assert_png_signature(bytes : Bytes) -> Unit {
  if bytes.length() < 8 {
    fail_smoke("encoded PNG data is too small")
  }
  if bytes[0] != 0x89 ||
    bytes[1] != 0x50 ||
    bytes[2] != 0x4e ||
    bytes[3] != 0x47 ||
    bytes[4] != 0x0d ||
    bytes[5] != 0x0a ||
    bytes[6] != 0x1a ||
    bytes[7] != 0x0a {
    fail_smoke("encoded image does not have a PNG signature")
  }
}

///|
fn assert_smoke_pixels(pixmap : @skia.Pixmap) -> Unit {
  assert_pixel(pixmap, @skia.IPoint::new(0, 0), 0xff, 0xff, 0xff, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(8, 8), 0xff, 0x00, 0x00, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(22, 8), 0x00, 0xff, 0x00, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(8, 22), 0x00, 0x00, 0xff, 0xff)
}

///|
fn smoke_text_bytes() -> Bytes {
  Bytes::from_array([0x53, 0x6b, 0x69, 0x61])
}

///|
fn main {
  smoke_mark(b"start")
  if !@native.skia_available() {
    fail_smoke(
      "real Skia backend is unavailable; configure native/moon.pkg with SKIA_MBT_HAS_SKIA, Skia headers, and linker flags",
    )
  }

  let size = @skia.ISize::new(32, 32)
  guard @native.Surface::raster_n32_premul(size) is Some(surface) else {
    fail_smoke("failed to create raster N32 premul surface")
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
  let smoke_gpu_plan = @skia.RenderCommandList::for_target(
    smoke_gpu_target,
  ).resource_plan()
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
  let smoke_gpu_frame = @skia.RenderCommandList::for_target(
    smoke_gpu_target,
  ).frame_descriptor(smoke_gpu_target)
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
  println("native smoke gpu context resource plan count")
  println(smoke_gpu_plan.length())
  println("native smoke gpu context key variation")
  println(1)
  println("native smoke gpu frame context validation")
  println(1)
  guard smoke_gpu_frame.present_descriptor(frame_index=2)
    is Some(smoke_gpu_present) else {
    fail_smoke("gpu frame did not expose a present descriptor")
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
  let smoke_gpu_submission_gpu_plan = smoke_gpu_submission
    .gpu_backed_resource_plan()
  let smoke_gpu_missing_submission = smoke_gpu_missing_context_frame
    .submission_descriptor(frame_index=2)
  if !smoke_gpu_submission.is_ready() ||
    !smoke_gpu_submission.has_present() ||
    smoke_gpu_submission.resource_plan.length() != 3 ||
    smoke_gpu_submission.resource_plan.gpu_backed_count != 3 ||
    smoke_gpu_submission_gpu_plan.length() != 3 ||
    smoke_gpu_submission_gpu_plan.count_kind(@skia.GpuSurfaceResource) != 2 ||
    smoke_gpu_submission_gpu_plan.count_kind(@skia.GpuContextResource) != 1 ||
    !smoke_gpu_submission_gpu_plan.contains_key(
      smoke_gpu_target.resource_key(),
    ) ||
    !smoke_gpu_submission_gpu_plan.contains_key(
      smoke_gpu_context.resource_key(),
    ) ||
    !smoke_gpu_submission_gpu_plan.contains_key(
      smoke_gpu_present.resource_key(),
    ) ||
    smoke_gpu_missing_submission.is_ready() ||
    smoke_gpu_missing_submission.has_present() ||
    smoke_gpu_missing_submission.gpu_backed_resource_plan().count_kind(
      @skia.GpuContextResource,
    ) != 0 {
    fail_smoke("gpu frame submission resource plan is invalid")
  }
  println("native smoke gpu present resource plan count")
  println(smoke_gpu_present_plan.length())
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
  let smoke_window_gpu_target = smoke_window.gpu_target_descriptor(
    gpu_context_key=Some(smoke_gpu_context.resource_key()),
  )
  let smoke_window_immediate_target = smoke_window_target.with_present_mode(
    @skia.ImmediatePresent,
  )
  let smoke_window_deeper_pacing_target = smoke_window_target
    .with_max_frames_in_flight(3)
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
  println("native smoke window physical width")
  println(smoke_window.dimensions().width)
  println("native smoke window frame pacing")
  println(smoke_window_target.max_frames_in_flight)
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
    fail_smoke("render frame validation did not reject target identity mismatch")
  }
  println("native smoke render target identity validation")
  println(1)
  let smoke_window_command_plan = @skia.RenderCommandList::for_target(
    smoke_window_target,
  ).resource_plan()
  if !smoke_window_command_plan.contains_key(smoke_window_target.resource_key()) ||
    smoke_window_command_plan.contains_key(smoke_window_target.surface.resource_key()) {
    fail_smoke("render command resource plan did not bind target identity")
  }
  println("native smoke render target resource binding")
  println(1)
  let smoke_window_frame = @skia.RenderCommandList::for_target(
    smoke_window_target,
  ).draw_rect(
    @skia.Rect::from_xywh(0, 0, 4, 4),
    paint=@skia.Paint::new(color=@skia.Color::black()),
  ).frame_descriptor(smoke_window_target)
  if !smoke_window_frame.needs_present() ||
    !smoke_window_frame.has_present() ||
    !smoke_window_frame.is_ready() ||
    smoke_window_frame.stats.present_count != 1 {
    fail_smoke("render frame did not finalize a present command for window target")
  }
  guard smoke_window_frame.present_descriptor(frame_index=3)
    is Some(smoke_window_present) else {
    fail_smoke("window frame did not expose a present descriptor")
  }
  let smoke_window_present_plan = smoke_window_frame.present_resource_plan(
    frame_index=3,
  )
  guard smoke_window_frame.present_descriptor(frame_index=4)
    is Some(smoke_window_next_present) else {
    fail_smoke("window frame did not expose the next present descriptor")
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
  let smoke_window_submission_cache_inserts = smoke_window_submission.cache_resources(
    smoke_window_submission_cache,
  )
  if !smoke_window_submission.is_ready() ||
    !smoke_window_submission.has_present() ||
    smoke_window_submission.validation_status != @skia.FrameReady ||
    smoke_window_submission.resource_plan.length() != 2 ||
    smoke_window_submission.resource_plan.cacheable_count != 1 ||
    smoke_window_submission.resource_plan.uncacheable_count != 1 ||
    smoke_window_submission_cache_inserts != 1 ||
    smoke_window_submission_cache.length() != 1 ||
    !smoke_window_submission.resource_plan.contains_key(
      smoke_window_target.resource_key(),
    ) ||
    !smoke_window_submission.resource_plan.contains_key(
      smoke_window_present.resource_key(),
    ) ||
    smoke_window_submission_cache.contains(smoke_window_present.resource_key()) {
    fail_smoke("window frame submission descriptor is invalid")
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
  if smoke_window_missing_present_frame.present_descriptor(frame_index=3) is Some(_) ||
    !smoke_window_missing_present_frame.present_resource_plan(
      frame_index=3,
    ).is_empty() {
    fail_smoke("missing-present frame exposed a present descriptor")
  }
  let smoke_window_missing_submission = smoke_window_missing_present_frame
    .submission_descriptor(frame_index=3)
  let smoke_window_missing_submission_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @skia.RendererResourceDescriptor,
  ] = @skia.ResourceCache::new()
  if smoke_window_missing_submission.is_ready() ||
    smoke_window_missing_submission.has_present() ||
    smoke_window_missing_submission.cache_resources(
      smoke_window_missing_submission_cache,
    ) != 0 ||
    !smoke_window_missing_submission_cache.is_empty() {
    fail_smoke("missing-present frame submission descriptor was ready")
  }
  guard smoke_window_frame.touched_bounds is Some(smoke_window_touched_bounds) else {
    fail_smoke("render frame did not record touched bounds for window target")
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
  println("native smoke render frame submission cache resources")
  println(smoke_window_submission_cache_inserts)
  println("native smoke render frame missing present validation")
  println(1)
  println("native smoke render frame touched bounds width")
  println(smoke_window_touched_bounds.width().round().to_int())

  guard surface.canvas() is Some(canvas) else {
    fail_smoke("failed to borrow native canvas")
  }

  canvas.clear(@skia.Color::white())
  canvas.draw_rect(
    @skia.Rect::from_xywh(4, 4, 10, 10),
    @skia.Paint::new(color=@skia.Color::red()),
  )
  canvas.draw_rect(
    @skia.Rect::from_xywh(18, 4, 10, 10),
    @skia.Paint::new(color=@skia.Color::green()),
  )
  canvas.draw_rect(
    @skia.Rect::from_xywh(4, 18, 10, 10),
    @skia.Paint::new(color=@skia.Color::blue()),
  )
  canvas.draw_points(
    [@skia.Point::new(30, 1)],
    @skia.Paint::new(color=@skia.Color::black(), stroke_width=1),
  )
  canvas.draw_points(
    [
      @skia.Point::new(28, 3),
      @skia.Point::new(31, 3),
      @skia.Point::new(28, 5),
      @skia.Point::new(31, 5),
    ],
    @skia.Paint::new(color=@skia.Color::black(), stroke_width=1),
    mode=@skia.Lines,
  )
  canvas.draw_points(
    [@skia.Point::new(28, 7), @skia.Point::new(31, 7), @skia.Point::new(31, 10)],
    @skia.Paint::new(color=@skia.Color::black(), stroke_width=1),
    mode=@skia.Polygon,
  )

  guard @native.Font::default(size=9.0) is Some(glyph_font) else {
    fail_smoke("failed to create native font for glyph drawing")
  }
  let glyph_text = smoke_text_bytes()
  let glyphs = glyph_font.text_to_glyphs_utf8(glyph_text)
  if glyphs.length() != glyph_font.count_text_utf8(glyph_text) ||
    glyphs.length() != 4 {
    fail_smoke("native font did not produce the expected glyph run")
  }
  let glyph_positions = glyph_font.glyph_positions(glyphs)
  if glyph_positions.length() != glyphs.length() {
    fail_smoke("native font did not produce positions for every glyph")
  }
  canvas.draw_glyphs(
    glyphs,
    glyph_positions,
    glyph_font,
    @skia.Paint::new(color=@skia.Color::black(), anti_alias=false),
    origin=@skia.Point::new(1, 31),
  )

  let save_count_before_clip = canvas.save_count()
  ignore(canvas.save())
  if canvas.save_count() != save_count_before_clip + 1 {
    fail_smoke("canvas save count did not increase after save")
  }
  let clip_bounds = @skia.Rect::from_xywh(28, 14, 4, 4)
  canvas.clip_rect(clip_bounds)
  if !canvas.quick_reject_rect(@skia.Rect::from_xywh(0, 14, 4, 4)) {
    fail_smoke("canvas did not reject a rect outside the active clip")
  }
  guard canvas.device_clip_bounds() is Some(device_clip) else {
    fail_smoke("canvas did not report device clip bounds")
  }
  if device_clip != @skia.IRect::from_xywh(28, 14, 4, 4) {
    fail_smoke("canvas device clip bounds do not match clipped rect")
  }
  println("native smoke canvas clip device width")
  println(device_clip.width())
  canvas.draw_rect(
    @skia.Rect::from_xywh(0, 0, 32, 32),
    @skia.Paint::new(color=@skia.Color::black()),
  )
  canvas.restore_to_count(save_count_before_clip)
  if canvas.save_count() != save_count_before_clip {
    fail_smoke("canvas save count did not restore after restore_to_count")
  }
  println("native smoke canvas state restored")
  println(canvas.save_count())
  canvas.draw_rect(
    @skia.Rect::from_xywh(28, 18, 4, 4),
    @skia.Paint::new(color=@skia.Color::black()),
  )

  guard @native.Shader::color(@skia.Color::cyan()) is Some(color_shader) else {
    fail_smoke("failed to create native color shader")
  }
  canvas.draw_rect_shader(
    @skia.Rect::from_xywh(18, 18, 4, 4),
    color_shader,
    @skia.Paint::new(),
  )
  guard @native.Shader::linear_gradient(
      @skia.Point::new(22, 18),
      @skia.Point::new(26, 18),
      @skia.Color::yellow(),
      @skia.Color::magenta(),
    )
    is Some(linear_shader) else {
    fail_smoke("failed to create native linear gradient shader")
  }
  canvas.draw_rect_shader(
    @skia.Rect::from_xywh(22, 18, 4, 4),
    linear_shader,
    @skia.Paint::new(),
  )
  guard @native.Shader::radial_gradient(
      @skia.Point::new(26, 24),
      2.0,
      @skia.Color::white(),
      @skia.Color::black(),
    )
    is Some(radial_shader) else {
    fail_smoke("failed to create native radial gradient shader")
  }
  canvas.draw_rect_shader(
    @skia.Rect::from_xywh(24, 22, 4, 4),
    radial_shader,
    @skia.Paint::new(),
  )
  println("native smoke shader draws")
  println(3)

  let color_shader_descriptor = @skia.ShaderDescriptor::color(
    @skia.Color::cyan(),
  )
  guard @skia.ShaderDescriptor::linear_gradient(
      @skia.Point::new(22, 18),
      @skia.Point::new(26, 18),
      @skia.Color::yellow(),
      @skia.Color::magenta(),
    )
    is Some(linear_shader_descriptor) else {
    fail_smoke("failed to create value-layer linear shader descriptor")
  }
  guard @skia.ShaderDescriptor::radial_gradient(
      @skia.Point::new(26, 24),
      2.0,
      @skia.Color::white(),
      @skia.Color::black(),
    )
    is Some(radial_shader_descriptor) else {
    fail_smoke("failed to create value-layer radial shader descriptor")
  }
  let shader_resource_plan = @skia.RendererResourcePlan::new([
    color_shader_descriptor.resource_descriptor(),
    linear_shader_descriptor.resource_descriptor(),
    radial_shader_descriptor.resource_descriptor(),
  ])
  if shader_resource_plan.length() != 3 ||
    shader_resource_plan.cacheable_count != 3 ||
    shader_resource_plan.uncacheable_count != 0 ||
    shader_resource_plan.byte_size <= 0L {
    fail_smoke("native shader resource plan did not match shader descriptors")
  }
  println("native smoke shader resource plan count")
  println(shader_resource_plan.length())

  guard @native.ColorFilter::saturation(0.8) is Some(color_filter) else {
    fail_smoke("failed to create native color filter")
  }
  guard @native.ImageFilter::blur(1.0, 1.0) is Some(image_filter) else {
    fail_smoke("failed to create native image filter")
  }
  guard @native.MaskFilter::blur(1.0) is Some(mask_filter) else {
    fail_smoke("failed to create native mask filter")
  }
  let filtered_layer_count = canvas.save_layer(
    bounds=Some(@skia.Rect::from_xywh(0, 0, 16, 16)),
    color_filter=Some(color_filter),
    image_filter=Some(image_filter),
    mask_filter=Some(mask_filter),
  )
  if filtered_layer_count <= 0 {
    fail_smoke("native filtered save_layer did not return a valid save count")
  }
  canvas.restore_to_count(save_count_before_clip)
  println("native smoke filter layer count")
  println(filtered_layer_count)

  guard @skia.ColorFilterDescriptor::saturation(0.8)
    is Some(color_filter_descriptor) else {
    fail_smoke("failed to create value-layer color filter descriptor")
  }
  guard @skia.ImageFilterDescriptor::blur(1.0, 1.0)
    is Some(image_filter_descriptor) else {
    fail_smoke("failed to create value-layer image filter descriptor")
  }
  guard @skia.MaskFilterDescriptor::blur(1.0) is Some(mask_filter_descriptor) else {
    fail_smoke("failed to create value-layer mask filter descriptor")
  }
  let filter_resource_plan = @skia.RendererResourcePlan::new([
    color_filter_descriptor.resource_descriptor(),
    image_filter_descriptor.resource_descriptor(),
    mask_filter_descriptor.resource_descriptor(),
  ])
  if filter_resource_plan.length() != 3 ||
    filter_resource_plan.cacheable_count != 3 ||
    filter_resource_plan.uncacheable_count != 0 ||
    filter_resource_plan.byte_size <= 0L {
    fail_smoke("native filter resource plan did not match filter descriptors")
  }
  println("native smoke filter resource plan count")
  println(filter_resource_plan.length())

  guard @native.Path::new() is Some(native_path) else {
    fail_smoke("failed to create native path")
  }
  native_path.add_rect(@skia.Rect::from_xywh(16, 24, 4, 4))
  if !native_path.contains(@skia.Point::new(18, 26)) {
    fail_smoke("native path does not contain a point inside its rect")
  }
  guard native_path.bounds() is Some(native_path_bounds) else {
    fail_smoke("native path did not report bounds")
  }
  if native_path_bounds != @skia.Rect::from_xywh(16, 24, 4, 4) {
    fail_smoke("native path bounds do not match its rect")
  }
  canvas.draw_path(native_path, @skia.Paint::new(color=@skia.Color::magenta()))

  guard @native.Path::new() is Some(native_poly) else {
    fail_smoke("failed to create native polygon path")
  }
  native_poly.add_poly(
    [
      @skia.Point::new(12, 28),
      @skia.Point::new(16, 28),
      @skia.Point::new(16, 31),
    ],
    close=true,
  )
  if !native_poly.is_last_contour_closed() ||
    native_poly.count_verbs() != 4 ||
    native_poly.count_points() != 3 {
    fail_smoke("native polygon path did not record the expected contour")
  }
  if !native_poly.contains(@skia.Point::new(15, 29)) {
    fail_smoke("native polygon path does not contain an interior point")
  }
  canvas.draw_path(native_poly, @skia.Paint::new(color=@skia.Color::magenta()))

  let portable_path = @skia.Path::new().add_rect(
    @skia.Rect::from_xywh(22, 26, 4, 4),
  )
  guard @native.Path::from_value(portable_path) is Some(replayed_path) else {
    fail_smoke("failed to replay portable path into native path")
  }
  if !replayed_path.contains(@skia.Point::new(24, 28)) {
    fail_smoke("replayed portable path does not contain an interior point")
  }
  canvas.draw_path_value(
    portable_path,
    @skia.Paint::new(color=@skia.Color::yellow()),
  )

  guard @native.Path::new() is Some(appended_path) else {
    fail_smoke("failed to create native add-path target")
  }
  appended_path.add_rect(@skia.Rect::from_xywh(28, 22, 2, 2))
  appended_path.add_path_value(
    @skia.Path::new().add_poly(
      [@skia.Point::new(0, 0), @skia.Point::new(3, 0), @skia.Point::new(3, 3)],
      close=true,
    ),
    matrix=@skia.Matrix::translate(28, 26),
  )
  if appended_path.count_verbs() != 9 ||
    appended_path.count_points() != 7 ||
    appended_path.bounds() != Some(@skia.Rect::new(28, 22, 31, 29)) {
    fail_smoke("native add_path_value did not append the expected geometry")
  }
  if !appended_path.contains(@skia.Point::new(30, 27)) {
    fail_smoke("native add_path_value does not contain appended geometry")
  }
  println("native smoke path verbs")
  println(appended_path.count_verbs())
  canvas.draw_path(appended_path, @skia.Paint::new(color=@skia.Color::cyan()))

  let save_count_before_transform = canvas.save_count()
  ignore(canvas.save())
  canvas.translate(@skia.Point::new(12, 24))
  canvas.draw_rect(
    @skia.Rect::from_xywh(0, 0, 3, 3),
    @skia.Paint::new(color=@skia.Color::cyan()),
  )
  canvas.restore_to_count(save_count_before_transform)

  if !surface.flush_and_submit() {
    fail_smoke("failed to flush and submit native surface")
  }
  println("native smoke surface flush-and-submit")
  println(1)

  guard surface.read_pixels() is Some(pixmap) else {
    fail_smoke("failed to read surface pixels")
  }
  smoke_mark(b"read pixels")
  if pixmap.dimensions() != size {
    fail_smoke("readback pixmap dimensions do not match the surface")
  }
  if pixmap.bytes_per_pixel() != 4 {
    fail_smoke("readback pixmap is not N32")
  }
  if pixmap.color_type() != @skia.RGBA8888 ||
    pixmap.alpha_type() != @skia.Premul {
    fail_smoke("readback pixmap color info is not N32 premul")
  }
  if pixmap.row_bytes() < size.width * 4 {
    fail_smoke("readback pixmap row bytes are too small")
  }

  assert_smoke_pixels(pixmap)
  assert_pixel(pixmap, @skia.IPoint::new(27, 15), 0xff, 0xff, 0xff, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(29, 15), 0x00, 0x00, 0x00, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(29, 19), 0x00, 0x00, 0x00, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(19, 19), 0x00, 0xff, 0xff, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(18, 26), 0xff, 0x00, 0xff, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(13, 25), 0x00, 0xff, 0xff, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(23, 27), 0xff, 0xff, 0x00, 0xff)
  println("native smoke readback width")
  println(pixmap.width())
  println("native smoke readback height")
  println(pixmap.height())
  println("native smoke readback row_bytes")
  println(pixmap.row_bytes())

  let red_bounds = @skia.IRect::from_xywh(4, 4, 4, 4)
  guard surface.read_pixels(bounds=red_bounds) is Some(red_pixmap) else {
    fail_smoke("failed to read bounded surface pixels")
  }
  if red_pixmap.dimensions() != red_bounds.size() {
    fail_smoke("bounded readback dimensions do not match requested bounds")
  }
  assert_pixel(red_pixmap, @skia.IPoint::new(0, 0), 0xff, 0x00, 0x00, 0xff)
  println("native smoke bounded readback width")
  println(red_pixmap.width())
  println("native smoke bounded readback height")
  println(red_pixmap.height())

  let replay_size = @skia.ISize::new(12, 12)
  guard @native.Surface::raster_n32_premul(replay_size) is Some(replay_surface) else {
    fail_smoke("failed to create replay smoke surface")
  }
  guard replay_surface.canvas() is Some(replay_canvas) else {
    fail_smoke("failed to create replay smoke canvas")
  }
  let replay_descriptor = @skia.TextRunDescriptor::new(
    range=@skia.TextRange::new(0, 5),
    fallback=@skia.FontFallbackRequest::new(
      families=@skia.FontFallbackChain::new(primary_family=b"Inter"),
      bcp47=[b"en"],
      character=0x68,
    ),
  )
  guard @native.Font::default(size=8.0) is Some(replay_font) else {
    fail_smoke("failed to create replay smoke font")
  }
  let replay_resource_descriptors = [
    color_shader_descriptor.resource_descriptor(),
    color_filter_descriptor.resource_descriptor(),
    image_filter_descriptor.resource_descriptor(),
    mask_filter_descriptor.resource_descriptor(),
  ]
  let replay_target = @skia.SurfaceTargetDescriptor::raster_n32_premul(
    replay_size,
  )
  let replay_commands = @skia.RenderCommandList::for_target(
      replay_target,
    )
    .declare_resources(replay_resource_descriptors)
    .clear(@skia.Color::white())
    .draw_rect(
      @skia.Rect::from_xywh(1, 1, 4, 4),
      paint=@skia.Paint::new(color=@skia.Color::red()),
    )
    .draw_path(
      @skia.Path::new().add_rect(@skia.Rect::from_xywh(6, 1, 4, 4)),
      paint=@skia.Paint::new(color=@skia.Color::blue()),
    )
    .draw_text_run_utf8(
      b"hello",
      @skia.Point::new(1, 10),
      descriptor=Some(replay_descriptor),
      font_key=@skia.RendererResourceKey::font(b"default:8"),
      paint=@skia.Paint::new(color=@skia.Color::black()),
    )
  let replay_plan = replay_commands.resource_plan()
  let replay_text_run_plan = replay_descriptor.resource_plan(
    b"hello",
    font_key=@skia.RendererResourceKey::font(b"default:8"),
  )
  if replay_text_run_plan.length() != 3 ||
    replay_text_run_plan.count_kind(@skia.TextRunResource) != 1 ||
    replay_text_run_plan.count_kind(@skia.FontResource) != 1 ||
    replay_text_run_plan.count_kind(@skia.TypefaceResource) != 1 ||
    replay_text_run_plan.byte_size <= 0L {
    fail_smoke("native text run resource plan did not include font and fallback dependencies")
  }
  let replay_measurement = @skia.TextMeasurementDescriptor::new(
    run=replay_descriptor,
    font_key=@skia.RendererResourceKey::font(b"default:8"),
    width=128.0,
    shape=true,
  )
  let replay_measurement_plan = replay_measurement.resource_plan(b"hello")
  if replay_measurement_plan.length() != 4 ||
    replay_measurement_plan.count_kind(@skia.TextRunResource) != 2 ||
    replay_measurement_plan.count_kind(@skia.FontResource) != 1 ||
    replay_measurement_plan.count_kind(@skia.TypefaceResource) != 1 ||
    replay_measurement_plan.byte_size <= replay_text_run_plan.byte_size {
    fail_smoke("native text measurement resource plan did not include measured run dependencies")
  }
  if replay_measurement.resource_key(b"hello") ==
    replay_measurement.with_width(64.0).resource_key(b"hello") ||
    replay_measurement.resource_key(b"hello") ==
    replay_measurement.with_shape(false).resource_key(b"hello") {
    fail_smoke("native text measurement resource key did not encode measurement inputs")
  }
  let replay_measured_advance = replay_font.measure_text_utf8(b"hello")
  let replay_measured_run = replay_measurement.measured_run_descriptor(
    advance=replay_measured_advance,
    bounds=replay_font.measure_text_bounds_utf8(b"hello"),
  )
  let replay_measured_run_plan = replay_measured_run.resource_plan(b"hello")
  if !replay_measured_run.is_valid() ||
    replay_measured_advance <= 0.0 ||
    replay_measured_run_plan.length() != 5 ||
    replay_measured_run_plan.count_kind(@skia.TextRunResource) != 3 ||
    replay_measured_run_plan.count_kind(@skia.FontResource) != 1 ||
    replay_measured_run_plan.count_kind(@skia.TypefaceResource) != 1 ||
    replay_measured_run_plan.byte_size <= replay_measurement_plan.byte_size ||
    !replay_measured_run_plan.contains_key(
      replay_measured_run.resource_key(b"hello"),
    ) ||
    !replay_measured_run_plan.contains_key(
      replay_measurement.resource_key(b"hello"),
    ) {
    fail_smoke("native measured text run metadata resource plan is invalid")
  }
  if replay_measured_run.resource_key(b"hello") ==
    replay_measurement.measured_run_descriptor(
      advance=replay_measured_advance + 1.0,
      bounds=replay_measured_run.bounds,
    ).resource_key(b"hello") {
    fail_smoke("native measured text run resource key did not encode result metadata")
  }
  let replay_shaping = @skia.TextShapingDescriptor::new(
    run=replay_descriptor,
    font_key=@skia.RendererResourceKey::font(b"default:8"),
    width=128.0,
  )
  let replay_shaping_plan = replay_shaping.resource_plan(b"hello")
  if replay_shaping_plan.length() != 4 ||
    replay_shaping_plan.count_kind(@skia.TextRunResource) != 2 ||
    replay_shaping_plan.count_kind(@skia.FontResource) != 1 ||
    replay_shaping_plan.count_kind(@skia.TypefaceResource) != 1 ||
    replay_shaping_plan.byte_size <= replay_text_run_plan.byte_size {
    fail_smoke("native text shaping resource plan did not include shaped run dependencies")
  }
  if replay_shaping.resource_key(b"hello") ==
    replay_shaping.with_width(64.0).resource_key(b"hello") ||
    replay_shaping.resource_key(b"hello") ==
    replay_shaping.with_run(
      replay_descriptor.with_direction(@skia.RightToLeft),
    ).resource_key(b"hello") {
    fail_smoke("native text shaping resource key did not encode shaping inputs")
  }
  let replay_shaped_run = replay_shaping.shaped_run_descriptor(
    glyph_count=4,
    cluster_count=4,
    advance=@skia.Point::new(16.0, 0.0),
  )
  let replay_shaped_run_plan = replay_shaped_run.resource_plan(b"hello")
  if !replay_shaped_run.is_valid() ||
    replay_shaped_run_plan.length() != 5 ||
    replay_shaped_run_plan.count_kind(@skia.TextRunResource) != 3 ||
    replay_shaped_run_plan.count_kind(@skia.FontResource) != 1 ||
    replay_shaped_run_plan.count_kind(@skia.TypefaceResource) != 1 ||
    replay_shaped_run_plan.byte_size <= replay_shaping_plan.byte_size {
    fail_smoke("native shaped text run resource plan is invalid")
  }
  if replay_shaped_run.resource_key(b"hello") ==
    replay_shaped_run.shaping.shaped_run_descriptor(
      glyph_count=5,
      cluster_count=4,
      advance=@skia.Point::new(16.0, 0.0),
    ).resource_key(b"hello") {
    fail_smoke("native shaped text run resource key did not encode result metadata")
  }
  println("native smoke text shaping resource plan count")
  println(replay_shaping_plan.length())
  println("native smoke shaped text resource plan count")
  println(replay_shaped_run_plan.length())
  let ranged_text_descriptor = @skia.TextRunDescriptor::new(
    range=@skia.TextRange::new(1, 5),
  )
  let ranged_text_key = ranged_text_descriptor.resource_key(
    b"xhelloz",
    font_key=@skia.RendererResourceKey::font(b"default:8"),
  )
  let same_ranged_text_key = ranged_text_descriptor.resource_key(
    b"yhelloq",
    font_key=@skia.RendererResourceKey::font(b"default:8"),
  )
  let ranged_text_resource = ranged_text_descriptor.resource_descriptor(
    b"xhelloz",
    font_key=@skia.RendererResourceKey::font(b"default:8"),
  )
  if ranged_text_key != same_ranged_text_key ||
    ranged_text_resource.byte_size != 4L {
    fail_smoke("native text run resource key was not scoped to byte range")
  }
  if replay_plan.length() != 9 ||
    replay_plan.cacheable_count != 9 ||
    replay_plan.uncacheable_count != 0 ||
    replay_plan.gpu_backed_count != 0 ||
    replay_plan.byte_size <= 0L {
    fail_smoke("native render resource plan did not match command list")
  }
  let replay_frame = replay_commands.frame_descriptor(replay_target)
  if !replay_frame.is_ready() ||
    replay_frame.validation_status() != @skia.FrameReady ||
    replay_frame.resource_plan.length() != 9 ||
    !replay_frame.resource_plan.contains_key(replay_target.resource_key()) ||
    !replay_frame.resource_plan.contains_key(
      replay_frame.command_list.pass.resource_descriptor().key,
    ) ||
    replay_frame.resource_plan.contains_key(
      replay_target.surface.resource_key(),
    ) {
    fail_smoke("native render frame descriptor did not match target resource plan")
  }
  let replay_unbalanced_frame = @skia.RenderCommandList::for_target(
    replay_target,
  ).save().frame_descriptor(replay_target)
  if replay_unbalanced_frame.validation_status() != @skia.FrameUnbalancedState ||
    replay_unbalanced_frame.is_ready() {
    fail_smoke("native render frame validation did not report unbalanced state")
  }
  println("native smoke render frame unbalanced validation")
  println(1)
  let replay_resource_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @skia.RendererResourceDescriptor,
  ] = @skia.ResourceCache::new(max_bytes=replay_frame.resource_plan.byte_size)
  let replay_cache_inserts = replay_frame.cache_resources(replay_resource_cache)
  if replay_cache_inserts != replay_frame.resource_plan.cacheable_count ||
    replay_resource_cache.byte_size() != replay_frame.resource_plan.byte_size ||
    !replay_resource_cache.contains_resource_plan(replay_frame.resource_plan) {
    fail_smoke("native render frame resources did not populate the resource cache")
  }
  let lru_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @skia.RendererResourceDescriptor,
  ] = @skia.ResourceCache::new(max_bytes=8L)
  let lru_image = @skia.RendererResourceDescriptor::image(
    b"native-smoke-cache-image",
    byte_size=4L,
  )
  let lru_shader = @skia.RendererResourceDescriptor::shader(
    b"native-smoke-cache-shader",
    byte_size=4L,
  )
  let lru_path = @skia.RendererResourceDescriptor::path(
    b"native-smoke-cache-path",
    byte_size=4L,
  )
  ignore(lru_cache.insert_resource_descriptor(lru_image))
  ignore(lru_cache.insert_resource_descriptor(lru_shader))
  if lru_cache.get(lru_image.key) != Some(lru_image) {
    fail_smoke("native resource cache did not report a refreshed LRU hit")
  }
  ignore(lru_cache.insert_resource_descriptor(lru_path))
  let lru_stats = lru_cache.stats()
  if lru_stats.evictions != 1 ||
    lru_stats.hits != 1 ||
    lru_stats.misses != 0 ||
    lru_cache.byte_size() != 8L ||
    !lru_cache.contains(lru_image.key) ||
    lru_cache.contains(lru_shader.key) ||
    !lru_cache.contains(lru_path.key) {
    fail_smoke("native resource cache LRU budget behavior did not match expectations")
  }
  let replay_stats = replay_canvas.replay(
    replay_commands,
    font=Some(replay_font),
  )
  if replay_stats.command_count != replay_commands.length() ||
    replay_stats.draw_count != 3 ||
    replay_stats.text_count != 1 ||
    !replay_stats.is_complete() {
    fail_smoke("native canvas replay stats did not match command list")
  }
  guard replay_surface.read_pixels(bounds=@skia.IRect::from_xywh(1, 1, 1, 1))
    is Some(replay_pixmap) else {
    fail_smoke("failed to read replay smoke pixels")
  }
  assert_pixel(replay_pixmap, @skia.IPoint::new(0, 0), 0xff, 0x00, 0x00, 0xff)
  println("native smoke canvas replay commands")
  println(replay_stats.command_count)
  println("native smoke render resource plan count")
  println(replay_plan.length())
  println("native smoke text run resource plan count")
  println(replay_text_run_plan.length())
  println("native smoke text run range byte size")
  println(ranged_text_resource.byte_size)
  println("native smoke text measurement resource plan count")
  println(replay_measurement_plan.length())
  println("native smoke measured text resource plan count")
  println(replay_measured_run_plan.length())
  println("native smoke measured text key variation")
  println(1)
  println("native smoke text measurement key variation")
  println(1)
  println("native smoke render frame resource plan count")
  println(replay_frame.resource_plan.length())
  println("native smoke render frame validation status")
  println(1)
  println("native smoke render frame cache resources")
  println(replay_cache_inserts)
  println("native smoke render resource cache inserts")
  println(replay_cache_inserts)
  println("native smoke render resource cache plan coverage")
  println(1)
  println("native smoke render resource cache evictions")
  println(lru_stats.evictions)
  println("native smoke render resource cache hits")
  println(lru_stats.hits)
  println("native smoke render resource cache misses")
  println(lru_stats.misses)
  println("native smoke render resource cache byte size")
  println(lru_cache.byte_size())

  guard surface.image_snapshot() is Some(image) else {
    fail_smoke("failed to snapshot surface")
  }
  if image.image_info() != @skia.ImageInfo::n32_premul(size) {
    fail_smoke("snapshot image metadata does not match N32 premul size")
  }
  guard surface.image_snapshot_with_bounds(red_bounds) is Some(red_image) else {
    fail_smoke("failed to snapshot bounded surface rectangle")
  }
  if red_image.dimensions() != red_bounds.size() {
    fail_smoke("bounded snapshot dimensions do not match requested bounds")
  }
  canvas.draw_image(red_image, @skia.Point::new(12, 28))
  canvas.draw_image_rect(
    red_image,
    @skia.Rect::from_xywh(0, 0, 4, 4),
    @skia.Rect::from_xywh(16, 28, 4, 4),
    @skia.Paint::new(),
    sampling=@skia.SamplingOptions::new(),
  )
  guard surface.read_pixels(bounds=@skia.IRect::from_xywh(12, 28, 8, 4))
    is Some(image_draw_pixmap) else {
    fail_smoke("failed to read image drawback pixels")
  }
  assert_pixel(
    image_draw_pixmap,
    @skia.IPoint::new(0, 0),
    0xff,
    0x00,
    0x00,
    0xff,
  )
  assert_pixel(
    image_draw_pixmap,
    @skia.IPoint::new(4, 0),
    0xff,
    0x00,
    0x00,
    0xff,
  )
  println("native smoke bounded snapshot width")
  println(red_image.width())
  println("native smoke bounded snapshot height")
  println(red_image.height())
  guard image.encode_to_data(format=@skia.PNG, quality=100) is Some(data) else {
    fail_smoke("failed to encode surface snapshot as PNG")
  }
  smoke_mark(b"encoded image")
  let encoded = data.to_bytes()
  if encoded.length() != data.size() {
    fail_smoke("encoded PNG byte length does not match Data::size")
  }
  assert_png_signature(encoded)
  println("native smoke encoded PNG bytes")
  println(encoded.length())

  guard @native.Image::from_encoded_bytes(encoded) is Some(decoded) else {
    fail_smoke("failed to decode encoded PNG bytes")
  }
  if decoded.dimensions() != size {
    fail_smoke("decoded PNG dimensions do not match the source surface")
  }
  println("native smoke decoded image width")
  println(decoded.width())
  println("native smoke decoded image height")
  println(decoded.height())

  guard @native.Codec::from_bytes(encoded) is Some(codec) else {
    fail_smoke("failed to create Codec from encoded PNG bytes")
  }
  if codec.encoded_format() != Some(@skia.PNG) {
    fail_smoke("Codec did not report PNG format")
  }
  if codec.dimensions() != size {
    fail_smoke("Codec dimensions do not match the source surface")
  }
  if codec.image_info() != @skia.ImageInfo::n32_premul(size) {
    fail_smoke("Codec image info does not match N32 premul size")
  }
  println("native smoke codec encoded format PNG")
  println("native smoke codec width")
  println(codec.width())
  println("native smoke codec height")
  println(codec.height())
  guard codec.decode_n32_premul() is Some(bitmap) else {
    fail_smoke("failed to decode PNG bytes into an N32 premul bitmap")
  }
  if bitmap.image_info() != @skia.ImageInfo::n32_premul(size) {
    fail_smoke("decoded bitmap metadata does not match N32 premul size")
  }
  if bitmap.row_bytes() < size.width * 4 ||
    bitmap.byte_size() < size.width * size.height * 4 {
    fail_smoke("decoded bitmap storage is too small for N32 pixels")
  }
  guard bitmap.to_pixmap() is Some(decoded_pixmap) else {
    fail_smoke("failed to copy decoded bitmap pixels")
  }
  assert_smoke_pixels(decoded_pixmap)
  smoke_mark(b"decoded bitmap")
  println("native smoke decoded bitmap width")
  println(decoded_pixmap.width())
  println("native smoke decoded bitmap height")
  println(decoded_pixmap.height())

  guard @native.Font::default(size=10.0) is Some(font) else {
    fail_smoke("failed to create default native font")
  }
  smoke_mark(b"font default")
  font.set_size(11.0)
  if font.size() != 11.0 {
    fail_smoke("native font size did not update")
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
      fail_smoke("native shaped text run descriptor did not record SkShaper metadata")
    }
    println("native smoke shaped text native resource plan count")
    println(shaped_smoke_plan.length())
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
  let fallback_key = fallback_request.resource_key()
  let fallback_language_key = @skia.FontFallbackRequest::new(
    families=@skia.FontFallbackChain::new(primary_family=first_family),
    bcp47=[b"ja"],
    character=0x53,
  ).resource_key()
  let fallback_character_key = fallback_request.with_character(0x4F61).resource_key()
  if fallback_key.is_empty() ||
    fallback_key != fallback_request.resource_key() ||
    fallback_key == fallback_language_key ||
    fallback_key == fallback_character_key {
    fail_smoke("native font fallback resource key did not encode request inputs")
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
  let fallback_match_descriptor = fallback_request.match_descriptor(fallback_family)
  if !fallback_match_descriptor.is_valid() ||
    fallback_match_descriptor.resource_key().is_empty() ||
    fallback_match_descriptor.resource_key() == fallback_key ||
    fallback_match_descriptor.resource_key() ==
    fallback_request.match_descriptor(
      fallback_family,
      fallback_index=fallback_match_descriptor.fallback_index,
      synthetic=true,
    ).resource_key() {
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
    fallback_request.resolution_descriptor(
      fallback_family,
      fallback_index=fallback_match_descriptor.fallback_index,
      synthetic=true,
    ).resource_key() ||
    fallback_resolution_plan.length() != 4 ||
    fallback_resolution_plan.count_kind(@skia.TypefaceResource) != 3 ||
    fallback_resolution_plan.count_kind(@skia.FontResource) != 1 ||
    !fallback_resolution_plan.contains_key(fallback_key) ||
    !fallback_resolution_plan.contains_key(
      fallback_match_descriptor.resource_key(),
    ) ||
    !fallback_resolution_plan.contains_key(fallback_resolution.resource_key()) ||
    fallback_resolution_plan.byte_size <= fallback_match_plan.byte_size {
    fail_smoke("native font fallback resolution metadata resource plan is invalid")
  }
  println("native smoke font fallback resolution key variation")
  println(1)
  println("native smoke font fallback resolution resource plan count")
  println(fallback_resolution_plan.length())
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

  smoke_mark(b"done")
  println("skia_mbt native smoke test passed")
}
