///|
/// Shared desktop host-backend skeleton (ADR 0018/0020). Platform backends
/// keep native event-loop creation, window creation, and decode; the
/// platform-view plugin wiring and first-frame smoke auto-exit blocks are
/// shared so the three desktop backends cannot drift.
///|
/// Install platform-view event dispatchers at app startup.
pub fn install_platform_view_plugins(
  plugins : Array[@backend_host.PlatformViewPlugin],
  dispatch : @backend_host.PlatformViewEventCallback,
) -> Unit {
  for plugin in plugins {
    (plugin.install_event_dispatcher)(dispatch)
  }
}

///|
/// Sync platform views and drain their queued commands during a redraw.
pub fn sync_platform_view_plugins(
  plugins : Array[@backend_host.PlatformViewPlugin],
  handle : UInt64,
  frame : @core.DrawFrame,
  content_offset~ : Double = 0.0,
) -> Unit {
  for plugin in plugins {
    (plugin.sync_platform_views)(handle, frame, content_offset)
    (plugin.drain_commands)(handle)
  }
}

///|
/// Finish a first-frame smoke auto-exit: print the platform marker, then run
/// the backend cleanup (clear the flag, dispose the window). Returns `true`
/// when the smoke flag was set so the caller can report completion.
pub fn finish_first_frame_smoke_auto_exit(
  platform_name~ : String,
  title~ : String,
  flag~ : Bool,
  finish~ : () -> Unit,
) -> Bool {
  if flag {
    println(
      platform_name + " renderer presented first frame; exiting by request; title=" + title,
    )
    finish()
    true
  } else {
    false
  }
}
