///|
pub fn Data::from_bytes(bytes : Bytes) -> Data? {
  ignore(bytes)
  None
}

///|
pub fn Data::is_available(self : Data) -> Bool {
  ignore(self)
  false
}

///|
pub fn Data::size(self : Data) -> Int {
  ignore(self)
  0
}

///|
pub fn Data::is_empty(self : Data) -> Bool {
  self.size() == 0
}

///|
pub fn Data::to_bytes(self : Data) -> Bytes {
  ignore(self)
  b""
}

///|
pub fn Codec::from_data(data : Data) -> Codec? {
  ignore(data)
  None
}

///|
pub fn Codec::from_bytes(bytes : Bytes) -> Codec? {
  ignore(bytes)
  None
}

///|
pub fn Codec::is_available(self : Codec) -> Bool {
  ignore(self)
  false
}

///|
pub fn Codec::width(self : Codec) -> Int {
  ignore(self)
  0
}

///|
pub fn Codec::height(self : Codec) -> Int {
  ignore(self)
  0
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
  ignore(self)
  None
}

///|
pub fn Codec::decode_n32_premul(self : Codec) -> Bitmap? {
  ignore(self)
  None
}

///|
pub fn Image::is_available(self : Image) -> Bool {
  ignore(self)
  false
}

///|
pub fn Image::width(self : Image) -> Int {
  ignore(self)
  0
}

///|
pub fn Image::height(self : Image) -> Int {
  ignore(self)
  0
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
  ignore(bitmap)
  None
}

///|
pub fn Image::from_encoded_data(data : Data) -> Image? {
  ignore(data)
  None
}

///|
pub fn Image::from_encoded_bytes(bytes : Bytes) -> Image? {
  ignore(bytes)
  None
}

///|
pub fn Image::encode_to_data(
  self : Image,
  format? : @skia.EncodedImageFormat = PNG,
  quality? : Int = 100,
) -> Data? {
  ignore(self)
  ignore(format)
  ignore(quality)
  None
}

///|
pub fn Bitmap::alloc_n32_premul(size : @skia.ISize) -> Bitmap? {
  ignore(size)
  None
}

///|
pub fn Bitmap::from_pixels(
  pixels : Bytes,
  width : Int,
  height : Int,
  row_bytes : Int,
) -> Bitmap? {
  ignore(pixels)
  ignore(width)
  ignore(height)
  ignore(row_bytes)
  None
}

///|
pub fn Bitmap::is_available(self : Bitmap) -> Bool {
  ignore(self)
  false
}

///|
pub fn Bitmap::width(self : Bitmap) -> Int {
  ignore(self)
  0
}

///|
pub fn Bitmap::height(self : Bitmap) -> Int {
  ignore(self)
  0
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
  ignore(self)
  0
}

///|
pub fn Bitmap::byte_size(self : Bitmap) -> Int {
  ignore(self)
  0
}

///|
pub fn Bitmap::erase_color(self : Bitmap, color : @skia.Color) -> Unit {
  ignore(self)
  ignore(color)
}

///|
pub fn Bitmap::to_bytes(self : Bitmap) -> Bytes {
  ignore(self)
  b""
}

///|
pub fn Bitmap::to_pixmap(self : Bitmap) -> @skia.Pixmap? {
  ignore(self)
  None
}

///|
pub fn GpuContext::is_available(self : GpuContext) -> Bool {
  ignore(self)
  false
}

///|
pub fn GpuContext::resource_key(self : GpuContext) -> @skia.RendererResourceKey {
  self.descriptor.resource_key()
}

///|
pub fn GpuContext::support_status(
  self : GpuContext,
) -> SkiaGpuContextSupportStatus {
  ignore(self)
  SkiaGpuContextSkiaUnavailable
}

///|
pub fn GpuContext::metal(
  descriptor : @skia.GpuContextDescriptor,
) -> GpuContext? {
  ignore(descriptor)
  None
}

///|
pub fn Surface::raster_n32_premul(size : @skia.ISize) -> Surface? {
  ignore(size)
  None
}

///|
pub fn Surface::gpu_n32_premul(
  context : GpuContext,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  ignore(context)
  ignore(descriptor)
  None
}

///|
pub fn Surface::metal_window_surface(
  context : GpuContext,
  layer_ptr : UInt64,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  ignore(context)
  ignore(layer_ptr)
  ignore(descriptor)
  None
}

///|
pub fn Surface::metal_present_and_acquire_next(
  surface : Surface,
  context : GpuContext,
  layer_ptr : UInt64,
) -> Surface? {
  ignore(surface)
  ignore(context)
  ignore(layer_ptr)
  None
}

///|
pub fn Surface::metal_gpu_context_opt_in_enabled() -> Bool {
  false
}

///|
pub fn Surface::metal_gpu_context_headers_available() -> Bool {
  false
}

///|
pub fn Surface::metal_gpu_context_runtime_available() -> Bool {
  false
}

///|
pub fn GpuContext::direct3d12(
  descriptor : @skia.GpuContextDescriptor,
) -> GpuContext? {
  ignore(descriptor)
  None
}

///|
pub fn Surface::direct3d_window_surface(
  context : GpuContext,
  hwnd_ptr : UInt64,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  ignore(context)
  ignore(hwnd_ptr)
  ignore(descriptor)
  None
}

///|
pub fn Surface::direct3d_present_and_acquire_next(
  surface : Surface,
  context : GpuContext,
  hwnd_ptr : UInt64,
) -> Surface? {
  ignore(surface)
  ignore(context)
  ignore(hwnd_ptr)
  None
}

///|
pub fn Surface::direct3d_gpu_context_opt_in_enabled() -> Bool {
  false
}

///|
pub fn Surface::direct3d_gpu_context_headers_available() -> Bool {
  false
}

///|
pub fn Surface::direct3d_gpu_context_runtime_available() -> Bool {
  false
}

///|
pub fn GpuContext::vulkan(
  descriptor : @skia.GpuContextDescriptor,
) -> GpuContext? {
  ignore(descriptor)
  None
}

///|
pub fn Surface::vulkan_window_surface(
  context : GpuContext,
  anw_ptr : UInt64,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  ignore(context)
  ignore(anw_ptr)
  ignore(descriptor)
  None
}

///|
pub fn Surface::vulkan_present_and_acquire_next(
  surface : Surface,
  context : GpuContext,
  anw_ptr : UInt64,
) -> Surface? {
  ignore(surface)
  ignore(context)
  ignore(anw_ptr)
  None
}

///|
pub fn Surface::vulkan_wayland_surface(
  context : GpuContext,
  display_ptr : UInt64,
  surface_ptr : UInt64,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  ignore(context)
  ignore(display_ptr)
  ignore(surface_ptr)
  ignore(descriptor)
  None
}

///|
pub fn Surface::vulkan_gpu_context_opt_in_enabled() -> Bool {
  false
}

///|
pub fn Surface::vulkan_gpu_context_headers_available() -> Bool {
  false
}

///|
pub fn Surface::vulkan_gpu_context_runtime_available() -> Bool {
  false
}

///|
pub fn GpuContext::egl(descriptor : @skia.GpuContextDescriptor) -> GpuContext? {
  ignore(descriptor)
  None
}

///|
pub fn Surface::egl_window_surface(
  context : GpuContext,
  native_window_ptr : UInt64,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  ignore(context)
  ignore(native_window_ptr)
  ignore(descriptor)
  None
}

///|
pub fn Surface::egl_present_and_acquire_next(
  surface : Surface,
  context : GpuContext,
  native_window_ptr : UInt64,
) -> Surface? {
  ignore(surface)
  ignore(context)
  ignore(native_window_ptr)
  None
}

///|
pub fn Surface::egl_gpu_context_opt_in_enabled() -> Bool {
  false
}

///|
pub fn Surface::egl_gpu_context_headers_available() -> Bool {
  false
}

///|
pub fn Surface::egl_gpu_context_runtime_available() -> Bool {
  false
}

///|
pub fn Surface::gpu_context_support_status(
  context : @skia.GpuContextDescriptor,
) -> SkiaGpuContextSupportStatus {
  ignore(context)
  SkiaGpuContextSkiaUnavailable
}

///|
/// Report why a value-layer render target cannot be allocated by this backend.
pub fn Surface::target_support_status(
  target : @skia.SurfaceTargetDescriptor,
) -> SurfaceTargetSupportStatus {
  if target.surface.is_empty() {
    SurfaceTargetEmpty
  } else {
    SurfaceTargetSkiaUnavailable
  }
}

///|
pub fn Surface::target_support_status_with_gpu_context(
  target : @skia.SurfaceTargetDescriptor,
  context : GpuContext,
) -> SurfaceTargetSupportStatus {
  ignore(context)
  Surface::target_support_status(target)
}

///|
pub fn Surface::for_target_with_gpu_context(
  target : @skia.SurfaceTargetDescriptor,
  context : GpuContext,
) -> Surface? {
  ignore(target)
  ignore(context)
  None
}

///|
pub fn Surface::for_target(target : @skia.SurfaceTargetDescriptor) -> Surface? {
  ignore(target)
  None
}

///|
pub fn Surface::width(self : Surface) -> Int {
  ignore(self)
  0
}

///|
pub fn Surface::height(self : Surface) -> Int {
  ignore(self)
  0
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
  ignore(self)
  false
}

///|
/// Surface copying is unavailable when native Skia is not linked.
pub fn Surface::copy_from(self : Surface, source : Surface) -> Bool {
  ignore(self)
  ignore(source)
  false
}

///|
pub fn Surface::render_frame(
  self : Surface,
  frame : @skia.RenderFrameDescriptor,
  font? : Font? = None,
  frame_index? : Int = 0,
) -> SurfaceFrameReplayStats {
  ignore(self)
  ignore(font)
  {
    replay: canvas_replay_skipped_stats(frame.command_list),
    validation_status: frame.validation_status(),
    surface_matches: false,
    finalization: frame.finalization_descriptor(frame_index~),
    finalized: false,
  }
}

///|
pub fn Surface::render_frame_with_resources(
  self : Surface,
  frame : @skia.RenderFrameDescriptor,
  resources : NativeReplayResources,
  font? : Font? = None,
  frame_index? : Int = 0,
) -> SurfaceFrameReplayStats {
  ignore(resources)
  self.render_frame(frame, font~, frame_index~)
}

///|
/// Snapshot current surface contents into an immutable image.
pub fn Surface::image_snapshot(self : Surface) -> Image? {
  ignore(self)
  None
}

///|
/// Snapshot a bounded rectangle of current surface contents into an image.
pub fn Surface::image_snapshot_with_bounds(
  self : Surface,
  bounds : @skia.IRect,
) -> Image? {
  ignore(self)
  ignore(bounds)
  None
}

///|
/// Read surface pixels into an owned MoonBit `Pixmap`.
pub fn Surface::read_pixels(
  self : Surface,
  bounds? : @skia.IRect = self.image_info().bounds(),
) -> @skia.Pixmap? {
  ignore(self)
  ignore(bounds)
  None
}

///|
/// Borrow the surface canvas.
pub fn Surface::canvas(self : Surface) -> Canvas? {
  ignore(self)
  None
}
