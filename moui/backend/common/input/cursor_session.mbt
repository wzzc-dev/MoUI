///|
/// Per-window pointer-cursor dispatch state, the `TextInputSession` shape
/// applied to cursor projection.
///
/// The host must be told a cursor at most once per *change*: a pointer stream
/// that stays inside one `.cursor(...)` region produces a `Move` per sample, and
/// a native `set_cursor_icon` call per sample is exactly the waste the runtime
/// resolution is designed to avoid. Keeping the last pushed style here (one
/// entry per window, because the cursor is a per-window fact) turns that into a
/// plain compare.
///
/// New windows start at `Default`, the value a host already shows, so a window
/// that never declares a cursor performs zero native calls.
pub struct CursorSession {
  priv applied : Map[Int32, @core.CursorStyle]
}

///|
pub fn CursorSession::new() -> CursorSession {
  { applied: Map([], capacity=4), }
}

///|
/// Record `resolved` for one window and report whether the host must be told.
///
/// Returns the style to push, or `None` when the host already shows it.
pub fn CursorSession::sync(
  self : CursorSession,
  window : @backend_host.WindowId,
  resolved : @core.CursorStyle,
) -> @core.CursorStyle? {
  let key = window.value
  let previous = match self.applied.get(key) {
    Some(style) => style
    None => @core.CursorStyle::Default
  }
  if previous == resolved {
    None
  } else {
    self.applied[key] = resolved
    Some(resolved)
  }
}

///|
/// The style this session believes the host is showing for one window.
pub fn CursorSession::applied(
  self : CursorSession,
  window : @backend_host.WindowId,
) -> @core.CursorStyle {
  match self.applied.get(window.value) {
    Some(style) => style
    None => @core.CursorStyle::Default
  }
}

///|
/// Forget one window's entry. Called when the platform window is disposed so a
/// recycled window id does not inherit a stale style.
pub fn CursorSession::forget(
  self : CursorSession,
  window : @backend_host.WindowId,
) -> Unit {
  self.applied.remove(window.value)
}
