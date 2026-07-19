///|
/// MoUI-independent runtime callbacks consumed by the fixed native embedding
/// ABI. Platform backends install an implementation; the shell owns all C ABI
/// exports and dispatches to this value.
pub(all) struct EmbeddingRuntimeCallbacks {
  renderer_configure : (String) -> Bool
  renderer_status_json : () -> String
  take_host_updates_json : () -> String
  take_host_update_envelope_json : () -> String
  dispatch_host_response_envelope_json : (String) -> Bool
  dispatch_text_input : (Int, String, Int, Int) -> Bool
  dispatch_command : (Int) -> Bool
  dispatch_accessibility : (Int, Int, String) -> Bool
  complete_clipboard : (Int, Int, String, Bytes) -> Bool
  complete_clipboard_v1 : (Int, Int, Int, String, Bytes) -> Bool
  attach_surface : (UInt64, Int, Int, Double) -> Bool
  resize : (Int, Int, Double) -> Bool
  dispatch_pointer : (Int, Double, Double, Double) -> Bool
  dispatch_scroll : (Double, Double, Double, Double, Int) -> Bool
  frame_tick : (Double) -> Bool
  render_frame : () -> Bool
  detach_surface : () -> Unit
  destroy_application : () -> Unit
}

///|
pub fn EmbeddingRuntimeCallbacks::new(
  renderer_configure~ : (String) -> Bool,
  renderer_status_json~ : () -> String,
  take_host_updates_json~ : () -> String,
  take_host_update_envelope_json~ : () -> String,
  dispatch_host_response_envelope_json~ : (String) -> Bool,
  dispatch_text_input~ : (Int, String, Int, Int) -> Bool,
  dispatch_command~ : (Int) -> Bool,
  dispatch_accessibility~ : (Int, Int, String) -> Bool,
  complete_clipboard~ : (Int, Int, String, Bytes) -> Bool,
  complete_clipboard_v1~ : (Int, Int, Int, String, Bytes) -> Bool,
  attach_surface~ : (UInt64, Int, Int, Double) -> Bool,
  resize~ : (Int, Int, Double) -> Bool,
  dispatch_pointer~ : (Int, Double, Double, Double) -> Bool,
  dispatch_scroll~ : (Double, Double, Double, Double, Int) -> Bool,
  frame_tick~ : (Double) -> Bool,
  render_frame~ : () -> Bool,
  detach_surface~ : () -> Unit,
  destroy_application~ : () -> Unit,
) -> EmbeddingRuntimeCallbacks {
  {
    renderer_configure,
    renderer_status_json,
    take_host_updates_json,
    take_host_update_envelope_json,
    dispatch_host_response_envelope_json,
    dispatch_text_input,
    dispatch_command,
    dispatch_accessibility,
    complete_clipboard,
    complete_clipboard_v1,
    attach_surface,
    resize,
    dispatch_pointer,
    dispatch_scroll,
    frame_tick,
    render_frame,
    detach_surface,
    destroy_application,
  }
}

///|
let installed_embedding_runtime : Ref[EmbeddingRuntimeCallbacks?] = Ref(None)

///|
/// Replaces the process-local runtime target. Replacing an installed runtime
/// first destroys it, so a later ABI call cannot reach an abandoned MoUI
/// session.
pub fn install_runtime(callbacks : EmbeddingRuntimeCallbacks) -> Unit {
  match installed_embedding_runtime.val {
    Some(previous) => (previous.destroy_application)()
    None => ()
  }
  installed_embedding_runtime.val = Some(callbacks)
}

///|
pub fn runtime_installed() -> Bool {
  installed_embedding_runtime.val is Some(_)
}

///|
pub fn moui_embedding_renderer_configure(mode : String) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.renderer_configure)(mode)
    None => false
  }
}

///|
pub fn moui_embedding_renderer_status_json() -> String {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.renderer_status_json)()
    None => "{}"
  }
}

///|
pub fn moui_embedding_take_host_updates_json() -> String {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.take_host_updates_json)()
    None => "[]"
  }
}

///|
pub fn moui_embedding_take_host_update_envelope_json() -> String {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.take_host_update_envelope_json)()
    None => "{\"schemaVersion\":1,\"sessionGeneration\":0,\"updates\":[]}"
  }
}

///|
pub fn moui_embedding_dispatch_host_response_envelope_json(
  text : String,
) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.dispatch_host_response_envelope_json)(text)
    None => false
  }
}

///|
pub fn moui_embedding_dispatch_text_input(
  kind : Int,
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.dispatch_text_input)(kind, text, start, end)
    None => false
  }
}

///|
pub fn moui_embedding_dispatch_command(kind : Int) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.dispatch_command)(kind)
    None => false
  }
}

///|
pub fn moui_embedding_dispatch_accessibility(
  element_id : Int,
  action : Int,
  value : String,
) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) =>
      (callbacks.dispatch_accessibility)(element_id, action, value)
    None => false
  }
}

///|
pub fn moui_embedding_complete_clipboard(
  id : Int,
  kind : Int,
  text : String,
  bytes : Bytes,
) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.complete_clipboard)(id, kind, text, bytes)
    None => false
  }
}

///|
pub fn moui_embedding_complete_clipboard_v1(
  session_generation : Int,
  id : Int,
  kind : Int,
  text : String,
  bytes : Bytes,
) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) =>
      (callbacks.complete_clipboard_v1)(
        session_generation, id, kind, text, bytes,
      )
    None => false
  }
}

///|
pub fn moui_embedding_attach_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) =>
      (callbacks.attach_surface)(surface_handle, width, height, scale_factor)
    None => false
  }
}

///|
pub fn moui_embedding_resize(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.resize)(width, height, scale_factor)
    None => false
  }
}

///|
pub fn moui_embedding_dispatch_pointer(
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.dispatch_pointer)(phase, x, y, time_ms)
    None => false
  }
}

///|
pub fn moui_embedding_dispatch_scroll(
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  phase : Int,
) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) =>
      (callbacks.dispatch_scroll)(x, y, delta_x, delta_y, phase)
    None => false
  }
}

///|
pub fn moui_embedding_frame_tick(time_ms : Double) -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.frame_tick)(time_ms)
    None => false
  }
}

///|
pub fn moui_embedding_render_frame() -> Bool {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.render_frame)()
    None => false
  }
}

///|
pub fn moui_embedding_detach_surface() -> Unit {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.detach_surface)()
    None => ()
  }
}

///|
pub fn moui_embedding_destroy_application() -> Unit {
  match installed_embedding_runtime.val {
    Some(callbacks) => (callbacks.destroy_application)()
    None => ()
  }
  installed_embedding_runtime.val = None
}
