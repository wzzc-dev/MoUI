///|
test "filter ffi rejects non-finite inputs" {
  let invalid_scalar : Float = 0.0 / 0.0
  let infinite_scalar : Float = 1.0 / 0.0
  let invalid_matrix : Array[Float] = [
    invalid_scalar, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
  ]
  assert_true(
    native_color_filter_is_null(
      native_color_filter_matrix(FixedArray::from_array(invalid_matrix)),
    ),
  )
  assert_true(
    native_image_filter_is_null(native_image_filter_blur(infinite_scalar, 1.0)),
  )
  assert_true(
    native_image_filter_is_null(native_image_filter_blur(1.0, invalid_scalar)),
  )
  assert_true(
    native_mask_filter_is_null(native_mask_filter_blur(infinite_scalar)),
  )
}
