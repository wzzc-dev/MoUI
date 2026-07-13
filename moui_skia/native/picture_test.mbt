///|
test "picture recorder follows native availability" {
  match PictureRecorder::new() {
    Some(recorder) => {
      assert_true(skia_available())
      recorder.record_empty(32, 24)
      match recorder.finish() {
        Some(picture) => {
          assert_true(picture.is_available())
          assert_true(picture.unique_id() != 0)
          assert_true(picture.approximate_bytes_used() >= 0L)
        }
        None => fail("real Skia picture recorder did not finish")
      }
    }
    None => assert_false(skia_available())
  }
}

///|
test "picture recorder captures canvas commands" {
  match PictureRecorder::new() {
    Some(recorder) =>
      match recorder.begin(16, 16) {
        Some(canvas) => {
          canvas.clear(@skia.Color::red())
          match recorder.finish() {
            Some(picture) => assert_true(picture.approximate_bytes_used() > 0L)
            None => fail("picture with canvas commands did not finish")
          }
        }
        None => fail("picture recorder did not expose a recording canvas")
      }
    None => assert_false(skia_available())
  }
}
