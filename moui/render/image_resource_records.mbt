///|
pub fn ImageResourceRecord::loading(source : String) -> ImageResourceRecord {
  {
    source,
    status: ImageResourceStatus::ImageLoading,
    width: 0,
    height: 0,
    diagnostic: "",
  }
}

///|
pub fn ImageResourceRecord::ready(
  source : String,
  width~ : Int,
  height~ : Int,
) -> ImageResourceRecord {
  {
    source,
    status: ImageResourceStatus::ImageReady,
    width,
    height,
    diagnostic: "",
  }
}

///|
pub fn ImageResourceRecord::failed(
  source : String,
  diagnostic~ : String,
) -> ImageResourceRecord {
  {
    source,
    status: ImageResourceStatus::ImageFailed,
    width: 0,
    height: 0,
    diagnostic,
  }
}

///|
pub fn ImageResourceRecord::disposed(source : String) -> ImageResourceRecord {
  {
    source,
    status: ImageResourceStatus::ImageDisposed,
    width: 0,
    height: 0,
    diagnostic: "",
  }
}
