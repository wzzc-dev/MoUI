///|
pub fn ImageResourceLoadCompletion::ready(
  source : String,
  width~ : Int,
  height~ : Int,
  background_io? : Bool = false,
) -> ImageResourceLoadCompletion {
  {
    source,
    status: ImageResourceLoadCompletionStatus::ImageLoadReady,
    width,
    height,
    diagnostic: "",
    background_io,
    decoded_pixels: Bytes::make(0, 0),
    decoded_row_bytes: 0,
    background_decode: false,
  }
}

///|
pub fn ImageResourceLoadCompletion::ready_decoded_rgba(
  source : String,
  width~ : Int,
  height~ : Int,
  row_bytes~ : Int,
  pixels : Bytes,
  background_io? : Bool = false,
  background_decode? : Bool = false,
) -> ImageResourceLoadCompletion {
  {
    source,
    status: ImageResourceLoadCompletionStatus::ImageLoadReady,
    width,
    height,
    diagnostic: "",
    background_io,
    decoded_pixels: pixels,
    decoded_row_bytes: row_bytes,
    background_decode,
  }
}

///|
pub fn ImageResourceLoadCompletion::failed(
  source : String,
  diagnostic~ : String,
  background_io? : Bool = false,
) -> ImageResourceLoadCompletion {
  {
    source,
    status: ImageResourceLoadCompletionStatus::ImageLoadFailed,
    width: 0,
    height: 0,
    diagnostic,
    background_io,
    decoded_pixels: Bytes::make(0, 0),
    decoded_row_bytes: 0,
    background_decode: false,
  }
}

///|
pub fn ImageResourceLoadCompletion::has_decoded_rgba_payload(
  self : ImageResourceLoadCompletion,
) -> Bool {
  self.status == ImageResourceLoadCompletionStatus::ImageLoadReady &&
  self.width > 0 &&
  self.height > 0 &&
  self.decoded_row_bytes >= self.width * 4 &&
  self.decoded_pixels.length() >= self.decoded_row_bytes * self.height
}

///|
pub fn ImageResourceLifecycle::apply_load_completion(
  self : ImageResourceLifecycle,
  completion : ImageResourceLoadCompletion,
) -> ImageResourceSnapshot {
  match self.lookup(completion.source) {
    Some({ status: ImageResourceStatus::ImageLoading, .. }) =>
      match completion.status {
        ImageResourceLoadCompletionStatus::ImageLoadReady =>
          ignore(
            self.mark_ready(
              completion.source,
              width=completion.width,
              height=completion.height,
            ),
          )
        ImageResourceLoadCompletionStatus::ImageLoadFailed =>
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
