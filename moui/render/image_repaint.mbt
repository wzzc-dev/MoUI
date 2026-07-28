///|
pub(all) enum HostImageResourceRepaintStatus {
  ImageRepaintRecorded
  ImageRepaintUnchanged
  ImageRepaintRequested
  ImageRepaintDiscardedClosed
} derive(Eq, Debug, ToJson)

///|
pub struct HostImageResourceRepaintResult {
  priv window_id : RenderWindowId
  priv previous_revision : Int
  priv current_revision : Int
  priv previous_status_counts : HostImageResourceStatusCounts
  priv current_status_counts : HostImageResourceStatusCounts
  priv status : HostImageResourceRepaintStatus
} derive(Eq, Debug, ToJson)

///|
pub struct HostImageResourceStatusCounts {
  priv record_count : Int
  priv loading_count : Int
  priv ready_count : Int
  priv failed_count : Int
  priv disposed_count : Int
} derive(Eq, Debug, ToJson)

///|
pub struct HostImageResourceTrackedWindow {
  priv window_id : RenderWindowId
  priv revision : Int
  priv status_counts : HostImageResourceStatusCounts
} derive(Eq, Debug, ToJson)

///|
pub struct HostImageResourceRepaintSnapshot {
  priv tracked_window_count : Int
  priv tracked_windows : Array[HostImageResourceTrackedWindow]
} derive(Eq, Debug, ToJson)

///|
pub struct HostImageResourceCompletionSourceDiagnostics {
  priv publish_count : Int
  priv recorded_count : Int
  priv redraw_requested_count : Int
  priv unchanged_count : Int
  priv discarded_closed_count : Int
  priv tracked_window_count : Int
} derive(Eq, Debug, ToJson)

///|
pub struct HostAsyncImageLoadScheduleResult {
  priv window_id : RenderWindowId
  priv snapshot_revision : Int
  priv loading_count : Int
  priv scheduled_count : Int
  priv already_in_flight_count : Int
} derive(Eq, Debug, ToJson)

///|
pub struct HostAsyncImageLoaderDiagnostics {
  priv scheduled_count : Int
  priv completed_count : Int
  priv cancelled_count : Int
  priv already_in_flight_count : Int
  priv in_flight_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostNativeAsyncImageCompletionStatus {
  NativeAsyncImageCompletionDelivered
  NativeAsyncImageCompletionMissing
} derive(Eq, Debug, ToJson)

///|
pub struct HostNativeAsyncImageLoadRequest {
  priv window_id : RenderWindowId
  priv source : String
} derive(Eq, Debug, ToJson)

///|
pub struct HostNativeAsyncImageCompletionResult {
  priv window_id : RenderWindowId
  priv source : String
  priv status : HostNativeAsyncImageCompletionStatus
} derive(Eq, Debug, ToJson)

///|
pub struct HostNativeAsyncImageSourceDiagnostics {
  priv requested_count : Int
  priv completed_count : Int
  priv cancelled_count : Int
  priv missing_completion_count : Int
  priv pending_count : Int
} derive(Eq, Debug, ToJson)

///|
pub fn HostImageResourceRepaintResult::window_id(
  self : HostImageResourceRepaintResult,
) -> RenderWindowId {
  self.window_id
}

///|
pub fn HostImageResourceRepaintResult::previous_revision(
  self : HostImageResourceRepaintResult,
) -> Int {
  self.previous_revision
}

///|
pub fn HostImageResourceRepaintResult::current_revision(
  self : HostImageResourceRepaintResult,
) -> Int {
  self.current_revision
}

///|
pub fn HostImageResourceRepaintResult::previous_status_counts(
  self : HostImageResourceRepaintResult,
) -> HostImageResourceStatusCounts {
  self.previous_status_counts
}

///|
pub fn HostImageResourceRepaintResult::current_status_counts(
  self : HostImageResourceRepaintResult,
) -> HostImageResourceStatusCounts {
  self.current_status_counts
}

///|
pub fn HostImageResourceRepaintResult::status(
  self : HostImageResourceRepaintResult,
) -> HostImageResourceRepaintStatus {
  self.status
}

///|
pub fn HostImageResourceStatusCounts::record_count(
  self : HostImageResourceStatusCounts,
) -> Int {
  self.record_count
}

///|
pub fn HostImageResourceStatusCounts::loading_count(
  self : HostImageResourceStatusCounts,
) -> Int {
  self.loading_count
}

///|
pub fn HostImageResourceStatusCounts::ready_count(
  self : HostImageResourceStatusCounts,
) -> Int {
  self.ready_count
}

///|
pub fn HostImageResourceStatusCounts::failed_count(
  self : HostImageResourceStatusCounts,
) -> Int {
  self.failed_count
}

///|
pub fn HostImageResourceStatusCounts::disposed_count(
  self : HostImageResourceStatusCounts,
) -> Int {
  self.disposed_count
}

///|
pub fn HostImageResourceTrackedWindow::window_id(
  self : HostImageResourceTrackedWindow,
) -> RenderWindowId {
  self.window_id
}

///|
pub fn HostImageResourceTrackedWindow::revision(
  self : HostImageResourceTrackedWindow,
) -> Int {
  self.revision
}

///|
pub fn HostImageResourceTrackedWindow::status_counts(
  self : HostImageResourceTrackedWindow,
) -> HostImageResourceStatusCounts {
  self.status_counts
}

///|
pub fn HostImageResourceRepaintSnapshot::tracked_window_count(
  self : HostImageResourceRepaintSnapshot,
) -> Int {
  self.tracked_window_count
}

///|
pub fn HostImageResourceRepaintSnapshot::tracked_windows(
  self : HostImageResourceRepaintSnapshot,
) -> Array[HostImageResourceTrackedWindow] {
  self.tracked_windows
}

///|
pub fn HostImageResourceCompletionSourceDiagnostics::publish_count(
  self : HostImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.publish_count
}

///|
pub fn HostImageResourceCompletionSourceDiagnostics::recorded_count(
  self : HostImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.recorded_count
}

///|
pub fn HostImageResourceCompletionSourceDiagnostics::redraw_requested_count(
  self : HostImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.redraw_requested_count
}

///|
pub fn HostImageResourceCompletionSourceDiagnostics::unchanged_count(
  self : HostImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.unchanged_count
}

///|
pub fn HostImageResourceCompletionSourceDiagnostics::discarded_closed_count(
  self : HostImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.discarded_closed_count
}

///|
pub fn HostImageResourceCompletionSourceDiagnostics::tracked_window_count(
  self : HostImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.tracked_window_count
}

///|
pub fn HostAsyncImageLoadScheduleResult::window_id(
  self : HostAsyncImageLoadScheduleResult,
) -> RenderWindowId {
  self.window_id
}

///|
pub fn HostAsyncImageLoadScheduleResult::snapshot_revision(
  self : HostAsyncImageLoadScheduleResult,
) -> Int {
  self.snapshot_revision
}

///|
pub fn HostAsyncImageLoadScheduleResult::loading_count(
  self : HostAsyncImageLoadScheduleResult,
) -> Int {
  self.loading_count
}

///|
pub fn HostAsyncImageLoadScheduleResult::scheduled_count(
  self : HostAsyncImageLoadScheduleResult,
) -> Int {
  self.scheduled_count
}

///|
pub fn HostAsyncImageLoadScheduleResult::already_in_flight_count(
  self : HostAsyncImageLoadScheduleResult,
) -> Int {
  self.already_in_flight_count
}

///|
pub fn HostAsyncImageLoaderDiagnostics::scheduled_count(
  self : HostAsyncImageLoaderDiagnostics,
) -> Int {
  self.scheduled_count
}

///|
pub fn HostAsyncImageLoaderDiagnostics::completed_count(
  self : HostAsyncImageLoaderDiagnostics,
) -> Int {
  self.completed_count
}

///|
pub fn HostAsyncImageLoaderDiagnostics::cancelled_count(
  self : HostAsyncImageLoaderDiagnostics,
) -> Int {
  self.cancelled_count
}

///|
pub fn HostAsyncImageLoaderDiagnostics::already_in_flight_count(
  self : HostAsyncImageLoaderDiagnostics,
) -> Int {
  self.already_in_flight_count
}

///|
pub fn HostAsyncImageLoaderDiagnostics::in_flight_count(
  self : HostAsyncImageLoaderDiagnostics,
) -> Int {
  self.in_flight_count
}

///|
pub fn HostNativeAsyncImageLoadRequest::window_id(
  self : HostNativeAsyncImageLoadRequest,
) -> RenderWindowId {
  self.window_id
}

///|
pub fn HostNativeAsyncImageLoadRequest::source(
  self : HostNativeAsyncImageLoadRequest,
) -> String {
  self.source
}

///|
pub fn HostNativeAsyncImageCompletionResult::window_id(
  self : HostNativeAsyncImageCompletionResult,
) -> RenderWindowId {
  self.window_id
}

///|
pub fn HostNativeAsyncImageCompletionResult::source(
  self : HostNativeAsyncImageCompletionResult,
) -> String {
  self.source
}

///|
pub fn HostNativeAsyncImageCompletionResult::status(
  self : HostNativeAsyncImageCompletionResult,
) -> HostNativeAsyncImageCompletionStatus {
  self.status
}

///|
pub fn HostNativeAsyncImageSourceDiagnostics::requested_count(
  self : HostNativeAsyncImageSourceDiagnostics,
) -> Int {
  self.requested_count
}

///|
pub fn HostNativeAsyncImageSourceDiagnostics::completed_count(
  self : HostNativeAsyncImageSourceDiagnostics,
) -> Int {
  self.completed_count
}

///|
pub fn HostNativeAsyncImageSourceDiagnostics::cancelled_count(
  self : HostNativeAsyncImageSourceDiagnostics,
) -> Int {
  self.cancelled_count
}

///|
pub fn HostNativeAsyncImageSourceDiagnostics::missing_completion_count(
  self : HostNativeAsyncImageSourceDiagnostics,
) -> Int {
  self.missing_completion_count
}

///|
pub fn HostNativeAsyncImageSourceDiagnostics::pending_count(
  self : HostNativeAsyncImageSourceDiagnostics,
) -> Int {
  self.pending_count
}

///|
pub struct HostImageResourceRepaintTracker {
  priv mut window_ids : Array[RenderWindowId]
  priv mut revisions : Array[Int]
  priv mut status_counts : Array[HostImageResourceStatusCounts]
}

///|
pub struct HostImageResourceCompletionSource {
  priv tracker : HostImageResourceRepaintTracker
  priv window_open_fn : (RenderWindowId) -> Bool
  priv request_redraw_fn : (RenderWindowId) -> Unit
  priv mut publish_count : Int
  priv mut recorded_count : Int
  priv mut redraw_requested_count : Int
  priv mut unchanged_count : Int
  priv mut discarded_closed_count : Int
}

///|
priv struct HostAsyncImageLoadInFlight {
  window_id : RenderWindowId
  source : String
  cancel : (() -> Unit)?
}

///|
priv struct HostNativeAsyncImageLoadPending {
  window_id : RenderWindowId
  source : String
  complete : (ImageResourceLoadCompletion) -> Unit
}

///|
pub struct HostAsyncImageLoader {
  priv start_load_fn : (
    RenderWindowId,
    String,
    (ImageResourceLoadCompletion) -> Unit,
  ) -> (() -> Unit)?
  priv drain_fn : () -> Unit
  priv mut in_flight : Array[HostAsyncImageLoadInFlight]
  priv mut scheduled_count : Int
  priv mut completed_count : Int
  priv mut cancelled_count : Int
  priv mut already_in_flight_count : Int
}

///|
pub struct HostNativeAsyncImageSource {
  priv mut pending : Array[HostNativeAsyncImageLoadPending]
  priv mut requested_count : Int
  priv mut completed_count : Int
  priv mut cancelled_count : Int
  priv mut missing_completion_count : Int
}

///|
pub fn HostImageResourceCompletionSource::new(
  tracker~ : HostImageResourceRepaintTracker,
  window_open~ : (RenderWindowId) -> Bool,
  request_redraw~ : (RenderWindowId) -> Unit,
) -> HostImageResourceCompletionSource {
  {
    tracker,
    window_open_fn: window_open,
    request_redraw_fn: request_redraw,
    publish_count: 0,
    recorded_count: 0,
    redraw_requested_count: 0,
    unchanged_count: 0,
    discarded_closed_count: 0,
  }
}

///|
pub fn HostAsyncImageLoader::new(
  start_load~ : (
    RenderWindowId,
    String,
    (ImageResourceLoadCompletion) -> Unit,
  ) -> (() -> Unit)?,
) -> HostAsyncImageLoader {
  {
    start_load_fn: start_load,
    drain_fn: fn() { () },
    in_flight: [],
    scheduled_count: 0,
    completed_count: 0,
    cancelled_count: 0,
    already_in_flight_count: 0,
  }
}

///|
pub fn HostAsyncImageLoader::new_with_drain(
  start_load~ : (
    RenderWindowId,
    String,
    (ImageResourceLoadCompletion) -> Unit,
  ) -> (() -> Unit)?,
  drain~ : () -> Unit,
) -> HostAsyncImageLoader {
  {
    start_load_fn: start_load,
    drain_fn: drain,
    in_flight: [],
    scheduled_count: 0,
    completed_count: 0,
    cancelled_count: 0,
    already_in_flight_count: 0,
  }
}

///|
pub fn HostNativeAsyncImageSource::new() -> HostNativeAsyncImageSource {
  {
    pending: [],
    requested_count: 0,
    completed_count: 0,
    cancelled_count: 0,
    missing_completion_count: 0,
  }
}

///|
pub fn HostNativeAsyncImageSource::loader(
  self : HostNativeAsyncImageSource,
) -> HostAsyncImageLoader {
  HostAsyncImageLoader::new(start_load=(window_id, source, complete) => {
    self.register(window_id, source, complete)
    Some(() => ignore(self.cancel(window_id, source)))
  })
}

///|
pub fn HostNativeAsyncImageSource::loader_with_drain(
  self : HostNativeAsyncImageSource,
  spawn~ : (RenderWindowId, String) -> Unit,
  drain~ : () -> Unit,
) -> HostAsyncImageLoader {
  HostAsyncImageLoader::new_with_drain(
    start_load=(window_id, source, complete) => {
      self.register(window_id, source, complete)
      spawn(window_id, source)
      Some(() => ignore(self.cancel(window_id, source)))
    },
    drain~,
  )
}

///|
pub fn HostNativeAsyncImageSource::pending_requests(
  self : HostNativeAsyncImageSource,
) -> Array[HostNativeAsyncImageLoadRequest] {
  let requests : Array[HostNativeAsyncImageLoadRequest] = []
  for entry in self.pending {
    requests.push({ window_id: entry.window_id, source: entry.source })
  }
  requests
}

///|
pub fn HostNativeAsyncImageSource::complete(
  self : HostNativeAsyncImageSource,
  window_id : RenderWindowId,
  completion : ImageResourceLoadCompletion,
) -> HostNativeAsyncImageCompletionResult {
  match self.remove_pending(window_id, completion.source) {
    Some(entry) => {
      self.completed_count = self.completed_count + 1
      (entry.complete)(completion)
      {
        window_id,
        source: completion.source,
        status: HostNativeAsyncImageCompletionStatus::NativeAsyncImageCompletionDelivered,
      }
    }
    None => {
      self.missing_completion_count = self.missing_completion_count + 1
      {
        window_id,
        source: completion.source,
        status: HostNativeAsyncImageCompletionStatus::NativeAsyncImageCompletionMissing,
      }
    }
  }
}

///|
pub fn HostNativeAsyncImageSource::diagnostics(
  self : HostNativeAsyncImageSource,
) -> HostNativeAsyncImageSourceDiagnostics {
  {
    requested_count: self.requested_count,
    completed_count: self.completed_count,
    cancelled_count: self.cancelled_count,
    missing_completion_count: self.missing_completion_count,
    pending_count: self.pending.length(),
  }
}

///|
pub fn HostImageResourceCompletionSource::publish(
  self : HostImageResourceCompletionSource,
  window_id : RenderWindowId,
  snapshot : ImageResourceSnapshot,
) -> HostImageResourceRepaintResult {
  self.publish_count = self.publish_count + 1
  let result = self.tracker.request_redraw_for_snapshot_if_changed(
    window_id,
    snapshot,
    window_open=(self.window_open_fn)(window_id),
    request_redraw=id => (self.request_redraw_fn)(id),
  )
  self.record_result_status(result.status)
  result
}

///|
pub fn HostImageResourceCompletionSource::complete(
  self : HostImageResourceCompletionSource,
  window_id : RenderWindowId,
  renderer : HostWindowRenderer,
  completion : ImageResourceLoadCompletion,
) -> HostImageResourceRepaintResult {
  let snapshot = renderer.apply_image_resource_load_completion(completion)
  self.publish(window_id, snapshot)
}

///|
pub fn HostAsyncImageLoader::schedule_loading_resources(
  self : HostAsyncImageLoader,
  window_id : RenderWindowId,
  renderer : HostWindowRenderer,
  completion_source : HostImageResourceCompletionSource,
) -> HostAsyncImageLoadScheduleResult {
  let snapshot = renderer.image_resource_snapshot()
  let mut loading_count = 0
  let mut scheduled_count = 0
  let mut already_in_flight_count = 0
  for record in snapshot.records {
    match record.status {
      ImageResourceStatus::ImageLoading => {
        loading_count = loading_count + 1
        if self.is_in_flight(window_id, record.source) {
          already_in_flight_count = already_in_flight_count + 1
          self.already_in_flight_count = self.already_in_flight_count + 1
        } else {
          self.schedule_one(
            window_id,
            record.source,
            renderer,
            completion_source,
          )
          scheduled_count = scheduled_count + 1
        }
      }
      _ => ()
    }
  }
  (self.drain_fn)()
  HostAsyncImageLoadScheduleResult::{
    window_id,
    snapshot_revision: snapshot.revision,
    loading_count,
    scheduled_count,
    already_in_flight_count,
  }
}

///|
pub fn HostAsyncImageLoader::cancel_window(
  self : HostAsyncImageLoader,
  window_id : RenderWindowId,
) -> Int {
  let kept : Array[HostAsyncImageLoadInFlight] = []
  let cancelled_entries : Array[HostAsyncImageLoadInFlight] = []
  let mut cancelled = 0
  for entry in self.in_flight {
    if entry.window_id == window_id {
      cancelled = cancelled + 1
      cancelled_entries.push(entry)
    } else {
      kept.push(entry)
    }
  }
  self.in_flight = kept
  self.cancelled_count = self.cancelled_count + cancelled
  for entry in cancelled_entries {
    match entry.cancel {
      Some(cancel) => cancel()
      None => ()
    }
  }
  cancelled
}

///|
pub fn HostAsyncImageLoader::cancel_all(self : HostAsyncImageLoader) -> Int {
  let cancelled_entries = self.in_flight
  let mut cancelled = 0
  self.in_flight = []
  for entry in cancelled_entries {
    cancelled = cancelled + 1
    match entry.cancel {
      Some(cancel) => cancel()
      None => ()
    }
  }
  self.cancelled_count = self.cancelled_count + cancelled
  cancelled
}

///|
pub fn HostAsyncImageLoader::diagnostics(
  self : HostAsyncImageLoader,
) -> HostAsyncImageLoaderDiagnostics {
  {
    scheduled_count: self.scheduled_count,
    completed_count: self.completed_count,
    cancelled_count: self.cancelled_count,
    already_in_flight_count: self.already_in_flight_count,
    in_flight_count: self.in_flight.length(),
  }
}

///|
pub fn HostImageResourceCompletionSource::diagnostics(
  self : HostImageResourceCompletionSource,
) -> HostImageResourceCompletionSourceDiagnostics {
  {
    publish_count: self.publish_count,
    recorded_count: self.recorded_count,
    redraw_requested_count: self.redraw_requested_count,
    unchanged_count: self.unchanged_count,
    discarded_closed_count: self.discarded_closed_count,
    tracked_window_count: self.tracker.tracked_count(),
  }
}

///|
fn HostAsyncImageLoader::schedule_one(
  self : HostAsyncImageLoader,
  window_id : RenderWindowId,
  source : String,
  renderer : HostWindowRenderer,
  completion_source : HostImageResourceCompletionSource,
) -> Unit {
  self.in_flight.push({ window_id, source, cancel: None })
  self.scheduled_count = self.scheduled_count + 1
  let cancel = (self.start_load_fn)(window_id, source, completion => {
    if self.remove_in_flight(window_id, source) && completion.source == source {
      self.completed_count = self.completed_count + 1
      ignore(completion_source.complete(window_id, renderer, completion))
    }
  })
  self.set_cancel_handler(window_id, source, cancel)
}

///|
fn HostAsyncImageLoader::is_in_flight(
  self : HostAsyncImageLoader,
  window_id : RenderWindowId,
  source : String,
) -> Bool {
  self.in_flight.any(entry => {
    entry.window_id == window_id && entry.source == source
  })
}

///|
fn HostNativeAsyncImageSource::register(
  self : HostNativeAsyncImageSource,
  window_id : RenderWindowId,
  source : String,
  complete : (ImageResourceLoadCompletion) -> Unit,
) -> Unit {
  self.pending.push({ window_id, source, complete })
  self.requested_count = self.requested_count + 1
}

///|
fn HostNativeAsyncImageSource::cancel(
  self : HostNativeAsyncImageSource,
  window_id : RenderWindowId,
  source : String,
) -> Bool {
  match self.remove_pending(window_id, source) {
    Some(_) => {
      self.cancelled_count = self.cancelled_count + 1
      true
    }
    None => false
  }
}

///|
fn HostNativeAsyncImageSource::remove_pending(
  self : HostNativeAsyncImageSource,
  window_id : RenderWindowId,
  source : String,
) -> HostNativeAsyncImageLoadPending? {
  let kept : Array[HostNativeAsyncImageLoadPending] = []
  let mut removed : HostNativeAsyncImageLoadPending? = None
  for entry in self.pending {
    if removed is None && entry.window_id == window_id && entry.source == source {
      removed = Some(entry)
    } else {
      kept.push(entry)
    }
  }
  self.pending = kept
  removed
}

///|
fn HostAsyncImageLoader::set_cancel_handler(
  self : HostAsyncImageLoader,
  window_id : RenderWindowId,
  source : String,
  cancel : (() -> Unit)?,
) -> Unit {
  for index, entry in self.in_flight {
    if entry.window_id == window_id && entry.source == source {
      self.in_flight[index] = { window_id, source, cancel }
      return
    }
  }
}

///|
fn HostAsyncImageLoader::remove_in_flight(
  self : HostAsyncImageLoader,
  window_id : RenderWindowId,
  source : String,
) -> Bool {
  let kept : Array[HostAsyncImageLoadInFlight] = []
  let mut removed = false
  for entry in self.in_flight {
    if !removed && entry.window_id == window_id && entry.source == source {
      removed = true
    } else {
      kept.push(entry)
    }
  }
  self.in_flight = kept
  removed
}

///|
fn HostImageResourceCompletionSource::record_result_status(
  self : HostImageResourceCompletionSource,
  status : HostImageResourceRepaintStatus,
) -> Unit {
  match status {
    HostImageResourceRepaintStatus::ImageRepaintRecorded =>
      self.recorded_count = self.recorded_count + 1
    HostImageResourceRepaintStatus::ImageRepaintUnchanged =>
      self.unchanged_count = self.unchanged_count + 1
    HostImageResourceRepaintStatus::ImageRepaintRequested =>
      self.redraw_requested_count = self.redraw_requested_count + 1
    HostImageResourceRepaintStatus::ImageRepaintDiscardedClosed =>
      self.discarded_closed_count = self.discarded_closed_count + 1
  }
}

///|
pub fn HostImageResourceRepaintTracker::new() -> HostImageResourceRepaintTracker {
  { window_ids: [], revisions: [], status_counts: [] }
}

///|
pub fn HostImageResourceRepaintTracker::tracked_count(
  self : HostImageResourceRepaintTracker,
) -> Int {
  self.window_ids.length()
}

///|
pub fn HostImageResourceRepaintTracker::snapshot(
  self : HostImageResourceRepaintTracker,
) -> HostImageResourceRepaintSnapshot {
  let tracked_windows : Array[HostImageResourceTrackedWindow] = []
  for index, id in self.window_ids {
    if index < self.revisions.length() {
      tracked_windows.push(HostImageResourceTrackedWindow::{
        window_id: id,
        revision: self.revisions[index],
        status_counts: self.status_counts_for_index(index),
      })
    }
  }
  HostImageResourceRepaintSnapshot::{
    tracked_window_count: tracked_windows.length(),
    tracked_windows,
  }
}

///|
pub fn HostImageResourceRepaintTracker::revision_for(
  self : HostImageResourceRepaintTracker,
  window_id : RenderWindowId,
) -> Int? {
  for index, id in self.window_ids {
    if id == window_id && index < self.revisions.length() {
      return Some(self.revisions[index])
    }
  }
  None
}

///|
pub fn HostImageResourceRepaintTracker::record_presented(
  self : HostImageResourceRepaintTracker,
  window_id : RenderWindowId,
  renderer : HostWindowRenderer,
) -> HostImageResourceRepaintResult {
  let snapshot = renderer.image_resource_snapshot()
  self.record_snapshot(window_id, snapshot)
}

///|
pub fn HostImageResourceRepaintTracker::request_redraw_if_changed(
  self : HostImageResourceRepaintTracker,
  window_id : RenderWindowId,
  renderer : HostWindowRenderer,
  window_open~ : Bool,
  request_redraw~ : (RenderWindowId) -> Unit,
) -> HostImageResourceRepaintResult {
  if !window_open {
    return self.discard_closed_window_change(window_id)
  }
  let snapshot = renderer.image_resource_snapshot()
  self.request_redraw_for_snapshot_if_changed(
    window_id,
    snapshot,
    window_open~,
    request_redraw~,
  )
}

///|
pub fn HostImageResourceRepaintTracker::request_redraw_for_snapshot_if_changed(
  self : HostImageResourceRepaintTracker,
  window_id : RenderWindowId,
  snapshot : ImageResourceSnapshot,
  window_open~ : Bool,
  request_redraw~ : (RenderWindowId) -> Unit,
) -> HostImageResourceRepaintResult {
  if !window_open {
    return self.discard_closed_window_change(window_id)
  }
  match self.revision_for(window_id) {
    Some(previous_revision) => {
      let previous_status_counts = self.status_counts_for_window(window_id)
      if snapshot.revision > previous_revision {
        let current_status_counts = host_image_resource_status_counts(
          snapshot.records,
        )
        self.set_snapshot(window_id, snapshot)
        request_redraw(window_id)
        HostImageResourceRepaintResult::{
          window_id,
          previous_revision,
          current_revision: snapshot.revision,
          previous_status_counts,
          current_status_counts,
          status: HostImageResourceRepaintStatus::ImageRepaintRequested,
        }
      } else if snapshot.revision < previous_revision {
        HostImageResourceRepaintResult::{
          window_id,
          previous_revision,
          current_revision: previous_revision,
          previous_status_counts,
          current_status_counts: previous_status_counts,
          status: HostImageResourceRepaintStatus::ImageRepaintUnchanged,
        }
      } else {
        let current_status_counts = host_image_resource_status_counts(
          snapshot.records,
        )
        self.set_snapshot(window_id, snapshot)
        HostImageResourceRepaintResult::{
          window_id,
          previous_revision,
          current_revision: snapshot.revision,
          previous_status_counts,
          current_status_counts,
          status: HostImageResourceRepaintStatus::ImageRepaintUnchanged,
        }
      }
    }
    None => self.record_snapshot(window_id, snapshot)
  }
}

///|
fn HostImageResourceRepaintTracker::discard_closed_window_change(
  self : HostImageResourceRepaintTracker,
  window_id : RenderWindowId,
) -> HostImageResourceRepaintResult {
  let previous_revision = self.previous_revision_or_zero(window_id)
  let previous_status_counts = self.status_counts_for_window(window_id)
  ignore(self.remove_window(window_id))
  HostImageResourceRepaintResult::{
    window_id,
    previous_revision,
    current_revision: previous_revision,
    previous_status_counts,
    current_status_counts: host_image_resource_empty_status_counts(),
    status: HostImageResourceRepaintStatus::ImageRepaintDiscardedClosed,
  }
}

///|
pub fn HostImageResourceRepaintTracker::remove_window(
  self : HostImageResourceRepaintTracker,
  window_id : RenderWindowId,
) -> Bool {
  let kept_ids : Array[RenderWindowId] = []
  let kept_revisions : Array[Int] = []
  let kept_status_counts : Array[HostImageResourceStatusCounts] = []
  let mut removed = false
  for index, id in self.window_ids {
    if id == window_id {
      removed = true
    } else if index < self.revisions.length() {
      kept_ids.push(id)
      kept_revisions.push(self.revisions[index])
      kept_status_counts.push(self.status_counts_for_index(index))
    }
  }
  self.window_ids = kept_ids
  self.revisions = kept_revisions
  self.status_counts = kept_status_counts
  removed
}

///|
fn HostImageResourceRepaintTracker::record_snapshot(
  self : HostImageResourceRepaintTracker,
  window_id : RenderWindowId,
  snapshot : ImageResourceSnapshot,
) -> HostImageResourceRepaintResult {
  let previous_revision = self.previous_revision_or_zero(window_id)
  let previous_status_counts = self.status_counts_for_window(window_id)
  let current_status_counts = host_image_resource_status_counts(
    snapshot.records,
  )
  self.set_snapshot(window_id, snapshot)
  HostImageResourceRepaintResult::{
    window_id,
    previous_revision,
    current_revision: snapshot.revision,
    previous_status_counts,
    current_status_counts,
    status: HostImageResourceRepaintStatus::ImageRepaintRecorded,
  }
}

///|
fn HostImageResourceRepaintTracker::previous_revision_or_zero(
  self : HostImageResourceRepaintTracker,
  window_id : RenderWindowId,
) -> Int {
  match self.revision_for(window_id) {
    Some(revision) => revision
    None => 0
  }
}

///|
fn HostImageResourceRepaintTracker::set_snapshot(
  self : HostImageResourceRepaintTracker,
  window_id : RenderWindowId,
  snapshot : ImageResourceSnapshot,
) -> Unit {
  let counts = host_image_resource_status_counts(snapshot.records)
  for index, id in self.window_ids {
    if id == window_id && index < self.revisions.length() {
      self.revisions[index] = snapshot.revision
      if index < self.status_counts.length() {
        self.status_counts[index] = counts
      }
      return
    }
  }
  self.window_ids.push(window_id)
  self.revisions.push(snapshot.revision)
  self.status_counts.push(counts)
}

///|
fn HostImageResourceRepaintTracker::status_counts_for_index(
  self : HostImageResourceRepaintTracker,
  index : Int,
) -> HostImageResourceStatusCounts {
  if index < self.status_counts.length() {
    self.status_counts[index]
  } else {
    host_image_resource_empty_status_counts()
  }
}

///|
fn HostImageResourceRepaintTracker::status_counts_for_window(
  self : HostImageResourceRepaintTracker,
  window_id : RenderWindowId,
) -> HostImageResourceStatusCounts {
  for index, id in self.window_ids {
    if id == window_id {
      return self.status_counts_for_index(index)
    }
  }
  host_image_resource_empty_status_counts()
}

///|
fn host_image_resource_empty_status_counts() -> HostImageResourceStatusCounts {
  {
    record_count: 0,
    loading_count: 0,
    ready_count: 0,
    failed_count: 0,
    disposed_count: 0,
  }
}

///|
fn host_image_resource_status_counts(
  records : Array[ImageResourceRecord],
) -> HostImageResourceStatusCounts {
  let mut loading_count = 0
  let mut ready_count = 0
  let mut failed_count = 0
  let mut disposed_count = 0
  for record in records {
    match record.status {
      ImageResourceStatus::ImageLoading =>
        loading_count = loading_count + 1
      ImageResourceStatus::ImageReady => ready_count = ready_count + 1
      ImageResourceStatus::ImageFailed =>
        failed_count = failed_count + 1
      ImageResourceStatus::ImageDisposed =>
        disposed_count = disposed_count + 1
    }
  }
  {
    record_count: records.length(),
    loading_count,
    ready_count,
    failed_count,
    disposed_count,
  }
}
