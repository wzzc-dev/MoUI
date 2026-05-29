///|
#borrow(pixels)
extern "C" fn native_present_rgba_to_window(
  raw_view_handle : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "skia_mbt_macos_present_rgba_to_window"

///|
let trace_logged : Array[Bool] = [false]

///|
fn trace_present(
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
) -> Unit {
  if trace_logged[0] {
    return
  }
  match @env.get_env_var("SKIA_MBT_HELLO_TRACE") {
    Some(trace) if trace != "" => {
      trace_logged[0] = true
      let sample_x = width / 2
      let sample_y = height / 2
      let sample = sample_y * row_bytes + sample_x * 4
      println(
        "skia hello present: \{width}x\{height} sample=\{pixels[sample].to_int()},\{pixels[sample + 1].to_int()},\{pixels[sample + 2].to_int()},\{pixels[sample + 3].to_int()}",
      )
    }
    _ => ()
  }
}

///|
fn present_rgba_to_window(
  raw_view_handle : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
) -> Int {
  trace_present(width, height, row_bytes, pixels)
  native_present_rgba_to_window(
    raw_view_handle,
    width,
    height,
    row_bytes,
    pixels,
    pixels.length(),
  )
}
