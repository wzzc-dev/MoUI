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
/// Declare (or replace) the window-drag region on a host content view.
///
/// `raw_content_view_handle` is the borrowed AppKit content-view pointer from
/// `macos_native_view_handle`. The rect is in MoUI logical (top-left origin)
/// coordinates of that content view; a non-positive width or height clears the
/// region. Clicks inside the region drag the window instead of reaching
/// application input; clicks outside behave exactly as before.
extern "C" fn macos_set_drag_region(
  raw_content_view_handle : UInt64,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit = "moui_macos_set_drag_region"

///|
/// Remove the window-drag region from a host content view, restoring the
/// presenter's default hit testing. Safe to call for an unset region.
extern "C" fn macos_clear_drag_region(raw_content_view_handle : UInt64) -> Unit = "moui_macos_clear_drag_region"

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
