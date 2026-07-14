///|
let valid_manifest_text =
  #|{
  #|  "schema_version": 1,
  #|  "capabilities": [
  #|    {
  #|      "id": "canvas",
  #|      "area": "Canvas",
  #|      "native_file": "canvas_native.mbt",
  #|      "unavailable_file": "canvas_unavailable.mbt",
  #|      "handles": ["SkCanvas"],
  #|      "smoke_markers": ["native_canvas_marker=passed"]
  #|    }
  #|  ]
  #|}

///|
let valid_ownership_text =
  #|{
  #|  "external_wrappers": [
  #|    { "name": "SkCanvas" }
  #|  ],
  #|  "regular_objects": []
  #|}

///|
let valid_status_text =
  #|{
  #|  "native_smoke_capabilities": [
  #|    { "marker": "native_canvas_marker=passed" }
  #|  ],
  #|  "native_smoke_conditional_capabilities": []
  #|}

///|
fn object_from_text(text : String) -> Map[String, Json] {
  let parsed = @json.parse(text) catch { _ => return Map([]) }
  match parsed {
    Json::Object(fields) => fields
    _ => Map([])
  }
}

///|
fn valid_manifest() -> Map[String, Json] {
  object_from_text(valid_manifest_text)
}

///|
fn valid_ownership() -> Map[String, Json] {
  object_from_text(valid_ownership_text)
}

///|
fn valid_status() -> Map[String, Json] {
  object_from_text(valid_status_text)
}

///|
fn valid_targets() -> Map[String, Array[String]] {
  {
    "canvas_native.mbt": ["native", "llvm"],
    "canvas_unavailable.mbt": ["wasm", "wasm-gc", "js"],
  }
}

///|
fn valid_native_files() -> Map[String, String] {
  {
    "canvas_native.mbt": "pub extern \"C\" fn canvas_make(handle : Int) -> Unit\npub fn Canvas::draw() -> Unit Map([])",
  }
}

///|
fn valid_fallback_files() -> Map[String, String] {
  {
    "canvas_unavailable.mbt": "pub fn canvas_make(handle : Int) -> Unit Map([])\npub fn Canvas::draw() -> Unit Map([])",
  }
}

///|
fn verify_fixture(
  manifest? : Map[String, Json] = valid_manifest(),
  ownership? : Map[String, Json] = valid_ownership(),
  status? : Map[String, Json] = valid_status(),
  targets? : Map[String, Array[String]] = valid_targets(),
  native_files? : Map[String, String] = valid_native_files(),
  fallback_files? : Map[String, String] = valid_fallback_files(),
  smoke_source? : String = "native_canvas_marker=passed",
) -> Result[Unit, String] {
  verify_capability_contract_data(
    manifest, ownership, status, targets, native_files, fallback_files, smoke_source,
  )
}

///|
test "accepts valid native capability contract data" {
  inspect(verify_fixture() is Ok(_), content="true")
}

///|
test "parses public extern and method functions" {
  let source =
    #|pub extern "C" fn canvas_make(handle : Int) -> Unit
    #|pub(all) fn Canvas::draw() -> Unit Map([])
  let exports = public_functions(source)
  inspect(exports.contains("canvas_make"), content="true")
  inspect(exports.contains("Canvas::draw"), content="true")
}

///|
test "rejects missing fallback public API" {
  let fallback_files = {
    "canvas_unavailable.mbt": "pub fn canvas_make(handle : Int) -> Unit Map([])",
  }
  match verify_fixture(fallback_files~) {
    Ok(_) => inspect("ok", content="err")
    Err(message) =>
      inspect(
        message.contains(
          "native capability fallback is missing public APIs: canvas: Canvas::draw",
        ),
        content="true",
      )
  }
}

///|
test "rejects missing ownership handle" {
  let ownership = object_from_text(
    "{ \"external_wrappers\": [], \"regular_objects\": [] }",
  )
  match verify_fixture(ownership~) {
    Ok(_) => inspect("ok", content="err")
    Err(message) =>
      inspect(
        message.contains(
          "native capability handle is missing from ownership manifest: canvas: SkCanvas",
        ),
        content="true",
      )
  }
}

///|
test "rejects marker absent from status" {
  let status = object_from_text(
    (
      #|{
      #|  "native_smoke_capabilities": [],
      #|  "native_smoke_conditional_capabilities": []
      #|},
    ),
  )
  match verify_fixture(status~) {
    Ok(_) => inspect("ok", content="err")
    Err(message) =>
      inspect(
        message.contains(
          "native capability smoke marker is missing from platform status: canvas: native_canvas_marker=passed",
        ),
        content="true",
      )
  }
}

///|
test "rejects uncovered native files" {
  let native_files = {
    "canvas_native.mbt": "pub extern \"C\" fn canvas_make(handle : Int) -> Unit\npub fn Canvas::draw() -> Unit Map([])",
    "path_native.mbt": "pub fn path_make() -> Unit Map([])",
  }
  match verify_fixture(native_files~) {
    Ok(_) => inspect("ok", content="err")
    Err(message) =>
      inspect(
        message.contains(
          "native capability manifest does not cover native files: path_native.mbt",
        ),
        content="true",
      )
  }
}
