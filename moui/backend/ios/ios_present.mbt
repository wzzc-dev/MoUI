///|
#borrow(pixels)
extern "C" fn ios_present_pixels_to_view(
  view_handle : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_ios_present_pixels_to_view"

///|
extern "C" fn ios_metal_layer_for_view(view_handle : UInt64) -> UInt64 = "moui_ios_metal_layer_for_view"
