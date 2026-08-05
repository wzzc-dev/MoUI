///|
pub(all) struct ImageLoadScheduleResult {
  window_id : RenderWindowId
  snapshot_revision : Int
  loading_count : Int
  scheduled_count : Int
  already_in_flight_count : Int
} derive(Eq, Debug, ToJson)

///|
pub fn ImageLoadScheduleResult::new(
  window_id~ : RenderWindowId,
  snapshot_revision~ : Int,
  loading_count~ : Int,
  scheduled_count~ : Int,
  already_in_flight_count~ : Int,
) -> ImageLoadScheduleResult {
  {
    window_id,
    snapshot_revision,
    loading_count,
    scheduled_count,
    already_in_flight_count,
  }
}

///|
pub fn ImageLoadScheduleResult::scheduled_count(
  self : ImageLoadScheduleResult,
) -> Int {
  self.scheduled_count
}

///|
pub fn ImageLoadScheduleResult::window_id(
  self : ImageLoadScheduleResult,
) -> RenderWindowId {
  self.window_id
}

///|
pub fn ImageLoadScheduleResult::snapshot_revision(
  self : ImageLoadScheduleResult,
) -> Int {
  self.snapshot_revision
}

///|
pub fn ImageLoadScheduleResult::loading_count(
  self : ImageLoadScheduleResult,
) -> Int {
  self.loading_count
}

///|
pub fn ImageLoadScheduleResult::already_in_flight_count(
  self : ImageLoadScheduleResult,
) -> Int {
  self.already_in_flight_count
}

///|
/// Stateless port used by host lifecycle code to schedule renderer image
/// resources without depending on the common in-flight implementation.
pub struct ImageLoader {
  priv schedule_fn : (
    RenderWindowId,
    WindowRenderer,
    (RenderWindowId, WindowRenderer, ImageResourceLoadCompletion) -> Unit,
  ) -> ImageLoadScheduleResult
  priv cancel_window_fn : (RenderWindowId) -> Int
  priv cancel_all_fn : () -> Int
}

///|
pub fn ImageLoader::new(
  schedule~ : (
    RenderWindowId,
    WindowRenderer,
    (RenderWindowId, WindowRenderer, ImageResourceLoadCompletion) -> Unit,
  ) -> ImageLoadScheduleResult,
  cancel_window~ : (RenderWindowId) -> Int,
  cancel_all~ : () -> Int,
) -> ImageLoader {
  {
    schedule_fn: schedule,
    cancel_window_fn: cancel_window,
    cancel_all_fn: cancel_all,
  }
}

///|
pub fn ImageLoader::schedule_loading_resources(
  self : ImageLoader,
  window_id : RenderWindowId,
  renderer : WindowRenderer,
  complete~ : (RenderWindowId, WindowRenderer, ImageResourceLoadCompletion) -> Unit,
) -> ImageLoadScheduleResult {
  (self.schedule_fn)(window_id, renderer, complete)
}

///|
pub fn ImageLoader::cancel_window(
  self : ImageLoader,
  window_id : RenderWindowId,
) -> Int {
  (self.cancel_window_fn)(window_id)
}

///|
pub fn ImageLoader::cancel_all(self : ImageLoader) -> Int {
  (self.cancel_all_fn)()
}
