///|
pub fn ImageResourceLifecycle::apply_load_completion(
  self : ImageResourceLifecycle,
  completion : @render.ImageResourceLoadCompletion,
) -> @render.ImageResourceSnapshot {
  match self.lookup(completion.source) {
    Some({ status: @render.ImageResourceStatus::ImageLoading, .. }) =>
      match completion.status {
        @render.ImageResourceLoadCompletionStatus::ImageLoadReady =>
          ignore(
            self.mark_ready(
              completion.source,
              width=completion.width,
              height=completion.height,
            ),
          )
        @render.ImageResourceLoadCompletionStatus::ImageLoadFailed =>
          ignore(
            self.mark_failed(
              completion.source,
              diagnostic=completion.diagnostic,
            ),
          )
      }
    _ => ()
  }
  self.snapshot_with_revision()
}
