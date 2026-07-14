// SIMD implementation of PNG filter Up — wasm target only.
//
// Filter Up: buf[i] = (row[i] - prev[i]) mod 256
//
// `i8x16.sub` does exactly this on 16 bytes at a time (modular byte
// subtraction). Inline-WAT can take `Bytes` as input on wasm (not on
// wasm-gc, which receives a GC ref — that target falls through to scalar
// via png_filter_scalar.mbt).

///|
/// Decode-side Up reconstruction: buf[i] = (row[i] + prev[i]) mod 256.
/// Pure `i8x16.add` (modular byte add) on 16-byte chunks.
fn reconstruct_filter_up_impl(
  row : Bytes,
  prev : Bytes,
  buf : FixedArray[Byte],
) -> Unit {
  let len = row.length()
  if len == 0 {
    return
  }
  reconstruct_filter_up_v128(row, prev, buf, len)
}

///|
/// Inline-WAT for filter Up reconstruction. Same shape as the encoder
/// `apply_filter_up_v128`, but using `i8x16.add` (decode) instead of sub.
///
/// Locals: 4 = vec_end, 5 = i.
#borrow(row, prev, buf)
fn reconstruct_filter_up_v128(
  row : Bytes,
  prev : Bytes,
  buf : FixedArray[Byte],
  len : Int,
) -> Unit =
  #|(func (param i32) (param i32) (param i32) (param i32) (local i32) (local i32) local.get 3 i32.const 4 i32.shr_s i32.const 4 i32.shl local.set 4 block loop local.get 5 local.get 4 i32.ge_s br_if 1 local.get 2 local.get 5 i32.add local.get 0 local.get 5 i32.add v128.load local.get 1 local.get 5 i32.add v128.load i8x16.add v128.store local.get 5 i32.const 16 i32.add local.set 5 br 0 end end block loop local.get 5 local.get 3 i32.ge_s br_if 1 local.get 2 local.get 5 i32.add local.get 0 local.get 5 i32.add i32.load8_u local.get 1 local.get 5 i32.add i32.load8_u i32.add i32.store8 local.get 5 i32.const 1 i32.add local.set 5 br 0 end end)

///|
fn apply_filter_up_impl(row : Bytes, prev : Bytes) -> FixedArray[Byte] {
  let len = row.length()
  let buf = FixedArray::make(len, b'\x00')
  if len == 0 {
    return buf
  }
  apply_filter_up_v128(row, prev, buf, len)
  buf
}

///|
/// Inline-WAT: walks `row` and `prev` 16 bytes at a time via `v128.load`
/// + `i8x16.sub` + `v128.store` into `buf`. Tail bytes scalar.
///
/// Locals: 4 = vec_end (= len & ~15), 5 = i.
#borrow(row, prev, buf)
fn apply_filter_up_v128(
  row : Bytes,
  prev : Bytes,
  buf : FixedArray[Byte],
  len : Int,
) -> Unit =
  #|(func (param i32) (param i32) (param i32) (param i32) (local i32) (local i32) local.get 3 i32.const 4 i32.shr_s i32.const 4 i32.shl local.set 4 block loop local.get 5 local.get 4 i32.ge_s br_if 1 local.get 2 local.get 5 i32.add local.get 0 local.get 5 i32.add v128.load local.get 1 local.get 5 i32.add v128.load i8x16.sub v128.store local.get 5 i32.const 16 i32.add local.set 5 br 0 end end block loop local.get 5 local.get 3 i32.ge_s br_if 1 local.get 2 local.get 5 i32.add local.get 0 local.get 5 i32.add i32.load8_u local.get 1 local.get 5 i32.add i32.load8_u i32.sub i32.store8 local.get 5 i32.const 1 i32.add local.set 5 br 0 end end)

///|
/// Filter Sub: buf[i] = row[i] - (i >= bpp ? row[i-bpp] : 0).
///
/// Head (i < bpp) is scalar; then SIMD as long as `i + 16 <= len`, then
/// scalar tail. The SIMD load `row + i - bpp` is safe because i >= bpp.
fn apply_filter_sub_impl(row : Bytes, bpp : Int) -> FixedArray[Byte] {
  let len = row.length()
  let buf = FixedArray::make(len, b'\x00')
  if len == 0 {
    return buf
  }
  // Scalar head: i = 0..bpp-1, buf[i] = row[i] (a = 0).
  let head_end = if bpp > len { len } else { bpp }
  for i in 0..<head_end {
    buf[i] = row[i]
  }
  if len > bpp {
    apply_filter_sub_v128(row, buf, bpp, len)
  }
  buf
}

///|
/// Inline-WAT: SIMD body + scalar tail for filter Sub.
/// Params: 0 = row, 1 = buf, 2 = bpp, 3 = len.
/// Locals: 4 = vec_end (= ((len - bpp) & ~15) + bpp), 5 = i.
#borrow(row, buf)
fn apply_filter_sub_v128(
  row : Bytes,
  buf : FixedArray[Byte],
  bpp : Int,
  len : Int,
) -> Unit =
  #|(func (param i32) (param i32) (param i32) (param i32) (local i32) (local i32) local.get 3 local.get 2 i32.sub i32.const 4 i32.shr_s i32.const 4 i32.shl local.get 2 i32.add local.set 4 local.get 2 local.set 5 block loop local.get 5 local.get 4 i32.ge_s br_if 1 local.get 1 local.get 5 i32.add local.get 0 local.get 5 i32.add v128.load local.get 0 local.get 5 i32.add local.get 2 i32.sub v128.load i8x16.sub v128.store local.get 5 i32.const 16 i32.add local.set 5 br 0 end end block loop local.get 5 local.get 3 i32.ge_s br_if 1 local.get 1 local.get 5 i32.add local.get 0 local.get 5 i32.add i32.load8_u local.get 0 local.get 5 i32.add local.get 2 i32.sub i32.load8_u i32.sub i32.store8 local.get 5 i32.const 1 i32.add local.set 5 br 0 end end)
