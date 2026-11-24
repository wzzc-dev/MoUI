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
  width~ : Int32,
  height~ : Int32,
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
        self.generation = self.generation + 1L
        true
      } else {
        false
      }
    None => {
      self.records[record.source] = record
      self.generation = self.generation + 1L
      true
    }
  }
}

///|
/// Forget every record. A host hot-reload swap calls this when the process
/// keeps its renderer but the plugin image changes: source bytes, fonts and
/// retained layers at the same path may now describe different content, and
/// an old Loading/Ready/Failed record must not keep serving or suppressing it.
/// The generation advances so per-frame record scans observe the reset.
pub fn ImageResourceLifecycle::reset(self : ImageResourceLifecycle) -> Unit {
  if self.records.length() > 0 {
    self.records.clear()
    self.generation = self.generation + 1L
  }
}

///|
pub fn ImageResourceLifecycle::evict_disposed(
  self : ImageResourceLifecycle,
) -> Int32 {
  let mut removed = 0
  let kept : Map[String, @render.ImageResourceRecord] = Map([])
  for key, record in self.records {
    if record.status == ImageDisposed {
      removed = removed + 1
    } else {
      kept[key] = record
    }
  }
  if removed > 0 {
    self.records = kept
    self.generation = self.generation + 1L
  }
  removed
}
