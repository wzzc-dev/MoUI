///|
fn sample_manifest() -> OwnershipManifest {
  {
    external_wrappers: [
      {
        name: "Surface",
        moonbit_handle: "SurfaceHandle",
        moonbit_type: "Surface",
        wrapper_struct: "MoonbitSkiaSurface",
        field: "surface",
        owner_field: None,
        owner_type: None,
        moonbit_owner_field: None,
        factory: "moonbit_skia_make_surface_wrapper",
        finalizer: "moonbit_skia_surface_finalize",
        ownership: "sk_refcnt",
      },
      {
        name: "Canvas",
        moonbit_handle: "CanvasHandle",
        moonbit_type: "Canvas",
        wrapper_struct: "MoonbitSkiaCanvas",
        field: "canvas",
        owner_field: Some("surface_owner"),
        owner_type: Some("Surface"),
        moonbit_owner_field: Some("owner"),
        factory: "moonbit_skia_make_canvas_wrapper",
        finalizer: "moonbit_skia_canvas_finalize",
        ownership: "borrowed_with_refcnt_owner",
      },
    ],
    regular_objects: [
      {
        name: "ShapedTextRun",
        moonbit_handle: Some("ShapedTextRunHandle"),
        moonbit_type: Some("ShapedTextRun"),
        wrapper_struct: "MoonbitSkiaShapedTextRun",
        factory: "moonbit_skia_make_shaped_text_run",
        allocation: "moonbit_malloc",
        pointer_field_count: 1,
        pointer_fields: ["glyphs"],
        value_fields: ["glyph_count"],
      },
    ],
    regular_runtime_objects: [
      {
        name: "Point",
        moonbit_handle: None,
        moonbit_type: None,
        wrapper_struct: "MoonbitSkiaPoint",
        factory: "moonbit_skia_make_point",
        allocation: "moonbit_malloc",
        pointer_field_count: 0,
        pointer_fields: [],
        value_fields: ["x", "y"],
      },
    ],
  }
}

///|
fn sample_inputs() -> OwnershipInputs {
  let header =
    #|struct MoonbitSkiaSurface {
    #|  SkSurface* surface;
    #|};
    #|struct MoonbitSkiaCanvas {
    #|  SkCanvas* canvas;
    #|  SkSurface* surface_owner;
    #|};
    #|struct MoonbitSkiaShapedTextRun {
    #|  MoonbitSkiaGlyphIdArray* glyphs;
    #|  int32_t glyph_count;
    #|};
    #|struct MoonbitSkiaPoint {
    #|  float x;
    #|  float y;
    #|};
  let source =
    #|static void moonbit_skia_surface_finalize(void* ptr) {
    #|  auto wrapper = static_cast<MoonbitSkiaSurface*>(ptr);
    #|  wrapper->surface->unref();
    #|  wrapper->surface = nullptr;
    #|}
    #|static void moonbit_skia_canvas_finalize(void* ptr) {
    #|  auto wrapper = static_cast<MoonbitSkiaCanvas*>(ptr);
    #|  wrapper->surface_owner->unref();
    #|  wrapper->surface_owner = nullptr;
    #|  wrapper->canvas = nullptr;
    #|}
    #|MoonbitSkiaSurface* moonbit_skia_make_surface_wrapper(SkSurface* surface) {
    #|  auto wrapper = static_cast<MoonbitSkiaSurface*>(moonbit_make_external_object(moonbit_skia_surface_finalize, sizeof(MoonbitSkiaSurface)));
    #|  wrapper->surface = surface;
    #|  return wrapper;
    #|}
    #|MoonbitSkiaCanvas* moonbit_skia_make_canvas_wrapper(SkCanvas* canvas, SkSurface* surface_owner) {
    #|  auto wrapper = static_cast<MoonbitSkiaCanvas*>(moonbit_make_external_object(moonbit_skia_canvas_finalize, sizeof(MoonbitSkiaCanvas)));
    #|  wrapper->canvas = canvas;
    #|  wrapper->surface_owner = surface_owner;
    #|  wrapper->surface_owner->ref();
    #|  return wrapper;
    #|}
    #|MoonbitSkiaShapedTextRun* moonbit_skia_make_shaped_text_run(int32_t glyph_count, MoonbitSkiaGlyphIdArray* glyphs) {
    #|  auto run = static_cast<MoonbitSkiaShapedTextRun*>(moonbit_malloc(sizeof(MoonbitSkiaShapedTextRun)));
    #|  Moonbit_object_header(run)->meta = moonbit_skia_regular_object_header(static_cast<uint32_t>(offsetof(MoonbitSkiaShapedTextRun, glyphs) >> 2), 1, 0);
    #|  run->glyph_count = glyph_count;
    #|  run->glyphs = glyphs;
    #|  return run;
    #|}
    #|MoonbitSkiaPoint* moonbit_skia_make_point(float x, float y) {
    #|  auto point = static_cast<MoonbitSkiaPoint*>(moonbit_malloc(sizeof(MoonbitSkiaPoint)));
    #|  Moonbit_object_header(point)->meta = moonbit_skia_regular_object_header(static_cast<uint32_t>(sizeof(MoonbitSkiaPoint) >> 2), 0, 0);
    #|  point->x = x;
    #|  point->y = y;
    #|  return point;
    #|}
  let types =
    #|pub(all) struct Surface {
    #|  priv handle : SurfaceHandle
    #|}
    #|pub(all) struct Canvas {
    #|  priv handle : CanvasHandle
    #|  priv owner : Surface?
    #|}
    #|pub(all) struct ShapedTextRun {
    #|  priv handle : ShapedTextRunHandle
    #|}
  {
    manifest_path: "native/ownership.json",
    handle_paths: [],
    header_text: header,
    source_text: source,
    types_text: types,
  }
}

///|
test "verifies sample ownership manifest" {
  match verify_manifest(sample_manifest(), sample_inputs()) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
}

///|
test "rejects missing finalizer cleanup" {
  let inputs = sample_inputs()
  let broken = {
    ..inputs,
    source_text: inputs.source_text.replace(
      old="wrapper->surface = nullptr;",
      new="",
    ),
  }
  let result = verify_manifest(sample_manifest(), broken)
  inspect(
    match result {
      Err(message) => message.contains("does not clear surface")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects regular object pointer field mismatch" {
  let manifest = sample_manifest()
  manifest.regular_objects[0].pointer_fields[0] = "missing"
  let result = verify_manifest(manifest, sample_inputs())
  inspect(
    match result {
      Err(message) => message.contains("pointer_fields mismatch")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "detects declared handles" {
  let handles = declared_handles(
    "priv type SurfaceHandle\npriv type CanvasHandle\n",
  )
  inspect(handles.contains("SurfaceHandle"), content="true")
  inspect(handles.contains("CanvasHandle"), content="true")
}
