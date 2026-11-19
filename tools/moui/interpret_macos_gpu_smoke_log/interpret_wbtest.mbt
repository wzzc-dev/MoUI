// White-box tests for tools/moui/interpret_macos_gpu_smoke_log.
// They pin present-count parsing, the short-path heuristic, the JSON report
// shape, and CLI validation.

///|
test "parse_present_count reads digits after the marker" {
  assert_eq(parse_present_count("present_count=7"), 7)
  assert_eq(parse_present_count("PRESENT_COUNT=0042"), 42)
  assert_eq(parse_present_count("present_count=none"), 0)
  assert_eq(parse_present_count("present_count="), 0)
  assert_eq(parse_present_count("unrelated log"), 0)
}

///|
test "interpret_macos_gpu_smoke_log requires route and presented frames" {
  let full = interpret_macos_gpu_smoke_log(
    "MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu\nsurface_gpu=true\npresent_count=3\nPicture worker",
  )
  assert_true(full.metal_route)
  assert_true(full.surface_gpu)
  assert_false(full.gpu_smoke_passed)
  assert_eq(full.present_count, 3)
  assert_true(full.worker_owned)
  assert_true(full.short_path_ok)
  let route_without_frames = interpret_macos_gpu_smoke_log(
    "surface_route=metal-gpu",
  )
  assert_true(route_without_frames.metal_route)
  assert_false(route_without_frames.surface_gpu)
  assert_false(route_without_frames.short_path_ok)
  let passed_without_route = interpret_macos_gpu_smoke_log(
    "MoUI Skia GPU Metal renderer smoke passed",
  )
  assert_false(passed_without_route.metal_route)
  assert_true(passed_without_route.gpu_smoke_passed)
  assert_true(passed_without_route.worker_owned)
  assert_true(passed_without_route.short_path_ok)
  let empty = interpret_macos_gpu_smoke_log("")
  assert_false(empty.metal_route)
  assert_false(empty.surface_gpu)
  assert_eq(empty.present_count, 0)
  assert_false(empty.worker_owned)
  assert_false(empty.short_path_ok)
}

///|
test "interpretation_to_json preserves every interpretation field" {
  let value = interpret_macos_gpu_smoke_log(
    "surface_route=metal-gpu surface_gpu=true present_count=5 native worker",
  )
  match interpretation_to_json(value) {
    Json::Object(fields) => {
      match fields.get("metalRoute") {
        Some(Json::True) => ()
        _ => fail("metalRoute must serialize as true")
      }
      match fields.get("surfaceGpu") {
        Some(Json::True) => ()
        _ => fail("surfaceGpu must serialize as true")
      }
      match fields.get("gpuSmokePassed") {
        Some(Json::False) => ()
        _ => fail("gpuSmokePassed must serialize as false")
      }
      match fields.get("presentCount") {
        Some(Json::Number(count, repr=_)) => assert_eq(count, 5.0)
        _ => fail("presentCount must serialize as a number")
      }
      match fields.get("workerOwned") {
        Some(Json::True) => ()
        _ => fail("workerOwned must serialize as true")
      }
      match fields.get("shortPathOk") {
        Some(Json::True) => ()
        _ => fail("shortPathOk must serialize as true")
      }
    }
    _ => fail("interpretation must serialize as a JSON object")
  }
}

///|
test "parse_cli accepts log text and reports missing or unknown options" {
  match parse_cli([]) {
    Ok((text, flag)) => {
      assert_eq(text, "")
      assert_false(flag)
    }
    Err(message) => fail(message)
  }
  match parse_cli(["--log-text", "hello"]) {
    Ok((text, flag)) => {
      assert_eq(text, "hello")
      assert_false(flag)
    }
    Err(message) => fail(message)
  }
  match parse_cli(["--help"]) {
    Ok(_) => fail("help must short-circuit through Err")
    Err(message) => assert_eq(message, "help")
  }
  match parse_cli(["--log-text"]) {
    Ok(_) => fail("missing --log-text value must be rejected")
    Err(message) => assert_eq(message, "missing value for --log-text")
  }
  match parse_cli(["--wat"]) {
    Ok(_) => fail("unknown option must be rejected")
    Err(message) => assert_eq(message, "Unknown argument: --wat")
  }
}
