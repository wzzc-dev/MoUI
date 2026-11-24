///|
/// File-backed state transport for the generated plugin. A missing path keeps
/// the transport inert, so an app without dev persistence still starts from
/// its own init model.
pub fn state_transport(path : String?) -> @core.ProgramStateTransport? {
  match path {
    Some(path) =>
      Some(
        @core.ProgramStateTransport::new(
          read=() => {
            if @fs.path_exists(path) {
              let bytes = @fs.read_file_to_bytes(path) catch {
                _ => return None
              }
              Some(@utf8.decode_lossy(bytes[:], ignore_bom=true))
            } else {
              None
            }
          },
          write=payload => {
            let bytes = @utf8.encode(payload[:], bom=false)
            @fs.write_bytes_to_file(path, bytes) catch {
              _ => return ()
            }
          },
        ),
      )
    None => None
  }
}

///|
/// Owns the app-layer runtime inside a plugin dylib. Only primitive JSON and
/// byte buffers cross the dylib boundary; the session runtime itself never
/// leaves this image.
pub struct Session {
  runtime : @runtime.AppRuntime
  transient_path : String?
}

///|
pub fn Session::new(
  runtime : @runtime.AppRuntime,
  transient_path : String?,
) -> Session {
  // The bridge host builds its accessibility tree and IME projection from the
  // committed semantics/text input carried on each frame, so the plugin opts
  // into the semantics frame payload for its whole lifetime.
  runtime.set_semantics_frames_enabled(true)
  { runtime, transient_path, }
}

///|
pub fn Session::dispatch_json(self : Session, payload : String) -> Bool {
  match @protocol.decode_event(payload) {
    Some(event) => {
      match event {
        @core.AppEvent::FrameTick(frame) => advance_hot_time(frame)
        _ => ()
      }
      self.runtime.dispatch_event(event)
      true
    }
    None => false
  }
}

///|
pub fn Session::frame_json(self : Session) -> String {
  let frame = self.runtime.draw_frame()
  @protocol.encode_frame(
    frame,
    text_input=Some(self.runtime.focused_text_input()),
  )
}

///|
/// Dispatch one semantics action decoded from the bridge. `None` means the
/// request itself was malformed and is reported as unavailable by the caller.
pub fn Session::semantics_action_json(
  self : Session,
  payload : String,
) -> Result[
  @runtime.SemanticsActionReceipt,
  @runtime.SemanticsActionDispatchError,
]? {
  match @protocol.decode_semantics_action_request(payload) {
    Some(request) => Some(self.runtime.perform_semantics_action(request))
    None => None
  }
}

///|
pub fn Session::flush(self : Session) -> Unit {
  match self.transient_path {
    Some(path) => {
      let payload = self.runtime.capture_dev_transient()
      let bytes = @utf8.encode(payload[:], bom=false)
      @fs.write_bytes_to_file(path, bytes) catch {
        _ => ()
      }
    }
    None => ()
  }
}

///|
pub fn Session::resize(self : Session, width : Double, height : Double) -> Unit {
  self.runtime.dispatch_event(
    @core.AppEvent::Resize(@core.Size::new(width~, height~)),
  )
}

///|
pub fn Session::destroy(self : Session) -> Unit {
  self.flush()
  self.runtime.destroy()
  // Timer callbacks close over the app program; drop them with the image.
  clear_hot_timers()
}
