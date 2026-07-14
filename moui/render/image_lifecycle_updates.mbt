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
  let kept : Map[String, ImageResourceRecord] = Map([])
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
