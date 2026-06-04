///|
fn run_image_codec_smoke(
  surface : @native.Surface,
  canvas : @native.Canvas,
  size : @skia.ISize,
  red_bounds : @skia.IRect,
) -> Unit {
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
  if surface.image_snapshot_with_bounds(@skia.IRect::from_xywh(-1, 0, 4, 4))
    is Some(_) ||
    surface.image_snapshot_with_bounds(@skia.IRect::from_xywh(30, 30, 4, 4))
    is Some(_) {
    fail_smoke("out-of-bounds surface snapshot should be rejected")
  }
  println("native smoke surface bounds rejected")
  println(1)
  guard @native.Surface::raster_n32_premul(@skia.ISize::new(4, 4))
    is Some(sampling_surface) else {
    fail_smoke("failed to create image sampling guard surface")
  }
  guard sampling_surface.canvas() is Some(sampling_canvas) else {
    fail_smoke("failed to create image sampling guard canvas")
  }
  sampling_canvas.clear(@skia.Color::white())
  sampling_canvas.draw_image_rect(
    red_image,
    @skia.Rect::from_xywh(0, 0, 4, 4),
    @skia.Rect::from_xywh(0, 0, 4, 4),
    @skia.Paint::new(),
    sampling=@skia.SamplingOptions::from_cubic(
      @skia.CubicResampler::new(0.0 / 0.0, 1.0 / 0.0),
    ),
  )
  guard sampling_surface.read_pixels(bounds=@skia.IRect::from_xywh(0, 0, 1, 1))
    is Some(sampling_pixmap) else {
    fail_smoke("failed to read image sampling guard pixel")
  }
  assert_pixel(sampling_pixmap, @skia.IPoint::new(0, 0), 0xff, 0x00, 0x00, 0xff)
  println("native smoke image sampling scalars sanitized")
  println(1)
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
  guard image.encode_to_data(format=@skia.PNG, quality=-100)
    is Some(low_quality_data) else {
    fail_smoke("failed to encode PNG with clamped low quality")
  }
  guard image.encode_to_data(format=@skia.PNG, quality=999)
    is Some(high_quality_data) else {
    fail_smoke("failed to encode PNG with clamped high quality")
  }
  if low_quality_data.size() <= 0 ||
    high_quality_data.size() <= 0 ||
    image.encode_to_data(format=@skia.AVIF, quality=100) is Some(_) ||
    image.encode_to_data(format=@skia.JPEGXL, quality=100) is Some(_) {
    fail_smoke("native image encode parameter validation failed")
  }
  println("native smoke image encode parameters sanitized")
  println(1)

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

  guard @skia.ImageDescriptor::encoded(
      encoded,
      format=Some(@skia.PNG),
      dimensions=Some(size),
    )
    is Some(render_image_descriptor) else {
    fail_smoke("failed to create render image descriptor")
  }
  let render_image_target = @skia.SurfaceTargetDescriptor::raster_n32_premul(
    @skia.ISize::new(8, 4),
  )
  let render_image_commands = @skia.RenderCommandList::for_target(
      render_image_target,
    )
    .clear(@skia.Color::white())
    .draw_image(render_image_descriptor, @skia.Point::new(-4, -4))
    .draw_image_rect(
      render_image_descriptor,
      @skia.Rect::from_xywh(4, 4, 4, 4),
      @skia.Rect::from_xywh(4, 0, 4, 4),
      sampling=@skia.SamplingOptions::new(),
    )
  let render_image_plan = render_image_commands.resource_plan()
  if render_image_plan.length() != 2 ||
    render_image_plan.count_kind(@skia.SurfaceResource) != 1 ||
    render_image_plan.count_kind(@skia.ImageResource) != 1 ||
    !render_image_plan.contains_key(render_image_descriptor.resource_key()) {
    fail_smoke("native render image command resource plan is invalid")
  }
  guard @native.Surface::raster_n32_premul(@skia.ISize::new(8, 4))
    is Some(render_image_surface) else {
    fail_smoke("failed to create render image replay surface")
  }
  guard render_image_surface.canvas() is Some(render_image_canvas) else {
    fail_smoke("failed to borrow render image replay canvas")
  }
  let render_image_cache : @skia.ResourceCache[
    @skia.RendererResourceKey,
    @native.Image,
  ] = @skia.ResourceCache::new(max_bytes=encoded.length().to_int64() * 2L)
  let render_image_stats = render_image_canvas.replay_with_image_cache(
    render_image_commands, render_image_cache,
  )
  let render_image_cache_stats = render_image_cache.stats()
  if render_image_stats.command_count != render_image_commands.length() ||
    render_image_stats.draw_count != 2 ||
    !render_image_stats.is_complete() ||
    render_image_cache.length() != 1 ||
    render_image_cache_stats.misses != 1 ||
    render_image_cache_stats.hits != 1 {
    fail_smoke("native render image command replay stats did not match")
  }
  guard render_image_surface.read_pixels() is Some(render_image_pixmap) else {
    fail_smoke("failed to read render image replay pixels")
  }
  assert_pixel(
    render_image_pixmap,
    @skia.IPoint::new(0, 0),
    0xff,
    0x00,
    0x00,
    0xff,
  )
  assert_pixel(
    render_image_pixmap,
    @skia.IPoint::new(4, 0),
    0xff,
    0x00,
    0x00,
    0xff,
  )
  println("native smoke render image command replay")
  println(1)
  println("native smoke render image command count")
  println(render_image_stats.command_count)
  println("native smoke render image resource plan count")
  println(render_image_plan.length())
  println("native smoke render image cache resources")
  println(render_image_cache.length())
  println("native smoke render image cache misses")
  println(render_image_cache_stats.misses)
  println("native smoke render image cache hits")
  println(render_image_cache_stats.hits)

  guard @skia.ImageDescriptor::encoded(
      b"not-a-real-png",
      format=Some(@skia.PNG),
      dimensions=Some(@skia.ISize::new(2, 2)),
    )
    is Some(render_image_decode_failure_descriptor) else {
    fail_smoke("failed to create undecodable render image descriptor")
  }
  let render_image_decode_failure_commands = @skia.RenderCommandList::for_target(
      @skia.SurfaceTargetDescriptor::raster_n32_premul(@skia.ISize::new(4, 4)),
    )
    .clear(@skia.Color::white())
    .draw_image(render_image_decode_failure_descriptor, @skia.Point::new(0, 0))
    .draw_image_rect(
      render_image_decode_failure_descriptor,
      @skia.Rect::from_xywh(0, 0, 2, 2),
      @skia.Rect::from_xywh(2, 0, 2, 2),
      sampling=@skia.SamplingOptions::new(),
    )
  let render_image_decode_failure_plan = render_image_decode_failure_commands.resource_plan()
  if render_image_decode_failure_plan.length() != 2 ||
    render_image_decode_failure_plan.count_kind(@skia.SurfaceResource) != 1 ||
    render_image_decode_failure_plan.count_kind(@skia.ImageResource) != 1 ||
    !render_image_decode_failure_plan.contains_key(
      render_image_decode_failure_descriptor.resource_key(),
    ) {
    fail_smoke("undecodable render image resource plan is invalid")
  }
  guard @native.Surface::raster_n32_premul(@skia.ISize::new(4, 4))
    is Some(render_image_decode_failure_surface) else {
    fail_smoke("failed to create undecodable render image replay surface")
  }
  guard render_image_decode_failure_surface.canvas()
    is Some(render_image_decode_failure_canvas) else {
    fail_smoke("failed to borrow undecodable render image replay canvas")
  }
  let render_image_decode_failure_resources = @native.NativeReplayResources::new(
    image_max_bytes=1024L,
  )
  let render_image_decode_failure_stats = render_image_decode_failure_canvas.replay_with_resources(
    render_image_decode_failure_commands, render_image_decode_failure_resources,
  )
  let render_image_decode_failure_cache_stats = render_image_decode_failure_resources.image_cache.stats()
  if render_image_decode_failure_stats.is_complete() ||
    render_image_decode_failure_stats.command_count !=
    render_image_decode_failure_commands.length() ||
    render_image_decode_failure_stats.replayed_count != 1 ||
    render_image_decode_failure_stats.skipped_count != 2 ||
    render_image_decode_failure_stats.draw_count != 2 ||
    render_image_decode_failure_stats.image_resource_count != 2 ||
    render_image_decode_failure_resources.image_cache.length() != 0 ||
    render_image_decode_failure_cache_stats.misses != 2 ||
    render_image_decode_failure_cache_stats.hits != 0 {
    fail_smoke("undecodable render image replay stats did not match")
  }
  println("native smoke render image decode failure resource plan count")
  println(render_image_decode_failure_plan.length())
  println("native smoke render image decode failure skipped")
  println(render_image_decode_failure_stats.skipped_count)
  println("native smoke render image decode failure cache resources")
  println(render_image_decode_failure_resources.image_cache.length())
  println("native smoke render image decode failure cache misses")
  println(render_image_decode_failure_cache_stats.misses)

  let empty_render_image_descriptor = @skia.EncodedImage(
    b"",
    Some(@skia.PNG),
    None,
  )
  let empty_render_image_commands = @skia.RenderCommandList::for_target(
      @skia.SurfaceTargetDescriptor::raster_n32_premul(@skia.ISize::new(4, 4)),
    )
    .clear(@skia.Color::white())
    .draw_image(empty_render_image_descriptor, @skia.Point::new(0, 0))
    .draw_image_rect(
      empty_render_image_descriptor,
      @skia.Rect::from_xywh(0, 0, 2, 2),
      @skia.Rect::from_xywh(2, 0, 2, 2),
      sampling=@skia.SamplingOptions::new(),
    )
  let empty_render_image_plan = empty_render_image_commands.resource_plan()
  if !empty_render_image_descriptor.resource_key().is_empty() ||
    empty_render_image_descriptor.resource_descriptor().is_cacheable() ||
    empty_render_image_plan.length() != 1 ||
    empty_render_image_plan.count_kind(@skia.SurfaceResource) != 1 ||
    empty_render_image_plan.count_kind(@skia.ImageResource) != 0 {
    fail_smoke("empty render image descriptor resource plan is not cache-safe")
  }
  guard @native.Surface::raster_n32_premul(@skia.ISize::new(4, 4))
    is Some(empty_render_image_surface) else {
    fail_smoke("failed to create empty render image replay surface")
  }
  guard empty_render_image_surface.canvas() is Some(empty_render_image_canvas) else {
    fail_smoke("failed to borrow empty render image replay canvas")
  }
  let empty_render_image_resources = @native.NativeReplayResources::new(
    image_max_bytes=1024L,
  )
  let empty_render_image_stats = empty_render_image_canvas.replay_with_resources(
    empty_render_image_commands, empty_render_image_resources,
  )
  let empty_render_image_cache_stats = empty_render_image_resources.image_cache.stats()
  if empty_render_image_stats.is_complete() ||
    empty_render_image_stats.command_count !=
    empty_render_image_commands.length() ||
    empty_render_image_stats.replayed_count != 1 ||
    empty_render_image_stats.skipped_count != 2 ||
    empty_render_image_stats.draw_count != 2 ||
    empty_render_image_stats.image_resource_count != 2 ||
    empty_render_image_resources.image_cache.length() != 0 ||
    empty_render_image_cache_stats.misses != 0 ||
    empty_render_image_cache_stats.hits != 0 {
    fail_smoke("empty render image replay should skip without touching cache")
  }
  println("native smoke empty image descriptor command plan count")
  println(empty_render_image_plan.length())
  println("native smoke empty image descriptor replay skipped")
  println(empty_render_image_stats.skipped_count)
  println("native smoke empty image descriptor cache misses")
  println(empty_render_image_cache_stats.misses)
}
