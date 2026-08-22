///|
pub(all) enum IncrementalDataChange[T] {
  Append(T)
  Upsert(T)
  Remove(String)
  Reset(Array[T])
}

///|
pub struct IncrementalData[T] {
  items : Array[T]
  revision : Int
}

///|
pub fn[T] IncrementalData::new(items? : Array[T] = []) -> IncrementalData[T] {
  { items: items.copy(), revision: 0 }
}

///|
pub fn[T] IncrementalData::items(self : IncrementalData[T]) -> Array[T] {
  self.items.copy()
}

///|
pub fn[T] IncrementalData::revision(self : IncrementalData[T]) -> Int {
  self.revision
}

///|
fn[T] incremental_data_upsert(
  items : Array[T],
  item : T,
  key : (T) -> String,
) -> Unit {
  let item_key = key(item)
  for index, existing in items {
    if key(existing) == item_key {
      items[index] = item
      return
    }
  }
  items.push(item)
}

///|
pub fn[T] IncrementalData::apply(
  self : IncrementalData[T],
  changes : Array[IncrementalDataChange[T]],
  key : (T) -> String,
) -> IncrementalData[T] {
  if changes.is_empty() {
    return self
  }
  let items = self.items.copy()
  for change in changes {
    match change {
      Append(item) | Upsert(item) => incremental_data_upsert(items, item, key)
      Remove(removed_key) => {
        let retained = items.filter(item => key(item) != removed_key)
        items.clear()
        items.append(retained)
      }
      Reset(next) => {
        items.clear()
        items.append(next)
      }
    }
  }
  { items, revision: self.revision + 1 }
}
