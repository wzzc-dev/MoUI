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

///|
pub fn ImageResourceSnapshot::new(
  revision~ : Int,
  records~ : Array[ImageResourceRecord],
) -> ImageResourceSnapshot {
  { revision, records }
}

///|
pub fn ImageResourceSnapshot::empty() -> ImageResourceSnapshot {
  { revision: 0, records: [] }
}

///|
pub fn ImageResourceSnapshot::from_records(
  records : Array[ImageResourceRecord],
) -> ImageResourceSnapshot {
  { revision: 0, records }
}
