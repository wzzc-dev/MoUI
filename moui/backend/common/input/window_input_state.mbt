///|
/// Window input owner for cross-platform subscriptions and the active IME
/// session. Raw native decoding remains in concrete backends.
pub struct WindowInputState {
  priv session : TextInputSession
  priv cursor : CursorSession
  priv event_sources : @apphost.HostPlatformEventSources?
}

///|
pub fn WindowInputState::new(
  event_sources~ : @apphost.HostPlatformEventSources? = None,
) -> WindowInputState {
  {
    session: TextInputSession::new(),
    cursor: CursorSession::new(),
    event_sources,
  }
}

///|
pub fn WindowInputState::sync(
  self : WindowInputState,
  state : @core.TextInputState,
) -> TextInputSessionAction {
  self.session.sync(state)
}

///|
/// Record a resolved pointer cursor for one window and report whether the host
/// must be told. See `CursorSession::sync`.
pub fn WindowInputState::sync_cursor(
  self : WindowInputState,
  window : @backend_host.WindowId,
  resolved : @core.CursorStyle,
) -> @core.CursorStyle? {
  self.cursor.sync(window, resolved)
}

///|
/// The cursor style this host last pushed for one window.
pub fn WindowInputState::applied_cursor(
  self : WindowInputState,
  window : @backend_host.WindowId,
) -> @core.CursorStyle {
  self.cursor.applied(window)
}

///|
/// Drop one window's cursor record after its platform window is disposed.
pub fn WindowInputState::forget_cursor(
  self : WindowInputState,
  window : @backend_host.WindowId,
) -> Unit {
  self.cursor.forget(window)
}

///|
pub fn WindowInputState::last_diagnostics(
  self : WindowInputState,
) -> TextInputImeRequestDiagnostics? {
  self.session.last_diagnostics()
}

///|
pub fn WindowInputState::publish(
  self : WindowInputState,
  window_id : @backend_host.WindowId,
  event : @backend_host.Event,
) -> @apphost.HostPlatformEventPublishResult? {
  match self.event_sources {
    Some(sources) => Some(sources.publish(window_id~, event~))
    None => None
  }
}
