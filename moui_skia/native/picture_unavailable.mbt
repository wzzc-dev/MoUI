///|
pub fn PictureRecorder::new() -> PictureRecorder? {
  None
}

///|
pub fn PictureRecorder::record_empty(
  self : PictureRecorder,
  _width : Int,
  _height : Int,
) -> Unit {
  let _ = self
}

///|
pub fn PictureRecorder::begin(
  self : PictureRecorder,
  _width : Int,
  _height : Int,
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
pub fn Picture::unique_id(self : Picture) -> Int {
  let _ = self
  0
}
