///|
/// Native executable export shims. The shell owns the ABI implementation and
/// callback state; this package only makes its symbols reachable to MoonBit's
/// native executable linker.
pub fn moui_embedding_take_host_updates_json() -> String {
  @shell_embedding.moui_embedding_take_host_updates_json()
}

///|
pub fn moui_embedding_take_host_update_envelope_json() -> String {
  @shell_embedding.moui_embedding_take_host_update_envelope_json()
}

///|
pub fn moui_embedding_dispatch_host_response_envelope_json(
  text : String,
) -> Bool {
  @shell_embedding.moui_embedding_dispatch_host_response_envelope_json(text)
}

///|
pub fn moui_embedding_renderer_configure(mode : String) -> Bool {
  @shell_embedding.moui_embedding_renderer_configure(mode)
}

///|
pub fn moui_embedding_renderer_status_json() -> String {
  @shell_embedding.moui_embedding_renderer_status_json()
}

///|
pub fn moui_embedding_dispatch_text_input(
  kind : Int,
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  @shell_embedding.moui_embedding_dispatch_text_input(kind, text, start, end)
}

///|
pub fn moui_embedding_dispatch_command(kind : Int) -> Bool {
  @shell_embedding.moui_embedding_dispatch_command(kind)
}

///|
pub fn moui_embedding_dispatch_accessibility(
  element_id : Int,
  action : Int,
  value : String,
) -> Bool {
  @shell_embedding.moui_embedding_dispatch_accessibility(
    element_id, action, value,
  )
}

///|
pub fn moui_embedding_complete_clipboard(
  id : Int,
  kind : Int,
  text : String,
  bytes : Bytes,
) -> Bool {
  @shell_embedding.moui_embedding_complete_clipboard(id, kind, text, bytes)
}

///|
pub fn moui_embedding_complete_clipboard_v1(
  session_generation : Int,
  id : Int,
  kind : Int,
  text : String,
  bytes : Bytes,
) -> Bool {
  @shell_embedding.moui_embedding_complete_clipboard_v1(
    session_generation, id, kind, text, bytes,
  )
}

///|
pub fn moui_embedding_attach_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  @shell_embedding.moui_embedding_attach_surface(
    surface_handle, width, height, scale_factor,
  )
}

///|
pub fn moui_embedding_resize(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  @shell_embedding.moui_embedding_resize(width, height, scale_factor)
}

///|
pub fn moui_embedding_dispatch_pointer(
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  @shell_embedding.moui_embedding_dispatch_pointer(phase, x, y, time_ms)
}

///|
pub fn moui_embedding_dispatch_scroll(
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  phase : Int,
) -> Bool {
  @shell_embedding.moui_embedding_dispatch_scroll(x, y, delta_x, delta_y, phase)
}

///|
pub fn moui_embedding_frame_tick(time_ms : Double) -> Bool {
  @shell_embedding.moui_embedding_frame_tick(time_ms)
}

///|
pub fn moui_embedding_render_frame() -> Bool {
  @shell_embedding.moui_embedding_render_frame()
}

///|
pub fn moui_embedding_detach_surface() -> Unit {
  @shell_embedding.moui_embedding_detach_surface()
}

///|
pub fn moui_embedding_destroy_application() -> Unit {
  @shell_embedding.moui_embedding_destroy_application()
}
