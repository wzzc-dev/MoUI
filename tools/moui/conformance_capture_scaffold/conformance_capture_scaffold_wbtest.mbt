///|
test "golden manifest has schema and screenshot artifacts" {
  match build_manifest("golden") {
    Json::Object(fields) => {
      debug_inspect(fields.get("mode"), content="Some(String(\"golden\"))")
      match fields.get("schemaVersion") {
        Some(Json::Number(number, repr=_)) =>
          debug_inspect(number.to_int(), content="1")
        _ => fail("unexpected schemaVersion")
      }
      match fields.get("screenshotArtifacts") {
        Some(Json::Array(values)) => debug_inspect(values.length(), content="3")
        _ => fail("expected screenshots")
      }
      debug_inspect(fields.get("benchmarkTargets"), content="None")
    }
    _ => fail("expected object")
  }
}

///|
test "benchmark manifest includes targets" {
  match build_manifest("benchmark") {
    Json::Object(fields) =>
      match fields.get("benchmarkTargets") {
        Some(Json::Array(values)) => {
          debug_inspect(values.length(), content="2")
          debug_inspect(
            values[0].stringify().contains("showcase-web-wasm"),
            content="true",
          )
        }
        _ => fail("expected benchmarkTargets")
      }
    _ => fail("expected object")
  }
}

///|
test "default output paths" {
  debug_inspect(
    default_output("golden"),
    content="\"artifacts/conformance/showcase-golden-capture.json\"",
  )
  debug_inspect(
    default_output("benchmark"),
    content="\"artifacts/conformance/showcase-benchmark-capture.json\"",
  )
}
