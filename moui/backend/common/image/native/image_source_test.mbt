///|
test "native filesystem image source reads raw bytes" {
  let path = "/tmp/moui-native-image-source-test.bin"
  @fs.remove_file(path) catch {
    _ => ()
  }
  defer (@fs.remove_file(path) catch { _ => () })
  @fs.write_bytes_to_file(path, b"\x01\x02")

  match filesystem_image_source().read(path) {
    Some(bytes) => assert_eq(bytes, b"\x01\x02")
    None => abort("expected raw image source bytes")
  }
}

///|
test "native filesystem image source leaves data URIs to the renderer" {
  assert_true(
    filesystem_image_source().read("data:image/png;base64,AA==") is None,
  )
}
