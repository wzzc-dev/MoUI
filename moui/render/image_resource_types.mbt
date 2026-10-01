///|
pub(all) enum ImageResourceStatus {
  ImageLoading
  ImageReady
  ImageFailed
  ImageDisposed
} derive(Eq, Debug, ToJson)

///|
pub extend ImageResourceStatus with Debug::{to_repr}

///|
pub extend ImageResourceStatus with Eq::{not_equal, equal}

///|
pub extend ImageResourceStatus with ToJson::{to_json}

///|
pub(all) struct ImageResourceRecord {
  source : String
  status : ImageResourceStatus
  width : Int
  height : Int
  diagnostic : String
} derive(Eq, Debug, ToJson)

///|
pub extend ImageResourceRecord with Debug::{to_repr}

///|
pub extend ImageResourceRecord with Eq::{not_equal, equal}

///|
pub extend ImageResourceRecord with ToJson::{to_json}

///|
pub(all) enum ImageResourceLoadCompletionStatus {
  ImageLoadReady
  ImageLoadFailed
} derive(Eq, Debug, ToJson)

///|
pub extend ImageResourceLoadCompletionStatus with Debug::{to_repr}

///|
pub extend ImageResourceLoadCompletionStatus with Eq::{not_equal, equal}

///|
pub extend ImageResourceLoadCompletionStatus with ToJson::{to_json}

///|
pub(all) struct ImageResourceLoadCompletion {
  source : String
  status : ImageResourceLoadCompletionStatus
  width : Int
  height : Int
  diagnostic : String
  background_io : Bool
  decoded_pixels : Bytes
  decoded_row_bytes : Int
  background_decode : Bool
} derive(Eq, Debug, ToJson)

///|
pub extend ImageResourceLoadCompletion with Debug::{to_repr}

///|
pub extend ImageResourceLoadCompletion with Eq::{not_equal, equal}

///|
pub extend ImageResourceLoadCompletion with ToJson::{to_json}
