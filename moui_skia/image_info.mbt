///|
/// Color storage metadata without a concrete color space handle.
///
/// The native layer will attach real Skia `ColorSpace` handles; this value layer
/// keeps the stable pieces needed by surfaces, pixmaps, and images.
pub(all) struct ColorInfo {
  color_type : ColorType
  alpha_type : AlphaType
} derive(Debug, Eq)

///|
pub fn ColorInfo::new(
  color_type? : ColorType = Unknown,
  alpha_type? : AlphaType = Unknown,
) -> ColorInfo {
  { color_type, alpha_type }
}

///|
pub impl Default for ColorInfo with fn default() {
  ColorInfo::new()
}

///|
pub fn AlphaType::is_opaque(self : AlphaType) -> Bool {
  self is Opaque
}

///|
pub fn ColorType::bytes_per_pixel(self : ColorType) -> Int {
  match self {
    Unknown => 0
    Alpha8 | Gray8 => 1
    RGB565 | ARGB4444 => 2
    RGBAF16 => 8
    RGBAF32 => 16
    _ => 4
  }
}

///|
pub fn ColorType::shift_per_pixel(self : ColorType) -> Int {
  match self.bytes_per_pixel() {
    1 => 0
    2 => 1
    4 => 2
    8 => 3
    16 => 4
    _ => 0
  }
}

///|
pub fn ColorType::is_always_opaque(self : ColorType) -> Bool {
  self is (RGB565 | RGB888x | RGB101010x | Gray8)
}

///|
pub fn ColorInfo::is_opaque(self : ColorInfo) -> Bool {
  self.alpha_type.is_opaque() || self.color_type.is_always_opaque()
}

///|
pub fn ColorInfo::bytes_per_pixel(self : ColorInfo) -> Int {
  self.color_type.bytes_per_pixel()
}

///|
pub fn ColorInfo::shift_per_pixel(self : ColorInfo) -> Int {
  self.color_type.shift_per_pixel()
}

///|
pub fn ColorInfo::with_alpha_type(
  self : ColorInfo,
  alpha_type : AlphaType,
) -> ColorInfo {
  { ..self, alpha_type, }
}

///|
pub fn ColorInfo::with_color_type(
  self : ColorInfo,
  color_type : ColorType,
) -> ColorInfo {
  { ..self, color_type, }
}

///|
/// Dimensions plus color metadata for images, bitmaps, pixmaps, and surfaces.
pub(all) struct ImageInfo {
  dimensions : ISize
  color_info : ColorInfo
} derive(Debug, Eq)

///|
pub fn ImageInfo::new(
  dimensions : ISize,
  color_type? : ColorType = Unknown,
  alpha_type? : AlphaType = Unknown,
) -> ImageInfo {
  { dimensions, color_info: ColorInfo::new(color_type~, alpha_type~) }
}

///|
pub fn ImageInfo::from_color_info(
  dimensions : ISize,
  color_info : ColorInfo,
) -> ImageInfo {
  { dimensions, color_info }
}

///|
pub fn ImageInfo::unknown(dimensions? : ISize = ISize::empty()) -> ImageInfo {
  ImageInfo::new(dimensions)
}

///|
pub fn ImageInfo::n32_premul(dimensions : ISize) -> ImageInfo {
  ImageInfo::new(dimensions, color_type=RGBA8888, alpha_type=Premul)
}

///|
pub fn ImageInfo::a8(dimensions : ISize) -> ImageInfo {
  ImageInfo::new(dimensions, color_type=Alpha8, alpha_type=Premul)
}

///|
pub impl Default for ImageInfo with fn default() {
  ImageInfo::unknown()
}

///|
pub fn ImageInfo::width(self : ImageInfo) -> Int {
  self.dimensions.width
}

///|
pub fn ImageInfo::height(self : ImageInfo) -> Int {
  self.dimensions.height
}

///|
pub fn ImageInfo::is_empty(self : ImageInfo) -> Bool {
  self.dimensions.is_empty()
}

///|
pub fn ImageInfo::bounds(self : ImageInfo) -> IRect {
  IRect::from_size(self.dimensions)
}

///|
pub fn ImageInfo::color_type(self : ImageInfo) -> ColorType {
  self.color_info.color_type
}

///|
pub fn ImageInfo::alpha_type(self : ImageInfo) -> AlphaType {
  self.color_info.alpha_type
}

///|
pub fn ImageInfo::is_opaque(self : ImageInfo) -> Bool {
  self.color_info.is_opaque()
}

///|
pub fn ImageInfo::bytes_per_pixel(self : ImageInfo) -> Int {
  self.color_info.bytes_per_pixel()
}

///|
pub fn ImageInfo::shift_per_pixel(self : ImageInfo) -> Int {
  self.color_info.shift_per_pixel()
}

///|
pub fn ImageInfo::min_row_bytes(self : ImageInfo) -> Int {
  Int::max(0, self.width()) * self.bytes_per_pixel()
}

///|
pub fn ImageInfo::min_row_bytes64(self : ImageInfo) -> Int64 {
  Int::max(0, self.width()).to_int64() * self.bytes_per_pixel().to_int64()
}

///|
pub fn ImageInfo::valid_row_bytes(self : ImageInfo, row_bytes : Int) -> Bool {
  row_bytes >= self.min_row_bytes()
}

///|
pub fn ImageInfo::valid_pixels(self : ImageInfo, row_bytes : Int) -> Bool {
  !self.is_empty() &&
  self.color_type() != Unknown &&
  self.alpha_type() != Unknown &&
  self.valid_row_bytes(row_bytes)
}

///|
pub fn ImageInfo::compute_offset(
  self : ImageInfo,
  point : IPoint,
  row_bytes : Int,
) -> Int {
  point.y * row_bytes + point.x * self.bytes_per_pixel()
}

///|
pub fn ImageInfo::compute_min_byte_size(self : ImageInfo) -> Int {
  if self.height() <= 0 {
    0
  } else {
    self.min_row_bytes() * self.height()
  }
}

///|
pub fn ImageInfo::compute_min_byte_size64(self : ImageInfo) -> Int64 {
  if self.height() <= 0 {
    0L
  } else {
    self.min_row_bytes64() * self.height().to_int64()
  }
}

///|
pub fn ImageInfo::compute_byte_size(self : ImageInfo, row_bytes : Int) -> Int {
  if self.height() <= 0 || !self.valid_row_bytes(row_bytes) {
    0
  } else {
    row_bytes * self.height()
  }
}

///|
pub fn ImageInfo::compute_byte_size64(
  self : ImageInfo,
  row_bytes : Int,
) -> Int64 {
  if self.height() <= 0 || !self.valid_row_bytes(row_bytes) {
    0L
  } else {
    row_bytes.to_int64() * self.height().to_int64()
  }
}

///|
pub fn ImageInfo::with_dimensions(
  self : ImageInfo,
  dimensions : ISize,
) -> ImageInfo {
  { ..self, dimensions, }
}

///|
pub fn ImageInfo::with_alpha_type(
  self : ImageInfo,
  alpha_type : AlphaType,
) -> ImageInfo {
  { ..self, color_info: self.color_info.with_alpha_type(alpha_type) }
}

///|
pub fn ImageInfo::with_color_type(
  self : ImageInfo,
  color_type : ColorType,
) -> ImageInfo {
  { ..self, color_info: self.color_info.with_color_type(color_type) }
}
