///|
test "typeface from file rejects invalid paths" {
  assert_true(Typeface::from_file(b"") is None)
  assert_true(
    Typeface::from_file(b"/definitely/missing/moui-open-sans.woff2") is None,
  )
  assert_true(
    Typeface::from_file(b"/definitely/missing/moui-open-sans.woff2", index=-1)
    is None,
  )
}
