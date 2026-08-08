///|
/// App-facing capability for requesting host-managed windows.
///
/// The platform host owns draining the queue, resolving scenes, and creating
/// native windows. Apps describe the scene they want to open and can enqueue
/// lifecycle requests (`close` / `focus` / `set_primary`) by `@backend_host.WindowId`.
/// Requests remain fire-and-forget on the shared queue; hosts record
/// completions on the queue when they drain it.
pub struct WindowActions {
  queue : WindowRequestQueue
}

///|
pub fn WindowActions::new(
  queue? : WindowRequestQueue = WindowRequestQueue::new(),
) -> WindowActions {
  { queue, }
}

///|
pub fn WindowActions::unavailable() -> WindowActions {
  WindowActions::new()
}

///|
/// Shared request queue used by the host entrypoint. Prefer the typed helpers
/// below from app code; entrypoints may pass this queue into
/// `AppBuilder::window_requests`.
pub fn WindowActions::queue(self : WindowActions) -> WindowRequestQueue {
  self.queue
}

///|
pub fn WindowActions::open(
  self : WindowActions,
  title~ : String,
  scene? : @backend_host.WindowScene = @backend_host.WindowScene::main(),
  metrics~ : @core.SurfaceMetrics,
  primary? : Bool = false,
) -> Unit {
  self.queue.open_window(title~, scene~, metrics~, primary~)
}

///|
/// Request that the host close the window identified by `id`.
pub fn WindowActions::close(
  self : WindowActions,
  id : @backend_host.WindowId,
) -> Unit {
  self.queue.close_window(id)
}

///|
/// Request that the host focus the window identified by `id`.
pub fn WindowActions::focus(
  self : WindowActions,
  id : @backend_host.WindowId,
) -> Unit {
  self.queue.focus_window(id)
}

///|
/// Request that the host treat `id` as the primary window.
pub fn WindowActions::set_primary(
  self : WindowActions,
  id : @backend_host.WindowId,
) -> Unit {
  self.queue.set_primary_window(id)
}

///|
/// Request a resize for the window identified by `id`.
pub fn WindowActions::resize(
  self : WindowActions,
  id : @backend_host.WindowId,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  self.queue.resize_window(id, metrics)
}

///|
/// Request that the host minimize the window identified by `id`.
pub fn WindowActions::minimize(
  self : WindowActions,
  id : @backend_host.WindowId,
) -> Unit {
  self.queue.minimize_window(id)
}

///|
/// Request that the host show the window identified by `id`.
pub fn WindowActions::show(
  self : WindowActions,
  id : @backend_host.WindowId,
) -> Unit {
  self.queue.show_window(id)
}
