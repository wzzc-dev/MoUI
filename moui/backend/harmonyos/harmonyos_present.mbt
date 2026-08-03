///|
#borrow(pixels)
extern "C" fn harmonyos_present_pixels_to_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_harmonyos_present_pixels_to_surface"
