///|
#borrow(pixels)
extern "C" fn windows_present_pixels_to_hwnd(
  hwnd : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_windows_present_pixels_to_hwnd"
