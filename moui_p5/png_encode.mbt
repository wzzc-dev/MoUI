///|
/// PNG encoding for `Image`: 8-bit straight RGBA, non-interlaced, filter 0
/// rows. The framework's neutral `@core.RgbaBuffer` owns the byte-level codec;
/// the addon keeps its own `Image` / `to_png_bytes` naming on top so sketch
/// code does not depend on a codec package directly and there is no second
/// framework pixel type.
pub fn Image::to_png_bytes(self : Image) -> Bytes {
  match
    @core.RgbaBuffer::from_rgba(
      width=self.width_,
      height=self.height_,
      pixels=self.pixels,
    ) {
    Some(buffer) => buffer.to_png_bytes()
    // `Image` invariants keep `pixels` at width*height*4; a mismatched buffer
    // can only come from manual `pixels` replacement, and has no PNG form.
    None => b""
  }
}

///|
/// Encodes the image as a PNG and hands the bytes to `saver`, which returns
/// false when it cannot write the path. The addon carries no filesystem
/// dependency: `Sketch::save_image` routes through the sketch's `FilePorts`,
/// and direct callers pass a host-backed saver (for example the native
/// filesystem package in the demo, an in-memory map in tests).
pub fn Image::save(
  self : Image,
  path : String,
  saver~ : (String, Bytes) -> Bool,
) -> Bool {
  saver(path, self.to_png_bytes())
}
