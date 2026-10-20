///|
#borrow(pixels)
extern "C" fn harmonyos_present_pixels_to_surface(
  surface_handle : UInt64,
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  pixels : Bytes,
  pixels_len : Int32,
) -> Int32 = "moui_harmonyos_present_pixels_to_surface"
