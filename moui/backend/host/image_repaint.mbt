///|
pub(all) enum HostImageResourceRepaintStatus {
  ImageRepaintRecorded
  ImageRepaintUnchanged
  ImageRepaintRequested
  ImageRepaintDiscardedClosed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostImageResourceRepaintResult {
  window_id : HostWindowId
  previous_revision : Int
  current_revision : Int
  previous_status_counts : HostImageResourceStatusCounts
  current_status_counts : HostImageResourceStatusCounts
  status : HostImageResourceRepaintStatus
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostImageResourceStatusCounts {
  record_count : Int
  loading_count : Int
  ready_count : Int
  failed_count : Int
  disposed_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostImageResourceTrackedWindow {
  window_id : HostWindowId
  revision : Int
  status_counts : HostImageResourceStatusCounts
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostImageResourceRepaintSnapshot {
  tracked_window_count : Int
  tracked_windows : Array[HostImageResourceTrackedWindow]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostImageResourceCompletionSourceDiagnostics {
  publish_count : Int
  recorded_count : Int
  redraw_requested_count : Int
  unchanged_count : Int
  discarded_closed_count : Int
  tracked_window_count : Int
} derive(Eq, Debug, ToJson)

///|
pub struct HostImageResourceRepaintTracker {
  priv mut window_ids : Array[HostWindowId]
  priv mut revisions : Array[Int]
  priv mut status_counts : Array[HostImageResourceStatusCounts]
}

///|
pub struct HostImageResourceCompletionSource {
  priv tracker : HostImageResourceRepaintTracker
  priv window_open_fn : (HostWindowId) -> Bool
  priv request_redraw_fn : (HostWindowId) -> Unit
  priv mut publish_count : Int
  priv mut recorded_count : Int
  priv mut redraw_requested_count : Int
  priv mut unchanged_count : Int
  priv mut discarded_closed_count : Int
}

///|
pub fn HostImageResourceCompletionSource::new(
  tracker~ : HostImageResourceRepaintTracker,
  window_open~ : (HostWindowId) -> Bool,
  request_redraw~ : (HostWindowId) -> Unit,
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
pub fn HostImageResourceCompletionSource::publish(
  self : HostImageResourceCompletionSource,
  window_id : HostWindowId,
  snapshot : @render.ImageResourceSnapshot,
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
  window_id : HostWindowId,
  renderer : HostWindowRenderer,
  completion : @render.ImageResourceLoadCompletion,
) -> HostImageResourceRepaintResult {
  let snapshot = renderer.apply_image_resource_load_completion(completion)
  self.publish(window_id, snapshot)
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
  window_id : HostWindowId,
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
  window_id : HostWindowId,
  renderer : HostWindowRenderer,
) -> HostImageResourceRepaintResult {
  let snapshot = renderer.image_resource_snapshot()
  self.record_snapshot(window_id, snapshot)
}

///|
pub fn HostImageResourceRepaintTracker::request_redraw_if_changed(
  self : HostImageResourceRepaintTracker,
  window_id : HostWindowId,
  renderer : HostWindowRenderer,
  window_open~ : Bool,
  request_redraw~ : (HostWindowId) -> Unit,
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
  window_id : HostWindowId,
  snapshot : @render.ImageResourceSnapshot,
  window_open~ : Bool,
  request_redraw~ : (HostWindowId) -> Unit,
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
  window_id : HostWindowId,
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
  window_id : HostWindowId,
) -> Bool {
  let kept_ids : Array[HostWindowId] = []
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
  window_id : HostWindowId,
  snapshot : @render.ImageResourceSnapshot,
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
  window_id : HostWindowId,
) -> Int {
  match self.revision_for(window_id) {
    Some(revision) => revision
    None => 0
  }
}

///|
fn HostImageResourceRepaintTracker::set_snapshot(
  self : HostImageResourceRepaintTracker,
  window_id : HostWindowId,
  snapshot : @render.ImageResourceSnapshot,
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
  window_id : HostWindowId,
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
  records : Array[@render.ImageResourceRecord],
) -> HostImageResourceStatusCounts {
  let mut loading_count = 0
  let mut ready_count = 0
  let mut failed_count = 0
  let mut disposed_count = 0
  for record in records {
    match record.status {
      @render.ImageResourceStatus::ImageLoading =>
        loading_count = loading_count + 1
      @render.ImageResourceStatus::ImageReady => ready_count = ready_count + 1
      @render.ImageResourceStatus::ImageFailed =>
        failed_count = failed_count + 1
      @render.ImageResourceStatus::ImageDisposed =>
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
