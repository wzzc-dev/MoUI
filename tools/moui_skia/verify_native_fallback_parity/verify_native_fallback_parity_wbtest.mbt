///|
test "parse moon.pkg target entries" {
  let text =
    #|options(
    #|  targets: {
    #|    "handles_native.mbt": [ "native", "llvm" ],
    #|    "handles_unavailable.mbt": [
    #|      "wasm",
    #|      "wasm-gc",
    #|      "js",
    #|    ],
    #|  },
    #|)
    #|
  let entries = match parse_target_entries(text) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match entries.get("handles_native.mbt") {
    Some(targets) => inspect(@tools.comma_join(targets), content="native, llvm")
    None => fail("missing handles_native.mbt")
  }
  match entries.get("handles_unavailable.mbt") {
    Some(targets) =>
      inspect(@tools.comma_join(targets), content="wasm, wasm-gc, js")
    None => fail("missing handles_unavailable.mbt")
  }
}

///|
test "detect duplicate moon.pkg target entries" {
  let text =
    #|options(targets: {
    #|  "handles_native.mbt": [ "native", "llvm" ],
    #|  "handles_native.mbt": [ "native", "llvm" ],
    #|})
    #|
  inspect(
    match parse_target_entries(text) {
      Err(_) => true
      Ok(_) => false
    },
    content="true",
  )
}
