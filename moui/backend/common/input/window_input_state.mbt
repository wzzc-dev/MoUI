///|
/// Window input owner for cross-platform subscriptions and the active IME
/// session. Raw native decoding remains in concrete backends.
pub struct WindowInputState {
  priv session : TextInputSession
  priv event_sources : @runtime.HostPlatformEventSources?
}

///|
pub fn WindowInputState::new(
  event_sources? : @runtime.HostPlatformEventSources? = None,
) -> WindowInputState {
  { session: TextInputSession::new(), event_sources }
}

///|
pub fn WindowInputState::sync(
  self : WindowInputState,
  state : @core.TextInputState,
) -> TextInputSessionAction {
  self.session.sync(state)
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
) -> @runtime.HostPlatformEventPublishResult? {
  match self.event_sources {
    Some(sources) => Some(sources.publish(window_id~, event~))
    None => None
  }
}
