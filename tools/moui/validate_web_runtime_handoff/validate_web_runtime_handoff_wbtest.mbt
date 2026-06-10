///|
fn sample_wasm_with_exports() -> Bytes {
  Bytes::from_array([
    b'\x00', b'\x61', b'\x73', b'\x6d', b'\x01', b'\x00', b'\x00', b'\x00', b'\x07',
    b'\x5b', b'\x03', b'\x12', b'w', b'e', b'b', b'_', b'd', b'i', b's', b'p', b'a',
    b't', b'c', b'h', b'_', b'e', b'v', b'e', b'n', b't', b'\x00', b'\x00', b'\x21',
    b'w', b'e', b'b', b'_', b'c', b'o', b'm', b'p', b'l', b'e', b't', b'e', b'_',
    b'a', b's', b'y', b'n', b'c', b'_', b'c', b'l', b'i', b'p', b'b', b'o', b'a',
    b'r', b'd', b'_', b'r', b'e', b'a', b'd', b'\x00', b'\x01', b'\x1e', b'w', b'e',
    b'b', b'_', b'c', b'o', b'm', b'p', b'l', b'e', b't', b'e', b'_', b'a', b's',
    b'y', b'n', b'c', b'_', b'f', b'i', b'l', b'e', b'_', b'd', b'i', b'a', b'l',
    b'o', b'g', b'\x00', b'\x02',
  ])
}

///|
test "parses wasm export names" {
  match wasm_export_names(sample_wasm_with_exports()) {
    Ok(exports) => {
      assert_true(array_contains(exports, "web_dispatch_event"))
      assert_true(array_contains(exports, "web_complete_async_clipboard_read"))
      assert_true(array_contains(exports, "web_complete_async_file_dialog"))
    }
    Err(message) => fail(message)
  }
}

///|
test "rejects non wasm bytes" {
  match wasm_export_names(Bytes::from_array([b'n', b'o', b't'])) {
    Err(message) => assert_true(message == "invalid wasm magic")
    Ok(_) => fail("expected invalid wasm magic")
  }
}

///|
test "manifest text records base url and boundary" {
  let target = handoff_targets()[0]
  let text = manifest_text(
    ".",
    "http://127.0.0.1:18080",
    [
      {
        target,
        wasm_bytes: 2048,
        compiled_wasm_exports: required_wasm_exports(),
      },
    ],
    [{ kind: "file", label: "", path: target.wasm_path, url: "", bytes: 2048 }],
  )
  assert_true(text.contains("\"baseUrl\": \"http://127.0.0.1:18080\""))
  assert_true(text.contains("not browser WebGPU device"))
}
