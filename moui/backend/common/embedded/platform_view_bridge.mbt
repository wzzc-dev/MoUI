///|
pub fn EmbeddedRuntimeHostBridge::sync_platform_views(
  self : EmbeddedRuntimeHostBridge,
  placements : Array[@core.PlatformViewPlacement],
) -> Bool {
  if self.disposed || placements == self.last_platform_views {
    false
  } else {
    self.platform_view_revision = self.platform_view_revision + 1
    self.last_platform_views = placements.copy()
    self.updates.push(
      EmbeddedHostUpdate::PlatformViews({
        revision: self.platform_view_revision,
        placements: placements.copy(),
      }),
    )
    true
  }
}

///|
fn EmbeddedRuntimeHostBridge::dispatch_platform_view_response(
  self : EmbeddedRuntimeHostBridge,
  revision : Int,
  kind : String,
  id : String,
  event : @core.PlatformViewEvent,
  driver : @runtime.HostRuntimeDriver,
) -> Bool {
  if revision != self.platform_view_revision ||
    !self.last_platform_views.any(placement => {
      placement.kind == kind && placement.id == id
    }) {
    false
  } else {
    driver.dispatch_platform_view(id, event)
    true
  }
}
