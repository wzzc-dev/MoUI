///|
pub(all) enum ImageResourceStatus {
  ImageLoading
  ImageReady
  ImageFailed
  ImageDisposed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ImageResourceRecord {
  source : String
  status : ImageResourceStatus
  width : Int
  height : Int
  diagnostic : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ImageResourceLoadCompletionStatus {
  ImageLoadReady
  ImageLoadFailed
} derive(Eq, Debug, ToJson)

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
