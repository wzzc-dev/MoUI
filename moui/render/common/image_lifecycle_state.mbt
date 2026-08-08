///|
pub struct ImageResourceLifecycle {
  priv mut records : Map[String, @render.ImageResourceRecord]
} derive(Eq, Debug)

///|
pub fn ImageResourceLifecycle::new() -> ImageResourceLifecycle {
  { records: Map([]) }
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
fn ImageResourceLifecycle::snapshot_records(
  self : ImageResourceLifecycle,
) -> Array[@render.ImageResourceRecord] {
  let records : Array[@render.ImageResourceRecord] = []
  for _, record in self.records {
    records.push(record)
  }
  records
}
