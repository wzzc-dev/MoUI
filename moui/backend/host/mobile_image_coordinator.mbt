///|
pub(all) struct MobileImageFrameObservation {
  present_count : Int
  loading_count : Int
  ready_count : Int
  failed_count : Int
  scheduled_count : Int
}

///|
pub struct MobileImageCoordinator {
  window_id : HostWindowId
  renderer : HostWindowRenderer
  tracker : HostImageResourceRepaintTracker
  completion_source : HostImageResourceCompletionSource
  loader : HostAsyncImageLoader?
  window_open : Ref[Bool]
}

///|
pub fn MobileImageCoordinator::new(
  renderer~ : HostWindowRenderer,
  image_loader~ : HostAsyncImageLoader?,
  request_redraw~ : () -> Unit,
) -> MobileImageCoordinator {
  let window_id = HostWindowId::new(1)
  let tracker = HostImageResourceRepaintTracker::new()
  let window_open = Ref(true)
  let completion_source = HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => window_open.val && id == window_id,
    request_redraw=_id => request_redraw(),
  )
  {
    window_id,
    renderer,
    tracker,
    completion_source,
    loader: image_loader,
    window_open,
  }
}

///|
pub fn MobileImageCoordinator::after_present(
  self : MobileImageCoordinator,
  present_count~ : Int,
) -> MobileImageFrameObservation {
  let baseline = self.tracker.record_presented(self.window_id, self.renderer)
  let counts = baseline.current_status_counts()
  let scheduled_count = match self.loader {
    Some(loader) =>
      loader
      .schedule_loading_resources(
        self.window_id,
        self.renderer,
        self.completion_source,
      )
      .scheduled_count()
    None => 0
  }
  {
    present_count,
    loading_count: counts.loading_count(),
    ready_count: counts.ready_count(),
    failed_count: counts.failed_count(),
    scheduled_count,
  }
}

///|
pub fn MobileImageCoordinator::dispose(self : MobileImageCoordinator) -> Unit {
  if self.window_open.val {
    self.window_open.val = false
    match self.loader {
      Some(loader) => ignore(loader.cancel_window(self.window_id))
      None => ()
    }
    ignore(self.tracker.remove_window(self.window_id))
  }
}
