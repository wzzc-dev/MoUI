///|
/// Shared mutable surface metrics owner.
pub(all) struct SurfaceState {
  mut metrics : @core.SurfaceMetrics
  owns_surface : Bool
  can_reconfigure : Bool
}

///|
pub fn SurfaceState::new(
  metrics~ : @core.SurfaceMetrics,
  owns_surface? : Bool = false,
  can_reconfigure? : Bool = true,
) -> SurfaceState {
  { metrics, owns_surface, can_reconfigure }
}

///|
pub fn SurfaceState::resize(
  self : SurfaceState,
  metrics : @core.SurfaceMetrics,
) -> @backend_host.Event {
  self.metrics = metrics
  @backend_host.Event::Resized(metrics)
}

///|
pub fn SurfaceState::logical_size(self : SurfaceState) -> @core.Size {
  self.metrics.logical_size
}
