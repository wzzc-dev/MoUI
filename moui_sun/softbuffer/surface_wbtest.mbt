///|
test "macOS presenter uses passthrough image view for pointer delivery" {
  assert_true(macos_presenter_passthrough_ready())
}

///|
test "copy_tightly_packed_rows drops per-row padding" {
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  pixels[0] = 11
  pixels[1] = 12
  pixels[2] = 13
  pixels[3] = 14
  pixels[4] = 91
  pixels[5] = 92
  pixels[6] = 93
  pixels[7] = 94
  pixels[8] = 21
  pixels[9] = 22
  pixels[10] = 23
  pixels[11] = 24
  pixels[12] = 95
  pixels[13] = 96
  pixels[14] = 97
  pixels[15] = 98

  let packed = copy_tightly_packed_rows(2, 8, 4, pixels)
  assert_eq(packed.length(), 8)
  assert_eq(packed[0], 11)
  assert_eq(packed[1], 12)
  assert_eq(packed[2], 13)
  assert_eq(packed[3], 14)
  assert_eq(packed[4], 21)
  assert_eq(packed[5], 22)
  assert_eq(packed[6], 23)
  assert_eq(packed[7], 24)
}
