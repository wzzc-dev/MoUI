///|
fn paeth_predictor(a : Int, b : Int, c : Int) -> Int {
  let p = a + b - c
  let pa = if p > a { p - a } else { a - p }
  let pb = if p > b { p - b } else { b - p }
  let pc = if p > c { p - c } else { c - p }
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}

///|
/// Reconstruct a filtered scanline (decode side).
/// `filter_type`: 0=None, 1=Sub, 2=Up, 3=Average, 4=Paeth
fn reconstruct_row(
  filter_type : Int,
  row : Bytes,
  prev : Bytes,
  bpp : Int,
) -> Bytes raise DecodeError {
  let len = row.length()
  let buf = FixedArray::make(len, b'\x00')
  match filter_type {
    0 => buf.blit_from_bytes(0, row, 0, len)
    1 =>
      for i in 0..<len {
        let a = if i >= bpp { buf[i - bpp].to_int() } else { 0 }
        buf[i] = ((row[i].to_int() + a) % 256).to_byte()
      }
    2 => reconstruct_filter_up_impl(row, prev, buf)
    3 =>
      for i in 0..<len {
        let a = if i >= bpp { buf[i - bpp].to_int() } else { 0 }
        let b = prev[i].to_int()
        buf[i] = ((row[i].to_int() + (a + b) / 2) % 256).to_byte()
      }
    4 =>
      for i in 0..<len {
        let a = if i >= bpp { buf[i - bpp].to_int() } else { 0 }
        let b = prev[i].to_int()
        let c = if i >= bpp { prev[i - bpp].to_int() } else { 0 }
        buf[i] = ((row[i].to_int() + paeth_predictor(a, b, c)) % 256).to_byte()
      }
    _ => raise CorruptData("unknown filter type: " + filter_type.to_string())
  }
  Bytes::from_array(buf)
}

///|
fn apply_filter_none(
  row : Bytes,
  _prev : Bytes,
  _bpp : Int,
) -> FixedArray[Byte] {
  let len = row.length()
  let buf = FixedArray::make(len, b'\x00')
  buf.blit_from_bytes(0, row, 0, len)
  buf
}

///|
fn apply_filter_sub(row : Bytes, _prev : Bytes, bpp : Int) -> FixedArray[Byte] {
  apply_filter_sub_impl(row, bpp)
}

///|
fn apply_filter_up(row : Bytes, prev : Bytes, _bpp : Int) -> FixedArray[Byte] {
  apply_filter_up_impl(row, prev)
}

///|
fn apply_filter_average(
  row : Bytes,
  prev : Bytes,
  bpp : Int,
) -> FixedArray[Byte] {
  let len = row.length()
  let buf = FixedArray::make(len, b'\x00')
  for i in 0..<len {
    let raw_val = row[i].to_int()
    let a = if i >= bpp { row[i - bpp].to_int() } else { 0 }
    let b = prev[i].to_int()
    buf[i] = ((raw_val - (a + b) / 2 + 256) % 256).to_byte()
  }
  buf
}

///|
fn apply_filter_paeth(row : Bytes, prev : Bytes, bpp : Int) -> FixedArray[Byte] {
  let len = row.length()
  let buf = FixedArray::make(len, b'\x00')
  for i in 0..<len {
    let raw_val = row[i].to_int()
    let a = if i >= bpp { row[i - bpp].to_int() } else { 0 }
    let b = prev[i].to_int()
    let c = if i >= bpp { prev[i - bpp].to_int() } else { 0 }
    buf[i] = ((raw_val - paeth_predictor(a, b, c) + 256) % 256).to_byte()
  }
  buf
}

///|
fn filter_sum(buf : FixedArray[Byte]) -> Int {
  let mut sum = 0
  for i in 0..<buf.length() {
    let v = buf[i].to_int()
    sum += if v < 128 { v } else { 256 - v }
  }
  sum
}

///|
fn select_best_filter(
  row : Bytes,
  prev : Bytes,
  bpp : Int,
) -> (Int, FixedArray[Byte]) {
  let f0 = apply_filter_none(row, prev, bpp)
  let mut best_type = 0
  let mut best_sum = filter_sum(f0)
  let mut best_buf = f0
  let f1 = apply_filter_sub(row, prev, bpp)
  let s1 = filter_sum(f1)
  if s1 < best_sum {
    best_type = 1
    best_sum = s1
    best_buf = f1
  }
  let f2 = apply_filter_up(row, prev, bpp)
  let s2 = filter_sum(f2)
  if s2 < best_sum {
    best_type = 2
    best_sum = s2
    best_buf = f2
  }
  let f3 = apply_filter_average(row, prev, bpp)
  let s3 = filter_sum(f3)
  if s3 < best_sum {
    best_type = 3
    best_sum = s3
    best_buf = f3
  }
  let f4 = apply_filter_paeth(row, prev, bpp)
  let s4 = filter_sum(f4)
  if s4 < best_sum {
    best_type = 4
    best_sum = s4
    best_buf = f4
  }
  ignore(best_sum)
  (best_type, best_buf)
}

///|
test "paeth_predictor" {
  assert_eq(paeth_predictor(0, 0, 0), 0)
  assert_eq(paeth_predictor(10, 20, 15), 15)
  assert_eq(paeth_predictor(100, 100, 100), 100)
  assert_eq(paeth_predictor(7, 5, 6), 6)
}

///|
test "reconstruct_row filter none" {
  let row = b"\x0A\x14\x1E"
  let prev = Bytes::new(3)
  let result = reconstruct_row(0, row, prev, 1)
  assert_eq(result, b"\x0A\x14\x1E")
}

///|
test "reconstruct_row filter sub" {
  // bpp=1: each byte adds the previous reconstructed byte
  // filtered: [10, 20, 30]
  // reconstructed: [10, 10+20=30, 30+30=60]
  let row = b"\x0A\x14\x1E"
  let prev = Bytes::new(3)
  let result = reconstruct_row(1, row, prev, 1)
  assert_eq(result, b"\x0A\x1E\x3C")
}

///|
test "reconstruct_row filter up" {
  // filtered: [5, 10, 15], prev: [100, 100, 100]
  // reconstructed: [105, 110, 115]
  let row = b"\x05\x0A\x0F"
  let prev = b"\x64\x64\x64"
  let result = reconstruct_row(2, row, prev, 1)
  assert_eq(result, b"\x69\x6E\x73")
}

///|
test "reconstruct_row filter average" {
  // filtered: [10, 20, 30], prev: [0, 0, 0], bpp=1
  // [0]: a=0, b=0, avg=0, out=10
  // [1]: a=10, b=0, avg=5, out=25
  // [2]: a=25, b=0, avg=12, out=42
  let row = b"\x0A\x14\x1E"
  let prev = Bytes::new(3)
  let result = reconstruct_row(3, row, prev, 1)
  assert_eq(result[0].to_int(), 10)
  assert_eq(result[1].to_int(), 25)
  assert_eq(result[2].to_int(), 42)
}

///|
test "reconstruct_row filter paeth" {
  // Paeth with prev all zeros, bpp=1
  // Same as Sub when prev is zero
  let row = b"\x0A\x14\x1E"
  let prev = Bytes::new(3)
  let result = reconstruct_row(4, row, prev, 1)
  assert_eq(result, b"\x0A\x1E\x3C")
}

///|
test "apply_filter_none roundtrip" {
  let row = b"\x0A\x14\x1E"
  let prev = Bytes::new(3)
  let filtered = apply_filter_none(row, prev, 1)
  let reconstructed = reconstruct_row(0, Bytes::from_array(filtered), prev, 1)
  assert_eq(reconstructed, row)
}

///|
test "apply_filter_sub roundtrip" {
  let row = b"\x0A\x1E\x32"
  let prev = Bytes::new(3)
  let filtered = apply_filter_sub(row, prev, 1)
  // [10, 30-10=20, 50-30=20]
  assert_eq(filtered[0].to_int(), 10)
  assert_eq(filtered[1].to_int(), 20)
  assert_eq(filtered[2].to_int(), 20)
  let reconstructed = reconstruct_row(1, Bytes::from_array(filtered), prev, 1)
  assert_eq(reconstructed, row)
}

///|
test "apply_filter_up roundtrip" {
  let row = b"\x69\x6E\x73"
  let prev = b"\x64\x64\x64"
  let filtered = apply_filter_up(row, prev, 1)
  // [105-100=5, 110-100=10, 115-100=15]
  assert_eq(filtered[0].to_int(), 5)
  assert_eq(filtered[1].to_int(), 10)
  assert_eq(filtered[2].to_int(), 15)
  let reconstructed = reconstruct_row(2, Bytes::from_array(filtered), prev, 1)
  assert_eq(reconstructed, row)
}

///|
test "apply_filter_average roundtrip" {
  let row = b"\x0A\x19\x2A"
  let prev = Bytes::new(3)
  let filtered = apply_filter_average(row, prev, 1)
  let reconstructed = reconstruct_row(3, Bytes::from_array(filtered), prev, 1)
  assert_eq(reconstructed, row)
}

///|
test "apply_filter_paeth roundtrip" {
  let row = b"\x0A\x1E\x3C"
  let prev = b"\x05\x0A\x0F"
  let filtered = apply_filter_paeth(row, prev, 1)
  let reconstructed = reconstruct_row(4, Bytes::from_array(filtered), prev, 1)
  assert_eq(reconstructed, row)
}

///|
test "apply_filter_sub wrapping" {
  // Test with values that wrap around 256
  let row = b"\x02\x01"
  let prev = Bytes::new(2)
  let filtered = apply_filter_sub(row, prev, 1)
  // [2, (1-2+256)%256=255]
  assert_eq(filtered[0].to_int(), 2)
  assert_eq(filtered[1].to_int(), 255)
  let reconstructed = reconstruct_row(1, Bytes::from_array(filtered), prev, 1)
  assert_eq(reconstructed, row)
}

///|
test "select_best_filter constant row" {
  // Constant row: Up filter should give all zeros (except first row)
  let row = b"\xFF\x00\x00\xFF\xFF\x00\x00\xFF"
  let prev = b"\xFF\x00\x00\xFF\xFF\x00\x00\xFF"
  let (filter_type, filtered) = select_best_filter(row, prev, 4)
  // Up filter should win (all zeros)
  assert_eq(filter_type, 2)
  for i in 0..<filtered.length() {
    assert_eq(filtered[i].to_int(), 0)
  }
}
