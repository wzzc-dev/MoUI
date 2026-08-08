///|
pub fn ImageResourceLifecycle::mark_loading(
  self : ImageResourceLifecycle,
  source : String,
) -> Bool {
  self.store_record(@render.ImageResourceRecord::loading(source))
}

///|
pub fn ImageResourceLifecycle::mark_ready(
  self : ImageResourceLifecycle,
  source : String,
  width~ : Int,
  height~ : Int,
) -> Bool {
  self.store_record(@render.ImageResourceRecord::ready(source, width~, height~))
}

///|
pub fn ImageResourceLifecycle::mark_failed(
  self : ImageResourceLifecycle,
  source : String,
  diagnostic~ : String,
) -> Bool {
  self.store_record(@render.ImageResourceRecord::failed(source, diagnostic~))
}

///|
pub fn ImageResourceLifecycle::dispose(
  self : ImageResourceLifecycle,
  source : String,
) -> Bool {
  self.store_record(@render.ImageResourceRecord::disposed(source))
}

///|
fn ImageResourceLifecycle::store_record(
  self : ImageResourceLifecycle,
  record : @render.ImageResourceRecord,
) -> Bool {
  match self.records.get(record.source) {
    Some(existing) =>
      if existing != record {
        self.records[record.source] = record
        true
      } else {
        false
      }
    None => {
      self.records[record.source] = record
      true
    }
  }
}

///|
pub fn ImageResourceLifecycle::evict_disposed(
  self : ImageResourceLifecycle,
) -> Int {
  let mut removed = 0
  let kept : Map[String, @render.ImageResourceRecord] = Map([])
  for key, record in self.records {
    if record.status == @render.ImageResourceStatus::ImageDisposed {
      removed = removed + 1
    } else {
      kept[key] = record
    }
  }
  self.records = kept
  removed
}
