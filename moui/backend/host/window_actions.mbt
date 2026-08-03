///|
/// App-facing capability for requesting host-managed windows.
///
/// The platform host owns draining the queue, resolving scenes, and creating
/// native windows. Apps describe the scene they want to open and can enqueue
/// lifecycle requests (`close` / `focus` / `set_primary`) by `HostWindowId`.
/// Requests remain fire-and-forget on the shared queue; hosts record
/// completions on the queue when they drain it.
pub struct HostWindowActions {
  queue : HostWindowRequestQueue
}

///|
pub fn HostWindowActions::new(
  queue? : HostWindowRequestQueue = HostWindowRequestQueue::new(),
) -> HostWindowActions {
  { queue, }
}

///|
pub fn HostWindowActions::unavailable() -> HostWindowActions {
  HostWindowActions::new()
}

///|
/// Shared request queue used by the host entrypoint. Prefer the typed helpers
/// below from app code; entrypoints may pass this queue into
/// `AppBuilder::window_requests`.
pub fn HostWindowActions::queue(
  self : HostWindowActions,
) -> HostWindowRequestQueue {
  self.queue
}

///|
pub fn HostWindowActions::open(
  self : HostWindowActions,
  title~ : String,
  scene? : HostWindowScene = HostWindowScene::main(),
  metrics~ : HostSurfaceMetrics,
  primary? : Bool = false,
) -> Unit {
  self.queue.open_window(title~, scene~, metrics~, primary~)
}

///|
/// Request that the host close the window identified by `id`.
pub fn HostWindowActions::close(
  self : HostWindowActions,
  id : HostWindowId,
) -> Unit {
  self.queue.close_window(id)
}

///|
/// Request that the host focus the window identified by `id`.
pub fn HostWindowActions::focus(
  self : HostWindowActions,
  id : HostWindowId,
) -> Unit {
  self.queue.focus_window(id)
}

///|
/// Request that the host treat `id` as the primary window.
pub fn HostWindowActions::set_primary(
  self : HostWindowActions,
  id : HostWindowId,
) -> Unit {
  self.queue.set_primary_window(id)
}

///|
/// Request a resize for the window identified by `id`.
pub fn HostWindowActions::resize(
  self : HostWindowActions,
  id : HostWindowId,
  metrics : HostSurfaceMetrics,
) -> Unit {
  self.queue.resize_window(id, metrics)
}

///|
/// Request that the host minimize the window identified by `id`.
pub fn HostWindowActions::minimize(
  self : HostWindowActions,
  id : HostWindowId,
) -> Unit {
  self.queue.minimize_window(id)
}

///|
/// Request that the host show the window identified by `id`.
pub fn HostWindowActions::show(
  self : HostWindowActions,
  id : HostWindowId,
) -> Unit {
  self.queue.show_window(id)
}
