///|
extern "c" fn renderer_macos_presenter_passthrough_ready() -> Int = "renderer_macos_presenter_passthrough_ready"

///|
pub fn macos_presenter_passthrough_ready() -> Bool {
  renderer_macos_presenter_passthrough_ready() != 0
}

///|
/// Present a tightly packed RGBA rectangle with the full surface dimensions.
///
/// Native backends that keep a backing store, such as macOS layer contents,
/// need the full surface dimensions even when only one dirty rectangle is
/// submitted.
#borrow(pixels)
extern "c" fn renderer_present_surface_rect(
  window : UInt64,
  pixels : FixedArray[Byte],
  surface_width : Int,
  surface_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) = "renderer_present_surface_rect"

///|
/// Present a tightly packed RGBA rectangle using a Bytes buffer (preferred FFI
/// path that avoids FixedArray[Byte] pointer issues on some native targets).
#borrow(pixels)
extern "c" fn renderer_present_surface_rect_bytes(
  window : UInt64,
  pixels : Bytes,
  surface_width : Int,
  surface_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) = "renderer_present_surface_rect"

///|
fn display_pixels_rect(
  hwnd : UInt64,
  pixels : FixedArray[Byte],
  surface_width : Int,
  surface_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> Unit {
  renderer_present_surface_rect(
    hwnd, pixels, surface_width, surface_height, x, y, width, height,
  )
}

///|
fn display_bytes_rect(
  hwnd : UInt64,
  pixels : Bytes,
  surface_width : Int,
  surface_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> Unit {
  renderer_present_surface_rect_bytes(
    hwnd, pixels, surface_width, surface_height, x, y, width, height,
  )
}
