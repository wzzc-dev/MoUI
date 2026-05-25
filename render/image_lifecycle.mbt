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
pub(all) struct ImageResourceLifecycle {
  mut records : Map[String, ImageResourceRecord]
} derive(Eq, Debug)

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
pub fn ImageResourceLifecycle::new() -> ImageResourceLifecycle {
  { records: {} }
}

///|
pub fn ImageResourceLifecycle::mark_loading(
  self : ImageResourceLifecycle,
  source : String,
) -> ImageResourceRecord {
  let record = ImageResourceRecord::loading(source)
  self.records[record.source] = record
  record
}

///|
pub fn ImageResourceLifecycle::mark_ready(
  self : ImageResourceLifecycle,
  source : String,
  width~ : Int,
  height~ : Int,
) -> ImageResourceRecord {
  let record = ImageResourceRecord::ready(source, width~, height~)
  self.records[record.source] = record
  record
}

///|
pub fn ImageResourceLifecycle::mark_failed(
  self : ImageResourceLifecycle,
  source : String,
  diagnostic~ : String,
) -> ImageResourceRecord {
  let record = ImageResourceRecord::failed(source, diagnostic~)
  self.records[record.source] = record
  record
}

///|
pub fn ImageResourceLifecycle::dispose(
  self : ImageResourceLifecycle,
  source : String,
) -> ImageResourceRecord {
  let record = ImageResourceRecord::disposed(source)
  self.records[source] = record
  record
}

///|
pub fn ImageResourceLifecycle::lookup(
  self : ImageResourceLifecycle,
  source : String,
) -> ImageResourceRecord? {
  self.records.get(source)
}

///|
pub fn ImageResourceLifecycle::snapshot(
  self : ImageResourceLifecycle,
) -> Array[ImageResourceRecord] {
  let records : Array[ImageResourceRecord] = []
  for _, record in self.records {
    records.push(record)
  }
  records
}

///|
pub fn ImageResourceLifecycle::evict_disposed(
  self : ImageResourceLifecycle,
) -> Int {
  let mut removed = 0
  let kept : Map[String, ImageResourceRecord] = {}
  for key, record in self.records {
    if record.status == ImageResourceStatus::ImageDisposed {
      removed = removed + 1
    } else {
      kept[key] = record
    }
  }
  self.records = kept
  removed
}
