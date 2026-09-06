///|
#borrow(pixels)
extern "C" fn macos_present_pixels_to_view(
  raw_content_view_handle : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_macos_present_pixels_to_view"

///|
extern "C" fn macos_surface_layer_from_view(
  raw_content_view_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> UInt64 = "moui_macos_surface_layer_from_view"

///|
/// Order a host-owned modal sheet on the key window for a native modal
/// presentation (overlay plan slice 6). Returns 1 when the sheet was
/// accepted onto a host window, 0 when no host window is available (the
/// presentation transparently falls back to the view-level surface).
extern "C" fn macos_present_modal_sheet(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Int = "moui_macos_present_modal_sheet"

///|
/// Dismiss the host-owned modal sheet previously ordered by
/// `macos_present_modal_sheet`. Safe to call when no sheet is open.
extern "C" fn macos_close_modal_sheet() -> Unit = "moui_macos_close_modal_sheet"
