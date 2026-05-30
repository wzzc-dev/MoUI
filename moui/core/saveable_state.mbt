///|
pub struct SaveableCodec[T] {
  encode : (T) -> String
  decode : (String) -> T?
}

///|
pub struct SaveableStateStore {
  mut strings : Array[SaveableStringEntry]
}

///|
pub(all) struct SaveableStateSnapshot {
  entries : Array[SaveableStringEntry]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SaveableStringEntry {
  key : String
  mut value : String
} derive(Eq, Debug, ToJson)

///|
pub fn[T] SaveableCodec::new(
  encode~ : (T) -> String,
  decode~ : (String) -> T?,
) -> SaveableCodec[T] {
  { encode, decode }
}

///|
pub fn[T] SaveableCodec::encode_value(
  self : SaveableCodec[T],
  value : T,
) -> String {
  (self.encode)(value)
}

///|
pub fn[T] SaveableCodec::decode_value(
  self : SaveableCodec[T],
  payload : String,
) -> T? {
  (self.decode)(payload)
}

///|
pub fn SaveableCodec::string() -> SaveableCodec[String] {
  SaveableCodec::new(encode=value => value, decode=value => Some(value))
}

///|
pub fn SaveableCodec::bool() -> SaveableCodec[Bool] {
  SaveableCodec::new(encode=value => if value { "true" } else { "false" }, decode=value => {
    match value {
      "true" => Some(true)
      "false" => Some(false)
      _ => None
    }
  })
}

///|
pub fn SaveableCodec::int() -> SaveableCodec[Int] {
  SaveableCodec::new(
    encode=value => value.to_string(),
    decode=parse_saveable_int,
  )
}

///|
pub fn SaveableStateStore::new() -> SaveableStateStore {
  { strings: [] }
}

///|
pub fn SaveableStateSnapshot::new(
  entries? : Array[SaveableStringEntry] = [],
) -> SaveableStateSnapshot {
  { entries, }
}

///|
pub fn SaveableStateStore::snapshot(
  self : SaveableStateStore,
) -> SaveableStateSnapshot {
  SaveableStateSnapshot::new(
    entries=self.strings.map(entry => { key: entry.key, value: entry.value }),
  )
}

///|
pub fn SaveableStateStore::restore(
  self : SaveableStateStore,
  snapshot : SaveableStateSnapshot,
) -> Unit {
  self.strings = snapshot.entries.map(entry => {
    key: entry.key,
    value: entry.value,
  })
}

///|
pub fn[T] SaveableStateStore::get(
  self : SaveableStateStore,
  key : String,
  codec : SaveableCodec[T],
) -> T? {
  match self.get_string(key) {
    Some(value) => codec.decode_value(value)
    None => None
  }
}

///|
pub fn[T] SaveableStateStore::set(
  self : SaveableStateStore,
  key : String,
  value : T,
  codec : SaveableCodec[T],
) -> Unit {
  self.set_string(key, codec.encode_value(value))
}

///|
pub fn SaveableStateStore::get_string(
  self : SaveableStateStore,
  key : String,
) -> String? {
  for entry in self.strings {
    if entry.key == key {
      return Some(entry.value)
    }
  }
  None
}

///|
pub fn SaveableStateStore::set_string(
  self : SaveableStateStore,
  key : String,
  value : String,
) -> Unit {
  for entry in self.strings {
    if entry.key == key {
      entry.value = value
      return
    }
  }
  self.strings.push({ key, value })
}

///|
pub fn SaveableStateStore::get_bool(
  self : SaveableStateStore,
  key : String,
) -> Bool? {
  self.get(key, SaveableCodec::bool())
}

///|
pub fn SaveableStateStore::set_bool(
  self : SaveableStateStore,
  key : String,
  value : Bool,
) -> Unit {
  self.set(key, value, SaveableCodec::bool())
}

///|
pub fn SaveableStateStore::get_int(
  self : SaveableStateStore,
  key : String,
) -> Int? {
  self.get(key, SaveableCodec::int())
}

///|
pub fn SaveableStateStore::set_int(
  self : SaveableStateStore,
  key : String,
  value : Int,
) -> Unit {
  self.set(key, value, SaveableCodec::int())
}

///|
pub fn SaveableStateStore::remove(
  self : SaveableStateStore,
  key : String,
) -> Unit {
  self.strings = self.strings.filter(entry => entry.key != key)
}

///|
fn parse_saveable_int(value : String) -> Int? {
  let chars = value.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut index = 0
  let mut sign = 1
  if chars[index] == '-' {
    sign = -1
    index = index + 1
  }
  if index >= chars.length() {
    return None
  }
  let mut parsed = 0
  while index < chars.length() {
    let char = chars[index]
    if !char.is_ascii_digit() {
      return None
    }
    parsed = parsed * 10 + char.to_int() - '0'.to_int()
    index = index + 1
  }
  Some(parsed * sign)
}

///|
pub fn BuildContext::save_string(
  self : BuildContext,
  key~ : String,
  value : String,
) -> Unit {
  self.save(key~, value, SaveableCodec::string())
}

///|
pub fn BuildContext::restore_string(
  self : BuildContext,
  key~ : String,
) -> String? {
  self.restore(key~, SaveableCodec::string())
}

///|
pub fn BuildContext::save_bool(
  self : BuildContext,
  key~ : String,
  value : Bool,
) -> Unit {
  self.save(key~, value, SaveableCodec::bool())
}

///|
pub fn BuildContext::restore_bool(self : BuildContext, key~ : String) -> Bool? {
  self.restore(key~, SaveableCodec::bool())
}

///|
pub fn BuildContext::save_int(
  self : BuildContext,
  key~ : String,
  value : Int,
) -> Unit {
  self.save(key~, value, SaveableCodec::int())
}

///|
pub fn BuildContext::restore_int(self : BuildContext, key~ : String) -> Int? {
  self.restore(key~, SaveableCodec::int())
}

///|
pub fn[T] BuildContext::save(
  self : BuildContext,
  key~ : String,
  value : T,
  codec : SaveableCodec[T],
) -> Unit {
  self.runtime.saveable_state.set(self.scoped_saveable_key(key), value, codec)
}

///|
pub fn[T] BuildContext::restore(
  self : BuildContext,
  key~ : String,
  codec : SaveableCodec[T],
) -> T? {
  self.runtime.saveable_state.get(self.scoped_saveable_key(key), codec)
}

///|
pub fn[T] BuildContext::saveable(
  self : BuildContext,
  key~ : String,
  initial : T,
  codec : SaveableCodec[T],
) -> State[T] {
  let scoped = self.scoped_saveable_key(key)
  let restored = self.runtime.saveable_state
    .get(scoped, codec)
    .unwrap_or(initial)
  let state = State::new(restored)
  let store = self.runtime.saveable_state
  let runtime = self.runtime
  let component_id = self.component_id
  ignore(
    state.subscribe(() => {
      store.set(scoped, state.get(), codec)
      runtime.request_component_rebuild(component_id)
    }),
  )
  store.set(scoped, state.get(), codec)
  state
}

///|
pub fn BuildContext::saveable_string(
  self : BuildContext,
  key~ : String,
  initial : String,
) -> State[String] {
  self.saveable(key~, initial, SaveableCodec::string())
}

///|
pub fn BuildContext::saveable_bool(
  self : BuildContext,
  key~ : String,
  initial : Bool,
) -> State[Bool] {
  self.saveable(key~, initial, SaveableCodec::bool())
}

///|
pub fn BuildContext::saveable_int(
  self : BuildContext,
  key~ : String,
  initial : Int,
) -> State[Int] {
  self.saveable(key~, initial, SaveableCodec::int())
}

///|
fn BuildContext::scoped_saveable_key(
  self : BuildContext,
  key : String,
) -> String {
  "\{self.component_id.value}:\{key}"
}
