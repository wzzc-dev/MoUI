///|
using @render {
  type ImageResourceLoadCompletion,
  type ImageLoadScheduleResult,
  type ImageResourceRecord,
  type ImageResourceSnapshot,
  type ImageResourceStatus,
  type RenderWindowId,
  type WindowRenderer,
}

///|
pub(all) enum ImageResourceRepaintStatus {
  ImageRepaintRecorded
  ImageRepaintUnchanged
  ImageRepaintRequested
  ImageRepaintDiscardedClosed
} derive(Eq, Debug, ToJson)

///|
pub struct ImageResourceRepaintResult {
  priv window_id : RenderWindowId
  priv previous_revision : Int
  priv current_revision : Int
  priv previous_status_counts : ImageResourceStatusCounts
  priv current_status_counts : ImageResourceStatusCounts
  priv status : ImageResourceRepaintStatus
} derive(Eq, Debug, ToJson)

///|
pub struct ImageResourceStatusCounts {
  priv record_count : Int
  priv loading_count : Int
  priv ready_count : Int
  priv failed_count : Int
  priv disposed_count : Int
} derive(Eq, Debug, ToJson)

///|
pub struct ImageResourceTrackedWindow {
  priv window_id : RenderWindowId
  priv revision : Int
  priv status_counts : ImageResourceStatusCounts
} derive(Eq, Debug, ToJson)

///|
pub struct ImageResourceRepaintSnapshot {
  priv tracked_window_count : Int
  priv tracked_windows : Array[ImageResourceTrackedWindow]
} derive(Eq, Debug, ToJson)

///|
pub struct ImageResourceCompletionSourceDiagnostics {
  priv publish_count : Int
  priv recorded_count : Int
  priv redraw_requested_count : Int
  priv unchanged_count : Int
  priv discarded_closed_count : Int
  priv tracked_window_count : Int
} derive(Eq, Debug, ToJson)

///|
pub struct AsyncImageLoaderDiagnostics {
  priv scheduled_count : Int
  priv completed_count : Int
  priv cancelled_count : Int
  priv already_in_flight_count : Int
  priv in_flight_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) enum NativeAsyncImageCompletionStatus {
  NativeAsyncImageCompletionDelivered
  NativeAsyncImageCompletionMissing
} derive(Eq, Debug, ToJson)

///|
pub struct NativeAsyncImageLoadRequest {
  priv window_id : RenderWindowId
  priv source : String
} derive(Eq, Debug, ToJson)

///|
pub struct NativeAsyncImageCompletionResult {
  priv window_id : RenderWindowId
  priv source : String
  priv status : NativeAsyncImageCompletionStatus
} derive(Eq, Debug, ToJson)

///|
pub struct NativeAsyncImageSourceDiagnostics {
  priv requested_count : Int
  priv completed_count : Int
  priv cancelled_count : Int
  priv missing_completion_count : Int
  priv pending_count : Int
} derive(Eq, Debug, ToJson)

///|
pub fn ImageResourceRepaintResult::window_id(
  self : ImageResourceRepaintResult,
) -> RenderWindowId {
  self.window_id
}

///|
pub fn ImageResourceRepaintResult::previous_revision(
  self : ImageResourceRepaintResult,
) -> Int {
  self.previous_revision
}

///|
pub fn ImageResourceRepaintResult::current_revision(
  self : ImageResourceRepaintResult,
) -> Int {
  self.current_revision
}

///|
pub fn ImageResourceRepaintResult::previous_status_counts(
  self : ImageResourceRepaintResult,
) -> ImageResourceStatusCounts {
  self.previous_status_counts
}

///|
pub fn ImageResourceRepaintResult::current_status_counts(
  self : ImageResourceRepaintResult,
) -> ImageResourceStatusCounts {
  self.current_status_counts
}

///|
pub fn ImageResourceRepaintResult::status(
  self : ImageResourceRepaintResult,
) -> ImageResourceRepaintStatus {
  self.status
}

///|
pub fn ImageResourceStatusCounts::record_count(
  self : ImageResourceStatusCounts,
) -> Int {
  self.record_count
}

///|
pub fn ImageResourceStatusCounts::loading_count(
  self : ImageResourceStatusCounts,
) -> Int {
  self.loading_count
}

///|
pub fn ImageResourceStatusCounts::ready_count(
  self : ImageResourceStatusCounts,
) -> Int {
  self.ready_count
}

///|
pub fn ImageResourceStatusCounts::failed_count(
  self : ImageResourceStatusCounts,
) -> Int {
  self.failed_count
}

///|
pub fn ImageResourceStatusCounts::disposed_count(
  self : ImageResourceStatusCounts,
) -> Int {
  self.disposed_count
}

///|
pub fn ImageResourceTrackedWindow::window_id(
  self : ImageResourceTrackedWindow,
) -> RenderWindowId {
  self.window_id
}

///|
pub fn ImageResourceTrackedWindow::revision(
  self : ImageResourceTrackedWindow,
) -> Int {
  self.revision
}

///|
pub fn ImageResourceTrackedWindow::status_counts(
  self : ImageResourceTrackedWindow,
) -> ImageResourceStatusCounts {
  self.status_counts
}

///|
pub fn ImageResourceRepaintSnapshot::tracked_window_count(
  self : ImageResourceRepaintSnapshot,
) -> Int {
  self.tracked_window_count
}

///|
pub fn ImageResourceRepaintSnapshot::tracked_windows(
  self : ImageResourceRepaintSnapshot,
) -> Array[ImageResourceTrackedWindow] {
  self.tracked_windows
}

///|
pub fn ImageResourceCompletionSourceDiagnostics::publish_count(
  self : ImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.publish_count
}

///|
pub fn ImageResourceCompletionSourceDiagnostics::recorded_count(
  self : ImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.recorded_count
}

///|
pub fn ImageResourceCompletionSourceDiagnostics::redraw_requested_count(
  self : ImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.redraw_requested_count
}

///|
pub fn ImageResourceCompletionSourceDiagnostics::unchanged_count(
  self : ImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.unchanged_count
}

///|
pub fn ImageResourceCompletionSourceDiagnostics::discarded_closed_count(
  self : ImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.discarded_closed_count
}

///|
pub fn ImageResourceCompletionSourceDiagnostics::tracked_window_count(
  self : ImageResourceCompletionSourceDiagnostics,
) -> Int {
  self.tracked_window_count
}

///|
pub fn AsyncImageLoaderDiagnostics::scheduled_count(
  self : AsyncImageLoaderDiagnostics,
) -> Int {
  self.scheduled_count
}

///|
pub fn AsyncImageLoaderDiagnostics::completed_count(
  self : AsyncImageLoaderDiagnostics,
) -> Int {
  self.completed_count
}

///|
pub fn AsyncImageLoaderDiagnostics::cancelled_count(
  self : AsyncImageLoaderDiagnostics,
) -> Int {
  self.cancelled_count
}

///|
pub fn AsyncImageLoaderDiagnostics::already_in_flight_count(
  self : AsyncImageLoaderDiagnostics,
) -> Int {
  self.already_in_flight_count
}

///|
pub fn AsyncImageLoaderDiagnostics::in_flight_count(
  self : AsyncImageLoaderDiagnostics,
) -> Int {
  self.in_flight_count
}

///|
pub fn NativeAsyncImageLoadRequest::window_id(
  self : NativeAsyncImageLoadRequest,
) -> RenderWindowId {
  self.window_id
}

///|
pub fn NativeAsyncImageLoadRequest::source(
  self : NativeAsyncImageLoadRequest,
) -> String {
  self.source
}

///|
pub fn NativeAsyncImageCompletionResult::window_id(
  self : NativeAsyncImageCompletionResult,
) -> RenderWindowId {
  self.window_id
}

///|
pub fn NativeAsyncImageCompletionResult::source(
  self : NativeAsyncImageCompletionResult,
) -> String {
  self.source
}

///|
pub fn NativeAsyncImageCompletionResult::status(
  self : NativeAsyncImageCompletionResult,
) -> NativeAsyncImageCompletionStatus {
  self.status
}

///|
pub fn NativeAsyncImageSourceDiagnostics::requested_count(
  self : NativeAsyncImageSourceDiagnostics,
) -> Int {
  self.requested_count
}

///|
pub fn NativeAsyncImageSourceDiagnostics::completed_count(
  self : NativeAsyncImageSourceDiagnostics,
) -> Int {
  self.completed_count
}

///|
pub fn NativeAsyncImageSourceDiagnostics::cancelled_count(
  self : NativeAsyncImageSourceDiagnostics,
) -> Int {
  self.cancelled_count
}

///|
pub fn NativeAsyncImageSourceDiagnostics::missing_completion_count(
  self : NativeAsyncImageSourceDiagnostics,
) -> Int {
  self.missing_completion_count
}

///|
pub fn NativeAsyncImageSourceDiagnostics::pending_count(
  self : NativeAsyncImageSourceDiagnostics,
) -> Int {
  self.pending_count
}

///|
pub struct ImageResourceRepaintTracker {
  priv mut window_ids : Array[RenderWindowId]
  priv mut revisions : Array[Int]
  priv mut status_counts : Array[ImageResourceStatusCounts]
}

///|
pub struct ImageResourceCompletionSource {
  priv tracker : ImageResourceRepaintTracker
  priv window_open_fn : (RenderWindowId) -> Bool
  priv request_redraw_fn : (RenderWindowId) -> Unit
  priv mut publish_count : Int
  priv mut recorded_count : Int
  priv mut redraw_requested_count : Int
  priv mut unchanged_count : Int
  priv mut discarded_closed_count : Int
}

///|
priv struct AsyncImageLoadInFlight {
  window_id : RenderWindowId
  source : String
  cancel : (() -> Unit)?
}

///|
priv struct NativeAsyncImageLoadPending {
  window_id : RenderWindowId
  source : String
  complete : (ImageResourceLoadCompletion) -> Unit
}

///|
pub struct AsyncImageLoader {
  priv start_load_fn : (
    RenderWindowId,
    String,
    (ImageResourceLoadCompletion) -> Unit,
  ) -> (() -> Unit)?
  priv drain_fn : () -> Unit
  priv mut in_flight : Array[AsyncImageLoadInFlight]
  priv mut scheduled_count : Int
  priv mut completed_count : Int
  priv mut cancelled_count : Int
  priv mut already_in_flight_count : Int
}

///|
pub struct NativeAsyncImageSource {
  priv mut pending : Array[NativeAsyncImageLoadPending]
  priv mut requested_count : Int
  priv mut completed_count : Int
  priv mut cancelled_count : Int
  priv mut missing_completion_count : Int
}

///|
pub fn ImageResourceCompletionSource::new(
  tracker~ : ImageResourceRepaintTracker,
  window_open~ : (RenderWindowId) -> Bool,
  request_redraw~ : (RenderWindowId) -> Unit,
) -> ImageResourceCompletionSource {
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
pub fn AsyncImageLoader::new(
  start_load~ : (RenderWindowId, String, (ImageResourceLoadCompletion) -> Unit) -> (() -> Unit)?,
) -> AsyncImageLoader {
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
pub fn AsyncImageLoader::new_with_drain(
  start_load~ : (RenderWindowId, String, (ImageResourceLoadCompletion) -> Unit) -> (() -> Unit)?,
  drain~ : () -> Unit,
) -> AsyncImageLoader {
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
pub fn AsyncImageLoader::as_loader(
  self : AsyncImageLoader,
) -> @render.ImageLoader {
  @render.ImageLoader::new(
    schedule=(window_id, renderer, complete) => {
      self.schedule_loading_resources_with(window_id, renderer, complete~)
    },
    cancel_window=window_id => self.cancel_window(window_id),
    cancel_all=() => self.cancel_all(),
  )
}

///|
pub fn image_loader(
  decoder : @render.RendererImageDecoder,
  image_source : @render.HostImageSource?,
) -> @render.ImageLoader {
  AsyncImageLoader::new(start_load=(_window_id, source, complete) => {
    let bytes = match image_source {
      Some(reader) => reader.read(source)
      None => None
    }
    complete(decoder.decode(source, bytes))
    None
  }).as_loader()
}

///|
pub fn NativeAsyncImageSource::new() -> NativeAsyncImageSource {
  {
    pending: [],
    requested_count: 0,
    completed_count: 0,
    cancelled_count: 0,
    missing_completion_count: 0,
  }
}

///|
pub fn NativeAsyncImageSource::loader(
  self : NativeAsyncImageSource,
) -> AsyncImageLoader {
  AsyncImageLoader::new(start_load=(window_id, source, complete) => {
    self.register(window_id, source, complete)
    Some(() => ignore(self.cancel(window_id, source)))
  })
}

///|
pub fn NativeAsyncImageSource::loader_with_drain(
  self : NativeAsyncImageSource,
  spawn~ : (RenderWindowId, String) -> Unit,
  drain~ : () -> Unit,
) -> AsyncImageLoader {
  AsyncImageLoader::new_with_drain(
    start_load=(window_id, source, complete) => {
      self.register(window_id, source, complete)
      spawn(window_id, source)
      Some(() => ignore(self.cancel(window_id, source)))
    },
    drain~,
  )
}

///|
pub fn NativeAsyncImageSource::pending_requests(
  self : NativeAsyncImageSource,
) -> Array[NativeAsyncImageLoadRequest] {
  let requests : Array[NativeAsyncImageLoadRequest] = []
  for entry in self.pending {
    requests.push({ window_id: entry.window_id, source: entry.source })
  }
  requests
}

///|
pub fn NativeAsyncImageSource::complete(
  self : NativeAsyncImageSource,
  window_id : RenderWindowId,
  completion : ImageResourceLoadCompletion,
) -> NativeAsyncImageCompletionResult {
  match self.remove_pending(window_id, completion.source) {
    Some(entry) => {
      self.completed_count = self.completed_count + 1
      (entry.complete)(completion)
      {
        window_id,
        source: completion.source,
        status: NativeAsyncImageCompletionStatus::NativeAsyncImageCompletionDelivered,
      }
    }
    None => {
      self.missing_completion_count = self.missing_completion_count + 1
      {
        window_id,
        source: completion.source,
        status: NativeAsyncImageCompletionStatus::NativeAsyncImageCompletionMissing,
      }
    }
  }
}

///|
pub fn NativeAsyncImageSource::diagnostics(
  self : NativeAsyncImageSource,
) -> NativeAsyncImageSourceDiagnostics {
  {
    requested_count: self.requested_count,
    completed_count: self.completed_count,
    cancelled_count: self.cancelled_count,
    missing_completion_count: self.missing_completion_count,
    pending_count: self.pending.length(),
  }
}

///|
pub fn ImageResourceCompletionSource::publish(
  self : ImageResourceCompletionSource,
  window_id : RenderWindowId,
  snapshot : ImageResourceSnapshot,
) -> ImageResourceRepaintResult {
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
pub fn ImageResourceCompletionSource::complete(
  self : ImageResourceCompletionSource,
  window_id : RenderWindowId,
  renderer : WindowRenderer,
  completion : ImageResourceLoadCompletion,
) -> ImageResourceRepaintResult {
  let snapshot = renderer.apply_image_resource_load_completion(completion)
  self.publish(window_id, snapshot)
}

///|
pub fn AsyncImageLoader::schedule_loading_resources(
  self : AsyncImageLoader,
  window_id : RenderWindowId,
  renderer : WindowRenderer,
  completion_source : ImageResourceCompletionSource,
) -> ImageLoadScheduleResult {
  self.schedule_loading_resources_with(window_id, renderer, complete=(
    id,
    target,
    completion,
  ) => ignore(completion_source.complete(id, target, completion)))
}

///|
fn AsyncImageLoader::schedule_loading_resources_with(
  self : AsyncImageLoader,
  window_id : RenderWindowId,
  renderer : WindowRenderer,
  complete~ : (RenderWindowId, WindowRenderer, ImageResourceLoadCompletion) -> Unit,
) -> ImageLoadScheduleResult {
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
          self.schedule_one(window_id, record.source, renderer, complete)
          scheduled_count = scheduled_count + 1
        }
      }
      _ => ()
    }
  }
  (self.drain_fn)()
  @render.ImageLoadScheduleResult::new(
    window_id~,
    snapshot_revision=snapshot.revision,
    loading_count~,
    scheduled_count~,
    already_in_flight_count~,
  )
}

///|
pub fn AsyncImageLoader::cancel_window(
  self : AsyncImageLoader,
  window_id : RenderWindowId,
) -> Int {
  let kept : Array[AsyncImageLoadInFlight] = []
  let cancelled_entries : Array[AsyncImageLoadInFlight] = []
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
pub fn AsyncImageLoader::cancel_all(self : AsyncImageLoader) -> Int {
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
pub fn AsyncImageLoader::diagnostics(
  self : AsyncImageLoader,
) -> AsyncImageLoaderDiagnostics {
  {
    scheduled_count: self.scheduled_count,
    completed_count: self.completed_count,
    cancelled_count: self.cancelled_count,
    already_in_flight_count: self.already_in_flight_count,
    in_flight_count: self.in_flight.length(),
  }
}

///|
pub fn ImageResourceCompletionSource::diagnostics(
  self : ImageResourceCompletionSource,
) -> ImageResourceCompletionSourceDiagnostics {
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
fn AsyncImageLoader::schedule_one(
  self : AsyncImageLoader,
  window_id : RenderWindowId,
  source : String,
  renderer : WindowRenderer,
  complete : (RenderWindowId, WindowRenderer, ImageResourceLoadCompletion) -> Unit,
) -> Unit {
  self.in_flight.push({ window_id, source, cancel: None })
  self.scheduled_count = self.scheduled_count + 1
  let cancel = (self.start_load_fn)(window_id, source, completion => {
    if self.remove_in_flight(window_id, source) && completion.source == source {
      self.completed_count = self.completed_count + 1
      complete(window_id, renderer, completion)
    }
  })
  self.set_cancel_handler(window_id, source, cancel)
}

///|
fn AsyncImageLoader::is_in_flight(
  self : AsyncImageLoader,
  window_id : RenderWindowId,
  source : String,
) -> Bool {
  self.in_flight.any(entry => {
    entry.window_id == window_id && entry.source == source
  })
}

///|
fn NativeAsyncImageSource::register(
  self : NativeAsyncImageSource,
  window_id : RenderWindowId,
  source : String,
  complete : (ImageResourceLoadCompletion) -> Unit,
) -> Unit {
  self.pending.push({ window_id, source, complete })
  self.requested_count = self.requested_count + 1
}

///|
fn NativeAsyncImageSource::cancel(
  self : NativeAsyncImageSource,
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
fn NativeAsyncImageSource::remove_pending(
  self : NativeAsyncImageSource,
  window_id : RenderWindowId,
  source : String,
) -> NativeAsyncImageLoadPending? {
  let kept : Array[NativeAsyncImageLoadPending] = []
  let mut removed : NativeAsyncImageLoadPending? = None
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
fn AsyncImageLoader::set_cancel_handler(
  self : AsyncImageLoader,
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
fn AsyncImageLoader::remove_in_flight(
  self : AsyncImageLoader,
  window_id : RenderWindowId,
  source : String,
) -> Bool {
  let kept : Array[AsyncImageLoadInFlight] = []
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
fn ImageResourceCompletionSource::record_result_status(
  self : ImageResourceCompletionSource,
  status : ImageResourceRepaintStatus,
) -> Unit {
  match status {
    ImageResourceRepaintStatus::ImageRepaintRecorded =>
      self.recorded_count = self.recorded_count + 1
    ImageResourceRepaintStatus::ImageRepaintUnchanged =>
      self.unchanged_count = self.unchanged_count + 1
    ImageResourceRepaintStatus::ImageRepaintRequested =>
      self.redraw_requested_count = self.redraw_requested_count + 1
    ImageResourceRepaintStatus::ImageRepaintDiscardedClosed =>
      self.discarded_closed_count = self.discarded_closed_count + 1
  }
}

///|
pub fn ImageResourceRepaintTracker::new() -> ImageResourceRepaintTracker {
  { window_ids: [], revisions: [], status_counts: [] }
}

///|
pub fn ImageResourceRepaintTracker::tracked_count(
  self : ImageResourceRepaintTracker,
) -> Int {
  self.window_ids.length()
}

///|
pub fn ImageResourceRepaintTracker::snapshot(
  self : ImageResourceRepaintTracker,
) -> ImageResourceRepaintSnapshot {
  let tracked_windows : Array[ImageResourceTrackedWindow] = []
  for index, id in self.window_ids {
    if index < self.revisions.length() {
      tracked_windows.push(ImageResourceTrackedWindow::{
        window_id: id,
        revision: self.revisions[index],
        status_counts: self.status_counts_for_index(index),
      })
    }
  }
  ImageResourceRepaintSnapshot::{
    tracked_window_count: tracked_windows.length(),
    tracked_windows,
  }
}

///|
pub fn ImageResourceRepaintTracker::revision_for(
  self : ImageResourceRepaintTracker,
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
pub fn ImageResourceRepaintTracker::record_presented(
  self : ImageResourceRepaintTracker,
  window_id : RenderWindowId,
  renderer : WindowRenderer,
) -> ImageResourceRepaintResult {
  let snapshot = renderer.image_resource_snapshot()
  self.record_snapshot(window_id, snapshot)
}

///|
pub fn ImageResourceRepaintTracker::request_redraw_if_changed(
  self : ImageResourceRepaintTracker,
  window_id : RenderWindowId,
  renderer : WindowRenderer,
  window_open~ : Bool,
  request_redraw~ : (RenderWindowId) -> Unit,
) -> ImageResourceRepaintResult {
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
pub fn ImageResourceRepaintTracker::request_redraw_for_snapshot_if_changed(
  self : ImageResourceRepaintTracker,
  window_id : RenderWindowId,
  snapshot : ImageResourceSnapshot,
  window_open~ : Bool,
  request_redraw~ : (RenderWindowId) -> Unit,
) -> ImageResourceRepaintResult {
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
        ImageResourceRepaintResult::{
          window_id,
          previous_revision,
          current_revision: snapshot.revision,
          previous_status_counts,
          current_status_counts,
          status: ImageResourceRepaintStatus::ImageRepaintRequested,
        }
      } else if snapshot.revision < previous_revision {
        ImageResourceRepaintResult::{
          window_id,
          previous_revision,
          current_revision: previous_revision,
          previous_status_counts,
          current_status_counts: previous_status_counts,
          status: ImageResourceRepaintStatus::ImageRepaintUnchanged,
        }
      } else {
        let current_status_counts = host_image_resource_status_counts(
          snapshot.records,
        )
        self.set_snapshot(window_id, snapshot)
        ImageResourceRepaintResult::{
          window_id,
          previous_revision,
          current_revision: snapshot.revision,
          previous_status_counts,
          current_status_counts,
          status: ImageResourceRepaintStatus::ImageRepaintUnchanged,
        }
      }
    }
    None => self.record_snapshot(window_id, snapshot)
  }
}

///|
fn ImageResourceRepaintTracker::discard_closed_window_change(
  self : ImageResourceRepaintTracker,
  window_id : RenderWindowId,
) -> ImageResourceRepaintResult {
  let previous_revision = self.previous_revision_or_zero(window_id)
  let previous_status_counts = self.status_counts_for_window(window_id)
  ignore(self.remove_window(window_id))
  ImageResourceRepaintResult::{
    window_id,
    previous_revision,
    current_revision: previous_revision,
    previous_status_counts,
    current_status_counts: host_image_resource_empty_status_counts(),
    status: ImageResourceRepaintStatus::ImageRepaintDiscardedClosed,
  }
}

///|
pub fn ImageResourceRepaintTracker::remove_window(
  self : ImageResourceRepaintTracker,
  window_id : RenderWindowId,
) -> Bool {
  let kept_ids : Array[RenderWindowId] = []
  let kept_revisions : Array[Int] = []
  let kept_status_counts : Array[ImageResourceStatusCounts] = []
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
fn ImageResourceRepaintTracker::record_snapshot(
  self : ImageResourceRepaintTracker,
  window_id : RenderWindowId,
  snapshot : ImageResourceSnapshot,
) -> ImageResourceRepaintResult {
  let previous_revision = self.previous_revision_or_zero(window_id)
  let previous_status_counts = self.status_counts_for_window(window_id)
  let current_status_counts = host_image_resource_status_counts(
    snapshot.records,
  )
  self.set_snapshot(window_id, snapshot)
  ImageResourceRepaintResult::{
    window_id,
    previous_revision,
    current_revision: snapshot.revision,
    previous_status_counts,
    current_status_counts,
    status: ImageResourceRepaintStatus::ImageRepaintRecorded,
  }
}

///|
fn ImageResourceRepaintTracker::previous_revision_or_zero(
  self : ImageResourceRepaintTracker,
  window_id : RenderWindowId,
) -> Int {
  match self.revision_for(window_id) {
    Some(revision) => revision
    None => 0
  }
}

///|
fn ImageResourceRepaintTracker::set_snapshot(
  self : ImageResourceRepaintTracker,
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
fn ImageResourceRepaintTracker::status_counts_for_index(
  self : ImageResourceRepaintTracker,
  index : Int,
) -> ImageResourceStatusCounts {
  if index < self.status_counts.length() {
    self.status_counts[index]
  } else {
    host_image_resource_empty_status_counts()
  }
}

///|
fn ImageResourceRepaintTracker::status_counts_for_window(
  self : ImageResourceRepaintTracker,
  window_id : RenderWindowId,
) -> ImageResourceStatusCounts {
  for index, id in self.window_ids {
    if id == window_id {
      return self.status_counts_for_index(index)
    }
  }
  host_image_resource_empty_status_counts()
}

///|
fn host_image_resource_empty_status_counts() -> ImageResourceStatusCounts {
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
) -> ImageResourceStatusCounts {
  let mut loading_count = 0
  let mut ready_count = 0
  let mut failed_count = 0
  let mut disposed_count = 0
  for record in records {
    match record.status {
      ImageResourceStatus::ImageLoading => loading_count = loading_count + 1
      ImageResourceStatus::ImageReady => ready_count = ready_count + 1
      ImageResourceStatus::ImageFailed => failed_count = failed_count + 1
      ImageResourceStatus::ImageDisposed => disposed_count = disposed_count + 1
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
