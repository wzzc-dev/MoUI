///|
pub fn PictureRecorder::new() -> PictureRecorder? {
  None
}

///|
pub fn PictureRecorder::record_empty(
  self : PictureRecorder,
  _width : Int32,
  _height : Int32,
) -> Unit {
  let _ = self
}

///|
pub fn PictureRecorder::begin(
  self : PictureRecorder,
  _width : Int32,
  _height : Int32,
) -> Canvas? {
  let _ = self
  None
}

///|
pub fn PictureRecorder::finish(self : PictureRecorder) -> Picture? {
  let _ = self
  None
}

///|
pub fn Picture::is_available(self : Picture) -> Bool {
  let _ = self
  false
}

///|
pub fn Picture::approximate_bytes_used(self : Picture) -> Int64 {
  let _ = self
  0L
}

///|
pub fn Picture::unique_id(self : Picture) -> Int32 {
  let _ = self
  0
}
