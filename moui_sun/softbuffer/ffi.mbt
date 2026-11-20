///|
extern "c" fn renderer_macos_presenter_passthrough_ready() -> Int32 = "renderer_macos_presenter_passthrough_ready"

///|
pub fn macos_presenter_passthrough_ready() -> Bool {
  renderer_macos_presenter_passthrough_ready() != 0
}

///|
/// Host platform of the native stub, so capability queries can be asserted
/// against the platform they belong to instead of the host that runs the test.
extern "c" fn renderer_host_is_macos() -> Int32 = "renderer_host_is_macos"

///|
/// True when the native stub was compiled for macOS. Capability queries such
/// as `macos_presenter_passthrough_ready` only promise AppKit support here.
pub fn host_is_macos() -> Bool {
  renderer_host_is_macos() != 0
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
  surface_width : Int32,
  surface_height : Int32,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
) = "renderer_present_surface_rect"

///|
/// Present a tightly packed RGBA rectangle using a Bytes buffer (preferred FFI
/// path that avoids FixedArray[Byte] pointer issues on some native targets).
#borrow(pixels)
extern "c" fn renderer_present_surface_rect_bytes(
  window : UInt64,
  pixels : Bytes,
  surface_width : Int32,
  surface_height : Int32,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
) = "renderer_present_surface_rect"

///|
fn display_pixels_rect(
  hwnd : UInt64,
  pixels : FixedArray[Byte],
  surface_width : Int32,
  surface_height : Int32,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
) -> Unit {
  renderer_present_surface_rect(
    hwnd, pixels, surface_width, surface_height, x, y, width, height,
  )
}

///|
fn display_bytes_rect(
  hwnd : UInt64,
  pixels : Bytes,
  surface_width : Int32,
  surface_height : Int32,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
) -> Unit {
  renderer_present_surface_rect_bytes(
    hwnd, pixels, surface_width, surface_height, x, y, width, height,
  )
}
