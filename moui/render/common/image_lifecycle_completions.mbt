///|
pub fn ImageResourceLifecycle::apply_load_completion(
  self : ImageResourceLifecycle,
  completion : @render.ImageResourceLoadCompletion,
) -> Bool {
  match self.lookup(completion.source) {
    Some({ status: ImageLoading, .. }) =>
      match completion.status {
        ImageLoadReady =>
          self.mark_ready(
            completion.source,
            width=completion.width,
            height=completion.height,
          )
        ImageLoadFailed =>
          self.mark_failed(completion.source, diagnostic=completion.diagnostic)
      }
    _ => false
  }
}
