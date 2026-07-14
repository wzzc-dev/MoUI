///|
test "jpeg_encode rgba_to_ycbcr white black red" {
  let (y_w, cb_w, cr_w) = rgba_to_ycbcr(255, 255, 255)
  assert_true((y_w - 255).abs() <= 1)
  assert_true((cb_w - 128).abs() <= 1)
  assert_true((cr_w - 128).abs() <= 1)

  let (y_b, cb_b, cr_b) = rgba_to_ycbcr(0, 0, 0)
  assert_true(y_b <= 1)
  assert_true((cb_b - 128).abs() <= 1)
  assert_true((cr_b - 128).abs() <= 1)

  let (y_r, cb_r, cr_r) = rgba_to_ycbcr(255, 0, 0)
  assert_true((y_r - 76).abs() <= 1)
  assert_true((cb_r - 85).abs() <= 2)
  assert_true((cr_r - 255).abs() <= 1)
}

///|
test "jpeg_encode jpeg_scale_quant_table quality 1 50 100" {
  let q1 = jpeg_scale_quant_table(jpeg_std_lum_quant, 1)
  let q50 = jpeg_scale_quant_table(jpeg_std_lum_quant, 50)
  let q100 = jpeg_scale_quant_table(jpeg_std_lum_quant, 100)

  assert_eq(q50[0], jpeg_std_lum_quant[0])
  assert_eq(q50[63], jpeg_std_lum_quant[63])
  assert_eq(q1[0], 255)
  assert_eq(q1[63], 255)
  assert_eq(q100[0], 1)
  assert_eq(q100[63], 1)
}

///|
test "jpeg_encode jpeg_bit_category basic" {
  assert_eq(jpeg_bit_category(0), 0)
  assert_eq(jpeg_bit_category(1), 1)
  assert_eq(jpeg_bit_category(-1), 1)
  assert_eq(jpeg_bit_category(127), 7)
  assert_eq(jpeg_bit_category(-127), 7)
}

///|
test "jpeg_encode fdct_block constant has dc only" {
  let input = FixedArray::make(64, 150)
  let dct = FixedArray::make(64, 0.0)
  fdct_block(input, dct)

  assert_true(dct[0] > 170.0 && dct[0] < 182.0)
  for i in 1..<64 {
    assert_true(dct[i].abs() < 0.01)
  }
}
