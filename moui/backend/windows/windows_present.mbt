///|
#borrow(pixels)
extern "C" fn windows_present_pixels_to_hwnd(
  hwnd : UInt64,
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  pixels : Bytes,
  pixels_len : Int32,
) -> Int32 = "moui_windows_present_pixels_to_hwnd"
