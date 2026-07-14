///|
/// App-facing capability for requesting host-managed windows.
///
/// The platform host owns draining the queue, resolving scenes, and creating
/// native windows. Apps only describe the scene they want to open.
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
pub fn HostWindowActions::open(
  self : HostWindowActions,
  title~ : String,
  scene? : HostWindowScene = HostWindowScene::main(),
  metrics~ : HostSurfaceMetrics,
  primary? : Bool = false,
) -> Unit {
  self.queue.open_window(title~, scene~, metrics~, primary~)
}
