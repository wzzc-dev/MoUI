///|
fn sample_status() -> Map[String, Json] {
  let text =
    #|{
    #|  "native_smoke_capabilities": [
    #|    { "id": "surface.descriptor", "marker": "native smoke surface descriptor backend" }
    #|  ],
    #|  "native_smoke_conditional_capabilities": [
    #|    {
    #|      "id": "text.shaped-glyph-count",
    #|      "marker": "native smoke shaped glyph count",
    #|      "when_marker": "native smoke surface descriptor backend",
    #|      "when_value": "1"
    #|    }
    #|  ]
    #|}
  let json = @json.parse(text) catch { _ => return Map([]) }
  match json {
    Json::Object(fields) => fields
    _ => Map([])
  }
}

///|
test "validates required and conditional markers" {
  let source = "native smoke surface descriptor backend\nnative smoke shaped glyph count"
  let verifier_source = "native_smoke_capabilities native_smoke_expected_values native_smoke_conditional_capabilities"
  let wrapper = "tools/moui_skia/verify_native_smoke_log verify_native_smoke_log.exe"
  match
    verify_capability_markers(
      sample_status(),
      source,
      verifier_source,
      wrapper,
      wrapper,
      "scripts/native_smoke",
      "tools/moui_skia/verify_native_smoke_log",
      "scripts/verify-native-smoke-log.sh",
      "scripts/verify-native-smoke-log.ps1",
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
}

///|
test "rejects conditional marker with unknown condition marker" {
  let text =
    #|{
    #|  "native_smoke_capabilities": [
    #|    { "id": "surface.descriptor", "marker": "native smoke surface descriptor backend" }
    #|  ],
    #|  "native_smoke_conditional_capabilities": [
    #|    {
    #|      "id": "text.shaped-glyph-count",
    #|      "marker": "native smoke shaped glyph count",
    #|      "when_marker": "missing marker",
    #|      "when_value": "1"
    #|    }
    #|  ]
    #|}
  let json = @json.parse(text) catch { _ => Json::empty_object() }
  let status = match json {
    Json::Object(fields) => fields
    _ => Map([])
  }
  let result = verify_capability_markers(
    status, "native smoke surface descriptor backend\nnative smoke shaped glyph count",
    "native_smoke_capabilities native_smoke_expected_values native_smoke_conditional_capabilities",
    "tools/moui_skia/verify_native_smoke_log", "tools/moui_skia/verify_native_smoke_log",
    "scripts/native_smoke", "tools/moui_skia/verify_native_smoke_log", "scripts/verify-native-smoke-log.sh",
    "scripts/verify-native-smoke-log.ps1",
  )
  inspect(
    match result {
      Err(message) => message.contains("unknown condition marker")
      Ok(_) => false
    },
    content="true",
  )
}
