///|
#borrow(pixels)
extern "C" fn android_present_pixels_to_surface(
  surface_handle : UInt64,
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  pixels : Bytes,
  pixels_len : Int32,
) -> Int32 = "moui_android_present_pixels_to_surface"

///|
/// Configure visible Android system bars before the hosted event loop starts.
/// The window template applies this on the Activity UI thread.
extern "C" fn android_set_status_bar_immersive(immersive : Int32) -> Int32 = "mbw_android_set_status_bar_immersive"
