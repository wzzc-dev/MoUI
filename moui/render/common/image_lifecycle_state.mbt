///|
pub struct ImageResourceLifecycle {
  priv mut records : Map[String, @render.ImageResourceRecord]
  priv mut revision : Int
} derive(Eq, Debug)

///|
pub fn ImageResourceLifecycle::new() -> ImageResourceLifecycle {
  { records: Map([]), revision: 0 }
}

///|
pub fn ImageResourceLifecycle::lookup(
  self : ImageResourceLifecycle,
  source : String,
) -> @render.ImageResourceRecord? {
  self.records.get(source)
}

///|
pub fn ImageResourceLifecycle::snapshot(
  self : ImageResourceLifecycle,
) -> Array[@render.ImageResourceRecord] {
  self.snapshot_records()
}

///|
pub fn ImageResourceLifecycle::snapshot_with_revision(
  self : ImageResourceLifecycle,
) -> @render.ImageResourceSnapshot {
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
) -> Array[@render.ImageResourceRecord] {
  let records : Array[@render.ImageResourceRecord] = []
  for _, record in self.records {
    records.push(record)
  }
  records
}
