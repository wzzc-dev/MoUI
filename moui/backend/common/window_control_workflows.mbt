///|
/// Host workflow: turn app-declared window-control intents into logical window
/// requests, then mirror the resulting window state back to the app.
///
/// Runs on the host's own tick: the app only records intent (invariants P5/P10),
/// the host owns the native projection, and the observed state the chrome reads
/// comes from the registry record that the request path already updates. A
/// window that is not open yet keeps its intents queued in the source, so an
/// early `maximize()` from `init` is applied on a later frame instead of being
/// dropped.
pub fn apply_window_control_requests(
  source : @services.WindowControlSource,
  lifecycle : @window_lifecycle.WindowLifecycle,
  id : @backend_host.WindowId,
) -> Unit {
  for request in source.drain() {
    let queue = lifecycle.requests()
    match request {
      @services.WindowControlRequest::Minimize => queue.push(MinimizeWindow(id))
      @services.WindowControlRequest::Maximize => queue.push(MaximizeWindow(id))
      @services.WindowControlRequest::Restore => queue.push(RestoreWindow(id))
      @services.WindowControlRequest::ToggleFullscreen => {
        let fullscreen = match lifecycle.window_registry().lookup(id) {
          Some(record) => !record.fullscreen
          None => true
        }
        queue.push(SetFullscreenWindow(id, fullscreen))
      }
      @services.WindowControlRequest::SetFullscreen(fullscreen) =>
        queue.push(SetFullscreenWindow(id, fullscreen))
      @services.WindowControlRequest::SetDecorations(decorations) =>
        queue.push(SetDecorationsWindow(id, decorations))
    }
  }
  // Mirror what the lifecycle record now says, so app chrome repaints from the
  // same state the platform was asked for.
  match lifecycle.window_registry().lookup(id) {
    Some(record) =>
      source.set_observed(
        maximized=record.maximized,
        fullscreen=record.fullscreen,
      )
    None => ()
  }
}

///|
/// Tick helper for platform backends: publish this host's window-control
/// capabilities, then forward any pending app intents for the active window.
///
/// Capabilities are re-published every tick on purpose — `set_capabilities`
/// dedupes, and a window can appear after the first tick, so a single startup
/// publish would race the primary window's creation.
pub fn sync_window_controls(
  source : @services.WindowControlSource?,
  lifecycle : @window_lifecycle.WindowLifecycle,
  capabilities : @services.WindowControlCapabilities,
) -> Unit {
  match source {
    Some(source) => {
      source.set_capabilities(capabilities)
      match lifecycle.active_runtime_slot() {
        Some(slot) => apply_window_control_requests(source, lifecycle, slot.id)
        None => ()
      }
    }
    None => ()
  }
}
