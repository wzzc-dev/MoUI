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
  format? : @skia.EncodedImageFormat = @skia.PNG,
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
pub fn Surface::raster_n32_premul(size : @skia.ISize) -> Surface? {
  ignore(size)
  None
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
  @skia.SurfaceDescriptor::raster_n32_premul(self.dimensions())
}

///|
/// Finalize pending surface work; current raster surfaces use this as a no-op boundary.
pub fn Surface::flush_and_submit(self : Surface) -> Bool {
  ignore(self)
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
