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
  status : HostImageResourceRepaintStatus
} derive(Eq, Debug, ToJson)

///|
pub struct HostImageResourceRepaintTracker {
  priv mut window_ids : Array[HostWindowId]
  priv mut revisions : Array[Int]
}

///|
pub fn HostImageResourceRepaintTracker::new() -> HostImageResourceRepaintTracker {
  { window_ids: [], revisions: [] }
}

///|
pub fn HostImageResourceRepaintTracker::tracked_count(
  self : HostImageResourceRepaintTracker,
) -> Int {
  self.window_ids.length()
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
  self.record_revision(window_id, snapshot.revision)
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
    let previous_revision = self.previous_revision_or_zero(window_id)
    ignore(self.remove_window(window_id))
    return HostImageResourceRepaintResult::{
      window_id,
      previous_revision,
      current_revision: previous_revision,
      status: HostImageResourceRepaintStatus::ImageRepaintDiscardedClosed,
    }
  }
  let snapshot = renderer.image_resource_snapshot()
  match self.revision_for(window_id) {
    Some(previous_revision) =>
      if snapshot.revision > previous_revision {
        self.set_revision(window_id, snapshot.revision)
        request_redraw(window_id)
        HostImageResourceRepaintResult::{
          window_id,
          previous_revision,
          current_revision: snapshot.revision,
          status: HostImageResourceRepaintStatus::ImageRepaintRequested,
        }
      } else if snapshot.revision < previous_revision {
        self.set_revision(window_id, snapshot.revision)
        HostImageResourceRepaintResult::{
          window_id,
          previous_revision,
          current_revision: snapshot.revision,
          status: HostImageResourceRepaintStatus::ImageRepaintRecorded,
        }
      } else {
        HostImageResourceRepaintResult::{
          window_id,
          previous_revision,
          current_revision: snapshot.revision,
          status: HostImageResourceRepaintStatus::ImageRepaintUnchanged,
        }
      }
    None => self.record_revision(window_id, snapshot.revision)
  }
}

///|
pub fn HostImageResourceRepaintTracker::remove_window(
  self : HostImageResourceRepaintTracker,
  window_id : HostWindowId,
) -> Bool {
  let kept_ids : Array[HostWindowId] = []
  let kept_revisions : Array[Int] = []
  let mut removed = false
  for index, id in self.window_ids {
    if id == window_id {
      removed = true
    } else if index < self.revisions.length() {
      kept_ids.push(id)
      kept_revisions.push(self.revisions[index])
    }
  }
  self.window_ids = kept_ids
  self.revisions = kept_revisions
  removed
}

///|
fn HostImageResourceRepaintTracker::record_revision(
  self : HostImageResourceRepaintTracker,
  window_id : HostWindowId,
  revision : Int,
) -> HostImageResourceRepaintResult {
  let previous_revision = self.previous_revision_or_zero(window_id)
  self.set_revision(window_id, revision)
  HostImageResourceRepaintResult::{
    window_id,
    previous_revision,
    current_revision: revision,
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
fn HostImageResourceRepaintTracker::set_revision(
  self : HostImageResourceRepaintTracker,
  window_id : HostWindowId,
  revision : Int,
) -> Unit {
  for index, id in self.window_ids {
    if id == window_id && index < self.revisions.length() {
      self.revisions[index] = revision
      return
    }
  }
  self.window_ids.push(window_id)
  self.revisions.push(revision)
}
