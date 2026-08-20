///|
#borrow(call_closure)
#owned(callback)
extern "C" fn macos_3d_install_event_callback(
  call_closure : FuncRef[
    (
      (UInt64, Int, Bytes, Bytes, Bytes, Int) -> Unit,
      UInt64,
      Int,
      Bytes,
      Bytes,
      Bytes,
      Int,
    ) -> Unit,
  ],
  callback : (UInt64, Int, Bytes, Bytes, Bytes, Int) -> Unit,
) -> Unit = "moui_macos_3d_install_event_callback"

///|
extern "C" fn macos_3d_available() -> Int = "moui_macos_3d_available"

///|
#borrow(id)
extern "C" fn macos_3d_sync(
  raw_content_view_handle : UInt64,
  id : Bytes,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  scale_factor : Double,
) -> UInt64 = "moui_macos_3d_sync"

///|
extern "C" fn macos_3d_platform_views_begin(
  raw_content_view_handle : UInt64,
) -> Unit = "moui_macos_3d_platform_views_begin"

///|
extern "C" fn macos_3d_platform_views_end(
  raw_content_view_handle : UInt64,
) -> Unit = "moui_macos_3d_platform_views_end"

///|
extern "C" fn macos_3d_platform_views_dispose(
  raw_content_view_handle : UInt64,
) -> Unit = "moui_macos_3d_platform_views_dispose"

///|
extern "C" fn macos_3d_surface_scale(surface_handle : UInt64) -> Double = "moui_macos_3d_surface_scale"

///|
#borrow(id)
extern "C" fn macos_3d_sync_overlay_mask(
  raw_content_view_handle : UInt64,
  id : Bytes,
  has_bounds : Int,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit = "moui_macos_3d_sync_overlay_mask"

///|
pub fn macos_3d_capabilities() -> String {
  if macos_3d_available() != 0 {
    "available: CAMetalLayer child surface"
  } else {
    "unavailable: macOS AppKit/QuartzCore host is unavailable"
  }
}

///|
pub fn install_macos_3d_event_dispatcher(
  dispatch : (UInt64, String, @core.PlatformViewEvent) -> Unit,
) -> Unit {
  macos_3d_install_event_callback(
    fn(callback, raw_handle, kind, id, value, detail, flag) {
      callback(raw_handle, kind, id, value, detail, flag)
    },
    (raw_handle, kind, id, value, detail, flag) => {
      let name = match kind {
        1 => "pointer_down"
        2 => "pointer_move"
        3 => "pointer_up"
        4 => "wheel"
        5 => "focus"
        _ => "unknown"
      }
      let id_string = @utf8.decode_lossy(id[:], ignore_bom=true)
      let value_string = @utf8.decode_lossy(value[:], ignore_bom=true)
      let detail_string = @utf8.decode_lossy(detail[:], ignore_bom=true)
      dispatch(
        raw_handle,
        id_string,
        @core.PlatformViewEvent::Named(
          name~,
          value=value_string,
          detail=detail_string,
          flag=flag != 0,
        ),
      )
    },
  )
}
