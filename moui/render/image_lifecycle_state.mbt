///|
pub fn ImageResourceLifecycle::new() -> ImageResourceLifecycle {
  { records: {}, revision: 0 }
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
fn ImageResourceLifecycle::snapshot_records(
  self : ImageResourceLifecycle,
) -> Array[ImageResourceRecord] {
  let records : Array[ImageResourceRecord] = []
  for _, record in self.records {
    records.push(record)
  }
  records
}
