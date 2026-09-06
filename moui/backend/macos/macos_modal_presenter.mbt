///|
/// Native hooks for the macOS modal presenter. Production wires these to the
/// `moui_macos_present_modal_sheet` / `moui_macos_close_modal_sheet` externs;
/// headless tests inject fakes so the HostModalSession lifecycle stays fully
/// testable without a running NSApplication (matching-host GUI smoke
/// `macos.host-modal` evidences the real NSWindow sheet ordering).
pub struct MacosModalNativeHooks {
  priv present : (@host.HostModalRequest) -> @host.HostModalResult
  priv close : (String) -> Unit
}

///|
pub fn MacosModalNativeHooks::new(
  present~ : (@host.HostModalRequest) -> @host.HostModalResult,
  close~ : (String) -> Unit,
) -> MacosModalNativeHooks {
  { present, close }
}

///|
/// macOS NSWindow-level modal presenter (overlay plan slice 6). The neutral
/// `HostModalSession` owns exactly-once lifecycle and generation gating; this
/// presenter adapts it to the native sheet flow and reports the capability
/// that lets `PreferNative`/`NativeRequired` presentations skip the
/// view-level surface.
pub struct MacosModalPresenter {
  capabilities : @host.HostModalCapabilities
  priv hooks : MacosModalNativeHooks
}

///|
pub fn MacosModalPresenter::capabilities(
  self : MacosModalPresenter,
) -> @host.HostModalCapabilities {
  self.capabilities
}

///|
pub fn macos_host_modal_capabilities() -> @host.HostModalCapabilities {
  @host.HostModalCapabilities::full()
}

///|
fn macos_native_present(request : @host.HostModalRequest) -> @host.HostModalResult {
  // The native sheet leg is exercised by the matching-host smoke
  // (the macOS renderer smoke script, `--run-modal-smoke`). Headless runs
  // have no host window: report rejection so the presentation transparently
  // falls back to the view-level surface.
  let bounds = request.bounds()
  let accepted = macos_present_modal_sheet(
      bounds.origin.x,
      bounds.origin.y,
      bounds.size.width,
      bounds.size.height,
    ) == 1
  if accepted {
    @host.HostModalResult::Accepted
  } else {
    @host.HostModalResult::Rejected("no native host window")
  }
}

///|
fn macos_native_close(_presentation_id : String) -> Unit {
  macos_close_modal_sheet()
}

///|
/// Production presenter wired to the native sheet externs.
pub fn macos_modal_presenter() -> MacosModalPresenter {
  {
    capabilities: macos_host_modal_capabilities(),
    hooks: {
      present: macos_native_present,
      close: macos_native_close,
    },
  }
}

///|
/// Test/alternative-host constructor with explicit native hooks.
pub fn MacosModalPresenter::with_hooks(
  capabilities~ : @host.HostModalCapabilities = macos_host_modal_capabilities(),
  hooks~ : MacosModalNativeHooks,
) -> MacosModalPresenter {
  { capabilities, hooks }
}

///|
/// Present a host modal surface: begin the session, negotiate the native
/// sheet, and return every lifecycle event observed (Pending plus the
/// Accepted/Rejected decision). A rejected request leaves the session
/// terminal so the presentation falls back to the view-level path.
pub fn MacosModalPresenter::present(
  self : MacosModalPresenter,
  request : @host.HostModalRequest,
) -> (@host_modal.HostModalSession, Array[@host.HostModalEvent]) {
  let session = @host_modal.HostModalSession::new(request)
  let events : Array[@host.HostModalEvent] = [session.begin()]
  let decision = (self.hooks.present)(request)
  match session.apply_result(request.request_id(), request.generation(), decision) {
    Some(event) => events.push(event)
    None => ()
  }
  (session, events)
}

///|
/// Close the native sheet and settle the session. Duplicate and stale closes
/// are dropped by the session's exactly-once gate; the native side is asked
/// to close at most once per emitted close event.
pub fn MacosModalPresenter::close(
  self : MacosModalPresenter,
  session : @host_modal.HostModalSession,
) -> @host.HostModalEvent? {
  let event = session.close(
    session.request().request_id(),
    session.request().generation(),
  )
  match event {
    Some(_) => (self.hooks.close)(session.request().presentation_id())
    None => ()
  }
  event
}

///|
pub fn MacosModalPresenter::attach_surface(
  self : MacosModalPresenter,
  session : @host_modal.HostModalSession,
  token : String,
) -> @host.HostModalEvent? {
  session.attach_surface_event(token, session.request().generation())
}

///|
pub fn MacosModalPresenter::detach_surface(
  self : MacosModalPresenter,
  session : @host_modal.HostModalSession,
  token : String,
) -> @host.HostModalEvent? {
  session.detach_surface_event(token, session.request().generation())
}

///|
pub fn MacosModalPresenter::route_input(
  self : MacosModalPresenter,
  session : @host_modal.HostModalSession,
  event : @core.PointerEvent,
) -> @host.HostModalEvent? {
  session.route_input(
    session.request().request_id(),
    session.request().generation(),
    event,
  )
}
