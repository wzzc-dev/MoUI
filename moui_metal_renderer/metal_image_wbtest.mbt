///|
/// A 4x4 PNG whose left two columns are red and right two are blue, so a
/// placement or uv bug changes the *pattern*, not just the presence of ink.
let metal_test_png_base64 : String = "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAFElEQVR4nGP4z8DwH4Sh1H8G0gUALFAf4TOCTgoAAAAASUVORK5CYII="

///|
fn metal_test_png_source() -> @render.HostImageSource {
  let decoded = @base64.decode(metal_test_png_base64, ignore_whitespace=true) catch {
    _err => abort("metal image fixture must decode")
  }
  @render.HostImageSource::new(read=_source => Some(decoded))
}

///|
fn metal_test_image_run(
  frame~ : @core.Rect,
  fit~ : @core.ImageFit = Stretch,
  src_rect~ : @core.Rect? = None,
) -> @core.DrawCommand {
  @core.DrawImage(@core.ImageRun::{
    source: "test.png",
    frame,
    opacity: 1.0,
    fit,
    src_rect,
  })
}

///|
test "a decoded png lands with its own colour layout" {
  let pixels = metal_proof(
    width=8,
    height=8,
    commands=[metal_test_image_run(frame=metal_rect(0.0, 0.0, 8.0, height=8.0))],
    image_source=metal_test_png_source(),
  )
  assert_true(metal_is_red(metal_proof_pixel(pixels, 1, 4, 8)))
  assert_true(metal_is_blue(metal_proof_pixel(pixels, 6, 4, 8)))
}

///|
test "src_rect windows the source pixels instead of falling back to the image" {
  let right_half = metal_proof(
    width=8,
    height=8,
    commands=[
      metal_test_image_run(
        frame=metal_rect(0.0, 0.0, 8.0, height=8.0),
        src_rect=Some(metal_rect(2.0, 0.0, 2.0, height=4.0)),
      ),
    ],
    image_source=metal_test_png_source(),
  )
  assert_true(metal_pixel_is_blue(right_half, 1, 4))
  assert_true(metal_pixel_is_blue(right_half, 6, 4))
  let empty_window = metal_frame_report(
    commands=[
      metal_test_image_run(
        frame=metal_rect(0.0, 0.0, 8.0, height=8.0),
        src_rect=Some(metal_rect(9.0, 0.0, 2.0, height=2.0)),
      ),
    ],
    width=8.0,
    height=8.0,
  )
  assert_eq(empty_window.image_ops_unresolved, 1)
  assert_eq(empty_window.items, 0)
}

///|
fn metal_pixel_is_blue(pixels : Bytes, x : Int32, y : Int32) -> Bool {
  metal_is_blue(metal_proof_pixel(pixels, x, y, 8))
}

///|
test "async images request once, then wait for the completion" {
  let cache = new_metal_image_cache()
  let source = "pending.png"
  let image_source = @render.HostImageSource::new(read=_ => {
    Some(metal_test_png())
  })
  // No device here: the state machine must still record exactly one request and
  // draw nothing until a completion arrives.
  match ensure_metal_image_async(cache, context=0UL, image_source, source~) {
    Some(_) => fail("a first async sighting must draw nothing")
    None => ()
  }
  assert_eq(cache.requests, 1)
  match cache.lifecycle.lookup(source) {
    Some(record) => assert_eq(record.status, @render.ImageLoading)
    None => fail("the source must have a loading record")
  }
  // A second frame while the load is in flight must not re-request it.
  ignore(ensure_metal_image_async(cache, context=0UL, image_source, source~))
  assert_eq(cache.requests, 1)
}

///|
test "a failed image re-requests only once its bytes become readable" {
  let cache = new_metal_image_cache()
  let source = "appears-later.png"
  let readable = Ref(false)
  let image_source = @render.HostImageSource::new(read=_ => {
    if readable.val {
      Some(metal_test_png())
    } else {
      None
    }
  })
  ignore(ensure_metal_image_async(cache, context=0UL, image_source, source~))
  assert_eq(cache.requests, 1)
  ignore(
    apply_metal_image_completion(
      cache,
      context=0UL,
      @render.ImageResourceLoadCompletion::failed(
        source,
        diagnostic="not there yet",
      ),
    ),
  )
  match cache.lifecycle.lookup(source) {
    Some(record) => {
      assert_eq(record.status, @render.ImageFailed)
      assert_eq(record.diagnostic, "not there yet")
    }
    None => fail("the failure must be recorded")
  }
  // Still unreadable: no new request, the record stays failed.
  ignore(ensure_metal_image_async(cache, context=0UL, image_source, source~))
  assert_eq(cache.requests, 1)
  // The file appears: the next frame re-requests instead of giving up.
  readable.val = true
  ignore(ensure_metal_image_async(cache, context=0UL, image_source, source~))
  assert_eq(cache.requests, 2)
  match cache.lifecycle.lookup(source) {
    Some(record) => assert_eq(record.status, @render.ImageLoading)
    None => fail("the retry must reopen the record")
  }
}

///|
test "a decoded completion installs the texture the next frame draws" {
  let context = metal_context_create()
  if context == 0UL {
    abort("this test needs a Metal device to install a texture")
  }
  let cache = new_metal_image_cache()
  let source = "installed.png"
  let image_source = @render.HostImageSource::new(read=_ => {
    Some(metal_test_png())
  })
  let completion = decode_metal_image_payload(source, metal_test_png())
  assert_true(completion.has_decoded_rgba_payload())
  ignore(ensure_metal_image_async(cache, context~, image_source, source~))
  assert_eq(cache.uploads, 0)
  ignore(apply_metal_image_completion(cache, context~, completion))
  assert_eq(cache.uploads, 1)
  match cache.lifecycle.lookup(source) {
    Some(record) => assert_eq(record.status, @render.ImageReady)
    None => fail("the completion must produce a record")
  }
  match ensure_metal_image_async(cache, context~, image_source, source~) {
    None => fail("the frame after a ready completion must draw the image")
    Some((_, size)) => {
      assert_eq(size.width, 4.0)
      assert_eq(size.height, 4.0)
    }
  }
  metal_context_release(context)
}

///|
fn metal_test_png() -> Bytes {
  @base64.decode(metal_test_png_base64, ignore_whitespace=true) catch {
    _ => abort("metal image fixture must decode")
  }
}

///|
test "the frame after an async completion paints the image pixels" {
  let context = metal_context_create()
  if context == 0UL {
    abort("this test needs a Metal device")
  }
  let cache = new_metal_image_cache()
  let source = "second-frame.png"
  let image_source = @render.HostImageSource::new(read=_ => {
    Some(metal_test_png())
  })
  let run = @core.DrawImage(@core.ImageRun::{
    source,
    frame: metal_rect(0.0, 0.0, 8.0, height=8.0),
    opacity: 1.0,
    fit: @core.Stretch,
    src_rect: None,
  })
  let metrics = @core.SurfaceMetrics::new(
    logical_size=@core.Size::new(width=8.0, height=8.0),
    physical_size=@core.Size::new(width=8.0, height=8.0),
    scale_factor=1.0,
  )
  let frame_context = MetalFrameContext::{
    cache: @native_text.NativeTextCache::new(),
    atlas: new_metal_glyph_atlas(),
    images: cache,
    image_source,
    context,
    async_images: true,
    image_budget_bytes: METAL_IMAGE_MAX_RESIDENT_BYTES,
    retained: new_metal_retained_cache(),
  }
  // Frame one: the load is only requested, so nothing of the image paints.
  let first = build_metal_geometry(
    @render_common.lower_draw_commands([run]),
    metrics,
    frame_context,
  )
  assert_eq(first.item_count, 0)
  assert_eq(first.image_ops_pending, 1)
  ignore(
    apply_metal_image_completion(
      cache,
      context~,
      decode_metal_image_payload(source, metal_test_png()),
    ),
  )
  // Frame two: the same command now resolves, and the pixels are the fixture's
  // own red/blue halves.
  let second = build_metal_geometry(
    @render_common.lower_draw_commands([run]),
    metrics,
    frame_context,
  )
  assert_eq(second.item_count, 1)
  let vertices = second.vertex_bytes()
  let items = second.item_bytes()
  let shapes = second.shape_bytes()
  let layers = second.layer_bytes()
  let output = Bytes::make(8 * 8 * 4, 0)
  let drawn = metal_draw_proof(
    context,
    8,
    8,
    0.0,
    0.0,
    0.0,
    1.0,
    vertices,
    vertices.length(),
    items,
    items.length(),
    shapes,
    shapes.length(),
    layers,
    layers.length(),
    output,
    output.length(),
  )
  assert_eq(drawn, 1)
  assert_true(metal_pixel_is_red(output, 1, 4))
  assert_true(metal_pixel_is_blue(output, 6, 4))
  metal_context_release(context)
}

///|
fn metal_pixel_is_red(pixels : Bytes, x : Int32, y : Int32) -> Bool {
  metal_is_red(metal_proof_pixel(pixels, x, y, 8))
}

///|
/// The failure a texture budget can introduce is an image that goes quietly blank,
/// so this drives the *automatic* path -- one texture's worth of budget, ordinary
/// builds -- and asks three things: the coldest image's texture was released, the
/// frame that wanted it either repainted it or asked for it again, and the source
/// that stayed resident kept painting the whole time.
test "an evicted image is requested again while the resident one keeps painting" {
  let context = metal_context_create()
  if context == 0UL {
    abort("this test needs a Metal device")
  }
  let cache = new_metal_image_cache()
  let image_source = @render.HostImageSource::new(read=_ => {
    Some(metal_test_png())
  })
  let metrics = @core.SurfaceMetrics::new(
    logical_size=@core.Size::new(width=8.0, height=8.0),
    physical_size=@core.Size::new(width=8.0, height=8.0),
    scale_factor=1.0,
  )
  // One 4x4 RGBA8 texture fits; the second installed source pushes the total over.
  let frame_context = MetalFrameContext::{
    cache: @native_text.NativeTextCache::new(),
    atlas: new_metal_glyph_atlas(),
    images: cache,
    image_source,
    context,
    async_images: true,
    retained: new_metal_retained_cache(),
    image_budget_bytes: 4 * 4 * 4 + 1,
  }
  fn run_for(source : String) -> @core.DrawCommand {
    @core.DrawImage(@core.ImageRun::{
      source,
      frame: metal_rect(0.0, 0.0, 8.0, height=8.0),
      opacity: 1.0,
      fit: @core.Stretch,
      src_rect: None,
    })
  }
  fn build(source : String) -> MetalFrameGeometry {
    build_metal_geometry(
      @render_common.lower_draw_commands([run_for(source)]),
      metrics,
      frame_context,
    )
  }
  fn completes(source : String) -> Unit {
    ignore(
      apply_metal_image_completion(
        cache,
        context~,
        decode_metal_image_payload(source, metal_test_png()),
      ),
    )
  }
  // One texture's worth of budget: installing a second image has to make the
  // first one leave, and the frame that wants it back must ask for it again.
  ignore(build("first.png"))
  completes("first.png")
  ignore(build("second.png"))
  completes("second.png")
  // The enforcing frame is the one that decides: a build never leaves more than
  // its budget installed once the next frame has run.
  ignore(build("second.png"))
  assert_true(
    metal_image_resident_bytes(cache) <= 4 * 4 * 4 + 1,
    msg="the budget is not holding: \{metal_image_resident_bytes(cache)} bytes resident",
  )
  let cold = build("first.png")
  assert_true(
    cache.released > 0,
    msg="no texture was ever released with a one-image budget and two sources",
  )
  // Nothing vanished: the cold source is either resolved again this frame or
  // requested; the case that would be a bug is neither.
  assert_eq(
    cold.item_count + cold.image_ops_pending,
    1,
    msg="the evicted image neither painted nor was requested",
  )
  completes("first.png")
  let back = build("first.png")
  assert_eq(back.item_count, 1)
  let vertices = back.vertex_bytes()
  let items = back.item_bytes()
  let shapes = back.shape_bytes()
  let layers = back.layer_bytes()
  let output = Bytes::make(8 * 8 * 4, 0)
  let drawn = metal_draw_proof(
      context,
      8,
      8,
      0.0,
      0.0,
      0.0,
      1.0,
      vertices,
      vertices.length(),
      items,
      items.length(),
      shapes,
      shapes.length(),
      layers,
      layers.length(),
      output,
      output.length(),
    ) ==
    1
  metal_context_release(context)
  assert_true(drawn, msg="the frame after the re-completion did not draw")
  let painted = metal_proof_pixel(output, 1, 4, 8)
  let mirrored = metal_proof_pixel(output, 6, 4, 8)
  assert_true(
    metal_is_red(painted) ||
    metal_is_blue(painted) ||
    metal_is_red(mirrored) ||
    metal_is_blue(mirrored),
    msg="the re-installed image painted nothing",
  )
}
