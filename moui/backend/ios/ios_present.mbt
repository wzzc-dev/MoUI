///|
#borrow(pixels)
extern "C" fn ios_present_pixels_to_view(
  view_handle : UInt64,
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  pixels : Bytes,
  pixels_len : Int32,
) -> Int32 = "moui_ios_present_pixels_to_view"

///|
extern "C" fn ios_metal_layer_for_view(view_handle : UInt64) -> UInt64 = "moui_ios_metal_layer_for_view"
