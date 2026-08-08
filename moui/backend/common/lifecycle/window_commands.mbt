///|
pub struct WindowCommands {
  queue : WindowRequestQueue
}

///|
pub fn WindowCommands::new(
  queue? : WindowRequestQueue = WindowRequestQueue::new(),
) -> WindowCommands {
  { queue, }
}

///|
pub fn WindowCommands::queue(self : WindowCommands) -> WindowRequestQueue {
  self.queue
}

///|
pub fn WindowCommands::pending_count(self : WindowCommands) -> Int {
  self.queue.pending_count()
}

///|
pub fn WindowCommands::completed_count(self : WindowCommands) -> Int {
  self.queue.completed_count()
}

///|
pub fn WindowCommands::is_empty(self : WindowCommands) -> Bool {
  self.queue.is_empty()
}

///|
pub fn WindowCommands::open_window(
  self : WindowCommands,
  request : @backend_host.WindowOpenRequest,
) -> Unit {
  self.queue.push(@backend_host.WindowRequest::OpenWindow(request))
}

///|
pub fn WindowCommands::open(
  self : WindowCommands,
  title~ : String,
  scene? : @backend_host.WindowScene = @backend_host.WindowScene::main(),
  metrics~ : @core.SurfaceMetrics,
  primary? : Bool = false,
) -> Unit {
  self.open_window(
    @backend_host.WindowOpenRequest::new(title~, scene~, metrics~, primary~),
  )
}

///|
pub fn WindowCommands::focus(
  self : WindowCommands,
  id : @backend_host.WindowId,
) -> Unit {
  self.queue.focus_window(id)
}

///|
pub fn WindowCommands::resize(
  self : WindowCommands,
  id : @backend_host.WindowId,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  self.queue.resize_window(id, metrics)
}

///|
pub fn WindowCommands::minimize(
  self : WindowCommands,
  id : @backend_host.WindowId,
) -> Unit {
  self.queue.minimize_window(id)
}

///|
pub fn WindowCommands::show(
  self : WindowCommands,
  id : @backend_host.WindowId,
) -> Unit {
  self.queue.show_window(id)
}

///|
pub fn WindowCommands::close(
  self : WindowCommands,
  id : @backend_host.WindowId,
) -> Unit {
  self.queue.close_window(id)
}

///|
pub fn WindowCommands::set_primary(
  self : WindowCommands,
  id : @backend_host.WindowId,
) -> Unit {
  self.queue.set_primary_window(id)
}

///|
pub fn WindowCommands::drain(
  self : WindowCommands,
) -> Array[@backend_host.WindowRequest] {
  self.queue.drain()
}

///|
pub fn WindowCommands::record_result(
  self : WindowCommands,
  request : @backend_host.WindowRequest,
  result : @backend_host.WindowRequestResult,
) -> Unit {
  self.queue.record_result(request, result)
}

///|
pub fn WindowCommands::drain_with_handler(
  self : WindowCommands,
  handle : (@backend_host.WindowRequest) -> @backend_host.WindowRequestResult,
) -> Array[@backend_host.WindowRequestCompletion] {
  self.queue.drain_with_handler(handle)
}

///|
pub fn WindowCommands::drain_to_registry(
  self : WindowCommands,
  registry : WindowRegistry,
) -> Array[@backend_host.WindowRequestCompletion] {
  self.drain_with_handler(request => registry.apply_request(request))
}

///|
pub fn WindowCommands::drain_completed(
  self : WindowCommands,
) -> Array[@backend_host.WindowRequestCompletion] {
  self.queue.drain_completed()
}
