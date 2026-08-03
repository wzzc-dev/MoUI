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
