///|
/// Browser-side platform canvases deliver neutral named events through this
/// export. The concrete addon owns the event vocabulary and decoding; the Web
/// backend only resolves the window and forwards the platform-view payload.
pub fn web_dispatch_platform_view_event(
  raw_id : Int,
  id_text_id : Int,
  name_text_id : Int,
  value_text_id : Int,
  detail_text_id : Int,
  flag : Bool,
) -> Unit {
  match web_active_app.val {
    Some(app) =>
      match
        app.lifecycle.lookup_window(@window_core.WindowId::from_raw(raw_id)) {
        Some(window_id) =>
          match app.lifecycle.runtime_slots().lookup(window_id) {
            Some(slot) =>
              slot.driver.dispatch_platform_view(
                web_host_string_from_id(id_text_id),
                @core.PlatformViewEvent::Named(
                  name=web_host_string_from_id(name_text_id),
                  value=web_host_string_from_id(value_text_id),
                  detail=web_host_string_from_id(detail_text_id),
                  flag~,
                ),
              )
            None => ()
          }
        None => ()
      }
    None => ()
  }
}
