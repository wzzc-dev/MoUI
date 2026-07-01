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
pub(all) struct ImageResourceSnapshot {
  revision : Int
  records : Array[ImageResourceRecord]
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
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ImageResourceLifecycle {
  mut records : Map[String, ImageResourceRecord]
  mut revision : Int
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
  { records: {}, revision: 0 }
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
  }
}

///|
pub fn ImageResourceLifecycle::mark_loading(
  self : ImageResourceLifecycle,
  source : String,
) -> ImageResourceRecord {
  self.store_record(ImageResourceRecord::loading(source))
}

///|
pub fn ImageResourceLifecycle::mark_ready(
  self : ImageResourceLifecycle,
  source : String,
  width~ : Int,
  height~ : Int,
) -> ImageResourceRecord {
  self.store_record(ImageResourceRecord::ready(source, width~, height~))
}

///|
pub fn ImageResourceLifecycle::mark_failed(
  self : ImageResourceLifecycle,
  source : String,
  diagnostic~ : String,
) -> ImageResourceRecord {
  self.store_record(ImageResourceRecord::failed(source, diagnostic~))
}

///|
pub fn ImageResourceLifecycle::dispose(
  self : ImageResourceLifecycle,
  source : String,
) -> ImageResourceRecord {
  self.store_record(ImageResourceRecord::disposed(source))
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
  self.snapshot_records()
}

///|
pub fn ImageResourceLifecycle::snapshot_with_revision(
  self : ImageResourceLifecycle,
) -> ImageResourceSnapshot {
  { revision: self.revision, records: self.snapshot_records() }
}

///|
pub fn ImageResourceLifecycle::revision(self : ImageResourceLifecycle) -> Int {
  self.revision
}

///|
pub fn ImageResourceLifecycle::changed_since(
  self : ImageResourceLifecycle,
  revision : Int,
) -> Bool {
  self.revision > revision
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

///|
fn ImageResourceLifecycle::snapshot_records(
  self : ImageResourceLifecycle,
) -> Array[ImageResourceRecord] {
  let records : Array[ImageResourceRecord] = []
  for _, record in self.records {
    records.push(record)
  }
  records
}

///|
fn ImageResourceLifecycle::store_record(
  self : ImageResourceLifecycle,
  record : ImageResourceRecord,
) -> ImageResourceRecord {
  match self.records.get(record.source) {
    Some(existing) =>
      if existing != record {
        self.revision = self.revision + 1
        self.records[record.source] = record
      }
    None => {
      self.revision = self.revision + 1
      self.records[record.source] = record
    }
  }
  record
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
  if removed > 0 {
    self.revision = self.revision + 1
  }
  removed
}
