///|
pub struct HostWindowCommands {
  queue : HostWindowRequestQueue
}

///|
pub fn HostWindowCommands::new(
  queue? : HostWindowRequestQueue = HostWindowRequestQueue::new(),
) -> HostWindowCommands {
  { queue, }
}

///|
pub fn HostWindowCommands::queue(
  self : HostWindowCommands,
) -> HostWindowRequestQueue {
  self.queue
}

///|
pub fn HostWindowCommands::pending_count(self : HostWindowCommands) -> Int {
  self.queue.pending_count()
}

///|
pub fn HostWindowCommands::completed_count(self : HostWindowCommands) -> Int {
  self.queue.completed_count()
}

///|
pub fn HostWindowCommands::is_empty(self : HostWindowCommands) -> Bool {
  self.queue.is_empty()
}

///|
pub fn HostWindowCommands::open_window(
  self : HostWindowCommands,
  request : HostWindowOpenRequest,
) -> Unit {
  self.queue.push(HostWindowRequest::OpenWindow(request))
}

///|
pub fn HostWindowCommands::open(
  self : HostWindowCommands,
  title~ : String,
  scene? : HostWindowScene = HostWindowScene::main(),
  metrics~ : HostSurfaceMetrics,
  primary? : Bool = false,
) -> Unit {
  self.open_window(
    HostWindowOpenRequest::new(title~, scene~, metrics~, primary~),
  )
}

///|
pub fn HostWindowCommands::focus(
  self : HostWindowCommands,
  id : HostWindowId,
) -> Unit {
  self.queue.focus_window(id)
}

///|
pub fn HostWindowCommands::resize(
  self : HostWindowCommands,
  id : HostWindowId,
  metrics : HostSurfaceMetrics,
) -> Unit {
  self.queue.resize_window(id, metrics)
}

///|
pub fn HostWindowCommands::minimize(
  self : HostWindowCommands,
  id : HostWindowId,
) -> Unit {
  self.queue.minimize_window(id)
}

///|
pub fn HostWindowCommands::show(
  self : HostWindowCommands,
  id : HostWindowId,
) -> Unit {
  self.queue.show_window(id)
}

///|
pub fn HostWindowCommands::close(
  self : HostWindowCommands,
  id : HostWindowId,
) -> Unit {
  self.queue.close_window(id)
}

///|
pub fn HostWindowCommands::set_primary(
  self : HostWindowCommands,
  id : HostWindowId,
) -> Unit {
  self.queue.set_primary_window(id)
}

///|
pub fn HostWindowCommands::drain(
  self : HostWindowCommands,
) -> Array[HostWindowRequest] {
  self.queue.drain()
}

///|
pub fn HostWindowCommands::record_result(
  self : HostWindowCommands,
  request : HostWindowRequest,
  result : HostWindowRequestResult,
) -> Unit {
  self.queue.record_result(request, result)
}

///|
pub fn HostWindowCommands::drain_with_handler(
  self : HostWindowCommands,
  handle : (HostWindowRequest) -> HostWindowRequestResult,
) -> Array[HostWindowRequestCompletion] {
  self.queue.drain_with_handler(handle)
}

///|
pub fn HostWindowCommands::drain_to_registry(
  self : HostWindowCommands,
  registry : HostWindowRegistry,
) -> Array[HostWindowRequestCompletion] {
  self.drain_with_handler(request => registry.apply_request(request))
}

///|
pub fn HostWindowCommands::drain_to_runtime_slots(
  self : HostWindowCommands,
  registry : HostWindowRegistry,
  slots : HostWindowRuntimeSlots,
) -> Array[HostWindowRequestCompletion] {
  self.drain_with_handler(request => slots.apply_request(registry, request))
}

///|
pub fn HostWindowCommands::drain_completed(
  self : HostWindowCommands,
) -> Array[HostWindowRequestCompletion] {
  self.queue.drain_completed()
}
