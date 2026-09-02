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
/// Wrap a platform window-backed Metal drawable as a Skia GPU surface.
///
/// `layer_ptr` is a raw `CAMetalLayer*` handle obtained from the host view.
/// `next_drawable_handle` receives the next `CAMetalDrawable*` (its
/// `MTLTexture` is what Skia will render into). The host presenter owns the
/// layer and drawable lifecycle; Skia only borrows the texture for the duration
/// of one frame.
#borrow(context)
extern "C" fn native_surface_metal_window(
  context : GpuContextHandle,
  layer_ptr : UInt64,
  width : Int,
  height : Int,
  origin : Int,
  sample_count : Int,
  stencil_bits : Int,
) -> SurfaceHandle = "moonbit_skia_surface_metal_window"

///|
/// Present the `CAMetalDrawable` whose `MTLTexture` backs the given
/// `SurfaceHandle`. The host renderer has already called
/// `surface.flush_and_submit()`; this call only asks the drawable to present
/// and returns the *next* drawable's `MTLTexture` wrapped as a fresh
/// `SurfaceHandle` so the renderer can swap surfaces for the next frame.
///
/// `layer_ptr` is the same `CAMetalLayer*` passed to
/// `native_surface_metal_window`. When the layer cannot produce a next
/// drawable (e.g. layer was detached), the returned handle is null and the
/// caller should treat it as a present failure.
#borrow(surface)
extern "C" fn native_surface_metal_present_and_acquire_next(
  surface : SurfaceHandle,
  layer_ptr : UInt64,
  width : Int,
  height : Int,
  origin : Int,
  sample_count : Int,
  stencil_bits : Int,
) -> SurfaceHandle = "moonbit_skia_surface_metal_present_and_acquire_next"

///|
extern "C" fn native_surface_gpu_metal_opt_in_enabled() -> Bool = "moonbit_skia_surface_gpu_metal_opt_in_enabled"

///|
extern "C" fn native_surface_gpu_metal_headers_available() -> Bool = "moonbit_skia_surface_gpu_metal_headers_available"

///|
extern "C" fn native_surface_gpu_metal_runtime_available() -> Bool = "moonbit_skia_surface_gpu_metal_runtime_available"

///|
extern "C" fn native_gpu_context_direct3d() -> GpuContextHandle = "moonbit_skia_gpu_context_direct3d"

///|
/// Wrap a platform window-backed Direct3D 12 swap chain back buffer as a Skia
/// GPU surface.
///
/// `hwnd_ptr` is a raw `HWND` handle (typed as `UInt64` for FFI portability)
/// obtained from the host window. The host presenter owns the HWND lifecycle;
/// Skia borrows the swap chain's back buffer texture for rendering. The
/// returned `Surface` must be flushed and then presented via
/// `Surface::direct3d_present_and_acquire_next` to advance to the next back
/// buffer.
#borrow(context)
extern "C" fn native_surface_direct3d_window(
  context : GpuContextHandle,
  hwnd_ptr : UInt64,
  width : Int,
  height : Int,
  origin : Int,
  sample_count : Int,
  stencil_bits : Int,
) -> SurfaceHandle = "moonbit_skia_surface_direct3d_window"

///|
/// Present the swap chain backing a `Surface` created via
/// `native_surface_direct3d_window`, and return the next back buffer wrapped as
/// a fresh `Surface` for the following frame.
///
/// `hwnd_ptr` is passed for interface symmetry with the Metal layer_ptr
/// parameter but is not used by D3D present (the swap chain already knows its
/// HWND). Returns a null handle when the swap chain cannot produce a next back
/// buffer (e.g. device lost, or the native Skia build lacks D3D support).
#borrow(surface)
extern "C" fn native_surface_direct3d_present_and_acquire_next(
  surface : SurfaceHandle,
  hwnd_ptr : UInt64,
  width : Int,
  height : Int,
  origin : Int,
  sample_count : Int,
  stencil_bits : Int,
) -> SurfaceHandle = "moonbit_skia_surface_direct3d_present_and_acquire_next"

///|
extern "C" fn native_surface_gpu_d3d_opt_in_enabled() -> Bool = "moonbit_skia_surface_gpu_d3d_opt_in_enabled"

///|
extern "C" fn native_surface_gpu_d3d_headers_available() -> Bool = "moonbit_skia_surface_gpu_d3d_headers_available"

///|
extern "C" fn native_surface_gpu_d3d_runtime_available() -> Bool = "moonbit_skia_surface_gpu_d3d_runtime_available"

///|
extern "C" fn native_gpu_context_vulkan() -> GpuContextHandle = "moonbit_skia_gpu_context_vulkan"

///|
/// Wrap a platform window-backed Vulkan swap chain image as a Skia GPU
/// surface.
///
/// `anw_ptr` is a raw `ANativeWindow*` handle (typed as `UInt64` for FFI
/// portability) obtained from the Android host. The host presenter owns the
/// ANativeWindow lifecycle; Skia borrows the swap chain's back buffer image
/// for rendering. The returned `Surface` must be flushed and then presented
/// via `Surface::vulkan_present_and_acquire_next` to advance to the next
/// back buffer.
#borrow(context)
extern "C" fn native_surface_vulkan_window(
  context : GpuContextHandle,
  anw_ptr : UInt64,
  width : Int,
  height : Int,
  origin : Int,
  sample_count : Int,
  stencil_bits : Int,
) -> SurfaceHandle = "moonbit_skia_surface_vulkan_window"

///|
/// Present the swap chain backing a `Surface` created via
/// `native_surface_vulkan_window`, and return the next swap chain image
/// wrapped as a fresh `Surface` for the following frame.
///
/// `anw_ptr` is passed for interface symmetry with the Metal layer_ptr
/// and Direct3D hwnd_ptr parameters but is not used by Vulkan present (the
/// swap chain already knows its surface). Returns a null handle when the
/// swap chain cannot produce a next image (e.g. device lost, or the native
/// Skia build lacks Vulkan support).
#borrow(surface)
extern "C" fn native_surface_vulkan_present_and_acquire_next(
  surface : SurfaceHandle,
  anw_ptr : UInt64,
  width : Int,
  height : Int,
  origin : Int,
  sample_count : Int,
  stencil_bits : Int,
) -> SurfaceHandle = "moonbit_skia_surface_vulkan_present_and_acquire_next"

///|
extern "C" fn native_surface_gpu_vulkan_opt_in_enabled() -> Bool = "moonbit_skia_surface_gpu_vulkan_opt_in_enabled"

///|
extern "C" fn native_surface_gpu_vulkan_headers_available() -> Bool = "moonbit_skia_surface_gpu_vulkan_headers_available"

///|
extern "C" fn native_surface_gpu_vulkan_runtime_available() -> Bool = "moonbit_skia_surface_gpu_vulkan_runtime_available"

///|
/// Wrap a Linux Wayland `wl_surface` as a Vulkan-backed Skia GPU surface.
///
/// `display_ptr` is a raw `wl_display*` and `surface_ptr` is a raw
/// `wl_surface*` (both typed as `UInt64` for FFI portability) obtained
/// from the window package's `Window::display_handle()` /
/// `Window::window_handle()`. The host presenter owns the Wayland
/// surface lifecycle; Skia borrows the swap chain's back buffer image
/// for rendering. The returned `Surface` must be flushed and then
/// presented via `Surface::vulkan_present_and_acquire_next` to advance
/// to the next back buffer.
#borrow(context)
extern "C" fn native_surface_vulkan_wayland_window(
  context : GpuContextHandle,
  display_ptr : UInt64,
  surface_ptr : UInt64,
  width : Int,
  height : Int,
  origin : Int,
  sample_count : Int,
  stencil_bits : Int,
) -> SurfaceHandle = "moonbit_skia_surface_vulkan_wayland_window"

///|
extern "C" fn native_gpu_context_egl() -> GpuContextHandle = "moonbit_skia_gpu_context_egl"

///|
/// Wrap a platform window-backed EGL surface as a Skia GPU surface.
///
/// `native_window_ptr` is a raw platform native-window handle (typed as
/// `UInt64` for FFI portability) obtained from the host. The host presenter
/// owns the native-window lifecycle; Skia borrows the
/// EGLSurface's back buffer for rendering. The returned `Surface` must be
/// flushed and then presented via
/// `Surface::egl_present_and_acquire_next` to swap the back buffer to the
/// front buffer.
#borrow(context)
extern "C" fn native_surface_egl_window(
  context : GpuContextHandle,
  native_window_ptr : UInt64,
  width : Int,
  height : Int,
  origin : Int,
  sample_count : Int,
  stencil_bits : Int,
) -> SurfaceHandle = "moonbit_skia_surface_egl_window"

///|
/// Present the EGL surface backing a `Surface` created via
/// `native_surface_egl_window`, and return a fresh `Surface` wrapping the
/// next back buffer for the following frame.
///
/// `native_window_ptr` is passed for interface symmetry with the Metal
/// layer_ptr, Direct3D hwnd_ptr, and Vulkan anw_ptr parameters but is not
/// used by EGL present (the EGLSurface already knows its window). Returns a
/// null handle when `eglSwapBuffers` fails (e.g. context lost, or the
/// native Skia build lacks EGL support).
#borrow(surface)
extern "C" fn native_surface_egl_present_and_acquire_next(
  surface : SurfaceHandle,
  native_window_ptr : UInt64,
  width : Int,
  height : Int,
  origin : Int,
  sample_count : Int,
  stencil_bits : Int,
) -> SurfaceHandle = "moonbit_skia_surface_egl_present_and_acquire_next"

///|
extern "C" fn native_surface_gpu_egl_opt_in_enabled() -> Bool = "moonbit_skia_surface_gpu_egl_opt_in_enabled"

///|
extern "C" fn native_surface_gpu_egl_headers_available() -> Bool = "moonbit_skia_surface_gpu_egl_headers_available"

///|
extern "C" fn native_surface_gpu_egl_runtime_available() -> Bool = "moonbit_skia_surface_gpu_egl_runtime_available"

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
#borrow(destination, source)
extern "C" fn native_surface_copy_from(
  destination : SurfaceHandle,
  source : SurfaceHandle,
) -> Bool = "moonbit_skia_surface_copy_from"

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
/// Wrap a platform window-backed Metal drawable as a Skia GPU surface.
///
/// `layer_ptr` is a raw `CAMetalLayer*` handle (typed as `UInt64` for FFI
/// portability) obtained from the host view. The host presenter owns the layer
/// and drawable lifecycle; Skia borrows the drawable's `MTLTexture` for one
/// frame. The returned `Surface` must be flushed and then presented via
/// `Surface::metal_present_and_acquire_next` to advance to the next drawable.
///
/// Returns `None` when the GPU context is unavailable, the size is empty, or
/// the native Skia build cannot wrap a Metal drawable (e.g. the opt-in flags
/// `MOUI_SKIA_ENABLE_GPU_METAL` / `MOUI_SKIA_HAS_GANESH_METAL_HEADERS` are not
/// enabled at link time).
pub fn Surface::metal_window_surface(
  context : GpuContext,
  layer_ptr : UInt64,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  if descriptor.is_empty() || !descriptor.is_gpu() || !context.is_available() {
    None
  } else if layer_ptr == 0 {
    None
  } else {
    Surface::from_handle(
      native_surface_metal_window(
        context.handle,
        layer_ptr,
        descriptor.width(),
        descriptor.height(),
        native_surface_origin_ordinal(descriptor.origin),
        descriptor.sample_count,
        descriptor.stencil_bits,
      ),
      descriptor,
    )
  }
}

///|
/// Present the `CAMetalDrawable` backing a `Surface` created via
/// `Surface::metal_window_surface`, and return the next drawable wrapped as a
/// fresh `Surface` for the following frame.
///
/// The host renderer has already called `Surface::flush_and_submit()` before
/// this function; this call only asks the current drawable to present and
/// acquires the next one. Returns:
/// - `Some(next_surface)` when the drawable was presented and a next drawable
///   was successfully acquired and wrapped.
/// - `None` when the layer cannot produce a next drawable (e.g. layer was
///   detached, device lost, or the native Skia build lacks Metal support).
///   The caller should treat `None` as a present failure.
pub fn Surface::metal_present_and_acquire_next(
  surface : Surface,
  context : GpuContext,
  layer_ptr : UInt64,
) -> Surface? {
  if !context.is_available() || layer_ptr == 0 {
    return None
  }
  let descriptor = surface.descriptor
  Surface::from_handle(
    native_surface_metal_present_and_acquire_next(
      surface.handle,
      layer_ptr,
      descriptor.width(),
      descriptor.height(),
      native_surface_origin_ordinal(descriptor.origin),
      descriptor.sample_count,
      descriptor.stencil_bits,
    ),
    descriptor,
  )
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
/// Create a Direct3D 12 GPU context from the host platform's default D3D12
/// device. Returns `None` when the native Skia build lacks D3D support, when
/// the D3D12 device cannot be created, or when `descriptor.backend` is not
/// `Direct3D12GpuContext`.
pub fn GpuContext::direct3d12(
  descriptor : @skia.GpuContextDescriptor,
) -> GpuContext? {
  if !Surface::gpu_context_support_status(descriptor).is_available() ||
    descriptor.backend != @skia.Direct3D12GpuContext {
    None
  } else {
    GpuContext::from_handle(native_gpu_context_direct3d(), descriptor)
  }
}

///|
/// Wrap a platform window-backed Direct3D 12 swap chain back buffer as a Skia
/// GPU surface.
///
/// `hwnd_ptr` is a raw `HWND` handle (typed as `UInt64` for FFI portability)
/// obtained from the host window. The host presenter owns the HWND lifecycle;
/// Skia borrows the swap chain's back buffer texture for rendering. The
/// returned `Surface` must be flushed and then presented via
/// `Surface::direct3d_present_and_acquire_next` to advance to the next back
/// buffer.
///
/// Returns `None` when the GPU context is unavailable, the size is empty, or
/// the native Skia build cannot wrap a D3D12 swap chain (e.g. the opt-in flags
/// `MOUI_SKIA_ENABLE_GPU_D3D` / `MOUI_SKIA_HAS_GANESH_D3D_HEADERS` are not
/// enabled at link time).
pub fn Surface::direct3d_window_surface(
  context : GpuContext,
  hwnd_ptr : UInt64,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  if descriptor.is_empty() || !descriptor.is_gpu() || !context.is_available() {
    None
  } else if hwnd_ptr == 0 {
    None
  } else {
    Surface::from_handle(
      native_surface_direct3d_window(
        context.handle,
        hwnd_ptr,
        descriptor.width(),
        descriptor.height(),
        native_surface_origin_ordinal(descriptor.origin),
        descriptor.sample_count,
        descriptor.stencil_bits,
      ),
      descriptor,
    )
  }
}

///|
/// Present the swap chain backing a `Surface` created via
/// `Surface::direct3d_window_surface`, and return the next back buffer wrapped
/// as a fresh `Surface` for the following frame.
///
/// The host renderer has already called `Surface::flush_and_submit()` before
/// this function; this call only asks the swap chain to present and acquires
/// the next back buffer. `expected_size` is the host window's current physical
/// size: when it differs from the swap chain extent, the swap chain is resized
/// via `ResizeBuffers` after the present (an HWND can hold only one flip-model
/// swap chain, so resizing in place is the only live-resize path on Windows).
/// Returns:
/// - `Some(next_surface)` when the swap chain was presented and a next back
///   buffer was successfully acquired and wrapped.
/// - `None` when the swap chain cannot produce a next back buffer (e.g. device
///   lost, or the native Skia build lacks D3D support). The caller should
///   treat `None` as a present failure.
pub fn Surface::direct3d_present_and_acquire_next(
  surface : Surface,
  context : GpuContext,
  hwnd_ptr : UInt64,
  expected_size? : @skia.ISize? = None,
) -> Surface? {
  if !context.is_available() || hwnd_ptr == 0 {
    return None
  }
  let descriptor = surface.descriptor
  let size = match expected_size {
    Some(size) if !size.is_empty() => size
    _ => descriptor.dimensions()
  }
  let next_descriptor = if size == descriptor.dimensions() {
    descriptor
  } else {
    @skia.SurfaceDescriptor::gpu_n32_premul(
      size,
      origin=descriptor.origin,
      sample_count=descriptor.sample_count,
      stencil_bits=descriptor.stencil_bits,
      budget=descriptor.budget,
    )
  }
  Surface::from_handle(
    native_surface_direct3d_present_and_acquire_next(
      surface.handle,
      hwnd_ptr,
      size.width,
      size.height,
      native_surface_origin_ordinal(descriptor.origin),
      descriptor.sample_count,
      descriptor.stencil_bits,
    ),
    next_descriptor,
  )
}

///|
/// Report whether the Windows Direct3D Skia GPU-context probe is enabled for this native build.
pub fn Surface::direct3d_gpu_context_opt_in_enabled() -> Bool {
  native_surface_gpu_d3d_opt_in_enabled()
}

///|
/// Report whether this native build can see the Skia Ganesh Direct3D headers.
pub fn Surface::direct3d_gpu_context_headers_available() -> Bool {
  native_surface_gpu_d3d_headers_available()
}

///|
/// Report whether the opt-in Direct3D GPU-context probe can create a D3D12 device.
pub fn Surface::direct3d_gpu_context_runtime_available() -> Bool {
  native_surface_gpu_d3d_runtime_available()
}

///|
pub fn GpuContext::vulkan(
  descriptor : @skia.GpuContextDescriptor,
) -> GpuContext? {
  if !Surface::gpu_context_support_status(descriptor).is_available() ||
    descriptor.backend != @skia.VulkanGpuContext {
    None
  } else {
    GpuContext::from_handle(native_gpu_context_vulkan(), descriptor)
  }
}

///|
/// Wrap an Android `ANativeWindow`-backed Vulkan swap chain image as a Skia
/// GPU surface. The caller passes the raw `ANativeWindow*` as `anw_ptr`.
/// Skia borrows the swap chain's back buffer image; the host presenter owns
/// the ANativeWindow lifecycle. The returned `Surface` must be flushed and
/// then presented via `Surface::vulkan_present_and_acquire_next` to advance
/// to the next back buffer.
pub fn Surface::vulkan_window_surface(
  context : GpuContext,
  anw_ptr : UInt64,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  if descriptor.is_empty() || !descriptor.is_gpu() || !context.is_available() {
    None
  } else if anw_ptr == 0 {
    None
  } else {
    Surface::from_handle(
      native_surface_vulkan_window(
        context.handle,
        anw_ptr,
        descriptor.width(),
        descriptor.height(),
        native_surface_origin_ordinal(descriptor.origin),
        descriptor.sample_count,
        descriptor.stencil_bits,
      ),
      descriptor,
    )
  }
}

///|
/// Present the Vulkan swap chain backing a `Surface` created via
/// `Surface::vulkan_window_surface`, and return the next swap chain image
/// wrapped as a fresh `Surface` for the following frame.
pub fn Surface::vulkan_present_and_acquire_next(
  surface : Surface,
  context : GpuContext,
  anw_ptr : UInt64,
) -> Surface? {
  if !context.is_available() {
    None
  } else {
    let descriptor = surface.descriptor
    Surface::from_handle(
      native_surface_vulkan_present_and_acquire_next(
        surface.handle,
        anw_ptr,
        descriptor.width(),
        descriptor.height(),
        native_surface_origin_ordinal(descriptor.origin),
        descriptor.sample_count,
        descriptor.stencil_bits,
      ),
      descriptor,
    )
  }
}

///|
/// Wrap a Linux Wayland `wl_surface`-backed Vulkan swap chain image as a
/// Skia GPU surface. The caller passes the raw `wl_display*` as
/// `display_ptr` and `wl_surface*` as `surface_ptr`. Skia borrows the
/// swap chain's back buffer image; the host presenter owns the Wayland
/// surface lifecycle. The returned `Surface` must be flushed and then
/// presented via `Surface::vulkan_present_and_acquire_next` to advance
/// to the next back buffer.
pub fn Surface::vulkan_wayland_surface(
  context : GpuContext,
  display_ptr : UInt64,
  surface_ptr : UInt64,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  if descriptor.is_empty() || !descriptor.is_gpu() || !context.is_available() {
    None
  } else if display_ptr == 0 || surface_ptr == 0 {
    None
  } else {
    Surface::from_handle(
      native_surface_vulkan_wayland_window(
        context.handle,
        display_ptr,
        surface_ptr,
        descriptor.width(),
        descriptor.height(),
        native_surface_origin_ordinal(descriptor.origin),
        descriptor.sample_count,
        descriptor.stencil_bits,
      ),
      descriptor,
    )
  }
}

///|
pub fn Surface::vulkan_gpu_context_opt_in_enabled() -> Bool {
  native_surface_gpu_vulkan_opt_in_enabled()
}

///|
pub fn Surface::vulkan_gpu_context_headers_available() -> Bool {
  native_surface_gpu_vulkan_headers_available()
}

///|
pub fn Surface::vulkan_gpu_context_runtime_available() -> Bool {
  native_surface_gpu_vulkan_runtime_available()
}

///|
pub fn GpuContext::egl(descriptor : @skia.GpuContextDescriptor) -> GpuContext? {
  if !Surface::gpu_context_support_status(descriptor).is_available() ||
    descriptor.backend != @skia.OpenGLGpuContext {
    None
  } else {
    GpuContext::from_handle(native_gpu_context_egl(), descriptor)
  }
}

///|
/// Wrap an Android `ANativeWindow` or HarmonyOS `OHNativeWindow`-backed EGL
/// surface as a Skia GPU surface. The caller passes the raw native-window
/// pointer as `native_window_ptr`. Skia borrows the EGLSurface's back buffer;
/// the host presenter owns the native-window lifecycle. The returned `Surface` must
/// be flushed and then presented via
/// `Surface::egl_present_and_acquire_next` to swap the back buffer to the
/// front buffer.
pub fn Surface::egl_window_surface(
  context : GpuContext,
  native_window_ptr : UInt64,
  descriptor : @skia.SurfaceDescriptor,
) -> Surface? {
  if descriptor.is_empty() || !descriptor.is_gpu() || !context.is_available() {
    None
  } else if native_window_ptr == 0 {
    None
  } else {
    Surface::from_handle(
      native_surface_egl_window(
        context.handle,
        native_window_ptr,
        descriptor.width(),
        descriptor.height(),
        native_surface_origin_ordinal(descriptor.origin),
        descriptor.sample_count,
        descriptor.stencil_bits,
      ),
      descriptor,
    )
  }
}

///|
/// Present the EGL surface backing a `Surface` created via
/// `Surface::egl_window_surface`, and return a fresh `Surface` wrapping the
/// next back buffer for the following frame.
pub fn Surface::egl_present_and_acquire_next(
  surface : Surface,
  context : GpuContext,
  native_window_ptr : UInt64,
) -> Surface? {
  if !context.is_available() {
    None
  } else {
    let descriptor = surface.descriptor
    Surface::from_handle(
      native_surface_egl_present_and_acquire_next(
        surface.handle,
        native_window_ptr,
        descriptor.width(),
        descriptor.height(),
        native_surface_origin_ordinal(descriptor.origin),
        descriptor.sample_count,
        descriptor.stencil_bits,
      ),
      descriptor,
    )
  }
}

///|
pub fn Surface::egl_gpu_context_opt_in_enabled() -> Bool {
  native_surface_gpu_egl_opt_in_enabled()
}

///|
pub fn Surface::egl_gpu_context_headers_available() -> Bool {
  native_surface_gpu_egl_headers_available()
}

///|
pub fn Surface::egl_gpu_context_runtime_available() -> Bool {
  native_surface_gpu_egl_runtime_available()
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
      @skia.Direct3D12GpuContext =>
        if !Surface::direct3d_gpu_context_opt_in_enabled() {
          SkiaGpuContextDirect3DOptInDisabled
        } else if !Surface::direct3d_gpu_context_headers_available() {
          SkiaGpuContextDirect3DHeadersUnavailable
        } else if !Surface::direct3d_gpu_context_runtime_available() {
          SkiaGpuContextDirect3DRuntimeUnavailable
        } else {
          SkiaGpuContextAvailable
        }
      @skia.VulkanGpuContext =>
        if !Surface::vulkan_gpu_context_opt_in_enabled() {
          SkiaGpuContextVulkanOptInDisabled
        } else if !Surface::vulkan_gpu_context_headers_available() {
          SkiaGpuContextVulkanHeadersUnavailable
        } else if !Surface::vulkan_gpu_context_runtime_available() {
          SkiaGpuContextVulkanRuntimeUnavailable
        } else {
          SkiaGpuContextAvailable
        }
      @skia.OpenGLGpuContext =>
        if !Surface::egl_gpu_context_opt_in_enabled() {
          SkiaGpuContextEglOptInDisabled
        } else if !Surface::egl_gpu_context_headers_available() {
          SkiaGpuContextEglHeadersUnavailable
        } else if !Surface::egl_gpu_context_runtime_available() {
          SkiaGpuContextEglRuntimeUnavailable
        } else {
          SkiaGpuContextAvailable
        }
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
/// Replace the destination surface pixels with a same-sized snapshot of the
/// source surface. Both surfaces must use compatible dimensions and GPU
/// contexts; callers must flush pending source work before copying and flush
/// the destination after copying.
pub fn Surface::copy_from(self : Surface, source : Surface) -> Bool {
  if self.descriptor != source.descriptor {
    false
  } else {
    native_surface_copy_from(self.handle, source.handle)
  }
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
    Some({ handle, owner: Some(self), recorder_owner: None })
  }
}
