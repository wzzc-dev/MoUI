///|
extern "C" fn native_picture_recorder_new() -> PictureRecorderHandle = "moonbit_skia_picture_recorder_new"

///|
#borrow(recorder)
extern "C" fn native_picture_recorder_is_null(
  recorder : PictureRecorderHandle,
) -> Bool = "moonbit_skia_picture_recorder_is_null"

///|
#borrow(recorder)
extern "C" fn native_picture_recorder_record_empty(
  recorder : PictureRecorderHandle,
  width : Int32,
  height : Int32,
) -> Unit = "moonbit_skia_picture_recorder_record_empty"

///|
#borrow(recorder)
extern "C" fn native_picture_recorder_begin(
  recorder : PictureRecorderHandle,
  width : Int32,
  height : Int32,
) -> CanvasHandle = "moonbit_skia_picture_recorder_begin"

///|
#borrow(canvas)
extern "C" fn native_picture_recorder_canvas_is_null(
  canvas : CanvasHandle,
) -> Bool = "moonbit_skia_canvas_is_null"

///|
#borrow(recorder)
extern "C" fn native_picture_recorder_finish(
  recorder : PictureRecorderHandle,
) -> PictureHandle = "moonbit_skia_picture_recorder_finish"

///|
#borrow(picture)
extern "C" fn native_picture_is_null(picture : PictureHandle) -> Bool = "moonbit_skia_picture_is_null"

///|
#borrow(picture)
extern "C" fn native_picture_approximate_bytes_used(
  picture : PictureHandle,
) -> Int64 = "moonbit_skia_picture_approximate_bytes_used"

///|
#borrow(picture)
extern "C" fn native_picture_unique_id(picture : PictureHandle) -> Int32 = "moonbit_skia_picture_unique_id"

///|
pub fn PictureRecorder::new() -> PictureRecorder? {
  let handle = native_picture_recorder_new()
  if native_picture_recorder_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
/// Records an empty immutable picture. Drawing commands can be appended by
/// the native Canvas bridge before `finish` in platform integrations.
pub fn PictureRecorder::record_empty(
  self : PictureRecorder,
  width : Int32,
  height : Int32,
) -> Unit {
  native_picture_recorder_record_empty(self.handle, width, height)
}

///|
/// Begin recording into a Canvas owned by this recorder. Finish recording only
/// after all Canvas calls are complete; the Canvas must not be used after
/// `finish`.
pub fn PictureRecorder::begin(
  self : PictureRecorder,
  width : Int32,
  height : Int32,
) -> Canvas? {
  let handle = native_picture_recorder_begin(self.handle, width, height)
  if native_picture_recorder_canvas_is_null(handle) {
    None
  } else {
    Some({ handle, owner: None, recorder_owner: Some(self), })
  }
}

///|
pub fn PictureRecorder::finish(self : PictureRecorder) -> Picture? {
  let handle = native_picture_recorder_finish(self.handle)
  if native_picture_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Picture::is_available(self : Picture) -> Bool {
  !native_picture_is_null(self.handle)
}

///|
pub fn Picture::approximate_bytes_used(self : Picture) -> Int64 {
  native_picture_approximate_bytes_used(self.handle)
}

///|
pub fn Picture::unique_id(self : Picture) -> Int32 {
  native_picture_unique_id(self.handle)
}
