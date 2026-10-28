///|
/// Decoded-image state for one renderer session: the shared
/// `ImageResourceLifecycle` state machine plus the textures this route has
/// actually installed.
///
/// Decoding is Apple's ImageIO (`CGImageSource`), so the "no third-party
/// graphics library" boundary holds: PNG/JPEG/WebP decode, premultiplied RGBA8
/// conversion and texture upload all run on the system stack.
priv struct MetalImageCache {
  lifecycle : @render_common.ImageResourceLifecycle
  keys : Map[String, Int32]
  sizes : Map[Int32, @core.Size]
  // Installed textures in least-to-most-recently-used order, and the source each
  // key came from so releasing one can drop its lookup too.
  mut order : Array[Int32]
  source_of : Map[Int32, String]
  mut released : Int32
  mut next_id : Int32
  mut uploads : Int32
  mut failures : Int32
  mut requests : Int32
}

///|
fn new_metal_image_cache() -> MetalImageCache {
  MetalImageCache::{
    lifecycle: @render_common.ImageResourceLifecycle::new(),
    keys: Map([]),
    sizes: Map([]),
    order: [],
    source_of: Map([]),
    released: 0,
    next_id: 1,
    uploads: 0,
    failures: 0,
    requests: 0,
  }
}

///|
fn metal_image_key(cache : MetalImageCache, source : String) -> Int32 {
  match cache.keys.get(source) {
    Some(key) => key
    None => {
      let key = cache.next_id
      cache.next_id = cache.next_id + 1
      cache.keys[source] = key
      key
    }
  }
}

///|
fn metal_image_installed(
  cache : MetalImageCache,
  source : String,
) -> (Int32, @core.Size)? {
  match cache.keys.get(source) {
    Some(key) =>
      match cache.sizes.get(key) {
        Some(size) => {
          // Using a source this frame is what keeps it off the eviction list
          // until something colder turns up.
          metal_image_touch(cache, key)
          Some((key, size))
        }
        None => None
      }
    None => None
  }
}

///|
/// Move `key` to the most-recently-used end of the order.
fn metal_image_touch(cache : MetalImageCache, key : Int32) -> Unit {
  let next : Array[Int32] = []
  for existing in cache.order {
    if existing != key {
      next.push(existing)
    }
  }
  next.push(key)
  cache.order = next
}

///|
/// Resident decoded-texture budget in bytes. Sixteen 1080p-sized RGBA8 frames is
/// the production number; the showcase's fixtures are 4x4, so nothing evicts
/// there, and the cap exists for the sessions that do hold hundreds of images.
const METAL_IMAGE_MAX_RESIDENT_BYTES : Int32 = 64 * 1024 * 1024

///|
fn metal_image_bytes(cache : MetalImageCache, key : Int32) -> Int32 {
  match cache.sizes.get(key) {
    Some(size) => (size.width * size.height * 4.0).to_int()
    None => 0
  }
}

///|
fn metal_image_resident_bytes(cache : MetalImageCache) -> Int32 {
  let mut total = 0
  for key, _size in cache.sizes {
    total = total + metal_image_bytes(cache, key)
  }
  total
}

///|
/// Release the coldest installed textures until the resident total fits the
/// budget, dropping their lookups so the next frame treats the source as
/// unresolved and asks for it again. Returns how many were released this call.
fn metal_image_enforce_budget(
  cache : MetalImageCache,
  context : UInt64,
  max_bytes~ : Int32,
) -> Int32 {
  let mut resident = metal_image_resident_bytes(cache)
  let mut released = 0
  while resident > max_bytes && cache.order.length() > 0 {
    let key = cache.order[0]
    let rest : Array[Int32] = []
    let mut index = 1
    while index < cache.order.length() {
      rest.push(cache.order[index])
      index = index + 1
    }
    cache.order = rest
    let freed = metal_image_bytes(cache, key)
    match cache.source_of.get(key) {
      Some(source) => {
        ignore(cache.source_of.remove(key))
        ignore(cache.keys.remove(source))
      }
      None => ()
    }
    ignore(cache.sizes.remove(key))
    ignore(metal_image_release(context, key))
    resident = resident - freed
    released = released + 1
  }
  cache.released = cache.released + released
  released
}

///|
/// Decode `bytes` and install them as the texture for `source`. The synchronous
/// draw path and the async completion applier both funnel through here, so a
/// decoded payload can only reach the GPU one way.
fn install_metal_image_bytes(
  cache : MetalImageCache,
  context~ : UInt64,
  source~ : String,
  bytes~ : Bytes,
) -> @core.Size? {
  if context == 0UL || bytes.length() <= 0 {
    return None
  }
  let size_out = Bytes::make(8, 0)
  // Capacity 0 is a size probe: the stub reports the decoded extent and asks
  // for room instead of writing pixels.
  if metal_image_decode(bytes, bytes.length(), size_out, 0, size_out) != 2 {
    cache.failures = cache.failures + 1
    return None
  }
  let width = metal_read_i32(size_out, 0)
  let height = metal_read_i32(size_out, 4)
  let needed = width * height * 4
  if width <= 0 || height <= 0 || needed <= 0 {
    cache.failures = cache.failures + 1
    return None
  }
  let pixels = Bytes::make(needed, 0)
  if metal_image_decode(bytes, bytes.length(), pixels, needed, size_out) != 1 {
    cache.failures = cache.failures + 1
    return None
  }
  match
    write_metal_image_rgba(
      cache,
      context~,
      source~,
      width~,
      height~,
      row_bytes=width * 4,
      pixels~,
    ) {
    None => None
    Some(size) => Some(size)
  }
}

///|
/// Install already-decoded RGBA8 as the texture for `source`. A completion's
/// payload arrives decoded, so re-running it through the codec would fail: the
/// bytes are pixels, not a PNG.
fn write_metal_image_rgba(
  cache : MetalImageCache,
  context~ : UInt64,
  source~ : String,
  width~ : Int32,
  height~ : Int32,
  row_bytes~ : Int32,
  pixels~ : Bytes,
) -> @core.Size? {
  if context == 0UL ||
    width <= 0 ||
    height <= 0 ||
    row_bytes < width * 4 ||
    pixels.length() < row_bytes * height {
    cache.failures = cache.failures + 1
    return None
  }
  let key = metal_image_key(cache, source)
  if metal_image_write_rgba(
      context,
      key,
      width,
      height,
      row_bytes,
      pixels,
      pixels.length(),
    ) !=
    1 {
    cache.failures = cache.failures + 1
    return None
  }
  let size = @core.Size::new(width=width.to_double(), height=height.to_double())
  cache.sizes[key] = size
  cache.source_of[key] = source
  metal_image_touch(cache, key)
  cache.uploads = cache.uploads + 1
  Some(size)
}

///|
/// The synchronous path: read, decode and draw in the same frame. The offscreen
/// proof pass uses it because it owns no host loader.
fn ensure_metal_image_sync(
  cache : MetalImageCache,
  context~ : UInt64,
  image_source : @render.HostImageSource,
  source~ : String,
) -> (Int32, @core.Size)? {
  match metal_image_installed(cache, source) {
    Some(ready) => Some(ready)
    None =>
      match image_source.read(source) {
        None => {
          cache.failures = cache.failures + 1
          None
        }
        Some(bytes) =>
          match install_metal_image_bytes(cache, context~, source~, bytes~) {
            None => None
            Some(_) => metal_image_installed(cache, source)
          }
      }
  }
}

///|
/// The asynchronous path, mirroring the state machine the Skia and Sun routes
/// pin: an unseen source becomes a loading request and draws nothing this
/// frame; a ready record draws once its texture exists; a failed record
/// re-requests only when the bytes became readable again, which is what makes a
/// file that appears later draw without restarting the app.
fn ensure_metal_image_async(
  cache : MetalImageCache,
  context~ : UInt64,
  image_source : @render.HostImageSource,
  source~ : String,
) -> (Int32, @core.Size)? {
  match cache.lifecycle.lookup(source) {
    None => {
      cache.requests = cache.requests + 1
      ignore(cache.lifecycle.mark_loading(source))
      None
    }
    Some(record) =>
      match record.status {
        @render.ImageReady =>
          match metal_image_installed(cache, source) {
            Some(ready) => Some(ready)
            None =>
              match image_source.read(source) {
                None => None
                Some(bytes) =>
                  match
                    install_metal_image_bytes(cache, context~, source~, bytes~) {
                    None => None
                    Some(_) => metal_image_installed(cache, source)
                  }
              }
          }
        ImageFailed =>
          match image_source.read(source) {
            None => None
            Some(_) => {
              cache.requests = cache.requests + 1
              ignore(cache.lifecycle.mark_loading(source))
              None
            }
          }
        _ => None
      }
  }
}

///|
/// The renderer-owned decoder the host async loader calls. It reports the
/// decoded extent and pixels so the payload comes back through
/// `apply_metal_image_completion` instead of a second read.
fn metal_image_decoder() -> @render.RendererImageDecoder {
  @render.RendererImageDecoder::new(decode=(source, bytes) => {
    match bytes {
      None =>
        @render.ImageResourceLoadCompletion::failed(
          source,
          diagnostic="metal image source is unreadable",
          background_io=true,
        )
      Some(data) => decode_metal_image_payload(source, data)
    }
  })
}

///|
fn decode_metal_image_payload(
  source : String,
  data : Bytes,
) -> @render.ImageResourceLoadCompletion {
  let size_out = Bytes::make(8, 0)
  let probe = metal_image_decode(data, data.length(), size_out, 0, size_out)
  let width = metal_read_i32(size_out, 0)
  let height = metal_read_i32(size_out, 4)
  let needed = width * height * 4
  if probe != 2 || width <= 0 || height <= 0 || needed <= 0 {
    return @render.ImageResourceLoadCompletion::failed(
      source,
      diagnostic="metal image bytes did not decode",
      background_io=true,
    )
  }
  let pixels = Bytes::make(needed, 0)
  if metal_image_decode(data, data.length(), pixels, needed, size_out) != 1 {
    return @render.ImageResourceLoadCompletion::failed(
      source,
      diagnostic="metal image decode rejected the payload",
      background_io=true,
    )
  }
  @render.ImageResourceLoadCompletion::ready_decoded_rgba(
    source,
    width~,
    height~,
    row_bytes=width * 4,
    pixels,
    background_io=true,
  )
}

///|
/// Install a completion's decoded payload as a texture, then record its state.
/// The result says whether the lifecycle changed, which is what
/// `RendererSession` reports to the host.
fn apply_metal_image_completion(
  cache : MetalImageCache,
  context~ : UInt64,
  completion : @render.ImageResourceLoadCompletion,
) -> Bool {
  if !completion.has_decoded_rgba_payload() {
    return cache.lifecycle.apply_load_completion(completion)
  }
  let source = completion.source
  match
    write_metal_image_rgba(
      cache,
      context~,
      source~,
      width=completion.width,
      height=completion.height,
      row_bytes=completion.decoded_row_bytes,
      pixels=completion.decoded_pixels,
    ) {
    None =>
      cache.lifecycle.apply_load_completion(
        @render.ImageResourceLoadCompletion::failed(
          source,
          diagnostic="metal could not upload the decoded image",
          background_io=completion.background_io,
        ),
      )
    Some(_) => cache.lifecycle.apply_load_completion(completion)
  }
}

///|
fn metal_read_i32(bytes : Bytes, offset : Int32) -> Int32 {
  bytes[offset].to_int() |
  (bytes[offset + 1].to_int() << 8) |
  (bytes[offset + 2].to_int() << 16) |
  (bytes[offset + 3].to_int() << 24)
}

///|
/// The uv window one `ImageRun` samples: a `src_rect` names source pixels and
/// wins over `fit` (the shared contract says so), otherwise `fit` resolves the
/// frame and a `Cover` crops symmetrically along the axis it overflowed.
fn metal_image_uv(
  run : @core.ImageRun,
  size : @core.Size,
) -> (Double, Double, Double, Double)? {
  if size.width <= 0.0 || size.height <= 0.0 {
    return None
  }
  match run.src_rect {
    Some(src_rect) =>
      match @render_common.image_src_window(src_rect, size) {
        None => None
        Some(window) =>
          if window.size.width <= 0.0 || window.size.height <= 0.0 {
            None
          } else {
            Some(
              (
                window.origin.x / size.width,
                window.origin.y / size.height,
                (window.origin.x + window.size.width) / size.width,
                (window.origin.y + window.size.height) / size.height,
              ),
            )
          }
      }
    None => {
      let placement = @render_common.image_placement(run.frame, size, run.fit)
      match placement.crop_axis {
        @render_common.Horizontal => {
          let inset = (1.0 - placement.visible) / 2.0
          Some((inset, 0.0, 1.0 - inset, 1.0))
        }
        Vertical => {
          let inset = (1.0 - placement.visible) / 2.0
          Some((0.0, inset, 1.0, 1.0 - inset))
        }
        @render_common.ImageCropAxis::None => Some((0.0, 0.0, 1.0, 1.0))
      }
    }
  }
}

///|
/// The frame an image run actually paints into, after `fit` resolves it.
fn metal_image_frame(run : @core.ImageRun, size : @core.Size) -> @core.Rect {
  let src_rect_overrides = match run.src_rect {
    Some(_) => true
    None => false
  }
  if src_rect_overrides {
    run.frame
  } else {
    @render_common.image_placement(run.frame, size, run.fit).frame
  }
}
