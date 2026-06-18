///|
extern "C" fn native_bitmap_alloc_n32_premul(
  width : Int,
  height : Int,
) -> BitmapHandle = "moonbit_skia_bitmap_alloc_n32_premul"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_is_null(bitmap : BitmapHandle) -> Bool = "moonbit_skia_bitmap_is_null"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_width(bitmap : BitmapHandle) -> Int = "moonbit_skia_bitmap_width"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_height(bitmap : BitmapHandle) -> Int = "moonbit_skia_bitmap_height"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_row_bytes(bitmap : BitmapHandle) -> Int = "moonbit_skia_bitmap_row_bytes"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_byte_size(bitmap : BitmapHandle) -> Int = "moonbit_skia_bitmap_byte_size"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_to_bytes(bitmap : BitmapHandle) -> Bytes = "moonbit_skia_bitmap_to_bytes"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_erase_color(
  bitmap : BitmapHandle,
  color_argb : UInt,
) -> Unit = "moonbit_skia_bitmap_erase_color"

///|
/// Create bitmap from external pixel buffer (RGBA8888 premultiplied)
#borrow(pixels)
extern "C" fn native_bitmap_from_pixels(
  pixels : Bytes,
  width : Int,
  height : Int,
  row_bytes : Int,
) -> BitmapHandle = "moonbit_skia_bitmap_from_pixels"

///|
#borrow(bytes)
extern "C" fn native_data_from_bytes(bytes : Bytes) -> DataHandle = "moonbit_skia_data_from_bytes"

///|
#borrow(data)
extern "C" fn native_data_is_null(data : DataHandle) -> Bool = "moonbit_skia_data_is_null"

///|
#borrow(data)
extern "C" fn native_data_size(data : DataHandle) -> Int = "moonbit_skia_data_size"

///|
#borrow(data)
extern "C" fn native_data_to_bytes(data : DataHandle) -> Bytes = "moonbit_skia_data_to_bytes"

///|
#borrow(data)
extern "C" fn native_codec_from_data(data : DataHandle) -> CodecHandle = "moonbit_skia_codec_from_data"

///|
#borrow(codec)
extern "C" fn native_codec_is_null(codec : CodecHandle) -> Bool = "moonbit_skia_codec_is_null"

///|
#borrow(codec)
extern "C" fn native_codec_width(codec : CodecHandle) -> Int = "moonbit_skia_codec_width"

///|
#borrow(codec)
extern "C" fn native_codec_height(codec : CodecHandle) -> Int = "moonbit_skia_codec_height"

///|
#borrow(codec)
extern "C" fn native_codec_encoded_format(codec : CodecHandle) -> Int = "moonbit_skia_codec_encoded_format"

///|
#borrow(codec)
extern "C" fn native_codec_decode_n32_premul(
  codec : CodecHandle,
) -> BitmapHandle = "moonbit_skia_codec_decode_n32_premul"

///|
#borrow(image)
extern "C" fn native_image_is_null(image : ImageHandle) -> Bool = "moonbit_skia_image_is_null"

///|
#borrow(image)
extern "C" fn native_image_width(image : ImageHandle) -> Int = "moonbit_skia_image_width"

///|
#borrow(image)
extern "C" fn native_image_height(image : ImageHandle) -> Int = "moonbit_skia_image_height"

///|
#borrow(bitmap)
extern "C" fn native_image_from_bitmap(bitmap : BitmapHandle) -> ImageHandle = "moonbit_skia_image_from_bitmap"

///|
#borrow(image)
extern "C" fn native_image_encode_to_data(
  image : ImageHandle,
  format : Int,
  quality : Int,
) -> DataHandle = "moonbit_skia_image_encode_to_data"

///|
#borrow(data)
extern "C" fn native_image_from_encoded_data(data : DataHandle) -> ImageHandle = "moonbit_skia_image_from_encoded_data"

///|
extern "C" fn native_surface_raster_n32_premul(
  width : Int,
  height : Int,
) -> SurfaceHandle = "moonbit_skia_surface_raster_n32_premul"

///|
extern "C" fn native_gpu_context_metal() -> GpuContextHandle = "moonbit_skia_gpu_context_metal"

///|
#borrow(context)
extern "C" fn native_gpu_context_is_null(context : GpuContextHandle) -> Bool = "moonbit_skia_gpu_context_is_null"

///|
#borrow(context)
extern "C" fn native_surface_gpu_n32_premul(
  context : GpuContextHandle,
  width : Int,
  height : Int,
  origin : Int,
  sample_count : Int,
  stencil_bits : Int,
  budgeted : Bool,
) -> SurfaceHandle = "moonbit_skia_surface_gpu_n32_premul"

///|
extern "C" fn native_surface_gpu_metal_opt_in_enabled() -> Bool = "moonbit_skia_surface_gpu_metal_opt_in_enabled"

///|
extern "C" fn native_surface_gpu_metal_headers_available() -> Bool = "moonbit_skia_surface_gpu_metal_headers_available"

///|
extern "C" fn native_surface_gpu_metal_runtime_available() -> Bool = "moonbit_skia_surface_gpu_metal_runtime_available"

///|
#borrow(surface)
extern "C" fn native_surface_is_null(surface : SurfaceHandle) -> Bool = "moonbit_skia_surface_is_null"

///|
#borrow(surface)
extern "C" fn native_surface_width(surface : SurfaceHandle) -> Int = "moonbit_skia_surface_width"

///|
#borrow(surface)
extern "C" fn native_surface_height(surface : SurfaceHandle) -> Int = "moonbit_skia_surface_height"

///|
#borrow(surface)
extern "C" fn native_surface_canvas(surface : SurfaceHandle) -> CanvasHandle = "moonbit_skia_surface_canvas"

///|
#borrow(surface)
extern "C" fn native_surface_flush_and_submit(surface : SurfaceHandle) -> Bool = "moonbit_skia_surface_flush_and_submit"

///|
#borrow(surface)
extern "C" fn native_surface_image_snapshot(
  surface : SurfaceHandle,
) -> ImageHandle = "moonbit_skia_surface_image_snapshot"

///|
#borrow(surface)
extern "C" fn native_surface_image_snapshot_with_bounds(
  surface : SurfaceHandle,
  left : Int,
  top : Int,
  right : Int,
  bottom : Int,
) -> ImageHandle = "moonbit_skia_surface_image_snapshot_with_bounds"

///|
#borrow(surface)
extern "C" fn native_surface_read_pixels(
  surface : SurfaceHandle,
  left : Int,
  top : Int,
  width : Int,
  height : Int,
) -> Bytes = "moonbit_skia_surface_read_pixels"

///|
fn Data::from_handle(handle : DataHandle) -> Data? {
  if native_data_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Data::from_bytes(bytes : Bytes) -> Data? {
  if bytes.is_empty() {
    None
  } else {
    Data::from_handle(native_data_from_bytes(bytes))
  }
}

///|
pub fn Data::is_available(self : Data) -> Bool {
  !native_data_is_null(self.handle)
}

///|
pub fn Data::size(self : Data) -> Int {
  native_data_size(self.handle)
}

///|
pub fn Data::is_empty(self : Data) -> Bool {
  self.size() == 0
}

///|
pub fn Data::to_bytes(self : Data) -> Bytes {
  native_data_to_bytes(self.handle)
}

///|
fn Codec::from_handle(handle : CodecHandle) -> Codec? {
  if native_codec_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Codec::from_data(data : Data) -> Codec? {
  Codec::from_handle(native_codec_from_data(data.handle))
}

///|
pub fn Codec::from_bytes(bytes : Bytes) -> Codec? {
  match Data::from_bytes(bytes) {
    None => None
    Some(data) => Codec::from_data(data)
  }
}

///|
pub fn Codec::is_available(self : Codec) -> Bool {
  !native_codec_is_null(self.handle)
}

///|
pub fn Codec::width(self : Codec) -> Int {
  native_codec_width(self.handle)
}

///|
pub fn Codec::height(self : Codec) -> Int {
  native_codec_height(self.handle)
}

///|
pub fn Codec::dimensions(self : Codec) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Codec::image_info(self : Codec) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
pub fn Codec::encoded_format(self : Codec) -> @skia.EncodedImageFormat? {
  @skia.EncodedImageFormat::from_skia_ordinal(
    native_codec_encoded_format(self.handle),
  )
}

///|
pub fn Codec::decode_n32_premul(self : Codec) -> Bitmap? {
  Bitmap::from_handle(native_codec_decode_n32_premul(self.handle))
}

///|
fn Image::from_handle(handle : ImageHandle) -> Image? {
  if native_image_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Image::is_available(self : Image) -> Bool {
  !native_image_is_null(self.handle)
}

///|
pub fn Image::width(self : Image) -> Int {
  native_image_width(self.handle)
}

///|
pub fn Image::height(self : Image) -> Int {
  native_image_height(self.handle)
}

///|
pub fn Image::dimensions(self : Image) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Image::image_info(self : Image) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
pub fn Image::from_bitmap(bitmap : Bitmap) -> Image? {
  Image::from_handle(native_image_from_bitmap(bitmap.handle))
}

///|
pub fn Image::from_encoded_data(data : Data) -> Image? {
  Image::from_handle(native_image_from_encoded_data(data.handle))
}

///|
pub fn Image::from_encoded_bytes(bytes : Bytes) -> Image? {
  match Data::from_bytes(bytes) {
    None => None
    Some(data) => Image::from_encoded_data(data)
  }
}

///|
fn native_image_encode_format_is_supported(
  format : @skia.EncodedImageFormat,
) -> Bool {
  format is (PNG | JPEG | WEBP)
}

///|
fn native_image_encode_quality(quality : Int) -> Int {
  quality.clamp(min=0, max=100)
}

///|
pub fn Image::encode_to_data(
  self : Image,
  format? : @skia.EncodedImageFormat = PNG,
  quality? : Int = 100,
) -> Data? {
  if !native_image_encode_format_is_supported(format) {
    None
  } else {
    Data::from_handle(
      native_image_encode_to_data(
        self.handle,
        format.to_skia_ordinal(),
        native_image_encode_quality(quality),
      ),
    )
  }
}

///|
fn Bitmap::from_handle(handle : BitmapHandle) -> Bitmap? {
  if native_bitmap_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Bitmap::alloc_n32_premul(size : @skia.ISize) -> Bitmap? {
  if size.is_empty() {
    None
  } else {
    Bitmap::from_handle(native_bitmap_alloc_n32_premul(size.width, size.height))
  }
}

///|
/// Create Bitmap from external pixel buffer (RGBA8888 premultiplied)
pub fn Bitmap::from_pixels(
  pixels : Bytes,
  width : Int,
  height : Int,
  row_bytes : Int,
) -> Bitmap? {
  if width <= 0 || height <= 0 {
    None
  } else {
    Bitmap::from_handle(
      native_bitmap_from_pixels(pixels, width, height, row_bytes),
    )
  }
}

///|
pub fn Bitmap::is_available(self : Bitmap) -> Bool {
  !native_bitmap_is_null(self.handle)
}

///|
pub fn Bitmap::width(self : Bitmap) -> Int {
  native_bitmap_width(self.handle)
}

///|
pub fn Bitmap::height(self : Bitmap) -> Int {
  native_bitmap_height(self.handle)
}

///|
pub fn Bitmap::dimensions(self : Bitmap) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Bitmap::image_info(self : Bitmap) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
pub fn Bitmap::row_bytes(self : Bitmap) -> Int {
  native_bitmap_row_bytes(self.handle)
}

///|
pub fn Bitmap::byte_size(self : Bitmap) -> Int {
  native_bitmap_byte_size(self.handle)
}

///|
pub fn Bitmap::erase_color(self : Bitmap, color : @skia.Color) -> Unit {
  native_bitmap_erase_color(self.handle, color.argb())
}

///|
pub fn Bitmap::to_bytes(self : Bitmap) -> Bytes {
  native_bitmap_to_bytes(self.handle)
}

///|
pub fn Bitmap::to_pixmap(self : Bitmap) -> @skia.Pixmap? {
  @skia.Pixmap::new(self.image_info(), self.row_bytes(), self.to_bytes())
}

///|
fn GpuContext::from_handle(
  handle : GpuContextHandle,
  descriptor : @skia.GpuContextDescriptor,
) -> GpuContext? {
  if native_gpu_context_is_null(handle) {
    None
  } else {
    Some({ handle, descriptor })
  }
}

///|
pub fn GpuContext::is_available(self : GpuContext) -> Bool {
  !native_gpu_context_is_null(self.handle)
}

///|
pub fn GpuContext::resource_key(self : GpuContext) -> @skia.RendererResourceKey {
  self.descriptor.resource_key()
}

///|
pub fn GpuContext::support_status(
  self : GpuContext,
) -> SkiaGpuContextSupportStatus {
  Surface::gpu_context_support_status(self.descriptor)
}

///|
pub fn GpuContext::metal(
  descriptor : @skia.GpuContextDescriptor,
) -> GpuContext? {
  if !Surface::gpu_context_support_status(descriptor).is_available() ||
    descriptor.backend != @skia.MetalGpuContext {
    None
  } else {
    GpuContext::from_handle(native_gpu_context_metal(), descriptor)
  }
}

///|
fn Surface::from_handle(
  handle : SurfaceHandle,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  if native_surface_is_null(handle) {
    None
  } else {
    Some({ handle, descriptor })
  }
}

///|
fn Surface::contains_pixel_bounds(self : Surface, bounds : @skia.IRect) -> Bool {
  self.image_info().bounds().contains_rect(bounds)
}

///|
/// Allocate a raster N32 premultiplied surface.
///
/// Returns `None` when the native Skia backend is not linked or the size is empty.
pub fn Surface::raster_n32_premul(size : @skia.ISize) -> Surface? {
  if size.is_empty() {
    None
  } else {
    Surface::from_handle(
      native_surface_raster_n32_premul(size.width, size.height),
      @skia.SurfaceDescriptor::raster_n32_premul(size),
    )
  }
}

///|
fn native_surface_origin_ordinal(origin : @skia.SurfaceOrigin) -> Int {
  match origin {
    @skia.TopLeft => 0
    @skia.BottomLeft => 1
  }
}

///|
/// Allocate an offscreen GPU-backed N32 premultiplied surface from an explicit GPU context.
pub fn Surface::gpu_n32_premul(
  context : GpuContext,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  if descriptor.is_empty() || !descriptor.is_gpu() || !context.is_available() {
    None
  } else {
    Surface::from_handle(
      native_surface_gpu_n32_premul(
        context.handle,
        descriptor.width(),
        descriptor.height(),
        native_surface_origin_ordinal(descriptor.origin),
        descriptor.sample_count,
        descriptor.stencil_bits,
        descriptor.budget.is_budgeted(),
      ),
      descriptor,
    )
  }
}

///|
/// Report whether the macOS Metal Skia GPU-context probe is enabled for this native build.
pub fn Surface::metal_gpu_context_opt_in_enabled() -> Bool {
  native_surface_gpu_metal_opt_in_enabled()
}

///|
/// Report whether this native build can see the Skia Ganesh Metal headers.
pub fn Surface::metal_gpu_context_headers_available() -> Bool {
  native_surface_gpu_metal_headers_available()
}

///|
/// Report whether the opt-in Metal GPU-context probe can create a Metal device and queue.
pub fn Surface::metal_gpu_context_runtime_available() -> Bool {
  native_surface_gpu_metal_runtime_available()
}

///|
/// Classify native support for a value-layer GPU context descriptor.
pub fn Surface::gpu_context_support_status(
  context : @skia.GpuContextDescriptor,
) -> SkiaGpuContextSupportStatus {
  if !skia_available() {
    SkiaGpuContextSkiaUnavailable
  } else if context.is_anonymous() {
    SkiaGpuContextAnonymous
  } else {
    match context.backend {
      @skia.MockGpuContext => SkiaGpuContextMockUnsupported
      @skia.MetalGpuContext =>
        if !Surface::metal_gpu_context_opt_in_enabled() {
          SkiaGpuContextMetalOptInDisabled
        } else if !Surface::metal_gpu_context_headers_available() {
          SkiaGpuContextMetalHeadersUnavailable
        } else if !Surface::metal_gpu_context_runtime_available() {
          SkiaGpuContextMetalRuntimeUnavailable
        } else {
          SkiaGpuContextAvailable
        }
      _ => SkiaGpuContextBackendUnsupported
    }
  }
}

///|
/// Report whether a value-layer render target can be allocated by this backend.
pub fn Surface::target_support_status(
  target : @skia.SurfaceTargetDescriptor,
) -> SurfaceTargetSupportStatus {
  if target.surface.is_empty() {
    SurfaceTargetEmpty
  } else if !skia_available() {
    SurfaceTargetSkiaUnavailable
  } else if target.surface.is_raster() {
    SurfaceTargetSupported
  } else if target.surface.is_window() {
    SurfaceTargetWindowUnsupported
  } else {
    SurfaceTargetGpuUnsupported
  }
}

///|
/// Report whether a value-layer render target can be allocated with a concrete GPU context.
pub fn Surface::target_support_status_with_gpu_context(
  target : @skia.SurfaceTargetDescriptor,
  context : GpuContext,
) -> SurfaceTargetSupportStatus {
  if target.surface.is_empty() {
    SurfaceTargetEmpty
  } else if !skia_available() {
    SurfaceTargetSkiaUnavailable
  } else if target.surface.is_raster() {
    SurfaceTargetSupported
  } else if target.surface.is_window() {
    SurfaceTargetWindowUnsupported
  } else if !context.is_available() {
    SurfaceTargetGpuContextUnsupported
  } else {
    match target.gpu_context_key {
      None => SurfaceTargetMissingGpuContext
      Some(key) =>
        if key != context.resource_key() {
          SurfaceTargetGpuContextMismatch
        } else if !context.support_status().is_available() {
          SurfaceTargetGpuContextUnsupported
        } else {
          SurfaceTargetSupported
        }
    }
  }
}

///|
/// Allocate a native surface for a value-layer render target and explicit GPU context.
pub fn Surface::for_target_with_gpu_context(
  target : @skia.SurfaceTargetDescriptor,
  context : GpuContext,
) -> Surface? {
  if !Surface::target_support_status_with_gpu_context(target, context).is_supported() {
    None
  } else if target.surface.is_gpu() {
    Surface::gpu_n32_premul(context, target.surface)
  } else {
    Surface::raster_n32_premul(target.dimensions())
  }
}

///|
/// Allocate a native surface for a value-layer render target.
///
/// Raster targets are supported by the current CPU backend. Window and GPU
/// targets return `None` until concrete native present/GPU backends are linked.
pub fn Surface::for_target(target : @skia.SurfaceTargetDescriptor) -> Surface? {
  if Surface::target_support_status(target).is_supported() {
    Surface::raster_n32_premul(target.dimensions())
  } else {
    None
  }
}

///|
pub fn Surface::width(self : Surface) -> Int {
  native_surface_width(self.handle)
}

///|
pub fn Surface::height(self : Surface) -> Int {
  native_surface_height(self.handle)
}

///|
pub fn Surface::dimensions(self : Surface) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Surface::image_info(self : Surface) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
pub fn Surface::descriptor(self : Surface) -> @skia.SurfaceDescriptor {
  self.descriptor
}

///|
/// Finalize pending surface work; current raster surfaces use this as a no-op boundary.
pub fn Surface::flush_and_submit(self : Surface) -> Bool {
  native_surface_flush_and_submit(self.handle)
}

///|
fn Surface::render_frame_internal(
  self : Surface,
  frame : @skia.RenderFrameDescriptor,
  font : Font?,
  resources : NativeReplayResources?,
  frame_index : Int,
) -> SurfaceFrameReplayStats {
  let validation_status = frame.validation_status()
  let surface_matches = self.descriptor() == frame.target.surface
  let replay = if validation_status.is_ready() && surface_matches {
    match self.canvas() {
      None => canvas_replay_skipped_stats(frame.command_list)
      Some(canvas) => canvas.replay_frame_internal(frame, font, resources)
    }
  } else {
    canvas_replay_skipped_stats(frame.command_list)
  }
  let finalization = frame.finalization_descriptor(frame_index~)
  let finalized = validation_status.is_ready() &&
    surface_matches &&
    replay.is_complete() &&
    finalization.is_ready() &&
    self.flush_and_submit()
  { replay, validation_status, surface_matches, finalization, finalized }
}

///|
/// Replay a ready frame into this surface and flush/submit its finalization boundary.
pub fn Surface::render_frame(
  self : Surface,
  frame : @skia.RenderFrameDescriptor,
  font? : Font? = None,
  frame_index? : Int = 0,
) -> SurfaceFrameReplayStats {
  self.render_frame_internal(frame, font, None, frame_index)
}

///|
/// Replay a ready frame into this surface with native resource caches, then flush/submit.
pub fn Surface::render_frame_with_resources(
  self : Surface,
  frame : @skia.RenderFrameDescriptor,
  resources : NativeReplayResources,
  font? : Font? = None,
  frame_index? : Int = 0,
) -> SurfaceFrameReplayStats {
  self.render_frame_internal(frame, font, Some(resources), frame_index)
}

///|
/// Snapshot current surface contents into an immutable image.
pub fn Surface::image_snapshot(self : Surface) -> Image? {
  Image::from_handle(native_surface_image_snapshot(self.handle))
}

///|
/// Snapshot a bounded rectangle of current surface contents into an image.
pub fn Surface::image_snapshot_with_bounds(
  self : Surface,
  bounds : @skia.IRect,
) -> Image? {
  if !self.contains_pixel_bounds(bounds) {
    None
  } else {
    Image::from_handle(
      native_surface_image_snapshot_with_bounds(
        self.handle,
        bounds.left,
        bounds.top,
        bounds.right,
        bounds.bottom,
      ),
    )
  }
}

///|
/// Read surface pixels into an owned MoonBit `Pixmap`.
pub fn Surface::read_pixels(
  self : Surface,
  bounds? : @skia.IRect = self.image_info().bounds(),
) -> @skia.Pixmap? {
  if !self.contains_pixel_bounds(bounds) {
    None
  } else {
    let info = @skia.ImageInfo::n32_premul(bounds.size())
    let row_bytes = info.min_row_bytes()
    let pixels = native_surface_read_pixels(
      self.handle,
      bounds.left,
      bounds.top,
      bounds.width(),
      bounds.height(),
    )
    @skia.Pixmap::new(info, row_bytes, pixels)
  }
}

///|
/// Borrow the surface canvas.
pub fn Surface::canvas(self : Surface) -> Canvas? {
  let handle = native_surface_canvas(self.handle)
  if native_canvas_is_null(handle) {
    None
  } else {
    Some({ handle, owner: Some(self) })
  }
}
