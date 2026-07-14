///|
test "package name benchmark" (b : @bench.T) {
  b.bench(fn() { ignore(package_name()) })
}

///|
// Generate a test PNG for benchmarking (64x64 RGBA)
fn make_bench_png() -> Bytes {
  let width = 64
  let height = 64
  let buf = FixedArray::make(width * height * 4, b'\x00')
  for y in 0..<height {
    for x in 0..<width {
      let idx = (y * width + x) * 4
      buf[idx] = (x * 4).to_byte()
      buf[idx + 1] = (y * 4).to_byte()
      buf[idx + 2] = ((x + y) * 2).to_byte()
      buf[idx + 3] = b'\xFF'
    }
  }
  let img : ImageData = { width, height, data: Bytes::from_array(buf) }
  encode_png(img) catch {
    _ => panic()
  }
}

///|
fn make_bench_image() -> ImageData {
  let width = 64
  let height = 64
  let buf = FixedArray::make(width * height * 4, b'\x00')
  for y in 0..<height {
    for x in 0..<width {
      let idx = (y * width + x) * 4
      buf[idx] = (x * 4).to_byte()
      buf[idx + 1] = (y * 4).to_byte()
      buf[idx + 2] = ((x + y) * 2).to_byte()
      buf[idx + 3] = b'\xFF'
    }
  }
  { width, height, data: Bytes::from_array(buf) }
}

///|
fn make_webp_cache_bench_image() -> ImageData {
  let width = 64
  let height = 64
  let buf = FixedArray::make(width * height * 4, b'\x00')
  for y in 0..<height {
    for x in 0..<width {
      let idx = (y * width + x) * 4
      let tile = x % 2 + y % 2 * 2
      match tile {
        0 => {
          buf[idx] = b'\x10'
          buf[idx + 1] = b'\x20'
          buf[idx + 2] = b'\x30'
        }
        1 => {
          buf[idx] = b'\x90'
          buf[idx + 1] = b'\x10'
          buf[idx + 2] = b'\xB0'
        }
        2 => {
          buf[idx] = b'\x12'
          buf[idx + 1] = b'\x34'
          buf[idx + 2] = b'\xF0'
        }
        _ => {
          buf[idx] = b'\xBA'
          buf[idx + 1] = b'\xDA'
          buf[idx + 2] = b'\x55'
        }
      }
      buf[idx + 3] = b'\xFF'
    }
  }
  { width, height, data: Bytes::from_array(buf) }
}

///|
test "bench: PNG decode 64x64" (b : @bench.T) {
  let png = make_bench_png()
  b.bench(fn() { b.keep(decode_png(png)) catch { _ => () } })
}

///|
test "bench: PNG encode 64x64" (b : @bench.T) {
  let img = make_bench_image()
  b.bench(fn() { b.keep(encode_png(img)) catch { _ => () } })
}

///|
test "bench: JPEG encode 64x64" (b : @bench.T) {
  let img = make_bench_image()
  b.bench(fn() { b.keep(encode_jpeg(img)) catch { _ => () } })
}

///|
test "bench: WebP encode 64x64" (b : @bench.T) {
  let img = make_bench_image()
  b.bench(fn() { b.keep(encode_webp(img)) catch { _ => () } })
}

///|
test "bench: WebP encode cache-friendly 64x64" (b : @bench.T) {
  let img = make_webp_cache_bench_image()
  b.bench(fn() { b.keep(encode_webp(img)) catch { _ => () } })
}

///|
test "bench: PNG roundtrip 64x64" (b : @bench.T) {
  let img = make_bench_image()
  b.bench(fn() {
    try {
      let png = encode_png(img)
      b.keep(decode_png(png))
    } catch {
      _ => ()
    }
  })
}

///|
test "bench: resize nearest 64x64 -> 128x128" (b : @bench.T) {
  let img = make_bench_image()
  b.bench(fn() { b.keep(resize(img, 128, 128, Nearest)) catch { _ => () } })
}

///|
test "bench: resize bilinear 64x64 -> 128x128" (b : @bench.T) {
  let img = make_bench_image()
  b.bench(fn() { b.keep(resize(img, 128, 128, Bilinear)) catch { _ => () } })
}

///|
test "bench: resize bicubic 64x64 -> 128x128" (b : @bench.T) {
  let img = make_bench_image()
  b.bench(fn() { b.keep(resize(img, 128, 128, Bicubic)) catch { _ => () } })
}

///|
test "bench: resize nearest 64x64 -> 32x32" (b : @bench.T) {
  let img = make_bench_image()
  b.bench(fn() { b.keep(resize(img, 32, 32, Nearest)) catch { _ => () } })
}

///|
test "bench: resize bilinear 64x64 -> 32x32" (b : @bench.T) {
  let img = make_bench_image()
  b.bench(fn() { b.keep(resize(img, 32, 32, Bilinear)) catch { _ => () } })
}

///|
test "bench: resize bicubic 64x64 -> 32x32" (b : @bench.T) {
  let img = make_bench_image()
  b.bench(fn() { b.keep(resize(img, 32, 32, Bicubic)) catch { _ => () } })
}
