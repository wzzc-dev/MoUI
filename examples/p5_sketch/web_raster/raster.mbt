///|
/// String-handle ABI against the p5-local `p5_raster` import namespace. The
/// example's `index.html` supplies the namespace through
/// `bootMouiWasmGcApp({ imports: { p5_raster } })`, so the shared
/// `moui_web_renderer/runtime.js` stays untouched.
extern "wasm" fn p5_raster_begin_string() -> Int32 = "p5_raster" "begin_string"

///|
extern "wasm" fn p5_raster_string_append(
  handle : Int32,
  code_point : Int32,
) -> Unit = "p5_raster" "string_append"

///|
extern "wasm" fn p5_raster_finish_string(handle : Int32) -> Unit = "p5_raster" "finish_string"

///|
extern "wasm" fn p5_raster_capture(
  width : Double,
  height : Double,
  text_handle : Int32,
) -> Int32 = "p5_raster" "capture"

///|
extern "wasm" fn p5_raster_bytes_len(handle : Int32) -> Int32 = "p5_raster" "bytes_len"

///|
extern "wasm" fn p5_raster_bytes_get(handle : Int32, index : Int32) -> Int32 = "p5_raster" "bytes_get"

///|
extern "wasm" fn p5_raster_bytes_close(handle : Int32) -> Unit = "p5_raster" "bytes_close"

///|
fn send_json(payload : String) -> Int32 {
  let handle = p5_raster_begin_string()
  for ch in payload {
    p5_raster_string_append(handle, ch.to_int())
  }
  p5_raster_finish_string(handle)
  handle
}

///|
/// Rasterizes the command list on the JS side (offscreen 2D canvas +
/// getImageData) and returns straight RGBA8 pixels.
pub fn rasterize(
  commands : Array[@core.DrawCommand],
  metrics : @core.SurfaceMetrics,
) -> @p5.Image? {
  let size = metrics.logical_size()
  let payload = commands_json(commands, size.width, size.height)
  let text_handle = send_json(payload)
  let bytes_handle = p5_raster_capture(size.width, size.height, text_handle)
  if bytes_handle <= 0 {
    return None
  }
  let width = size.width.to_int().max(0)
  let height = size.height.to_int().max(0)
  let expected = width * height * 4
  let length = p5_raster_bytes_len(bytes_handle)
  if length < expected {
    p5_raster_bytes_close(bytes_handle)
    return None
  }
  let pixels : FixedArray[Byte] = FixedArray::make(expected, (0 : Byte))
  for index in 0..<expected {
    pixels[index] = p5_raster_bytes_get(bytes_handle, index).to_byte()
  }
  p5_raster_bytes_close(bytes_handle)
  @p5.Image::from_rgba(width, height, pixels)
}

///|
/// Installs the web rasterizer as the default for sketches created afterwards.
pub fn install() -> Unit {
  @p5m.set_default_canvas_rasterizer(Some(rasterize))
}

///|
/// Boot-log probe: rasterizes a 2x1 red/green scene through the JS host and
/// prints the read-back pixel channels. Run before the window backend starts
/// so `?debug=1` surfaces it in the boot log.
pub fn self_test() -> Unit {
  let commands : Array[@core.DrawCommand] = [
    @core.FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0),
    ),
    @core.FillRect(
      @core.Rect::new(x=1.0, y=0.0, width=1.0, height=1.0),
      @core.Color::rgba(r=0.0, g=1.0, b=0.0),
    ),
  ]
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=2.0, height=1.0),
    scale_factor=1.0,
  )
  match rasterize(commands, metrics) {
    Some(image) => {
      let left = image.get(0, 0)
      let right = image.get(1, 0)
      println(
        "p5 web readback self-test: left=(\{(left.r * 255.0).to_int()},\{(left.g * 255.0).to_int()},\{(left.b * 255.0).to_int()}) right=(\{(right.r * 255.0).to_int()},\{(right.g * 255.0).to_int()},\{(right.b * 255.0).to_int()})",
      )
    }
    None => println("p5 web readback self-test: unavailable")
  }
}
