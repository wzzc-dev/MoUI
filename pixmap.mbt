///|
/// Immutable pixel snapshot plus layout metadata.
///
/// This mirrors the lightweight role of Skia's `SkPixmap`, but owns the copied
/// bytes on the MoonBit side so it is safe across backend boundaries.
pub(all) struct Pixmap {
  image_info : ImageInfo
  row_bytes : Int
  pixels : Bytes
} derive(Debug, Eq)

///|
pub fn Pixmap::new(
  image_info : ImageInfo,
  row_bytes : Int,
  pixels : Bytes,
) -> Pixmap? {
  if image_info.is_empty() || !image_info.valid_row_bytes(row_bytes) {
    None
  } else if pixels.length() < image_info.compute_byte_size(row_bytes) {
    None
  } else {
    Some({ image_info, row_bytes, pixels })
  }
}

///|
pub fn Pixmap::width(self : Pixmap) -> Int {
  self.image_info.width()
}

///|
pub fn Pixmap::height(self : Pixmap) -> Int {
  self.image_info.height()
}

///|
pub fn Pixmap::dimensions(self : Pixmap) -> ISize {
  self.image_info.dimensions
}

///|
pub fn Pixmap::bounds(self : Pixmap) -> IRect {
  self.image_info.bounds()
}

///|
pub fn Pixmap::bytes_per_pixel(self : Pixmap) -> Int {
  self.image_info.bytes_per_pixel()
}

///|
pub fn Pixmap::byte_size(self : Pixmap) -> Int {
  self.image_info.compute_byte_size(self.row_bytes)
}

///|
pub fn Pixmap::is_empty(self : Pixmap) -> Bool {
  self.image_info.is_empty() || self.pixels.is_empty()
}

///|
pub fn Pixmap::contains(self : Pixmap, point : IPoint) -> Bool {
  self.bounds().contains_point(point)
}

///|
pub fn Pixmap::offset(self : Pixmap, point : IPoint) -> Int? {
  if self.contains(point) {
    Some(self.image_info.compute_offset(point, self.row_bytes))
  } else {
    None
  }
}
