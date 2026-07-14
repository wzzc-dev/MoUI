///|
test "zlib roundtrip" {
  let data = b"\x48\x65\x6C\x6C\x6F"
  let compressed = @zlib.zlib_compress(data)
  let decompressed = @zlib.zlib_decompress(compressed)
  assert_eq(decompressed, data)
}

///|
test "ImageData creation" {
  let img : ImageData = { width: 2, height: 2, data: Bytes::new(16) }
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.data.length(), 16)
}
